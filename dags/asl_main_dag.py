from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator
from airflow.providers.docker.operators.docker import DockerOperator
from airflow.operators.dummy import DummyOperator
from airflow.utils.task_group import TaskGroup
from operators.matlab_operator import MatlabOperator
from dicomsort.dicomsorter import DicomSorter
from airflow.models import Variable

from docker.types import Mount
from pydicom import read_file as dcm_read_file
from datetime import datetime
import os


def _make_raw_staging_path(*, path: str, **kwargs) -> None:
    # this is where the dicom files will be sorted after reading from disk
    os.makedirs(path, exist_ok=True)


def _make_proc_staging_path(*, path: str, **kwargs) -> None:
    # this is where analyzed files (.nii, .BRIK, etc.) will be stored
    os.makedirs(path, exist_ok=True)


def _t1_scan_names() -> list:
    # include all variations of the T1 scan name between studies
    return [
        'axial',
        'madni'
    ]


def _asl_scan_names() -> list:
    # include all variations of the asl scan name between studies
    return [
        'contrast'
    ]


def _get_t1_path(*, path: str, **kwargs) -> str:
    potential_t1_names = _t1_scan_names()

    # get lowest directories to search for t1 directories
    t1_paths = []
    for root, dirs, files in os.walk(path):
        if not dirs and root in potential_t1_names:
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
    find asl folders
    :param is the target path for the dicom sorting
    """
    potential_asl_names = _asl_scan_names()

    # get lowest directories to search for asl directories
    asl_paths = []
    for root, dirs, files in os.walk(path):
        if not dirs and root in potential_asl_names:
            asl_paths.append(root)

    # set to airflow variable for dynamic task generation
    Variable.set("asl_paths", asl_paths)

    # also return for xcom
    return asl_paths


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
    dcm = dcm_read_file(files_in_folder[0])
    images_in_acquisition = getattr(dcm, 'ImagesInAcquisition')
    file_count = len(files_in_folder)

    if file_count < images_in_acquisition:
        return 'reslice-t1'
    else:
        return 'dcm2niix'


def _count_asl_images(*, path: str, **kwargs) -> str:
    files_in_folder = os.listdir(path)
    dcm = dcm_read_file(files_in_folder[0])
    images_in_acquisition = getattr(dcm, 'ImagesInAcquisition')
    file_count = len(files_in_folder)

    if file_count < images_in_acquisition:
        return ''
    else:
        return ''


def _get_subject_id(*, path: str, **kwargs) -> str:
    files = os.listdir(path)[0]
    dcm = dcm_read_file(files[0])
    subject_id = getattr(dcm, 'PatientName')
    return subject_id


def _dicom_sort(*, source: str, target: str, **kwargs):
    return 'dicom sorting...'


# todo: set default args dict
# todo: rename DAG after testing
with DAG('asl-main-dag', schedule_interval=None, start_date=datetime(2021, 8, 1), catchup=False) as dag:
    # DOCKER_URL = Variable.get("docker_url")

    with TaskGroup(group_id='init') as init_tg:

        make_raw_staging_path = PythonOperator(
            task_id='set-raw-staging-path',
            python_callable=_make_raw_staging_path,
            op_kwargs={
                'path': "{{ var.value.asl_raw_path }}"
            }
        )

        make_proc_staging_path = PythonOperator(
            task_id='set-proc-staging-path',
            python_callable=_make_proc_staging_path,
            op_kwargs={
                'path': "{{ var.value.asl_proc_path }}"
            }
        )

        dicom_sort = PythonOperator(
            task_id='dicom-sort',
            python_callable=DicomSorter,
            op_kwargs={
                'source': "{{ var.value.disk_drive }}",
                'target': "{{ var.value.asl_raw_path }}"
            }
        )
        [make_raw_staging_path, make_proc_staging_path] >> dicom_sort

        get_t1_path = PythonOperator(
            task_id='get-t1-path',
            python_callable=_get_t1_path,
            op_kwargs={
                'path': "{{ var.value.asl_raw_path }}"
            }
        )
        dicom_sort >> get_t1_path

        get_asl_sessions = PythonOperator(
            task_id='get-asl-sessions',
            python_callable=_get_asl_sessions,
            op_kwargs={
                'path': "{{ var.value.asl_raw_path }}"
            }
        )
        dicom_sort >> get_asl_sessions

        get_subject_id = PythonOperator(
            task_id='get-subject-id',
            python_callable=_get_subject_id,
            op_kwargs={
                'path': "{{ var.value.asl_raw_path }}"
            }
        )
        get_t1_path >> get_subject_id

    with TaskGroup(group_id='t1') as t1_tg:
        count_t1_images = BranchPythonOperator(
            task_id='count-t1-images',
            python_callable=_count_t1_images,
            op_kwargs={
                'path': "{{ ti.xcom_pull(task_ids='get-t1-path') }}"
            }
        )
        init_tg >> count_t1_images

        # todo: build a reslice command in one of the MRI programs...
        reslice_t1 = DummyOperator(
            task_id='reslice-t1',
        )
        count_t1_images >> reslice_t1

        dcm2niix = DockerOperator(
            task_id='dcm2niix',
            image='asl/dcm2niix',
            # command='dcm2niix -f {{ params.file_name }} -o {{ params.output_dir }} {{ params.input_dir }}',
            command="""/bin/bash -c 'echo "{{ params.file_name }}">/in/xcom_file.txt; ls /data/in'""",
            api_version='auto',
            auto_remove=True,
            # docker_url=DOCKER_URL,
            do_xcom_push=True,
            mounts=[
                Mount(
                    target='/in',
                    # todo: extend docker operator for templating mount names
                    source="{{ ti.xcom_pull(task_ids='init.get-t1-path') }}",
                    type='bind'
                ),
                Mount(
                    target='/out',
                    # todo: extend docker operator for templating mount names
                    source="{{ var.value.asl_proc_path }}",
                    type='bind'
                ),
            ],
            params={
                'file_name': "t1_{{ ti.xcom_pull(task_ids='init.get-subject-id') }}",
                'output_dir': "{{ var.value.asl_proc_path }}",
                'input_dir': '/out'
            }
        )
        [count_t1_images, reslice_t1] >> dcm2niix

        segment_t1 = MatlabOperator(
            task_id='segment-t1-image',
            matlab_function='segment_t1',
            matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
            op_args=[
                "{{ ti.xcom_pull(task_ids='dcm2niix') }}"
            ],
            op_kwargs={
                'outdir': "{{ var.value.asl_proc_path }}",
                'nargout': 3
            }
        )
        dcm2niix >> segment_t1

        # following segmentation, by default SPM creates a few files prefaced with `c` for each tissue segmentation, a `y`
        # file for the deformation field, and a `*seg8*.mat` file for tissue volume matrix
        # therefore, it's best to keep to the default naming convention by spm to ensure the pipeline stays intact

        smooth_gm = MatlabOperator(
            task_id='smooth',
            matlab_function='sl_smooth',
            m_dir=["{{ var.value.matlab_path_asl }}"],
            op_args=[
                "{{ ti.xcom_pull(task_ids='segment-t1-image') }}"
            ],
            op_kwargs={
                'fwhm': '[8 8 8]',
                'outdir': "{{ var.value.asl_proc_path }}",
                'nargout': 1
            }
        )
        segment_t1 >> smooth_gm

        get_brain_volumes = DummyOperator(
            task_id='get-brain-volumes'
        )
        smooth_gm >> get_brain_volumes

    with TaskGroup(group_id='asl') as asl_tg:
        # dynamically create tasks based on number of asl sessions
        asl_sessions = Variable.get("asl_paths")
        for idx, session in enumerate(asl_sessions):
            basename = os.path.basename(session)

            count_asl_images = BranchPythonOperator(
                task_id=f'count-asl-images-{basename}',
                python_callable=_count_asl_images,
                op_kwargs={
                    'path': session
                }
            )
            init_tg >> count_asl_images

            # todo: change to docker operator
            afni_to3d = DummyOperator(
                task_id=f'afni-to3d-{basename}'
            )
            count_asl_images >> afni_to3d

            # todo: change to bash operator
            pcasl = DummyOperator(
                task_id=f'3df-pcasl-{basename}'
            )
            afni_to3d >> pcasl

            # todo: change to docker operator
            # todo: make fmap and pdmap parallel
            afni_3dcalc_fmap = DummyOperator(
                task_id=f'afni-3dcalc-fmap-{basename}'
            )

            # todo: change to docker operator
            afni_3dcalc_pdmap = DummyOperator(
                task_id=f'afni-3dcalc-pdmap-{session}'
            )
            pcasl >> [afni_3dcalc_fmap, afni_3dcalc_pdmap]

            # todo: change to matlab operator
            coregister = DummyOperator(
                task_id='coregister'
            )
            [smooth_gm, afni_3dcalc_fmap, afni_3dcalc_pdmap] >> coregister

            # todo: change to matlab operator
            normalize = DummyOperator(
                task_id='normalize'
            )
            coregister >> normalize

            # todo: change to matlab operator
            smooth_coregistered_image = DummyOperator(
                task_id='smooth-coregistered-image'
            )
            normalize >> smooth_coregistered_image

            # todo: change to matlab operator
            apply_icv_mask = DummyOperator(
                task_id='apply-icv-mask'
            )
            smooth_coregistered_image >> apply_icv_mask

            # todo: change to matlab operator
            create_perfusion_mask = DummyOperator(
                task_id='create-perfusion-mask'
            )
            apply_icv_mask >> create_perfusion_mask

            # todo: change to matlab operator
            get_global_perfusion = DummyOperator(
                task_id='get-global-perfusion'
            )
            create_perfusion_mask >> get_global_perfusion

            # could create a task for each mask... but that would be >100 per asl session
            # todo: change to matlab operator
            inverse_warp_mask = DummyOperator(
                task_id='inverse-warp-mask'
            )
            create_perfusion_mask >> inverse_warp_mask

            # todo: change to matlab operator
            restrict_gm_to_mask = DummyOperator(
                task_id='restrict-gm-to-mask'
            )
            inverse_warp_mask >> restrict_gm_to_mask

            # todo: change to bash operator
            get_roi_perfusion = DummyOperator(
                task_id='get-roi-perfusion'
            )
            restrict_gm_to_mask >> get_roi_perfusion

        with TaskGroup(group_id='misc') as misc_tg:
            missing_files = DummyOperator(
                task_id='missing-files'
            )
            [count_t1_images, count_t1_images] >> missing_files
