import os
from glob import glob


"""functions to be used in conjunction with asl* dags"""


def count_t1_images(folder: str, count: int) -> str:
    """
    Count the number of raw T1 images. If the number is below a threshold, then reslice; otherwise, continue
    :param folder: absolute path to raw T1 files
    :type folder: str
    :param count: number of expected raw T1 files
    :type count: int
    :return: next task_id in the pipeline
    :rtype: str
    """

    file_count = len(os.listdir(folder))
    if file_count < count:
        return 'reslice-t1'
    return 'dcm2niix'


def get_file(file_name: str, path: str) -> str:
    """
    Get file using glob and push actual file name to xcom with the associated key
    :param file_name: file name to search for. Can be exact or with wildcards
    :type file_name: str
    :param path: absolute path to search for `file_name`
    :type path: str
    :return: file name found that is pushed to xcom
    :rtype: str
    """

    files = glob(os.path.join(path, file_name))
    if len(files) < 1:
        FileExistsError(f"No files found in {path} that match the search term {file_name}")
    if len(files) > 1:
        FileExistsError(f"Multiple files found in {path} that match the search term {file_name}:\n"
                        f"{files}")
    return files[0]


def move_file(ti, source_directory: str, target_directory: str, task_id: str, xcom_key: str = 'value') -> None:
    """
    Move file(s) to target directory
    :param ti: task instance object
    :param source_directory: source directory where file is currently stored
    :type source_directory: str
    :param target_directory: target directory to move the file to
    :type target_directory: str
    :param task_id: task_id from which to perform xcom_pull
    :type task_id: str
    :param xcom_key: xcom key associated with file and task_id
    :type xcom_key: str
    :return: None
    """

    file = ti.xcom_pull(task_ids=[task_id], key=xcom_key)
    os.replace(os.path.join(source_directory, file), os.path.join(target_directory, file))


def make_dir(path: str, directory: str) -> None:
    os.makedirs(os.path.join(path, directory), exist_ok=True)


def count_asl_images(folder: str, count: int):
    file_count = len(os.listdir(folder))
    if file_count < count:
        return 'not-enough-asl-dcm'
    return 'run-downstream-asl-processing'


def get_asl_sessions(ti, folder: str):
    """
    Count the number of ASL sessions (i.e. scans) and push the session name to xcom
    :param ti: task instance object
    :param folder: absolute path to parent directory housing child ASL session folders
    :return: None
    """
    sessions = glob(os.path.join(folder, 'asl*'))
    for session in sessions:
        ti.xcom_push(key='session', value=session)


def create_asl_downstream_dag(ti):
    """
    Create downstream asl_downstream DAG(s) based on the number of ASL sessions
    :param ti: task instance object
    :return: generator containing key-value pairs for DAGs
    """
    sessions = ti.xcom_pull(task_ids=['get-asl-sessions'], key='session')
    for session in sessions:
        yield {'session': session}
