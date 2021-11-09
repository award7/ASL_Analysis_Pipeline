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
