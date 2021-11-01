from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator, ShortCircuitOperator
from operators.docker_templated_mounts_operator import DockerTemplatedMountsOperator
from operators.docker_remove_image import DockerRemoveImage
from operators.docker_build_local_image_operator import DockerBuildLocalImageOperator
from airflow.operators.bash import BashOperator
from airflow.operators.dummy import DummyOperator
from airflow.utils.task_group import TaskGroup
from operators.matlab_operator import MatlabOperator
from dicomsort.dicomsorter import DicomSorter
from airflow.models import Variable
from airflow.utils.trigger_rule import TriggerRule
from pydicom import read_file as dcm_read_file
from datetime import datetime
import os
from glob import glob
import matlab


def _make_raw_staging_path(*, path: str, **kwargs) -> None:
    # this is where the dicom files will be sorted after reading from disk
    os.makedirs(path, exist_ok=True)


def _make_proc_staging_path(*, path: str, **kwargs) -> None:
    # this is where analyzed files (.nii, .BRIK, etc.) will be stored
    os.makedirs(path, exist_ok=True)


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


def _get_asl_sessions(*, path: str, **kwargs) -> bool:
    """
    find asl folders
    :param is the target path for the dicom sorting
    """
    potential_asl_names = _asl_scan_names()

    # get lowest directories to search for asl directories
    asl_paths = []
    for root, dirs, files in os.walk(path):
        if not dirs and any(name in root for name in potential_asl_names):
            asl_paths.append(root)

    if asl_paths:
        # set to airflow variable for dynamic task generation
        Variable.set("asl_sessions", len(asl_paths))

        # return paths for xcom
        ti = kwargs['ti']
        for idx, path in enumerate(asl_paths):
            ti.xcom_push(key=f"path{idx}", value=path)
        return True
    else:
        return False


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
        return 'reslice-t1'
    else:
        return 't1.build-dcm2niix-image'


def _count_asl_images(*, path: str, success_task_id: str, **kwargs) -> str:
    files_in_folder = os.listdir(path)
    dcm = dcm_read_file(files_in_folder[0])
    images_in_acquisition = getattr(dcm, 'ImagesInAcquisition')
    file_count = len(files_in_folder)

    if file_count < images_in_acquisition:
        return 'errors.missing-files'
    else:
        return success_task_id


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
                'target': "{{ var.value.asl_raw_path }}"
            }
        )

        get_asl_sessions = ShortCircuitOperator(
            task_id='get-asl-sessions',
            python_callable=_get_asl_sessions,
            op_kwargs={
                'path': "{{ var.value.asl_raw_path }}"
            }
        )
        dicom_sort >> get_asl_sessions

        get_t1_path = PythonOperator(
            task_id='get-t1-path',
            python_callable=_get_t1_path,
            op_kwargs={
                'path': "{{ var.value.asl_raw_path }}"
            }
        )
        dicom_sort >> get_t1_path

        get_subject_id = PythonOperator(
            task_id='get-subject-id',
            python_callable=_get_subject_id,
            op_kwargs={
                'path': "{{ ti.xcom_pull(task_ids='init.get-t1-path') }}"
            }
        )
        get_t1_path >> get_subject_id

    with TaskGroup(group_id='t1') as t1_tg:
        count_t1_images = BranchPythonOperator(
            task_id='count-t1-images',
            python_callable=_count_t1_images,
            op_kwargs={
                'path': "{{ ti.xcom_pull(task_ids='init.get-t1-path') }}"
            }
        )
        init_tg >> count_t1_images

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
                    'source': "{{ var.value.asl_proc_path }}",
                    'type': 'bind'
                },
            ],
            auto_remove=True,
            do_xcom_push=True
        )
        build_dcm2niix_image >> dcm2niix

        segment_t1 = MatlabOperator(
            task_id='segment-t1-image',
            matlab_function='segment_t1',
            matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
            op_args=[
                "{{ var.value.asl_proc_path }}/{{ ti.xcom_pull(task_ids='t1.dcm2niix') }}"
            ]
        )
        dcm2niix >> segment_t1

        # following segmentation, by default SPM creates a few files prefaced with `c` for each tissue segmentation, a `y`
        # file for the deformation field, and a `*seg8*.mat` file for tissue volume matrix
        # therefore, it's best to keep to the default naming convention by spm to ensure the pipeline stays intact
        get_gm_file = PythonOperator(
            task_id='get-gm-file',
            python_callable=_get_file,
            op_kwargs={
                'path': "{{ var.value.asl_proc_path }}",
                'search': "c1*"
            }
        )
        segment_t1 >> get_gm_file

        get_seg8mat_file = PythonOperator(
            task_id='get-seg8mat-file',
            python_callable=_get_file,
            op_kwargs={
                'path': "{{ var.value.asl_proc_path }}",
                'search': "*seg8.mat"
            }
        )
        segment_t1 >> get_seg8mat_file

        get_forward_deformation_file = PythonOperator(
            task_id='get-forward_deformation-file',
            python_callable=_get_file,
            op_kwargs={
                'path': "{{ var.value.asl_proc_path }}",
                'search': "y*"
            }
        )
        segment_t1 >> get_forward_deformation_file

        smooth_gm = MatlabOperator(
            task_id='smooth',
            matlab_function='smooth_t1',
            matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
            op_args=[
                "{{ ti.xcom_pull(task_ids='t1.get-gm-file') }}"
            ],
            op_kwargs={
                'fwhm': matlab.double([8, 8, 8])
            }
        )
        get_gm_file >> smooth_gm

        get_brain_volumes = MatlabOperator(
            task_id='get-brain-volumes',
            matlab_function='brain_volumes',
            matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
            op_args=["{{ ti.xcom_pull(task_ids='t1.get-seg8mat-file') }}"],
            op_kwargs={
                'subject': "{{ ti.xcom_pull(task_ids='init.get-subject-id') }}"
            }
        )
        get_seg8mat_file >> get_brain_volumes

    with TaskGroup(group_id='asl') as asl_tg:
        # dynamically create tasks based on number of asl sessions
        asl_sessions = int(Variable.get("asl_sessions"))
        mask_count = len(Variable.get("asl_roi_masks"))

        build_afni_image = DockerBuildLocalImageOperator(
            task_id='build-afni-image',
            path="{{ var.value.afni_docker_image }}",
            tag='asl/afni'
        )
        init_tg >> build_afni_image

        build_fsl_image = DockerBuildLocalImageOperator(
            task_id='build-fsl-image',
            path="{{ var.value.fsl_docker_image }}",
            tag='asl/fsl'
        )
        init_tg >> build_fsl_image

        for session in range(0, asl_sessions):
            # basename = os.path.basename(session)
            with TaskGroup(group_id=f'asl-session-{session}') as asl_session_tg:
                count_asl_images = BranchPythonOperator(
                    task_id=f'count-asl-images-{session}',
                    python_callable=_count_asl_images,
                    op_kwargs={
                        'path': f"{{ ti.xcom_pull(task_ids='init.get-asl-sessions', key='path{session}') }}",
                        'success_task_id': f'afni-to3d-{session}'
                    }
                )
                init_tg >> count_asl_images

                afni_to3d = DockerTemplatedMountsOperator(
                    task_id=f'afni-to3d-{session}',
                    image='asl/afni',
                    command=f"""/bin/bash -c \'{'; '.join(['dcmcount=$(ls {{ params.input }} | wc -l)',
                                                           'nt=$(($dcmcount / 2))',
                                                           'tr=1000',
                                                           'file="zt_{{ params.subject }}_{{ params.session }}"',
                                                           'to3d -prefix "$file" -fse -time:zt ${nt} 2 ${tr} seq+z "{{ params.input }}"/*',
                                                           'echo "${file}.BRIK" | sed "s#.*/##"',
                                                           'mv zt* -t "{{ params.outdir }}"'
                                                           ]
                                                          )}\'""",
                    mounts=[
                        {
                            'target': '/in',
                            'source': r'/mnt/hgfs/bucket/asl/raw/3D_ASL_(non-contrast)_Series0007',
                            'type': 'bind'
                        },
                        {
                            'target': '/out',
                            'source': "{{ var.value.asl_proc_path }}",
                            'type': 'bind'
                        }
                    ],
                    params={
                        'input': '/in',
                        'outdir': '/out',
                        'subject': 'test',
                        'session': f'{session}'
                    },
                    auto_remove=True,
                    do_xcom_push=True
                )
                [build_afni_image, count_asl_images] >> afni_to3d

                pcasl = BashOperator(
                    task_id=f'pcasl-{session}',
                    # need to get the file created by to3d, strip all characters after `+`, feed that to 3df_pcasl, then get the
                    # file that was created for xcom
                    bash_command="""file={{ ti.xcom_pull(task_ids='afni-to3d') }}; input=${file%+*}; 3df_pcasl -odata {{ var.value.asl_proc_path }}/${input} -nex 3; ls {{ var.value.asl_proc_path }}/*fmap*.BRIK | sed \'s#.*/##\'""",
                    do_xcom_push=True
                )

                afni_3dcalc_fmap = DockerTemplatedMountsOperator(
                    task_id=f'afni-3dcalc-fmap-{session}',
                    image='asl/afni',
                    command=f"""/bin/bash -c \'{'; '.join(['file={{ ti.xcom_pull(task_ids="pcasl") }}',
                                                           'stripped_ext=${file%.BRIK}',
                                                           'stripped_prefix=${stripped_ext#zt_}',
                                                           '3dcalc -a /data/${stripped_prefix}.[{{ params.map }}] -datum float -expr "a" -prefix ASL_${stripped_prefix}.nii',
                                                           'mv "ASL_${stripped_prefix}.nii" -t /data',
                                                           'echo "ASL_${stripped_prefix}.nii"'
                                                           ]
                                                          )}\'""",
                    params={
                        'map': '0',
                    },
                    mounts=[
                        {
                            'target': '/data',
                            'source': "{{ var.value.asl_proc_path }}",
                            'type': 'bind'
                        }
                    ]
                )

                afni_3dcalc_pdmap = DockerTemplatedMountsOperator(
                    task_id=f'afni-3dcalc-pdmap-{session}',
                    image='asl/afni',
                    command=f"""/bin/bash -c \'{'; '.join(['file={{ ti.xcom_pull(task_ids="pcasl") }}',
                                                           'stripped_ext=${file%.BRIK}',
                                                           'stripped_prefix=${stripped_ext#zt_}',
                                                           '3dcalc -a /data/${stripped_prefix}.[{{ params.map }}] -datum float -expr "a" -prefix ASL_${stripped_prefix}.nii',
                                                           'mv "ASL_${stripped_prefix}.nii" -t /data',
                                                           'echo "ASL_${stripped_prefix}.nii"'
                                                           ]
                                                          )}\'""",
                    params={
                        'map': '1',
                    },
                    mounts=[
                        {
                            'target': '/data',
                            'source': "{{ var.value.asl_proc_path }}",
                            'type': 'bind'
                        }
                    ]
                )
                pcasl >> [afni_3dcalc_fmap, afni_3dcalc_pdmap]

                # todo: change to matlab operator
                coregister = DummyOperator(
                    task_id=f'coregister-{session}'
                )
                [smooth_gm, afni_3dcalc_fmap, afni_3dcalc_pdmap] >> coregister

                # todo: change to matlab operator
                normalize = DummyOperator(
                    task_id=f'normalize-{session}'
                )
                coregister >> normalize

                # todo: change to matlab operator
                smooth_coregistered_image = DummyOperator(
                    task_id=f'smooth-coregistered-image-{session}'
                )
                normalize >> smooth_coregistered_image

                # todo: change to matlab operator
                apply_icv_mask = DummyOperator(
                    task_id=f'apply-icv-mask-{session}'
                )
                smooth_coregistered_image >> apply_icv_mask

                # todo: change to matlab operator
                create_perfusion_mask = DummyOperator(
                    task_id=f'create-perfusion-mask-{session}'
                )
                apply_icv_mask >> create_perfusion_mask

                # todo: change to matlab operator
                get_global_perfusion = DummyOperator(
                    task_id=f'get-global-perfusion-{session}'
                )
                create_perfusion_mask >> get_global_perfusion

                with TaskGroup(group_id=f'roi-{session}') as roi_tg:
                    for roi in range(0, 100):
                        # todo: change to matlab operator
                        inverse_warp_mask = DummyOperator(
                            task_id=f'inverse-warp-mask-{session}-{roi}'
                        )
                        create_perfusion_mask >> inverse_warp_mask

                        # todo: change to matlab operator
                        restrict_gm_to_mask = DummyOperator(
                            task_id=f'restrict-gm-to-mask-{session}-{roi}'
                        )
                        inverse_warp_mask >> restrict_gm_to_mask

                        # todo: change to docker operator
                        # todo: redirect stdout to .csv??
                        get_roi_perfusion = DummyOperator(
                            task_id=f'get-roi-perfusion-{session}-{roi}'
                        )
                        [build_fsl_image, restrict_gm_to_mask] >> get_roi_perfusion

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

    with TaskGroup(group_id='errors') as misc_tg:
        # todo: change to python operator to log
        missing_files = DummyOperator(
            task_id='missing-files'
        )
        [count_asl_images] >> missing_files

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
        [afni_3dcalc_fmap, afni_3dcalc_pdmap] >> remove_afni_image

        remove_fsl_image = DockerRemoveImage(
            task_id='remove-fsl-image',
            image='asl/fsl',
            trigger_rule=TriggerRule.ALL_DONE
        )
        get_roi_perfusion >> remove_fsl_image

        # todo: change to python operator
        remove_staged_files = DummyOperator(
            task_id='remove-staged-files',
            trigger_rule=TriggerRule.ALL_DONE
        )
        asl_tg >> remove_staged_files
