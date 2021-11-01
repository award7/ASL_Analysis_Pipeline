from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime


with DAG(dag_id='test', start_date=datetime(2021, 8, 1), catchup=False) as dag:
    script = BashOperator(
        task_id='script',
        bash_command="{{ var.value.test_bash_script }} {{ params.arg1 }} ",
        params={
            'arg1': 'FOO!'
        }
    )
