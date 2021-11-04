from airflow import DAG
from airflow.utils.task_group import TaskGroup
from airflow.operators.dummy import DummyOperator
from airflow.operators.python import PythonOperator
from operators.matlab_operator import MatlabOperator
from operators.docker_templated_mounts_operator import DockerTemplatedMountsOperator


with TaskGroup(group_id='t1') as t1_tg:
    # todo: build a reslice command in one of the MRI programs...
    reslice_t1 = DummyOperator(
        task_id='reslice-t1',
    )
    count_t1_images >> reslice_t1

    build_dcm2niix_image = DockerBuildLocalImageOperator(
        task_id='build-dcm2niix-image',
        path="{{ var.value.dcm2niix_docker_image }}",
        tag="asl/dcm2niix",
        trigger_rule=TriggerRule.NONE_FAILED
    )
    [count_t1_images, reslice_t1] >> build_dcm2niix_image

    dcm2niix = DockerTemplatedMountsOperator(
        task_id='dcm2niix',
        image='asl/dcm2niix',
        # this command calls a bash shell ->
        # calls dcm2niix program (filename being protocol_name_timestamp) and outputs to the /tmp directory on the
        #     container ->
        # find the .nii file that was created and save the name to a variable ->
        # move the created files from /tmp to the mounted directory /out ->
        # clear the stdout ->
        # echo the filename to stdout so it will be returned as the xcom value
        command="""/bin/sh -c \'dcm2niix -f %p_%n_%t -o /tmp /in; clear; file=$(find ./tmp -name "*.nii" -type f); mv /tmp/* /out; clear; echo "${file##*/}"\'""",
        mounts=[
            {
                'target': '/in',
                'source': "{{ ti.xcom_pull(task_ids='init.get-t1-path') }}",
                'type': 'bind'
            },
            {
                'target': '/out',
                'source': "{{ ti.xcom_pull(task_ids='init.make-proc-path') }}",
                'type': 'bind'
            },
        ],
        auto_remove=True,
        do_xcom_push=True
    )
    build_dcm2niix_image >> dcm2niix

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

    to get a specific image, ensure that the nargout parameter will encompass the index of the image. E.g. to get 
    the csf image, nargout must be 6.
    """

    segment_t1 = MatlabOperator(
        task_id='segment-t1-image',
        matlab_function='segment_t1',
        matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
        op_args=[
            "{{ ti.xcom_pull(task_ids='init.make-proc-path') }}/{{ ti.xcom_pull(task_ids='t1.dcm2niix') }}",
        ],
        nargout=4
    )
    dcm2niix >> segment_t1

    get_brain_volumes = MatlabOperator(
        task_id='get-brain-volumes',
        matlab_function='brain_volumes',
        matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
        op_args=["{{ ti.xcom_pull(task_ids='t1.segment-t1-image', key='return_value2') }}"],
        op_kwargs={
            'subject': "{{ ti.xcom_pull(task_ids='init.get-subject-id') }}"
        }
    )
    segment_t1 >> get_brain_volumes

    smooth_gm = MatlabOperator(
        task_id='smooth',
        matlab_function='smooth_t1',
        matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
        op_args=[
            "{{ ti.xcom_pull(task_ids='t1.segment-t1-image', key='return_value3') }}"
        ],
        op_kwargs={
            'fwhm': matlab.double([5, 5, 5])
        }
    )
    segment_t1 >> smooth_gm
