from airflow import DAG
from airflow.operators.bash import BashOperator
from custom.matlab_operator import MatlabOperator
# # from airflow.providers.mongo.hooks.mongo import MongoHook
# from custom.mongodb_operator import S3ToMongoOperator
# from airflow.providers.microsoft.mssql.operators.mssql import MsSqlOperator
# # from airflow.providers.microsoft.mssql.hooks.mssql import MsSqlHook
from custom.docker_xcom_operator import DockerXComOperator
# from airflow.asl_utils.trigger_rule import TriggerRule
from datetime import datetime
import os
from docker.types import Mount


with DAG('asl_perfusion_dag', start_date=datetime(2021, 8, 1), schedule_interval=None, catchup=False) as dag:
    # bucket is the directory in /home/schragelab that holds the files being processed i.e. staging area
    # write all processed files to this directory first, do validation on the files (e.g. count, type), then move
    bucket = os.path.join('/home', os.getlogin(), 'bucket')

    # directory containing the relevant .m files for processing
    asl_processing_m_files_directory = ''

    file_name = 'foo.nii'
    data_in_mount = Mount('/data/in', os.path.join(bucket, 't1/raw'))
    date_out_mount = Mount('/data/out', os.path.join(bucket, 't1/proc'))
    afni_to3d = DockerXComOperator(
        task_id='afni-to3d',
        image='asl/afni',
        api_version='auto',
        auto_remove=False,
        command="echo 'afni to3d perfusion'",
        params={'file_name': file_name,
                'output_dir': '/data/out',
                'input_dir': '/data/in'},
        mounts=[data_in_mount, date_out_mount]
    )

    pcasl = BashOperator(
        task_id='3df-pcasl',
        bash_command="echo '3df_pcasl'"
    )

    afni_to3d >> pcasl

    file_name = 'foo.nii'
    data_in_mount = Mount('/data/in', os.path.join(bucket, 't1/raw'))
    date_out_mount = Mount('/data/out', os.path.join(bucket, 't1/proc'))
    afni_3dcalc_fmap = DockerXComOperator(
        task_id='afni-3dcalc-fmap',
        image='asl/afni',
        api_version='auto',
        auto_remove=False,
        command="echo 'afni 3dcalc fmap'",
        params={'file_name': file_name,
                'output_dir': '/data/out',
                'input_dir': '/data/in'},
        mounts=[data_in_mount, date_out_mount]
    )

    pcasl >> afni_3dcalc_fmap

    file_name = 'foo.nii'
    data_in_mount = Mount('/data/in', os.path.join(bucket, 't1/raw'))
    date_out_mount = Mount('/data/out', os.path.join(bucket, 't1/proc'))
    afni_3dcalc_pdmap = DockerXComOperator(
        task_id='afni-3dcalc-pdmap',
        image='asl/afni',
        api_version='auto',
        auto_remove=False,
        command="echo 'afni 3dcalc pdmap'",
        params={'file_name': file_name,
                'output_dir': '/data/out',
                'input_dir': '/data/in'},
        mounts=[data_in_mount, date_out_mount]
    )

    pcasl >> afni_3dcalc_pdmap

    coregister = MatlabOperator(
        task_id='coregister',
        matlab_function='sl_coregister',
        m_dir=asl_processing_m_files_directory,
        op_args=[],
        op_kwargs={'nargout': 0}
    )

    [afni_3dcalc_fmap, afni_3dcalc_pdmap] >> coregister

    normalize = MatlabOperator(
        task_id='normalize',
        matlab_function='sl_normalize',
        m_dir=asl_processing_m_files_directory,
        op_args=[],
        op_kwargs={'nargout': 0}
    )

    coregister >> normalize

    create_brain_mask = MatlabOperator(
        task_id='create-brain-mask',
        matlab_function='sl_create_brain_mask',
        m_dir=asl_processing_m_files_directory,
        op_args=[],
        op_kwargs={'nargout': 0}
    )

    normalize >> create_brain_mask

    create_perfusion_mask = MatlabOperator(
        task_id='create-perfusion-mask',
        matlab_function='sl_create_perfusion_mask',
        m_dir=asl_processing_m_files_directory,
        op_args=[],
        op_kwargs={'nargout': 0}
    )

    create_brain_mask >> create_perfusion_mask

    get_global_perfusion = MatlabOperator(
        task_id='get-global-perfusion',
        matlab_function='sl_get_global',
        m_dir=asl_processing_m_files_directory,
        op_args=[],
        op_kwargs={'nargout': 0}
    )

    create_perfusion_mask >> get_global_perfusion

    apply_aal_atlas = MatlabOperator(
        task_id='apply-aal-atlas',
        matlab_function='sl_invwarp',
        m_dir=asl_processing_m_files_directory,
        op_args=[],
        op_kwargs={'nargout': 0}
    )

    create_perfusion_mask >> apply_aal_atlas

    restrict_roi_masks_to_gm = MatlabOperator(
        task_id='restrict-roi-masks-to-gm',
        matlab_function='sl_invwarpXgm',
        m_dir=asl_processing_m_files_directory,
        op_args=[],
        op_kwargs={'nargout': 0}
    )

    apply_aal_atlas >> restrict_roi_masks_to_gm

    file_name = 'foo.nii'
    data_in_mount = Mount('/data/in', os.path.join(bucket, 't1/raw'))
    date_out_mount = Mount('/data/out', os.path.join(bucket, 't1/proc'))
    get_roi_perfusion = DockerXComOperator(
        task_id='get-roi-perfusion',
        image='asl/fsl',
        api_version='auto',
        auto_remove=False,
        command="echo 'get roi perfusion'",
        params={'file_name': file_name,
                'output_dir': '/data/out',
                'input_dir': '/data/in'},
        mounts=[data_in_mount, date_out_mount]
    )

    restrict_roi_masks_to_gm >> get_roi_perfusion
