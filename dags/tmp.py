from airflow import DAG
from airflow.operators.bash import BashOperator
from operators.docker_build_local_image_operator import DockerBuildLocalImageOperator
from operators.docker_templated_mounts_operator import DockerTemplatedMountsOperator
from datetime import datetime

default_args = {
    'email': 'award7@wisc.edu',
    'email_on_failure': False
}

with DAG(dag_id='test', default_args=default_args, start_date=datetime(2021, 8, 1), catchup=False) as dag:
    build_afni_image = DockerBuildLocalImageOperator(
        task_id='build-afni-image',
        path='{{ var.value.afni_docker_image }}',
        tag='asl/afni'
    )

    idx = 0
    afni_to3d = DockerTemplatedMountsOperator(
        task_id='afni-to3d',
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
            'session': f'{idx}'
        }
    )
    build_afni_image >> afni_to3d

    pcasl = BashOperator(
        task_id='pcasl',
        # need to get the file created by to3d, strip all characters after `+`, feed that to 3df_pcasl, then get the
        # file that was created for xcom
        bash_command="""file={{ ti.xcom_pull(task_ids='afni-to3d') }}; input=${file%+*}; 3df_pcasl -odata {{ var.value.asl_proc_path }}/${input} -nex 3; ls {{ var.value.asl_proc_path }}/*fmap*.BRIK | sed \'s#.*/##\'""",
        do_xcom_push=True
    )

    afni_to3d >> pcasl

    afni_3dcalc_fmap = DockerTemplatedMountsOperator(
        task_id='afni-3dcalc-fmap',
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
    pcasl >> afni_3dcalc_fmap