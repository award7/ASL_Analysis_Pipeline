from airflow import DAG
from operators.matlab_operator import MatlabOperator
from airflow.operators.python import PythonOperator, ShortCircuitOperator, BranchPythonOperator
from operators.docker_templated_mounts_operator import DockerTemplatedMountsOperator
from operators.docker_build_local_image_operator import DockerBuildLocalImageOperator
from operators.docker_remove_image import DockerRemoveImage
from airflow.utils.trigger_rule import TriggerRule
from airflow.operators.dummy import DummyOperator
from airflow.utils.task_group import TaskGroup
from airflow.models import Variable
from datetime import datetime
import os
from pydicom import read_file as dcm_read_file
from glob import glob
import matlab


def _get_subject_id(*, path: str, **kwargs) -> str:
    files = os.listdir(path)
    dcm = dcm_read_file(os.path.join(path, files[0]))
    subject_id = str(getattr(dcm, 'PatientName')).replace('-', '_')
    return subject_id


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


def _get_asl_sessions(*, path: str, **kwargs) -> bool:
    """
    find asl folders
    :param is the target path for the dicom sorting
    """
    potential_asl_names = _asl_scan_names()

    # get lowest directories to search for asl directories
    asl_paths = []
    for root, dirs, files in os.walk(path):
        if not dirs and any(name in root for name in potential_asl_names):
            asl_paths.append(root)

    if asl_paths:
        # set to airflow variable for dynamic task generation
        Variable.set("asl_sessions", len(asl_paths))

        # return paths for xcom
        ti = kwargs['ti']
        for idx, path in enumerate(asl_paths):
            ti.xcom_push(key=f"path{idx}", value=path)
        return True
    else:
        return False


def _count_t1_images(*, path: str, **kwargs) -> str:
    files_in_folder = os.listdir(path)
    dcm = dcm_read_file(os.path.join(path, files_in_folder[0]))
    images_in_acquisition = getattr(dcm, 'ImagesInAcquisition')
    file_count = len(files_in_folder)

    if file_count < images_in_acquisition:
        return 'reslice-t1'
    else:
        return 't1.build-dcm2niix-image'


def _get_file(*, path: str, search: str, **kwargs) -> str:
    glob_string = os.path.join(path, search)
    file = glob(glob_string)
    if len(file) > 1:
        raise ValueError("Too many files found")
    return file[0]


default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email': ['award7@wisc.edu.com'],
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 0,
    'retry_delay': None,
    # 'queue': 'bash_queue',
    # 'pool': 'backfill',
    # 'priority_weight': 10,
    # 'end_date': datetime(2016, 1, 1),
    # 'wait_for_downstream': False,
    # 'dag': dag,
    # 'sla': timedelta(hours=2),
    # 'execution_timeout': timedelta(seconds=300),
    # 'on_failure_callback': some_function,
    # 'on_success_callback': some_other_function,
    # 'on_retry_callback': another_function,
    # 'sla_miss_callback': yet_another_function,
    # 'trigger_rule': 'all_success'
}


with DAG(dag_id='tmp', schedule_interval='@daily', start_date=datetime(2021, 8, 1), catchup=False) as dag:
    with TaskGroup(group_id='init') as init_tg:

        get_asl_sessions = ShortCircuitOperator(
            task_id='get-asl-sessions',
            python_callable=_get_asl_sessions,
            op_kwargs={
                'path': "{{ var.value.asl_raw_path }}"
            }
        )

        get_t1_path = PythonOperator(
            task_id='get-t1-path',
            python_callable=_get_t1_path,
            op_kwargs={
                'path': "{{ var.value.asl_raw_path }}"
            }
        )
        get_asl_sessions >> get_t1_path

        get_subject_id = PythonOperator(
            task_id='get-subject-id',
            python_callable=_get_subject_id,
            op_kwargs={
                'path': "{{ ti.xcom_pull(task_ids='init.get-t1-path') }}"
            }
        )
        get_t1_path >> get_subject_id

    with TaskGroup(group_id='t1') as t1_tg:
        # count_t1_images = BranchPythonOperator(
        #     task_id='count-t1-images',
        #     python_callable=_count_t1_images,
        #     op_kwargs={
        #         'path': "{{ ti.xcom_pull(task_ids='init.get-t1-path') }}"
        #     }
        # )
        # init_tg >> count_t1_images
        #
        # # todo: build a reslice command in one of the MRI programs...
        # reslice_t1 = DummyOperator(
        #     task_id='reslice-t1',
        # )
        # count_t1_images >> reslice_t1
        #
        # build_dcm2niix_image = DockerBuildLocalImageOperator(
        #     task_id='build-dcm2niix-image',
        #     path="{{ var.value.dcm2niix_docker_image }}",
        #     tag="asl/dcm2niix",
        #     trigger_rule=TriggerRule.NONE_FAILED
        # )
        # [count_t1_images, reslice_t1] >> build_dcm2niix_image
        #
        # dcm2niix = DockerTemplatedMountsOperator(
        #     task_id='dcm2niix',
        #     image='asl/dcm2niix',
        #     # this command calls a bash shell ->
        #     # calls dcm2niix program (filename being protocol_name_timestamp) and outputs to the /tmp directory on the
        #     #     container ->
        #     # find the .nii file that was created and save the name to a variable ->
        #     # move the created files from /tmp to the mounted directory /out ->
        #     # clear the stdout ->
        #     # echo the filename to stdout so it will be returned as the xcom value
        #     command="""/bin/sh -c \'dcm2niix -f %p_%n_%t -o /tmp /in; clear; file=$(find ./tmp -name "*.nii" -type f); mv /tmp/* /out; clear; echo "${file##*/}"\'""",
        #     mounts=[
        #         {
        #             'target': '/in',
        #             'source': "{{ ti.xcom_pull(task_ids='init.get-t1-path') }}",
        #             'type': 'bind'
        #         },
        #         {
        #             'target': '/out',
        #             'source': "{{ var.value.asl_proc_path }}",
        #             'type': 'bind'
        #         },
        #     ],
        #     auto_remove=True,
        #     do_xcom_push=True
        # )
        # build_dcm2niix_image >> dcm2niix
        #
        # segment_t1 = MatlabOperator(
        #     task_id='segment-t1-image',
        #     matlab_function='segment_t1',
        #     matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
        #     op_args=[
        #         "{{ var.value.asl_proc_path }}/{{ ti.xcom_pull(task_ids='t1.dcm2niix') }}"
        #     ]
        # )
        # dcm2niix >> segment_t1

        get_gm_file = PythonOperator(
            task_id='get-gm-file',
            python_callable=_get_file,
            op_kwargs={
                'path': "{{ var.value.asl_proc_path }}",
                'search': "c1*"
            }
        )
        # segment_t1 >> get_gm_file
        get_subject_id >> get_gm_file

        get_seg8mat_file = PythonOperator(
            task_id='get-seg8mat-file',
            python_callable=_get_file,
            op_kwargs={
                'path': "{{ var.value.asl_proc_path }}",
                'search': "*seg8.mat"
            }
        )
        # segment_t1 >> get_seg8mat_file
        get_subject_id >> get_seg8mat_file

        get_forward_deformation_file = PythonOperator(
            task_id='get-forward_deformation-file',
            python_callable=_get_file,
            op_kwargs={
                'path': "{{ var.value.asl_proc_path }}",
                'search': "y*"
            }
        )
        # segment_t1 >> get_forward_deformation_file
        get_subject_id >> get_forward_deformation_file

        smooth_gm = MatlabOperator(
            task_id='smooth',
            matlab_function='smooth_t1',
            matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
            op_args=["{{ ti.xcom_pull(task_ids='t1.get-gm-file') }}"],
            op_kwargs={
                'fwhm': matlab.double([8, 8, 8])
            }
        )
        get_gm_file >> smooth_gm

        get_brain_volumes = MatlabOperator(
            task_id='get-brain-volumes',
            matlab_function='brain_volumes',
            matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
            op_args=["{{ ti.xcom_pull(task_ids='t1.get-seg8mat-file') }}"],
            op_kwargs={
                'subject': "{{ ti.xcom_pull(task_ids='init.get-subject-id') }}"
            }
        )
        get_seg8mat_file >> get_brain_volumes

    # with TaskGroup(group_id='cleanup') as cleanup_tg:
    #     remove_dcm2niix_image = DockerRemoveImage(
    #         task_id='remove-dcm2niix-image',
    #         image='asl/dcm2niix',
    #         force=True,
    #         trigger_rule=TriggerRule.ALL_DONE
    #     )
    #     dcm2niix >> remove_dcm2niix_image
