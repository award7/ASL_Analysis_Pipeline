from shutil import move as mv
import os


class Sort:

    def __init__(self):
        pass

    @staticmethod
    def rename_subj_dir(self, img_dir: str) -> None:
        # TODO: use PatientName field from dicom image to rename src directory
        pass

    @staticmethod
    def rename_scan_dir(self, src_dir: str) -> None:
        # TODO: remove spaces; replace with underscores
        #  compare AcquisitionTime to rename ASL directories
        pass

    @staticmethod
    def move_raw_files(src_dir: str, dst_dir: str) -> None:
        for file in os.listdir(src_dir):
            if not os.path.isfile(file):
                continue
            mv(os.path.join(src_dir, file), dst_dir)

    @staticmethod
    def add_subdir(img_dir: str) -> None:
        """add subdirectories to each scan folder"""
        subdir = [
            "raw",
            "proc",
            "data"
        ]
        for sub in subdir:
            os.makedirs(os.path.join(img_dir, sub), exist_ok=True)

    @staticmethod
    def add_dcm_extension(img_dir: str) -> None:
        """add .dcm extension to all files for a scan"""
        for file in os.listdir(img_dir):
            if not os.path.isfile(file):
                continue
            file = file.replace(' ', '_')
            head, tail = os.path.splitext(file)
            if not tail:
                src = os.path.join(img_dir, file)
                dst = os.path.join(img_dir, file + '.dcm')

                if not os.path.exists(dst):
                    os.rename(src, dst)