from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator, ShortCircuitOperator
from operators.docker_templated_mounts_operator import DockerTemplatedMountsOperator
from operators.docker_remove_image import DockerRemoveImage
from operators.docker_build_local_image_operator import DockerBuildLocalImageOperator
from operators.trigger_multi_dagrun import TriggerMultiDagRunOperator
from airflow.operators.dummy import DummyOperator
from airflow.utils.task_group import TaskGroup
from operators.matlab_operator import MatlabOperator
from airflow.models import Variable
from airflow.utils.trigger_rule import TriggerRule

import logging
from dicomsort.dicomsorter import DicomSorter
from pydicom import read_file as dcm_read_file
from datetime import datetime
import os
from glob import glob
import matlab
from typing import Union, List


def _make_dir(*, path: Union[str, List[str]], **kwargs) -> None:
    if isinstance(path, list):
        _path = ""
        for item in path:
            _path = os.path.join(_path, item)
        path = _path
    os.makedirs(path, exist_ok=True)
    return path


def _t1_scan_names() -> list:
    # include all variations of the T1 scan name between studies
    return [
        'Ax_T1_Bravo_3mm',
        'mADNI3_T1'
    ]


def _asl_scan_names() -> list:
    # include all variations of the asl scan name between studies
    return [
        'UW_eASL',
        '3D_ASL'
    ]


def _get_t1_path(*, path: str, **kwargs) -> str:
    potential_t1_names = _t1_scan_names()

    # get lowest directories to search for t1 directories
    t1_paths = []
    for root, dirs, files in os.walk(path):
        if not dirs and any(name in root for name in potential_t1_names):
            t1_paths.append(root)

    # if there's more than one t1 directory found, get each scan's acquisition time and return the scan with the most
    # recent time stamp
    if len(t1_paths) > 1:
        d = {}
        for path in t1_paths:
            dcm = dcm_read_file(os.listdir(path)[0])
            d[path] = getattr(dcm, 'AcquisitionTime')

        sorted_d = {k: v for k, v in sorted(d.items(), key=lambda item: item[1])}
        t1_paths = next(iter(sorted_d))
    return t1_paths[0]


def _get_asl_sessions(*, path: str, **kwargs) -> list:
    """
    find asl folders to trigger multiple asl-perfusion-processing dags
    :param is the target path for the dicom sorting
    """
    potential_asl_names = _asl_scan_names()

    # get lowest directories to search for asl directories
    for root, dirs, files in os.walk(path):
        if not dirs and any(name in root for name in potential_asl_names):
            yield{'session': root}


def _get_study_date(*, path: str, **kwargs) -> str:
    file = os.listdir(path)[0]
    dcm = dcm_read_file(file)
    return getattr(dcm, 'AcquisitionDate')


def _get_protocol_name(*, path: str, **kwargs) -> str:
    file = os.listdir(path)[0]
    dcm = dcm_read_file(file)
    return getattr(dcm, 'ProtocolName')


def _count_t1_images(*, path: str, **kwargs) -> str:
    files_in_folder = os.listdir(path)
    dcm = dcm_read_file(os.path.join(path, files_in_folder[0]))
    images_in_acquisition = getattr(dcm, 'ImagesInAcquisition')
    file_count = len(files_in_folder)

    if file_count < images_in_acquisition:
        return 't1.reslice-t1'
    else:
        return 't1.build-dcm2niix-image'


def _get_subject_id(*, path: str, **kwargs) -> str:
    files = os.listdir(path)
    dcm = dcm_read_file(os.path.join(path, files[0]))
    subject_id = str(getattr(dcm, 'PatientName')).replace('-', '_')
    return subject_id


def _check_for_scans(*, path: str, **kwargs) -> bool:
    if os.listdir(path):
        return True


def _get_file(*, path: str, search: str, **kwargs) -> str:
    glob_string = os.path.join(path, search)
    file = glob(glob_string)
    if len(file) > 1:
        raise ValueError("Too many files found")
    return file[0]


# todo: set default args dict
# todo: rename DAG after testing
with DAG('asl-main-dag', schedule_interval='@daily', start_date=datetime(2021, 8, 1), catchup=False) as dag:
    with TaskGroup(group_id='init') as init_tg:
        dicom_sort = PythonOperator(
            task_id='dicom-sort',
            python_callable=DicomSorter,
            op_kwargs={
                'source': "{{ var.value.disk_drive }}",
                'target': "{{ ti.xcom_pull(task_ids='init.make-raw-staging-path') }}"
            }
        )

        get_subject_id = PythonOperator(
            task_id='get-subject-id',
            python_callable=_get_subject_id,
            op_kwargs={
                'path': "{{ var.value.disk_drive }}"
            }
        )
        dicom_sort >> get_subject_id

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
        dicom_sort >> make_proc_path

        get_t1_path = PythonOperator(
            task_id='get-t1-path',
            python_callable=_get_t1_path,
            op_kwargs={
                'path': "{{ var.value.asl_raw_path }}"
            }
        )
        dicom_sort >> get_t1_path

        count_t1_images = BranchPythonOperator(
            task_id='count-t1-images',
            python_callable=_count_t1_images,
            op_kwargs={
                'path': "{{ ti.xcom_pull(task_ids='init.get-t1-path') }}"
            }
        )
        get_t1_path >> count_t1_images

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
