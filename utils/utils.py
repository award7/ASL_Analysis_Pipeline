import os
from glob import glob
from pydicom import read_file as dcm_read_file
from typing import Union, List, Generator
import logging
from pydicom.errors import InvalidDicomError
from shutil import rmtree

"""functions to be used in conjunction with asl* dags"""


def get_dicom_field(*, path: str, field: str, **kwargs) -> str:
    file = os.listdir(path)[0]
    dcm = dcm_read_file(os.path.join(path, file))
    return str(getattr(dcm, field))


def check_for_scans(*, path: str, **kwargs) -> bool:
    # check for any folders in /bucket/asl/raw
    if os.listdir(path):
        return True
    else:
        return False


def count_t1_images(*, path: str, **kwargs) -> str:
    """
    Count the number of raw T1 images. If the number is below a threshold then raise error; otherwise, continue.

    :param path: absolute path to raw T1 files
    :type path: str
    :return None
    """
    t1_path = _get_t1_path(path=path, **kwargs)

    files_in_folder = os.listdir(t1_path)
    dcm = dcm_read_file(os.path.join(t1_path, files_in_folder[0]))
    images_in_acquisition = getattr(dcm, 'ImagesInAcquisition')
    file_count = len(files_in_folder)

    try:
        assert file_count == images_in_acquisition
        return t1_path
    except AssertionError:
        raise ValueError(f"Insufficient T1 images in {t1_path}. Images in acquisition is {images_in_acquisition} but "
                         f"only {file_count} were found.")


def rename_asl_sessions(*, path: str, **kwargs) -> None:
    potential_asl_names = _asl_scan_names()
    sessions = []
    for root, dirs, files in os.walk(path):
        if not dirs and any(name in root for name in potential_asl_names):
            sessions.append(root)

    sessions.sort()
    for idx, session in enumerate(sessions):
        os.rename(session, os.path.join(os.path.dirname(session), f'asl{idx}'))

    # return the number of directories that were renamed
    return idx + 1


def count_asl_images(*, root_path: str, **kwargs) -> None:
    """

    :param root_path: absolute path to recursively search for asl files.
    :type root_path: str
    :return: None
    """

    potential_asl_names = _asl_scan_names()

    # get lowest directories to search for asl directories
    sessions = []
    for root, dirs, files in os.walk(root_path):
        if not dirs and any(name in root for name in potential_asl_names):
            sessions.append(root)

    bad_sessions = {}
    for idx, path in enumerate(sessions):
        files_in_folder = os.listdir(path)
        dcm = dcm_read_file(os.path.join(path, files_in_folder[0]))
        images_in_acquisition = getattr(dcm, 'ImagesInAcquisition')
        file_count = len(files_in_folder)

        if file_count < images_in_acquisition:
            bad_sessions[f'session{idx}'] = [path, file_count, images_in_acquisition]

    if len(bad_sessions) > 0:
        error_string = ""
        for key, val in bad_sessions.items():
            error_string = f"{error_string}" \
                           f"Insufficient ASL images in {bad_sessions[key][0]}. Images in acquisition is " \
                           f"{bad_sessions[key][2]} but only {bad_sessions[key][1]} were found. " \
                           f"{os.linesep}"
        ti = kwargs['ti']
        ti.xcom_push(key="bad_sessions", value=','.join([path[0] for path in bad_sessions.values()]))
        return 'errors.notify-about-error'
    return 'get-subject-id'


def get_file(*, path: str, search: str, **kwargs) -> str:
    """
    Get file using glob and push actual file name to xcom with the associated key

    :param path: absolute path to search for `file_name`
    :type path: str
    :param search: file name to search for. Can be exact or with wildcards
    :type search: str
    :return: file name found that is pushed to xcom
    :rtype: str
    """

    files = glob(os.path.join(path, search))
    if len(files) < 1:
        FileExistsError(f"No files found in {path} that match the search term {search}")
    if len(files) > 1:
        FileExistsError(f"Multiple files found in {path} that match the search term {search}:\n"
                        f"{files}")
    return files[0]


def make_dir(*, path: Union[str, List[str]], **kwargs) -> str:
    if isinstance(path, list):
        _path = ""
        for item in path:
            _path = os.path.join(_path, item)
        path = _path
    os.makedirs(path, exist_ok=True)
    return path


def get_asl_sessions(*, path: str, exclude: str = None, **kwargs) -> Generator:
    """
    find asl folders to trigger multiple asl-perfusion-processing dags
    :param path: is the target path for the dicom sorting
    :type path: str
    :param exclude: any paths to exclude
    :type exclude: list
    """

    potential_asl_names = _asl_scan_names()
    if exclude:
        exclude = exclude.split(',')

    # get lowest directories to search for asl directories
    for root, dirs, files in os.walk(path):
        if not dirs and any(name in root for name in potential_asl_names):
            if exclude is not None and root in exclude:
                continue
            session_number = os.path.join(kwargs['asl_proc_path'], os.path.basename(root))
            yield {
                'session': root,
                'asl_proc_path': asl_proc_path
            }


def get_docker_url() -> str:
    return "unix://var/run/docker.sock"


def get_mask_count(*, path: str, **kwargs) -> int:
    return len(os.listdir(path))


def rm_files(*, path: str, **kwargs) -> None:
    """
    remove folders and/or files from path

    :param path: absolute path to folders/files to delete
    :type path: str
    :param kwargs: keyword args for airflow conf
    :return: None
    """
    rmtree(path)


def _t1_scan_names() -> list:
    # include all variations of the T1 scan name between studies
    return [
        'Ax_T1_Bravo_3mm',
        'mADNI3_T1'
    ]


def _asl_scan_names() -> list:
    # include all variations of the asl scan name between studies
    return [
        'UW_eASL',
        '3D_ASL'
    ]


def _get_t1_path(*, path: str, **kwargs) -> str:
    potential_t1_names = _t1_scan_names()

    # get lowest directories to search for t1 directories
    t1_paths = []
    for root, dirs, files in os.walk(path):
        if not dirs and any(name in root for name in potential_t1_names):
            t1_paths.append(root)

    if len(t1_paths) < 1:
        raise FileNotFoundError(f"No directories matching a T1 session in {path}")

    # if there's more than one t1 directory found, get each scan's acquisition time and return the scan with the most
    # recent time stamp
    if len(t1_paths) > 1:
        d = {}
        for path in t1_paths:
            dcm = dcm_read_file(os.path.join(path, os.listdir(path)[0]))
            d[path] = getattr(dcm, 'AcquisitionTime')

        sorted_d = {k: v for k, v in sorted(d.items(), key=lambda item: item[1])}
        t1_paths = next(iter(sorted_d))
        return t1_paths
    return t1_paths[0]
