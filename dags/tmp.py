from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from datetime import datetime

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
