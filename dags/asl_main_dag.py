from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.dummy import DummyOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator

from asl_analysis_pipeline.asl_utils.utils import get_docker_url
from custom.docker_xcom_operator import DockerXComOperator
from airflow.operators.python import BranchPythonOperator
from airflow_multi_dagrun.operators import TriggerMultiDagRunOperator
from airflow.utils.trigger_rule import TriggerRule
from airflow.utils.task_group import TaskGroup

from docker.types import Mount
from datetime import datetime
import os
# from asl_utils.utils import get_asl_sessions, create_asl_downstream_dag, count_t1_images


with DAG('asl-main-dag', schedule_interval=None, start_date=datetime(2021, 8, 1), catchup=False) as dag:
    DOCKER_URL = get_docker_url()

    with TaskGroup(group_id='init') as init_tg:
        set_raw_location = DummyOperator(
            task_id='set-raw-location'
        )

        set_staging_location = DummyOperator(
            task_id='set-staging-location'
        )

        dicom_sort = DummyOperator(
            task_id='dicom-sort'
        )
        [set_raw_location, set_staging_location] >> dicom_sort

        get_subject_id = DummyOperator(
            task_id='get-subject-id'
        )
        dicom_sort >> get_subject_id

    with TaskGroup(group_id='t1') as t1_tg:
        t1_image_count = DummyOperator(
            task_id='count-t1-images'
        )
        # t1_image_count = BranchPythonOperator(
        #     task_id='count-t1-images',
        #     python_callable=count_t1_images,
        #     op_args=["{{ ti.xcom_pull(task_ids='init.set-raw-location) }}", 50]
        # )
        [set_raw_location, set_staging_location, dicom_sort] >> t1_image_count

        # todo: build a reslice command in one of the MRI programs...
        reslice_t1 = DummyOperator(
            task_id='reslice-t1',
        )
        t1_image_count >> reslice_t1

        # todo: get subject id from previous DAG or dicom metadata xcom
        dcm2niix_outfile_name = 'foo.nii'
        dcm2niix = DockerXComOperator(
            task_id='dcm2niix',
            image='asl/dcm2niix',
            # command='dcm2niix -f {{ params.file_name }} -o {{ params.output_dir }} {{ params.input_dir }}',
            command='dcm2niix -f tmp -o /data/in /data/in',
            api_version='auto',
            auto_remove=False,
            docker_url=DOCKER_URL,
            # 2021-10-18: cannot figure out error:
            # docker.errors.APIError: 400 Client Error for http+docker://localhost/v1.41/containers/create: Bad Request ("create /home/schragelab/Desktop/t1: "/home/schragelab/Desktop/t1" includes invalid characters for a local volume name, only "[a-zA-Z0-9][a-zA-Z0-9_.-]" are allowed. If you intended to pass a host directory, use absolute path")

            mounts=[Mount('/data/in', '/home/schragelab/Desktop/t1')]
            # params={'file_name': "{{ ti.xcom_pull(task_ids='init.get-subject-id') }}",
            #         'output_dir': '/data/out',
            #         'input_dir': '/data/in'},
            # mounts=[Mount('/data/in', "{{ ti.xcom_pull(task_ids='init.set-raw-location) }}"),
            #         Mount('/data/in', "{{ ti.xcom_pull(task_ids='init.set-staging-location) }}")]
        )
        [t1_image_count, reslice_t1] >> dcm2niix
    #
    #     get_reconstructed_t1_file = PythonOperator(
    #         task_id='get-reconstructed-t1-file',
    #         python_callable=_get_file,
    #         op_args=[dcm2niix_outfile_name, t1_raw_folder]
    #     )
    #     dcm2niix >> get_reconstructed_t1_file
    #
    #     move_reconstructed_t1_file = PythonOperator(
    #         task_id='move-reconstructed-t1-file',
    #         python_callable=_move_file,
    #         op_args=[t1_raw_folder, t1_proc_folder, 'get-reconstructed-t1-file']
    #     )
    #     get_reconstructed_t1_file >> move_reconstructed_t1_file
    #
    #     segment_t1_image = MatlabOperator(
    #         task_id='segment-t1-image',
    #         matlab_function='sl_segment',
    #         m_dir=asl_processing_m_files_directory,
    #         op_args=[],
    #         op_kwargs={'nargout': 0}
    #         # params={'file': os.path.join(tmp_root_folder, dcm2niix_outfile_name)}
    #     )
    #     move_reconstructed_t1_file >> segment_t1_image
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
    #     asl_sessions = PythonOperator(
    #         task_id='get-asl-sessions',
    #         python_callable=get_asl_sessions,
    #         op_args=[tmp_root_folder]
    #         )
    #     dicom_sort >> asl_sessions
    #
    #     # trigger multiple asl_downstream DAGs, one for each ASL session
    #     asl_perfusion_processing = TriggerMultiDagRunOperator(
    #         task_id='asl-perfusion-processing',
    #         trigger_dag_id='asl-perfusion-dag',
    #         python_callable=create_asl_downstream_dag,
    #         op_args=tmp_root_folder,
    #         trigger_rule=TriggerRule.ALL_SUCCESS
    #         )
    #     [t1_processing, get_asl_sessions] >> asl_perfusion_processing
