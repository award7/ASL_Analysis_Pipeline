from airflow import DAG
from airflow.utils.task_group import TaskGroup
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.operators.dummy import DummyOperator
from operators.docker_templated_mounts_operator import DockerTemplatedMountsOperator
from operators.matlab_operator import MatlabOperator
from airflow.utils.trigger_rule import TriggerRule

from utils.utils import make_dir


with DAG(dag_id='asl-perfusion-processing', ) as dag:
    # this is where analyzed asl files will be stored
    make_proc_asl_path = PythonOperator(
        task_id='make-proc-asl-paths',
        python_callable=make_dir,
        op_kwargs={
            'path': [
                "{{ var.value.asl_proc_path }}",
                "{{ dag_run.conf['subject_id'] }}",
                "{{ dag_run.conf['session'] }}"
            ],
        }
    )

    afni_to3d = DockerTemplatedMountsOperator(
        task_id='afni-to3d',
        image='asl/afni',
        command=f"""/bin/bash -c \'{'; '.join(['dcmcount=$(ls {{ params.input }} | wc -l)',
                                               'nt=$(($dcmcount / 2))',
                                               'tr=1000',
                                               'file="zt_{{ params.subject }}"',
                                               'to3d -prefix "$file" -fse -time:zt ${nt} 2 ${tr} seq+z "{{ params.input }}"/*',
                                               'mv zt* -t "{{ params.outdir }}"',
                                               'echo "${file}.BRIK" | sed "s#.*/##"',
                                               ]
                                              )}\'""",
        mounts=[
            {
                'target': '/in',
                'source': "{{ dag_run.conf['session'] }}",
                'type': 'bind'
            },
            {
                'target': '/out',
                'source': "{{ dag_run.conf['asl_proc_path'] }}",
                'type': 'bind'
            }
        ],
        params={
            'input': '/in',
            'outdir': '/out',
            'subject': 'test'
        },
        auto_remove=True,
        do_xcom_push=True
    )
    make_proc_asl_paths >> afni_to3d

    pcasl = BashOperator(
        task_id='pcasl',
        # need to get the file created by to3d, strip all characters after `+`, feed that to 3df_pcasl, then get the
        # file that was created for xcom
        bash_command="""file={{ params.file }}; input=${file%+*}; 3df_pcasl -odata {{ params.path }}/${input} -nex 3; ls {{ params.path }}/*fmap*.BRIK | sed \'s#.*/##\'""",
        params={
            'file': "{{ ti.xcom_pull(task_ids='afni-to3d') }}",
            'path': "{{ dag_run.conf['asl_proc_path'] }}"
        },
        do_xcom_push=True
    )
    afni_to3d >> pcasl

    afni_3dcalc_fmap = DockerTemplatedMountsOperator(
        task_id='afni-3dcalc-fmap',
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
            'file': "{{ ti.xcom_pull(task_ids='pcasl') }}",
            'map': '0',
        },
        mounts=[
            {
                'target': '/data',
                'source': "{{ dag_run.conf['asl_proc_path'] }}",
                'type': 'bind'
            }
        ]
    )
    pcasl >> afni_3dcalc_fmap

    afni_3dcalc_pdmap = DockerTemplatedMountsOperator(
        task_id='afni-3dcalc-pdmap',
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
                'source': "{{ dag_run.conf['asl_proc_path'] }}",
                'type': 'bind'
            }
        ]
    )
    pcasl >> afni_3dcalc_pdmap

    coregister = MatlabOperator(
        task_id='coregister',
        matlab_function='coregister_asl.m',
        matlab_function_paths=["{{ var.value.matlab_path_asl }}"],
        op_args=[
            "{{ dag_run.conf['asl_proc_path'] }}"
        ],
        op_kwargs={
            'ref': "",
            'nargout': '4'
        }
    )
    [afni_3dcalc_fmap, afni_3dcalc_pdmap] >> coregister

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

    with TaskGroup(group_id='roi') as roi_tg:
        for roi in range(0, 100):
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

            # todo: change to docker operator
            # todo: redirect stdout to .csv??
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
