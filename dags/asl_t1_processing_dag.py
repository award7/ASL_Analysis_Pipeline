from airflow import DAG
from operators.matlab_operator import MatlabOperator
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from operators.docker_templated_mounts_operator import DockerTemplatedMountsOperator
from datetime import datetime
import matlab
from utils.utils import make_dir


# todo: set default args dict
default_args = {}

with DAG(dag_id='t1-processing', schedule_interval=None, start_date=datetime(2021, 11, 1), catchup=False) as dag:
    # this is where analyzed files (.nii, .BRIK, etc.) will be stored
    make_proc_t1_path = PythonOperator(
        task_id='make-proc-t1-path',
        python_callable=make_dir,
        op_kwargs={
            'path': [
                "{{ var.value.asl_proc_path }}",
                "{{ dag_run.conf['subject_id'] }}",
                "t1"
            ]
        }
    )

    dcm2niix = BashOperator(
        task_id='dcm2niix',
        bash_command="/home/schragelab/airflow/dags/asl_analysis_pipeline/shell/runDcm2nii.bash {{ var.value.asl_proc_path }} {{ dag_run.conf['t1_raw_path'] }} ",
        do_xcom_push=True
    )
    make_proc_t1_path >> dcm2niix

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
            "{{ ti.xcom_pull(task_ids='make-proc-t1-path') }}/{{ ti.xcom_pull(task_ids='dcm2niix') }}",
        ],
        nargout=4
    )
    dcm2niix >> segment_t1

    get_brain_volumes = MatlabOperator(
        task_id='get-brain-volumes',
        matlab_function='brain_volumes',
        matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
        op_args=["{{ ti.xcom_pull(task_ids='segment-t1-image', key='return_value2') }}"],
        op_kwargs={
            'subject': "{{ dag_run.conf['subject_id'] }}"
        },
        nargout=1
    )
    segment_t1 >> get_brain_volumes

    smooth_gm = MatlabOperator(
        task_id='smooth',
        matlab_function='smooth_t1',
        matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
        op_args=[
            "{{ ti.xcom_pull(task_ids='segment-t1-image', key='return_value3') }}"
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
            "{{ ti.xcom_pull(task_ids='segment-t1-image', value='return_value1') }}",
            "{{ ti.xcom_pull(task_ids='smooth') }}"
        ]
    )
    smooth_gm >> apply_icv_mask

    # inverse_warp_mask = MatlabOperator(
    #     task_id='inverse-warp-mask',
    #     matlab_function='invwarp.m',
    #     matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
    # )
    # create_perfusion_mask >> inverse_warp_mask
