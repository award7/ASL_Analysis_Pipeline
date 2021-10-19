# from asl_utils.asl_utils import count_t1_images
from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator, BranchPythonOperator
from docker.types import Mount
from airflow.operators.dummy import DummyOperator
from custom.docker_xcom_operator import DockerXComOperator
from custom.matlab_operator import MatlabOperator

# todo: include default args
default_args = {}

with DAG('asl_t1_dag', schedule_interval=None, start_date=datetime(2021, 8, 1), catchup=False) as DAG:
    # bucket is the directory in server that holds the files being processed i.e. staging area
    # write all processed files to this directory first, do validation on the files (e.g. count, type), then move
    bucket = '/mnt/hgfs/server/bucket'
    # t1_raw_folder = os.path.join(tmp_root_folder, 't1/raw')
    # t1_proc_folder = os.path.join(tmp_root_folder, 't1/proc')
    asl_processing_m_files_directory = ''


    t1_image_count = BranchPythonOperator(
        task_id='count-t1-images',
        python_callable=count_t1_images,
        op_args=[t1_raw_folder, 50]
    )

    # todo: build a reslice command in one of the MRI programs...
    reslice_t1 = DummyOperator(
        task_id='reslice-t1',
    )
    t1_image_count >> reslice_t1

    # todo: get subject id from previous DAG or dicom metadata xcom
    dcm2niix_outfile_name = 'foo.nii'
    data_in_mount = Mount('/data/in', t1_raw_folder)
    date_out_mount = Mount('/data/out', t1_proc_folder)
    dcm2niix = DockerXComOperator(
        task_id='dcm2niix',
        image='asl/dcm2niix',
        api_version='auto',
        auto_remove=False,
        # command='dcm2niix -f {{ params.file_name }} -o {{ params.output_dir }} {{ params.input_dir }}',
        command="echo 'hello world!'",
        params={'file_name': dcm2niix_outfile_name,
                'output_dir': '/data/out',
                'input_dir': '/data/in'},
        mounts=[data_in_mount, date_out_mount]
    )
    [t1_image_count, reslice_t1] >> dcm2niix

    get_reconstructed_t1_file = PythonOperator(
        task_id='get-reconstructed-t1-file',
        python_callable=_get_file,
        op_args=[dcm2niix_outfile_name, t1_raw_folder]
    )
    dcm2niix >> get_reconstructed_t1_file

    move_reconstructed_t1_file = PythonOperator(
        task_id='move-reconstructed-t1-file',
        python_callable=_move_file,
        op_args=[t1_raw_folder, t1_proc_folder, 'get-reconstructed-t1-file']
    )
    get_reconstructed_t1_file >> move_reconstructed_t1_file

    segment_t1_image = MatlabOperator(
        task_id='segment-t1-image',
        matlab_function='sl_segment',
        m_dir=asl_processing_m_files_directory,
        op_args=[],
        op_kwargs={'nargout': 0}
        # params={'file': os.path.join(tmp_root_folder, dcm2niix_outfile_name)}
    )
    move_reconstructed_t1_file >> segment_t1_image

    # following segmentation, by default SPM creates a few files prefaced with `c` for each tissue segmentation, a `y`
    # file for the deformation field, and a `*seg8*.mat` file for tissue volume matrix
    # therefore, it's best to keep to the default naming convention by spm to ensure the pipeline stays intact
    file_name = 'c1*'
    get_gray_matter_file = PythonOperator(
        task_id='get-gray-matter-file',
        python_callable=_get_file,
        op_args=[file_name, t1_proc_folder],
    )
    segment_t1_image >> get_gray_matter_file

    file_name = 'y*'
    get_t1_deformation_field_file = BashOperator(
        task_id='get-t1-deforamtion-field-file',
        bash_command="find {{ params.path }} -type f -name {{ params.file_name }} -print",
        params={'path': t1_raw_folder,
                'name': file_name}
    )
    segment_t1_image >> get_t1_deformation_field_file

    seg8_file = 'seg8.mat'
    get_brain_volumes = MatlabOperator(
        task_id='get-brain-volumes',
        matlab_function='sl_get_brain_volumes',
        m_dir=asl_processing_m_files_directory,
        op_args=[],
        op_kwargs={'nargout': 0}
    )
    segment_t1_image >> get_brain_volumes

    smooth = MatlabOperator(
        task_id='smooth',
        matlab_function='sl_smooth',
        m_dir=asl_processing_m_files_directory,
        op_args=[],
        op_kwargs={'nargout': 0}
    )
    [get_gray_matter_file, get_t1_deformation_field_file] >> smooth
