from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from operators.matlab_operator import MatlabOperator
from airflow.operators.dummy import DummyOperator
from airflow.utils.task_group import TaskGroup
import matlab
from datetime import datetime
from utils.utils import (
    parse_info,
    make_dir
)

default_args = {
    'email': 'award7@wisc.edu',
    'email_on_failure': False
}


def _get_payload(**kwargs):
    dag_run = kwargs['dag_run']
    dag_run.conf.update({'payload': 'foo_bar'})


def log_payload(**kwargs):
    dag_run = kwargs['dag_run']
    print(f"payload = {dag_run.conf.get('payload')}")


with DAG(dag_id='test', default_args=default_args, start_date=datetime(2021, 8, 1), catchup=False) as dag:
    get_payload = PythonOperator(
        task_id='get-payload',
        python_callable=_get_payload
    )

    parent = TriggerDagRunOperator(
        task_id='parent',
        trigger_dag_id='test-child',
        conf={
            "payload": "{{ dag_run.conf.get('payload') }}"
        },
    )
    get_payload >> parent

with DAG('test-child', default_args=default_args, start_date=datetime(2021, 8, 1), catchup=False) as child_dag:
    child = PythonOperator(
        task_id='child',
        python_callable=log_payload
    )

    with TaskGroup(group_id='setup') as setup_tg:
        parse_visit_info = PythonOperator(
            task_id='parse-visit-info',
            python_callable=parse_info,
            op_kwargs={
                'path': "{{ dag_run.conf['payload'] }}"
            }
        )

        set_scan_paths = PythonOperator(
            task_id='set-scan-paths',
            python_callable=make_dir,
            op_kwargs={
                'raw_path': "{{ dag_run.conf['payload'] }}",
                'proc_path': "{{ var.value.asl_proc_path }}"
            }
        )
        parse_visit_info >> set_scan_paths

    with TaskGroup(group_id='t1-processing') as t1_tg:
        dcm2niix = BashOperator(
            task_id='dcm2niix',
            bash_command="/home/schragelab/airflow/dags/asl_analysis_pipeline/shell/runDcm2nii.bash {{ ti.xcom_pull(task_ids='setup.set-scan-paths', key='t1_proc') }} {{ ti.xcom_pull(task_ids='setup.set-scan-paths', key='t1_raw') }} ",
            do_xcom_push=True
        )
        set_scan_paths >> dcm2niix

        """ 
        following segmentation, by default SPM creates a few files prefaced with `c` for each tissue segmentation, a `y`
        file for the deformation field, and a `*seg8*.mat` file for tissue volume matrix
        therefore, it's best to keep to the default naming convention by spm to ensure the pipeline stays intact

        the xcom keys from segment_t1.m are:
        return_value0 = bias-corrected image (m*)
        return_value1 = forward deformation image (y*)
        return_value2 = segmentation parameters (*seg8.mat)
        return_value3 = gray matter image (c1*)
        return_value4 = white matter image (c2*)
        return_value5 = csf image (c3*)
        return_value6 = skull image (c4*)
        return_value7 = soft tissue image (c5*)

        to get a specific image into an xcom, ensure that the nargout parameter will encompass the index of the image. 
        E.g. to get the csf image, nargout must be at least 6.
        """

        segment_t1 = MatlabOperator(
            task_id='segment-t1-image',
            matlab_function='segment_t1',
            matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
            op_args=[
                "{{ ti.xcom_pull(task_ids='t1-processing.dcm2niix') }}",
            ],
            nargout=4
        )
        dcm2niix >> segment_t1

        get_brain_volumes = MatlabOperator(
            task_id='get-brain-volumes',
            matlab_function='brain_volumes',
            matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
            op_args=["{{ ti.xcom_pull(task_ids='t1-processing.segment-t1-image', key='return_value2') }}"],
            op_kwargs={
                'subject': "{{ ti.xcom_pull(task_ids='setup.parse-visit-info', key='subject_id') }}"
            },
            nargout=1
        )
        segment_t1 >> get_brain_volumes

        smooth_gm = MatlabOperator(
            task_id='smooth',
            matlab_function='smooth_t1',
            matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
            op_args=[
                "{{ ti.xcom_pull(task_ids='t1-processing.segment-t1-image', key='return_value3') }}"
            ],
            op_kwargs={
                'fwhm': matlab.double([5, 5, 5])
            },
            nargout=1
        )
        segment_t1 >> smooth_gm

        apply_icv_mask = MatlabOperator(
            task_id='apply-icv-mask',
            matlab_function='icv_mask.m',
            matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
            op_args=[
                "{{ ti.xcom_pull(task_ids='t1-processing.segment-t1-image', key='return_value1') }}",
                "{{ ti.xcom_pull(task_ids='t1-processing.smooth') }}"
            ]
        )
        smooth_gm >> apply_icv_mask

