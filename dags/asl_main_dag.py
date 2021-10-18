from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow_multi_dagrun.operators import TriggerMultiDagRunOperator
from airflow.utils.trigger_rule import TriggerRule
from datetime import datetime
import os



with DAG('asl-master-dag', schedule_interval=None, start_date=datetime(2021, 8, 1), catchup=False) as dag:
    tmp_root_folder = os.path.join('/home', os.getlogin(), 'tmp')

    dicom_sort = TriggerDagRunOperator(
        task_id='dicom-sort',
        trigger_dag_id='dcm-sort-dag',
        reset_dag_run=True,
        wait_for_completion=True
        )

    t1_processing = TriggerDagRunOperator(
        task_id='t1-processing',
        trigger_dag_id='asl-t1-dag',
        reset_dag_run=True,
        wait_for_completion=True
        )
    dicom_sort >> t1_processing

    get_asl_sessions = PythonOperator(
        task_id='get-asl-sessions',
        python_callable=_get_asl_sessions,
        op_args=[tmp_root_folder]
        )
    dicom_sort >> get_asl_sessions

    # trigger multiple asl_downstream DAGs, one for each ASL session
    asl_perfusion_processing = TriggerMultiDagRunOperator(
        task_id='asl-perfusion-processing',
        trigger_dag_id='asl-perfusion-dag',
        python_callable=_create_asl_downstream_dag,
        op_args=tmp_root_folder,
        trigger_rule=TriggerRule.ALL_SUCCESS
        )
    [t1_processing, get_asl_sessions] >> asl_perfusion_processing
