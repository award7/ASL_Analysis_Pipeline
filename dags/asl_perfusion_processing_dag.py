from airflow import DAG
from airflow.utils.task_group import TaskGroup
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.operators.dummy import DummyOperator
from operators.matlab_operator import MatlabOperator
from airflow.utils.trigger_rule import TriggerRule

from utils.utils import make_dir, get_mask_count

with DAG(dag_id='asl-perfusion-processing', ) as dag:
    coregister = MatlabOperator(
        task_id='coregister',
        matlab_function='coregister_asl.m',
        matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
        op_args=[
            "{{ dag_run.conf['smoothed_gm_image'] }}",
            "{{ ti.xcom_pull(task_ids='afni-3dcalc-fmap') }}"
        ],
        op_kwargs={
            'other': "{{ ti.xcom_pull(task_ids='afni-3dcalc-pdmap') }}"
        },
        nargout=1
    )

    normalize = MatlabOperator(
        task_id='normalize',
        matlab_function='normalize_t1.m',
        matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
        op_args=[
            "{{ ti.xcom_pull(task_ids='coregister', value='return_value0') }}",
            "{{ dag_run.conf['deformation_field'] }}",
            "{{ dag_run.conf['bias_corrected_image'] }}"
        ],
        op_kwargs={
            'other': "{{ ti.xcom_pull(task_ids='coregister', value='return_value1') }}"
        },
        nargout=1
    )
    coregister >> normalize

    smooth_coregistered_normalized_fmap = MatlabOperator(
        task_id='smooth-coregistered-normalized-fmap',
        matlab_function='smooth_t1.m',
        matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
        op_args=[
            "{{ ti.xcom_pull(task_ids='normalize', value='return_value0') }}"
        ],
        nargout=1
    )
    normalize >> smooth_coregistered_normalized_fmap

    smooth_coregistered_normalized_pdmap = MatlabOperator(
        task_id='smooth-coregistered-normalized-pdmap',
        matlab_function='smooth_t1.m',
        matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
        op_args=[
            "{{ ti.xcom_pull(task_ids='normalize', value='return_value1') }}"
        ],
        nargout=1
    )
    normalize >> smooth_coregistered_normalized_pdmap

    create_perfusion_mask = MatlabOperator(
        task_id='create-perfusion-mask',
        matlab_function='brainmask.m',
        matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
        op_args=[
            "{{ ti.xcom_pull(task_ids='coregister', value='return_value0') }}",
            "{{ dag_run.comf['icv_mask_image'] }}"
        ],
        nargout=1
    )
    smooth_coregistered_normalized_fmap >> create_perfusion_mask

    get_global_perfusion = MatlabOperator(
        task_id='get-global-perfusion',
        matlab_function='calculate_global_asl.m',
        matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
        op_args=[
            "{{ ti.xcom_pull(task_ids='create-perfusion-mask') }}"
        ],
        nargout=1
    )
    create_perfusion_mask >> get_global_perfusion

    inverse_warp_mask = MatlabOperator(
        task_id='inverse-warp-mask',
        matlab_function='invwarp.m',
        matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
    )
    apply_icv_mask >> inverse_warp_mask

    # todo: change to matlab operator
    restrict_gm_to_mask = DummyOperator(
        task_id='restrict-gm-to-mask'
    )
    inverse_warp_mask >> restrict_gm_to_mask

    # todo: change to bash operator
    # call runFsl which then calculates perfusion data for each mask and places data into a csv
    get_roi_perfusion = DummyOperator(
        task_id='get-roi-perfusion'
    )
    restrict_gm_to_mask >> get_roi_perfusion

    with TaskGroup(group_id='aggregate-data') as aggregate_data_tg:
        # todo: change to python operator todo: task should walk through each asl session (one task per session??)
        #  aggregating all perfusion data (.csv) and form one .csv file
        aggregate_perfusion_data = DummyOperator(
            task_id='aggregate-perfusion-data',
            trigger_rule=TriggerRule.ALL_DONE
        )
        [get_global_perfusion, get_roi_perfusion] >> aggregate_perfusion_data

        # todo: make as csv2db operator
        # todo: upload .csv file to staging table in database
        asl_to_db = DummyOperator(
            task_id='asl-to-db'
        )
        aggregate_perfusion_data >> asl_to_db
