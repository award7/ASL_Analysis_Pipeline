from airflow import DAG
from airflow.operators.dummy import DummyOperator
from airflow.operators.python import PythonOperator, ShortCircuitOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.utils.task_group import TaskGroup
from airflow.utils.trigger_rule import TriggerRule
from operators.trigger_multi_dagrun import TriggerMultiDagRunOperator
from operators.docker_build_local_image_operator import DockerBuildLocalImageOperator
from operators.docker_remove_image import DockerRemoveImage
# from operators.custom_docker_operator import (
#     DockerBuildLocalImageOperator,
#     DockerRemoveImage
# )

from datetime import datetime
from utils.utils import (
    get_asl_sessions,
    get_dicom_field,
    check_for_scans,
    count_t1_images,
    count_asl_images,
    make_dir,
    rm_files,
    package_xcom_to_conf
)

# todo: set default args dict
# todo: rename DAG after testing
with DAG('asl-main-dag', schedule_interval=None, start_date=datetime(2021, 8, 1), catchup=False) as dag:
    with TaskGroup(group_id='init') as init_tg:
        # todo: put this in its own DAG which will essentially act as a trigger for this DAG
        _check_for_scans = ShortCircuitOperator(
            task_id='check-for-scans',
            python_callable=check_for_scans,
            op_kwargs={
                'path': "{{ var.value.asl_raw_path }}"
            }
        )

        _count_t1_images = PythonOperator(
            task_id='count-t1-images',
            python_callable=count_t1_images,
            op_kwargs={
                'path': "{{ var.value.asl_raw_path }}"
            }
        )
        _check_for_scans >> _count_t1_images

        _count_asl_images = PythonOperator(
            task_id='count-asl-images',
            python_callable=count_asl_images,
            op_kwargs={
                'root_path': "{{ var.value.asl_raw_path }}"
            }
        )
        _count_t1_images >> _count_asl_images

        get_protocol_name = PythonOperator(
            task_id='get-protocol-name',
            python_callable=get_dicom_field,
            op_kwargs={
                'path': "{{ ti.xcom_pull(task_ids='init.count-t1-images') }}",
                'field': 'ProtocolName'
            }
        )
        _count_asl_images >> get_protocol_name

        get_subject_id = PythonOperator(
            task_id='get-subject-id',
            python_callable=get_dicom_field,
            op_kwargs={
                'path': "{{ ti.xcom_pull(task_ids='init.count-t1-images') }}",
                'field': 'PatientName'
            }
        )
        _count_asl_images >> get_subject_id

        # this is where analyzed files (.nii, .BRIK, etc.) will be stored
        _make_proc_path = PythonOperator(
            task_id='make-proc-path',
            python_callable=make_dir,
            op_kwargs={
                'path': [
                    "{{ var.value.asl_proc_path }}",
                    "{{ ti.xcom_pull(task_ids='init.get-protocol-name') }}",
                    "{{ ti.xcom_pull(task_ids='init.get-subject-id') }}"
                ]
            }
        )
        [get_protocol_name, get_subject_id] >> _make_proc_path

        # to pass parameters to other DAGs, the parameters must be passed in the dag_run.conf dictionary
        package_variables_for_dags = PythonOperator(
            task_id='package-variables-for-dags',
            python_callable=package_xcom_to_conf,
            op_kwargs={
                't1_path': "{{ ti.xcom_pull(task_ids='init.count-t1-images') }}",
                'proc_path': "{{ ti.xcom_pull(task_ids='init.make-proc-path') }}",
                'subject_id': "{{ ti.xcom_pull(task_ids='get-subject-id') }}"
            }
        )
        _make_proc_path >> package_variables_for_dags

    with TaskGroup(group_id='build-docker-images') as docker_tg:
        build_dcm2niix_image = DockerBuildLocalImageOperator(
            task_id='build-dcm2niix-image',
            path="{{ var.value.dcm2niix_docker_image }}",
            tag="asl/dcm2niix",
            trigger_rule=TriggerRule.NONE_FAILED
        )
        _make_proc_path >> build_dcm2niix_image

        build_afni_image = DockerBuildLocalImageOperator(
            task_id='build-afni-image',
            path="{{ var.value.afni_docker_image }}",
            tag='asl/afni',
            trigger_rule=TriggerRule.NONE_FAILED
        )
        _make_proc_path >> build_afni_image

        build_fsl_image = DockerBuildLocalImageOperator(
            task_id='build-fsl-image',
            path="{{ var.value.fsl_docker_image }}",
            tag='asl/fsl',
            trigger_rule=TriggerRule.NONE_FAILED
        )
        _make_proc_path >> build_fsl_image

    with TaskGroup(group_id='t1-processing') as t1_tg:
        t1_processing = TriggerDagRunOperator(
            task_id='t1-processing-dag',
            trigger_dag_id='t1-processing',
            wait_for_completion=True
        )
        [build_dcm2niix_image, package_variables_for_dags] >> t1_processing

    with TaskGroup(group_id='perfusion-processing') as perfusion_tg:
        asl_perfusion_processing = DummyOperator(task_id='asl-processing')
        # asl_perfusion_processing = TriggerMultiDagRunOperator(
        #     task_id='asl-perfusion',
        #     trigger_dag_id='asl-perfusion-processing',
        #     python_callable=get_asl_sessions,
        #     op_kwargs={
        #         'path': "{{ var.value.asl_raw_path }}",
        #         'exclude': "{{ ti.xcom_pull(task_ids('init.count-asl-images') }}"
        #     },
        #     wait_for_completion=True
        # )
        [t1_processing, build_afni_image, build_fsl_image] >> asl_perfusion_processing

    with TaskGroup(group_id='cleanup') as cleanup_tg:
        remove_dcm2niix_image = DockerRemoveImage(
            task_id='remove-dcm2niix-image',
            image='asl/dcm2niix',
            trigger_rule=TriggerRule.ALL_DONE
        )
        t1_processing >> remove_dcm2niix_image

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

        remove_staged_files = DummyOperator(task_id='remove-staged-files')
        # remove_staged_files = PythonOperator(
        #     task_id='remove-staged-files',
        #     python_callable=rm_files,
        #     op_kwargs={
        #         'path': "{{ var.value.asl_raw_path }}"
        #     },
        #     trigger_rule=TriggerRule.NONE_FAILED_OR_SKIPPED,
        # )
        asl_perfusion_processing >> remove_staged_files

    with TaskGroup(group_id='errors') as errors_tg:
        # todo: make an email operator
        notify_about_error = DummyOperator(
            task_id='notify-about-error',
            trigger_rule=TriggerRule.ONE_FAILED
        )
        _count_asl_images >> notify_about_error >> get_protocol_name
