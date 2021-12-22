import os
from glob import glob
from pydicom import read_file as dcm_read_file
from typing import Union, List, Generator, Dict
import logging
from pydicom.errors import InvalidDicomError
from shutil import rmtree

"""functions to be used in conjunction with asl* dags"""


def get_dicom_field(*, path: str, field: str, **kwargs) -> str:
    file = os.listdir(path)[0]
    dcm = dcm_read_file(os.path.join(path, file))
    return str(getattr(dcm, field))


def count_t1_images(*, path: Union[str, dict], **kwargs) -> None:
    """
    Count the number of raw T1 images. If the number is below a threshold then raise error; otherwise, continue.

    :param path: absolute path to raw T1 files
    :type path: str
    :return None
    """

    if isinstance(path, dict):
        path = path['raw']

    files_in_folder = os.listdir(path)
    dcm = dcm_read_file(os.path.join(path, files_in_folder[0]))
    images_in_acquisition = getattr(dcm, 'ImagesInAcquisition')
    file_count = len(files_in_folder)

    try:
        assert file_count == images_in_acquisition
    except AssertionError:
        raise ValueError(f"Insufficient T1 images in {path}. Images in acquisition is {images_in_acquisition} "
                         f"but only {file_count} were found.")


def count_asl_images(*, root_path: str, **kwargs) -> str:
    """

    :param root_path: absolute path to recursively search for asl files.
    :type root_path: str
    :return: None
    """

    potential_asl_names = _asl_scan_names()

    # get lowest directories to search for asl directories
    sessions = []
    for root, dirs, files in os.walk(root_path):
        if not dirs and any(name.lower() in root.lower() for name in potential_asl_names):
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
        # ti = kwargs['ti']
        # ti.xcom_push(key="bad_sessions", value=','.join([path[0] for path in bad_sessions.values()]))
        return 'errors.notify-about-error'
    return 'set-asl-sessions'


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


def make_dir(*, raw_path: str, proc_path: str, **kwargs) -> None:

    # ATW 12/22/2021: I had to do the xcom_pull here instead of templating at the task because my checks for a None on
    # the variables were not working
    ti = kwargs['ti']
    study_id = ti.xcom_pull(task_ids='setup.parse-visit-info', key='study_id')
    subject_id = ti.xcom_pull(task_ids='setup.parse-visit-info', key='subject_id')
    group_id = ti.xcom_pull(task_ids='setup.parse-visit-info', key='group_id')
    treatment_id = ti.xcom_pull(task_ids='setup.parse-visit-info', key='treatment_id')

    new_root_dir_name = f"{study_id}_{subject_id}"
    if group_id is not None:
        new_root_dir_name = f"{study_id}_{group_id}"

    new_root_dir_name = f"{new_root_dir_name}_{subject_id}"

    if treatment_id is not None:
        new_root_dir_name = f"{new_root_dir_name}_{treatment_id}"

    # t1
    raw_path_t1 = get_t1_path(path=raw_path)
    proc_path_t1 = os.path.join(proc_path, new_root_dir_name, 't1')

    ti.xcom_push(key='t1_raw', value=raw_path_t1)
    ti.xcom_push(key='t1_proc', value=proc_path_t1)
    os.makedirs(proc_path_t1, exist_ok=True)

    # asl
    sessions = order_asl_sessions(path=raw_path)

    for raw_session, proc_session in sessions.items():
        raw_path_asl = os.path.join(raw_path, raw_session)
        proc_path_asl = os.path.join(proc_path, new_root_dir_name, proc_session)

        ti.xcom_push(key=f"{proc_session}_raw", value=raw_path_asl)
        ti.xcom_push(key=f"{proc_session}_proc", value=proc_path_asl)

        os.makedirs(proc_path_asl, exist_ok=True)


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
    # rmtree(path)
    return


def _t1_scan_names() -> list:
    # include all variations of the T1 scan name between studies
    return [
        'Ax_T1',
        'mADNI3_T1',
        'FSPGR'
    ]


def _asl_scan_names() -> list:
    # include all variations of the asl scan name between studies
    return [
        'UW_eASL',
        '3D_ASL'
    ]


def get_t1_path(*, path: str, **kwargs) -> str:
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


def order_asl_sessions(*, path: str, **kwargs):
    d = {}
    scan_names = _asl_scan_names()
    for session in os.listdir(path):
        for scan in scan_names:
            if scan in session:
                dcm = dcm_read_file(os.path.join(path, session, 'Image_(0001).dcm'))
                d[session] = int(dcm.AcquisitionTime)

    # sort by time
    sorted_d = dict(sorted(d.items(), key=lambda item: item[1]))

    for idx, key in enumerate(sorted_d):
        sorted_d[key] = f"asl{idx}"

    return sorted_d


def parse_info(*, path: str, **kwargs):
    subject_directory = os.path.basename(path)

    # the naming convention depends on study but generally is:
    #   the first 4 characters/numbers are the study id (always)
    #   the character at index 5 is the group identifier (if applicable to study)
    #   if true:
    #       the characters at index 7-9 is the subject number
    #   else:
    #       the characters at index 5-7 is the subject number
    #   the last character is the treatment id

    group_id = None
    treatment_id = None

    study_id = subject_directory[0:4]
    if study_id == "0336":
        group_id = subject_directory[5]
        subject_id = subject_directory[7:10]
        if subject_directory[-1].isalpha():
            treatment_id = subject_directory[-1]
    elif study_id == "0361":
        subject_id = subject_directory[-3:]
    else:
        raise ValueError(f'Invalid study id: {study_id}')

    ti = kwargs['ti']
    ti.xcom_push(key="study_id", value=study_id)
    ti.xcom_push(key="subject_id", value=subject_id)
    ti.xcom_push(key="group_id", value=group_id)
    ti.xcom_push(key="treatment_id", value=treatment_id)


if __name__ == '__main__':
    study_id = "0336"
    subject_id = "020"
    group_id = "M"
    treatment_id=None
    raw_path = "/mnt/hgfs/bucket/asl/raw/0336_M_020"
    proc_path = "/mnt/hgfs/bucket/asl/proc"
    make_dir_v2(study_id=study_id, subject_id=subject_id, group_id=group_id, raw_path=raw_path, proc_path=proc_path, treatment_id=treatment_id)