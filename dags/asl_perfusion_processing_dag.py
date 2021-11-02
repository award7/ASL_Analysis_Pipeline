from airflow import DAG
from airflow.utils.task_group import TaskGroup
from operators.docker_templated_mounts_operator import DockerTemplatedMountsOperator
from operators.docker_build_local_image_operator import DockerBuildLocalImageOperator
from operators.docker_remove_image import DockerRemoveImage


def _count_asl_images(*, path: str, success_task_id: str, **kwargs) -> str:
    """
    It was decided to put this fcn here instead of the main dag because a failure due to insufficient image count was
    easier to catch

    :param path:
    :param success_task_id:
    :param kwargs:
    :return:
    """
    files_in_folder = os.listdir(path)
    dcm = dcm_read_file(files_in_folder[0])
    images_in_acquisition = getattr(dcm, 'ImagesInAcquisition')
    file_count = len(files_in_folder)

    if file_count < images_in_acquisition:
        return 'errors.missing-files'
    else:
        # return paths for xcom
        ti = kwargs['ti']
        ti.xcom_push(key=f"session", value=path)
        return success_task_id


with DAG(dag_id='asl-perfusion-processing', ) as dag:
    with TaskGroup(group_id='asl') as asl_tg:
        # dynamically create tasks based on number of asl sessions
        mask_count = len(Variable.get("asl_roi_masks"))

        build_afni_image = DockerBuildLocalImageOperator(
            task_id='build-afni-image',
            path="{{ var.value.afni_docker_image }}",
            tag='asl/afni'
        )
        smooth_gm >> build_afni_image

        build_fsl_image = DockerBuildLocalImageOperator(
            task_id='build-fsl-image',
            path="{{ var.value.fsl_docker_image }}",
            tag='asl/fsl'
        )
        smooth_gm >> build_fsl_image

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
                    'source': f"{{ ti.xcom_pull(task_ids='init.get-asl-sessions', key='path{session}') }}",
                    'type': 'bind'
                },
                {
                    'target': '/out',
                    'source': "{{ ti.xcom_pull(task_ids='init.make-proc-path') }}",
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
            bash_command="""file={{ params.file }}; input=${file%+*}; 3df_pcasl -odata {{ params.path }}/${input} -nex 3; ls {{ params.path }}/*fmap*.BRIK | sed \'s#.*/##\'""",
            params={
                'file': f"{{ ti.xcom_pull(task_ids='afni-to3d-{session}') }}",
                'path': "{{ ti.xcom_pull(task_ids='init.make-proc-path') }}"
            },
            do_xcom_push=True
        )
        afni_to3d >> pcasl

        afni_3dcalc_fmap = DockerTemplatedMountsOperator(
            task_id=f'afni-3dcalc-fmap-{session}',
            image='asl/afni',
            command=f"""/bin/bash -c \'{'; '.join(['file={{ params.file }}',
                                                   'stripped_ext=${file%.BRIK}',
                                                   'stripped_prefix=${stripped_ext#zt_}',
                                                   '3dcalc -a /data/${stripped_prefix}.[{{ params.map }}] -datum float -expr "a" -prefix ASL_${stripped_prefix}.nii',
                                                   'mv "ASL_${stripped_prefix}.nii" -t /data',
                                                   'echo "ASL_${stripped_prefix}.nii"'
                                                   ]
                                                  )}\'""",
            params={
                'file': f"{{ ti.xcom_pull(task_ids='pcasl-{session}') }}",
                'map': '0',
            },
            mounts=[
                {
                    'target': '/data',
                    'source': "{{ ti.xcom_pull(task_ids='init.make-proc-path') }}",
                    'type': 'bind'
                }
            ]
        )
        pcasl >> afni_3dcalc_fmap

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
                    'source': "{{ ti.xcom_pull(task_ids='init.make-proc-path') }}",
                    'type': 'bind'
                }
            ]
        )
        pcasl >> afni_3dcalc_pdmap

        coregister = MatlabOperator(
            task_id=f'coregister-{session}',
            matlab_function='coregister_asl.m',
            matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
            op_args=[
                "{{ ti.xcom_pull(task_ids='init.make-proc-path') }}"
            ],
            op_kwargs={
                'ref': "",
                'nargout': '4'
            }
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
        # todo: move to asl-perfusion-processing-dag
        # todo: change to python operator to log
        missing_files = DummyOperator(
            task_id='missing-files'
        )
        [count_asl_images] >> missing_files