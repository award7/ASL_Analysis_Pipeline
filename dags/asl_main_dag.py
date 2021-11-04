from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator, ShortCircuitOperator
from operators.docker_remove_image import DockerRemoveImage
from operators.docker_build_local_image_operator import DockerBuildLocalImageOperator
from operators.trigger_multi_dagrun import TriggerMultiDagRunOperator
from airflow.operators.dummy import DummyOperator
from airflow.utils.task_group import TaskGroup
from airflow.utils.trigger_rule import TriggerRule

from pydicom import read_file as dcm_read_file
from pydicom.errors import InvalidDicomError
from datetime import datetime
import os
from glob import glob
from typing import Union, List
import logging


def _make_dir(*, path: Union[str, List[str]], **kwargs) -> str:
    if isinstance(path, list):
        _path = ""
        for item in path:
            _path = os.path.join(_path, item)
        path = _path
    os.makedirs(path, exist_ok=True)
    return path


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
            dcm = dcm_read_file(os.listdir(path)[0])
            d[path] = getattr(dcm, 'AcquisitionTime')

        sorted_d = {k: v for k, v in sorted(d.items(), key=lambda item: item[1])}
        t1_paths = next(iter(sorted_d))
    return t1_paths[0]


def _get_asl_sessions(*, path: str, **kwargs) -> list:
    """
    find asl folders to trigger multiple asl-perfusion-processing dags
    :param is the target path for the dicom sorting
    """
    potential_asl_names = _asl_scan_names()

    # get lowest directories to search for asl directories
    for root, dirs, files in os.walk(path):
        if not dirs and any(name in root for name in potential_asl_names):
            yield{'session': root}


def _count_asl_images(*, root_path: str, **kwargs) -> str:
    """

    :param path:
    :param success_task_id:
    :param kwargs:
    :return:
    """

    sessions = _get_asl_sessions(path=root_path)
    bad_sessions = []
    for path in sessions:
        files_in_folder = os.listdir(path)
        dcm = dcm_read_file(files_in_folder[0])
        images_in_acquisition = getattr(dcm, 'ImagesInAcquisition')
        file_count = len(files_in_folder)

        if file_count < images_in_acquisition:
            bad_sessions.append(path)

    if len(bad_sessions) > 1:
        ti = kwargs['ti']
        for idx, session in enumerate(bad_sessions):
            ti.xcom_push(key=f"bad_asl_session{idx}", value=session)
        return 'notify-bad-sessions'
    return 'make-proc-path'


def _get_study_date(*, path: str, **kwargs) -> str:
    file = os.listdir(path)[0]
    dcm = dcm_read_file(file)
    return getattr(dcm, 'AcquisitionDate')


def _get_protocol_name(*, path: str, **kwargs) -> None:
    file = os.listdir(path)[0]
    dcm = dcm_read_file(file)
    return getattr(dcm, 'ProtocolName')


def _count_t1_images(*, path: str, **kwargs) -> None:
    files_in_folder = os.listdir(path)
    dcm = dcm_read_file(os.path.join(path, files_in_folder[0]))
    images_in_acquisition = getattr(dcm, 'ImagesInAcquisition')
    file_count = len(files_in_folder)

    try:
        assert file_count == images_in_acquisition
    except AssertionError:
        raise ValueError(f"Insufficient T1 images in {path}. Images in acquisition is {images_in_acquisition} but only"
                         f"{file_count} were found.")


def _get_subject_id(*, path: str, **kwargs) -> str:
    files = os.listdir(path)
    dcm = dcm_read_file(os.path.join(path, files[0]))
    subject_id = str(getattr(dcm, 'PatientName')).replace('-', '_')
    return subject_id


def _check_for_scans(*, path: str, **kwargs) -> bool:
    # check for any folders in /bucket/asl/raw and if any are found, check the contents for t1 scan, asl scan(s), and
    # dicom images, in order
    # fail at any check so the pipeline is skipped
    if os.listdir(path):
        try:
            t1_path = _get_t1_path(path=path)
        except FileNotFoundError:
            return False

        try:
            asl_sessions = _get_asl_sessions(path=path)
            asl_lst = []
            for session in asl_sessions:
                asl_lst.append(session)
            assert len(asl_lst) > 1
        except FileNotFoundError or AssertionError:
            return False

        try:
            t1_contents = os.listdir(t1_path)
            assert len(t1_contents) > 1
            dcm_read_file(t1_contents[0])
        except InvalidDicomError:
            logging.error(f"No DICOM files were found in {path}. Ensure DicomSort finished and that no other files "
                          f"exist in this directory.")
            return False

        try:
            for session in asl_lst:
                contents = os.listdir(session)
                assert len(contents) > 1
                dcm_read_file(contents[0])
        except InvalidDicomError or AssertionError:
            return False

        ti = kwargs['ti']
        ti.xcom_push(key="t1_path", value=t1_path)
        return True


def _get_file(*, path: str, search: str, **kwargs) -> str:
    glob_string = os.path.join(path, search)
    file = glob(glob_string)
    if len(file) > 1:
        raise ValueError("Too many files found")
    return file[0]


# todo: set default args dict
# todo: rename DAG after testing
with DAG('asl-main-dag', schedule_interval='@daily', start_date=datetime(2021, 8, 1), catchup=False) as dag:
    with TaskGroup(group_id='init') as init_tg:
        check_for_scans = ShortCircuitOperator(
            task_id='check-for-scans',
            python_callable=_check_for_scans,
            op_kwargs={
                'path': "{{ var.value.asl_raw_path }}"
            }
        )

        count_t1_images = BranchPythonOperator(
            task_id='count-t1-images',
            python_callable=_count_t1_images,
            op_kwargs={
                'path': "{{ ti.xcom_pull(task_ids='init.get-t1-path') }}"
            }
        )

        count_asl_images = BranchPythonOperator(
            task_id='count-asl-images',
            python_callable=_count_asl_images,
            op_kwargs={
                'root_path': "{{ var.value.asl_raw_path }}"
            }
        )

        get_subject_id = PythonOperator(
            task_id='get-subject-id',
            python_callable=_get_subject_id,
            op_kwargs={
                'path': "{{ var.value.disk_drive }}"
            }
        )

        # this is where analyzed files (.nii, .BRIK, etc.) will be stored
        make_proc_path = PythonOperator(
            task_id='make-proc-path',
            python_callable=_make_dir,
            op_kwargs={
                'path': [
                    "{{ var.value.asl_proc_path }}",
                    "{{ ti.xcom_pull(task_ids='init.get-subject-id') }}"
                ]
            }
        )


    with TaskGroup(group_id='perfusion') as perfusion_tg:
        asl_perfusion_processing = TriggerMultiDagRunOperator(
            task_id='asl-perfusion',
            trigger_dag_id='asl-perfusion-processing',
            python_callable='',
            wait_for_completion=True
        )
        smooth_gm >> asl_perfusion_processing

    with TaskGroup(group_id='cleanup') as cleanup_tg:
        remove_dcm2niix_image = DockerRemoveImage(
            task_id='remove-dcm2niix-image',
            image='asl/dcm2niix',
            trigger_rule=TriggerRule.ALL_DONE
        )
        dcm2niix >> remove_dcm2niix_image

        remove_afni_image = DockerRemoveImage(
            task_id='remove-afni-image',
            image='asl/afni',
            trigger_rule=TriggerRule.ALL_DONE
        )
        asl_perfusion_processing >> remove_afni_image

        remove_fsl_image = DockerRemoveImage(
            task_id='remove-fsl-image',
            image='asl/fsl',
            trigger_rule=TriggerRule.ALL_DONE
        )
        asl_perfusion_processing >> remove_fsl_image

        # todo: change to python operator
        remove_staged_files = DummyOperator(
            task_id='remove-staged-files',
            trigger_rule=TriggerRule.ALL_DONE
        )
        asl_perfusion_processing >> remove_staged_files
