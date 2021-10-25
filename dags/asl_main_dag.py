from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator
from airflow.providers.docker.operators.docker import DockerOperator
from airflow.operators.dummy import DummyOperator
from airflow.utils.trigger_rule import TriggerRule
from airflow.utils.task_group import TaskGroup
from operators.matlab_operator import MatlabOperator

from asl_utils.utils import get_docker_url

from docker.types import Mount
from datetime import datetime
import os
# from asl_utils.utils import get_asl_sessions, create_asl_downstream_dag, count_t1_images


def _set_dicom_source_path(**kwargs):
    # the path to the cdrom and the folder housing dicom files therein
    return '/media/schragelab/CDROM/a'


def _set_raw_staging_path(**kwargs):
    # this is where the dicom files will be sorted after reading from disk
    path = '/mnt/hgfs/bucket/asl/raw'
    os.makedirs(path, exist_ok=True)
    return path


def _set_proc_staging_path(**kwargs):
    path = '/mnt/hgfs/bucket/asl/proc'
    os.makedirs(path, exist_ok=True)
    return path


def _t1_scan_names() -> list:
    # include all variations of the T1 scan name between studies
    return [
        'axial',
        'madni'
    ]


def _asl_scan_names() -> list:
    # include all variations of the asl scan name between studies
    return [
        'contrast'
    ]


def _count_t1_images(*, path: str, **kwargs) -> str:
    # find t1 folder
    t1_folder = list(set(os.listdir(path)).intersection(_t1_scan_names()))
    file_count = len(os.listdir(os.path.join(path, t1_folder[0])))
    if file_count < 50:
        return 'reslice-t1'
    else:
        return 'dcm2niix'


def _get_asl_sessions(*, path: str, **kwargs) -> list:
    # find asl folders
    # todo: need to use wildcards as session time may be included in the directory name
    asl_name = list(set(os.listdir(path)).intersection(_asl_scan_names()))
    asl_folders = os.listdir(os.path.join(path, asl_name[0]))
    return asl_folders


def _count_asl_images(*, path: str, **kwargs) -> str:
    asl_count = len(os.listdir(path))
    if asl_count < 80:
        return ''
    else:
        return ''


def _dicom_sort(*, source: str, target: str, **kwargs):
    return 'dicom sorting...'


# todo: set default args dict
# todo: rename DAG after testing
with DAG('asl-main-dag', schedule_interval=None, start_date=datetime(2021, 8, 1), catchup=False) as dag:
    DOCKER_URL = get_docker_url()

    with TaskGroup(group_id='init') as init_tg:

        set_dicom_source_path = PythonOperator(
            task_id='set-dicom-source-path',
            python_callable=_set_dicom_source_path
        )

        set_raw_staging_path = PythonOperator(
            task_id='set-raw-staging-path',
            python_callable=_set_raw_staging_path
        )

        set_proc_staging_path = PythonOperator(
            task_id='set-proc-staging-path',
            python_callable=_set_proc_staging_path
        )

        dicom_sort = PythonOperator(
            task_id='dicom-sort',
            python_callable=_dicom_sort,
            op_kwargs={
                'source': "{{ ti.xcom_pull(task_ids='set-dicom-source-path') }}",
                'target': "{{ ti.xcom_pull(task_ids='set-raw-staging-path') }}"
            }
        )
        [set_dicom_source_path, set_raw_staging_path, set_proc_staging_path] >> dicom_sort

        get_subject_id = DummyOperator(
            task_id='get-subject-id'
        )
        dicom_sort >> get_subject_id

        get_t1_path = DummyOperator(
            task_id='get-t1-path'
        )
        dicom_sort >> get_t1_path

    with TaskGroup(group_id='t1') as t1_tg:
        count_t1_images = BranchPythonOperator(
            task_id='count-t1-images',
            python_callable=_count_t1_images,
            op_kwargs={
                'path': "{{ ti.xcom_pull(task_ids='set-raw-staging-path') }}"
            }
        )
        init_tg >> count_t1_images

        # todo: build a reslice command in one of the MRI programs...
        reslice_t1 = DummyOperator(
            task_id='reslice-t1',
        )
        count_t1_images >> reslice_t1

        # todo: get subject id from previous DAG or dicom metadata xcom
        # dcm2niix_outfile_name = 'foo.nii'
        # dcm2niix = DockerOperator(
        #     task_id='dcm2niix',
        #     image='asl/dcm2niix',
        #     # command='dcm2niix -f {{ params.file_name }} -o {{ params.output_dir }} {{ params.input_dir }}',
        #     command="""/bin/bash -c 'echo "{{ params.file_name }}">/data/in/xcom_file.txt; ls /data/in'""",
        #     api_version='auto',
        #     auto_remove=True,
        #     docker_url=DOCKER_URL,
        #     do_xcom_push=True,
        #     mounts=[Mount(target='/data/in', source='/home/schragelab/Desktop/t1', type='bind')],
        #     params={'file_name': 'test'}
        #     # params={'file_name': "{{ ti.xcom_pull(task_ids='init.get-subject-id') }}",
        #     #         'output_dir': '/data/out',
        #     #         'input_dir': '/data/in'},
        #     # mounts=[Mount('/data/in', "{{ ti.xcom_pull(task_ids='init.set-raw-location) }}"),
        #     #         Mount('/data/in', "{{ ti.xcom_pull(task_ids='init.set-staging-location) }}")]
        # )
        # [count_t1_images, reslice_t1] >> dcm2niix

    #     segment = MatlabOperator(
    #         task_id='segment-t1-image',
    #         matlab_function='sl_segment',
    #         m_dir=asl_processing_m_files_directory,
    #         op_args=[],
    #         op_kwargs={'nargout': 0}
    #         # params={'file': os.path.join(tmp_root_folder, dcm2niix_outfile_name)}
    #     )
    #
    #
    #     # following segmentation, by default SPM creates a few files prefaced with `c` for each tissue segmentation, a `y`
    #     # file for the deformation field, and a `*seg8*.mat` file for tissue volume matrix
    #     # therefore, it's best to keep to the default naming convention by spm to ensure the pipeline stays intact
    #     file_name = 'c1*'
    #     get_gray_matter_file = PythonOperator(
    #         task_id='get-gray-matter-file',
    #         python_callable=_get_file,
    #         op_args=[file_name, t1_proc_folder],
    #     )
    #     segment_t1_image >> get_gray_matter_file
    #
    #     file_name = 'y*'
    #     get_t1_deformation_field_file = BashOperator(
    #         task_id='get-t1-deforamtion-field-file',
    #         bash_command="find {{ params.path }} -type f -name {{ params.file_name }} -print",
    #         params={'path': t1_raw_folder,
    #                 'name': file_name}
    #     )
    #     segment_t1_image >> get_t1_deformation_field_file
    #
    #     seg8_file = 'seg8.mat'
    #     get_brain_volumes = MatlabOperator(
    #         task_id='get-brain-volumes',
    #         matlab_function='sl_get_brain_volumes',
    #         m_dir=asl_processing_m_files_directory,
    #         op_args=[],
    #         op_kwargs={'nargout': 0}
    #     )
    #     segment_t1_image >> get_brain_volumes
    #
    #     smooth = MatlabOperator(
    #         task_id='smooth',
    #         matlab_function='sl_smooth',
    #         m_dir=asl_processing_m_files_directory,
    #         op_args=[],
    #         op_kwargs={'nargout': 0}
    #     )
    #     [get_gray_matter_file, get_t1_deformation_field_file] >> smooth
    #
    # with TaskGroup(group_id='asl') as asl_tg:
    #     asl_sessions = _get_asl_sessions(path='path')
    #     # dynamically create tasks based on number of asl sessions
    #     for session in asl_sessions:
    #         # todo: make this branch
    #         count_asl_images = DummyOperator(
    #             task_id=f'count-asl-images-{session}'
    #         )
    #         # todo: set to depend on last t1 process
    #         dcm2niix >> count_asl_images
    #
    #         afni_to3d = DummyOperator(
    #             task_id=f'afni-to3d-{session}'
    #         )
    #         count_asl_images >> afni_to3d
    #
    #         pcasl = DummyOperator(
    #             task_id=f'3df-pcasl-{session}'
    #         )
    #         afni_to3d >> pcasl
    #
    #         # todo: make fmap and pdmap parallel
    #         afni_3dcalc_fmap = DummyOperator(
    #             task_id=f'afni-3dcalc-fmap-{session}'
    #         )
    #         pcasl >> afni_3dcalc_fmap
    #
    #         afni_3dcalc_pdmap = DummyOperator(
    #             task_id=f'afni-3dcalc-pdmap-{session}'
    #         )
    #         pcasl >> afni_3dcalc_pdmap
    #
