from airflow import DAG
from airflow.operators.dummy import DummyOperator
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator, BranchPythonOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.utils.task_group import TaskGroup
from airflow.utils.trigger_rule import TriggerRule
from operators.trigger_multi_dagrun import TriggerMultiDagRunOperator
from operators.custom_docker_operator import (
    DockerBuildLocalImageOperator,
)

from datetime import datetime
from utils.utils import (
    get_dicom_field,
    count_t1_images,
    count_asl_images,
    rm_files,
    rename_asl_sessions
)

# todo: set default args dict
# todo: rename DAG after testing
with DAG('asl-main-dag', schedule_interval=None, start_date=datetime(2021, 8, 1), catchup=False) as dag:
    with TaskGroup(group_id='init') as init_tg:
        _count_t1_images = PythonOperator(
            task_id='count-t1-images',
            python_callable=count_t1_images,
            op_kwargs={
                'path': "{{ dag_run.conf['directory_or_file'] }}"
            }
        )

        _count_asl_images = BranchPythonOperator(
            task_id='count-asl-images',
            python_callable=count_asl_images,
            op_kwargs={
                'root_path': "{{ dag_run.conf['directory_or_file'] }}"
            }
        )
        _count_t1_images >> _count_asl_images

        rename_asl_sessions = PythonOperator(
            task_id='rename-asl-sessions',
            python_callable=rename_asl_sessions,
            op_kwargs={
                'path': "{{ dag_run.conf['directory_or_file'] }}"
            },
            trigger_rule=TriggerRule.ONE_SUCCESS
        )
        _count_asl_images >> rename_asl_sessions

        get_protocol_name = PythonOperator(
            task_id='get-protocol-name',
            python_callable=get_dicom_field,
            op_kwargs={
                'path': "{{ ti.xcom_pull(task_ids='init.count-t1-images') }}",
                'field': 'ProtocolName'
            }
        )
        rename_asl_sessions >> get_protocol_name

        get_subject_id = PythonOperator(
            task_id='get-subject-id',
            python_callable=get_dicom_field,
            op_kwargs={
                'path': "{{ ti.xcom_pull(task_ids='init.count-t1-images') }}",
                'field': 'PatientName'
            }
        )
        rename_asl_sessions >> get_subject_id

    with TaskGroup(group_id='build-docker-images') as docker_tg:
        build_dcm2niix_image = DockerBuildLocalImageOperator(
            task_id='build-dcm2niix-image',
            path="{{ var.value.dcm2niix_docker_image }}",
            tag="asl/dcm2niix",
            trigger_rule=TriggerRule.NONE_FAILED
        )
        get_subject_id >> build_dcm2niix_image

        build_afni_image = DockerBuildLocalImageOperator(
            task_id='build-afni-image',
            path="{{ var.value.afni_docker_image }}",
            tag='asl/afni',
            trigger_rule=TriggerRule.NONE_FAILED
        )

    with TaskGroup(group_id='t1-processing') as t1_tg:
        t1_processing = TriggerDagRunOperator(
            task_id='t1-processing-dag',
            trigger_dag_id='t1-processing',
            wait_for_completion=True,
            conf={
                't1_raw_path': "{{ ti.xcom_pull(task_ids='init.count-t1-images') }}",
                't1_proc_path': "{{ ti.xcom_pull(task_ids='init.make-proc-t1-path') }}",
                'subject_id': "{{ ti.xcom_pull(task_ids='init.get-subject-id') }}"
            }
        )
        build_dcm2niix_image >> t1_processing
        t1_processing >> build_afni_image

    with TaskGroup(group_id='perfusion-processing') as perfusion_tg:
        FIND_FILE_COMMAND = """echo $(find {{ params.path }} -type f -name {{ params.file }})"""

        get_gm_image = BashOperator(
            task_id='get-gm-image',
            bash_command=FIND_FILE_COMMAND,
            params={
                "path": "{{ ti.xcom_pull(task_ids='init.make-proc-t1-path') }}",
                "file": "sc1*.nii"
            }
        )
        t1_processing >> get_gm_image

        get_smoothed_gm_image = BashOperator(
            task_id='get-smoothed-gm-image',
            bash_command=FIND_FILE_COMMAND,
            params={
                "path": "{{ ti.xcom_pull(task_ids='init.make-proc-t1-path') }}",
                "file": "sc1*.nii"
            }
        )
        t1_processing >> get_smoothed_gm_image

        get_t1_deformation_field = BashOperator(
            task_id='get-t1-deformation-field',
            bash_command="""echo $(find {{ params.path }} -type f -name {{ params.file }}"""
        )
        t1_processing >> get_t1_deformation_field

        asl_perfusion_processing = DummyOperator(
            task_id='asl-perfusion'
        )
        # asl_perfusion_processing = TriggerMultiDagRunOperator(
        #     task_id='asl-perfusion',
        #     trigger_dag_id='asl-perfusion-processing',
        #     python_callable=get_asl_sessions,
        #     op_kwargs={
        #         'path': "{{ dag_run.conf['directory_or_file'] }}",
        #         'asl_proc_path': "{{ var.value.asl_proc_path }}/{{ ti.xcom_pull(task_ids='init.get-subject-id') }}"
        #     },
        #     wait_for_completion=True,
        #     conf={

        #     }
        # )
        [t1_processing, build_afni_image, get_gm_image,
         get_smoothed_gm_image, get_t1_deformation_field] >> asl_perfusion_processing

    with TaskGroup(group_id='cleanup') as cleanup_tg:
        remove_staged_files = PythonOperator(
            task_id='remove-staged-files',
            python_callable=rm_files,
            op_kwargs={
                'path': "{{ var.value.asl_raw_path }}"
            },
            trigger_rule=TriggerRule.NONE_FAILED_OR_SKIPPED
        )
        asl_perfusion_processing >> remove_staged_files

    with TaskGroup(group_id='errors') as errors_tg:
        # todo: make an email operator
        notify_about_error = DummyOperator(
            task_id='notify-about-error',
            trigger_rule=TriggerRule.ONE_FAILED
        )
        [_count_t1_images, _count_asl_images] >> notify_about_error >> rename_asl_sessions
