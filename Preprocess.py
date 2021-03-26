import os
import docker
from DockerImageBuilder import Builder


class Preprocess:

    def __init__(self):
        self.client = docker.from_env()
        self.builder = Builder()


    def dcm2niix(self, indir: str, outdir: str, fname: str) -> None:
        """Convert DICOM images to Nifti format via dcm2niix"""
        # validate inputs
        if not os.path.isdir(indir):
            raise NotADirectoryError(f"{indir} is not a valid directory")
        if not os.path.isdir(outdir):
            raise NotADirectoryError(f"{outdir} is not a valid directory")
        if not type(fname) == str:
            raise TypeError(f"{fname} is required to be a string")

        # remove file extension (just in case)
        fname = os.path.splitext(fname)[0]

        # make image if doesn't exist
        img = "aslproc/dcm2niix"
        if img not in self.client.images.list():
            self.builder.dcm2niix()

        # setup container parameters
        vols = {
            indir: {
                'bind': '/mnt/data/in',
                'mode': 'rw'
            },
            outdir: {
                'bind': '/mnt/data/out',
                'mode': 'rw'
            }
        }

        # run container
        self.client.containers.run(
            f"dcm2niix -f {fname} -o /mnt/data/out /mnt/data/in",
            image=img,
            name="dcm2niix_cont",
            volumes=vols,
            working_dir='/mnt/data/in',
            remove=True
        )


class pproc:
    # TODO: switch inputs to argparse input
    def __init__(self, subject, subject_directory, asl_directory, coreg_method="A") -> None:
        self.subject_id = subject
        self.subject_directory = subject_directory
        self.asl_directory = asl_directory
        self.coreg_method = coreg_method

        self.t1_directory = os.path.join(self.subject_directory, "t1")
        self.aal_invwarp_directory = os.path.join(self.t1_directory, "mask", "aal", "invwarp")
        self.aal_invwarpXgm_directory = os.path.join(self.t1_directory, "mask", "aal", "invwarpXgm")
        self.lobe_invwarp_directory = os.path.join(self.t1_directory, "mask", "aal", "invwarp")
        self.lobe_invwarpXgm_directory = os.path.join(self.t1_directory, "mask", "aal", "invwarpXgm")

        self.aal_masks = [os.path.abspath(x) for x in os.listdir("/usr/local/bin/masks/aal/") if x.endswith(".nii")]
        self.aal_masks.append("/usr/local/MATLAB/spm12/aal_for_SPM12/aal_for_SPM12/ROI_MNI_V4.nii")
        self.lobe_masks = [os.path.abspath(x) for x in os.listdir("/usr/local/bin/masks/lobes/") if x.endswith(".nii")]

        self.asl_data_subdirectory = None
        self.asl_processed_directory = None
        self.fmap = None
        self.pdmap = None
        self.coreg_fmap = None
        self.coreg_pdmap = None
        self.normalized_coreg_fmap = None
        self.normalized_coreg_pdmap = None
        self.smoothed_normalized_coreg_fmap = None
        self.smoothed_normalized_coreg_pdmap = None
        self.asl_mask = None

        self.t1_data_directory = None
        self.t1_processed_directory = None
        self.t1_image = None
        self.t1_seg8mat = None
        self.t1_bias_corrected = None
        self.t1_deformation_field = None
        self.gm_image = None
        self.wm_image = None
        self.smoothed_gm_image = None
        self.normalized_gm_image = None
        self.smoothed_normalized_gm_image = None
        self.icv_mask = None

        self._set_asl_paths()
        self._set_t1_paths()

    def segment_t1(self):
        print("---segmenting T1 image...")
        # sl_segment(self.t1_image, self.t1_processed_directory)

    def smooth_gm(self):
        print("---smoothing T1 image...")
        # sl_smooth(self.gm_image, self._t1_processed_directory)

    def coregister_gm_asl(self):
        print("---coregistering images...")
        # sl_coreg(self.smoothed_gm_image, self.pdmap, self.fmap, self.asl_processed_directory)

    def noramlize_img(self):
        print("---normalizing and smoothing image...")
        # sl_normalize(self.t1_deformation_field, self.t1_bias_corrected, self.coreg_fmap, self.coreg_pdmap, self.asl_processed_directory)

    def create_icv_mask(self):
        print("--creating ICV brain mask...")
        # sl_brainmask(self.t1_deformation_field, self.smoothed_gm_image)
        _subject_id = self.subject_id.replace("_", "")
        fname = os.path.join(self.t1_processed_directory, f"wt1_{_subject_id}_mask_icv.nii")
        os.rename("wmask_ICV.nii", os.path.join(self.t1_processed_directory, fname))
        self.icv_mask = fname

    def create_asl_mask(self):
        print("---applying brain mask to ASL image...")
        # sl_brainmask_asl(self.icv_mask, self.coreg_fmap, self.asl_processed_directory)
        _subject_id = self.subject_id.replace("_", "")
        asl_timepoint = os.path.basename(self.asl_directory)
        fname = os.path.join(self.asl_processed_directory, f"rasl_fmap_{self.subject_id}_{asl_timepoint}_bmasked.nii")
        os.rename(os.path.join(self.asl_processed_directory, "output.nii"), fname)
        self.asl_mask = fname

    def calc_global_asl(self):
        print("---calculating global ASL value...")
        # TODO: revamp this with matlab.engine to call spm OR make a wrapper for direct calls to spm

    def inverse_warp(self, masks: list, output_dir: str = None) -> None:
        subject_id = self.subject_id.replace("_", "")
        for mask in masks:
            print(f"---applying deformation field to {mask}...")
            # TODO: extract mask name, set new outname, call invwarp fcn

    def inverse_warp_gm(self, masks: list, output_dir: str = None) -> None:
        subject_id = self.subject_id.replace("_", "")
        for mask in masks:
            print(f"---restricting {mask} to gray matter...")
            # TODO: extract mask name, set new outname, call invwarpXgm fcn

    def calc_brain_vols(self):
        print("---calculating segmented brain volumes...")
        # todo: call spm brain volumes, rename file, move

    def _set_asl_paths(self) -> None:
        # set paths and filenames for asl
        self.asl_data_subdirectory = os.path.join(self.asl_directory, "data")
        self.asl_processed_directory = os.path.join(self.asl_directory, "proc")
        processed_files = os.listdir(self.asl_processed_directory)
        for file in processed_files:
            file_prefix = file.find("_")
            if file_prefix == "asl":
                self.fmap = os.path.join(self.asl_processed_directory, file)
            elif file_prefix == "pdmap":
                self.pdmap = os.path.join(self.asl_processed_directory, file)
            elif file_prefix == "rasl":
                self.coreg_fmap = os.path.join(self.asl_processed_directory, file)
            elif file_prefix == "rpdmap":
                self.coreg_pdmap = os.path.join(self.asl_processed_directory, file)
            elif file_prefix == "wrasl":
                self.normalized_coreg_fmap = os.path.join(self.asl_processed_directory, file)
            elif file_prefix == "wrpdmap":
                self.normalized_coreg_pdmap = os.path.join(self.asl_processed_directory, file)
            elif file_prefix == "swrasl":
                self.smoothed_normalized_coreg_fmap = os.path.join(self.asl_processed_directory, file)
            elif file_prefix == "swrpdmap":
                self.smoothed_normalized_coreg_pdmap = os.path.join(self.asl_processed_directory, file)

    def _set_t1_paths(self) -> None:
        # set paths and filenames for t1
        self.t1_data_directory = os.path.join(self.t1_directory, "data")
        self.t1_processed_directory = os.path.join(self.t1_directory, "proc")
        processed_files = os.listdir(self.t1_processed_directory)
        for file in processed_files:
            file_prefix = file.find("_")
            if file_prefix == "t1":
                if file.endswith(".nii"):
                    self.t1_image = os.path.join(self.t1_processed_directory, file)
                elif file.endswith(".mat"):
                    self.t1_seg8mat = os.path.join(self.t1_processed_directory, file)
            elif file_prefix == "c1t1":
                self.gm_imgae = os.path.join(self.t1_processed_directory, file)
            elif file_prefix == "c2t1":
                self.wm_image = os.path.join(self.t1_processed_directory, file)
            elif file_prefix == "mt1":
                self.t1_bias_correctedd = os.path.join(self.t1_processed_directory, file)
            elif file_prefix == "y":
                self.t1_deformation_field = os.path.join(self.t1_processed_directory, file)
            elif file_prefix == "sc1t1":
                self.smoothed_gm_image = os.path.join(self.t1_processed_directory, file)
            elif file_prefix == "wmt1":
                self.normalized_gm_image = os.path.join(self.t1_processed_directory, file)
            elif file_prefix == "swmt1":
                self.smoothed_normalized_gm_image = os.path.join(self.t1_processed_directory, file)
            elif file_prefix == "wt1":
                self.icv_mask = os.path.join(self.t1_processed_directory, file)

    # methods for organizing files and dirs
    def rename_dir(self):
        pass

    def add_directories(self):
        pass

    def get_subfolders(self):
        pass



    # methods for asl processing
    def asl_proc(self):
        pass

    def fmap_make(self):
        pass

    def fsl_stats(self):
        pass

    # methods for fressurfer cortical thickness processing
    def fs_proc(self):
        pass

    # methods for dti processing in freesurfer
    def dti_proc(self):
        pass

    # getters
    @property
    def subject_id(self):
        return self._subject_id

    @property
    def subject_directory(self):
        return self._subject_directory

    @property
    def asl_directory(self):
        return self._asl_directory

    @property
    def coreg_method(self):
        return self._coreg_method

    @property
    def t1_directory(self):
        return self._t1_directory

    @property
    def aal_invwarp_directory(self):
        return self._aal_invwarp_directory

    @property
    def aal_invwarpXgm_directory(self):
        return self._aal_invwarpXgm_directory

    @property
    def lobe_invwarp_directory(self):
        return self._lobe_invwarp_directory

    @property
    def lobe_invwarpXgm_directory(self):
        return self._lobe_invwarpXgm_directory

    @property
    def aal_masks(self):
        return self._aal_masks

    @property
    def lobe_masks(self):
        return self._lobe_masks

    @property
    def asl_data_subdirectory(self):
        return self._asl_data_subdirectory

    @property
    def asl_processed_directory(self):
        return self._asl_processed_directory

    @property
    def fmap(self):
        return self._fmap

    @property
    def pdmap(self):
        return self._pdmap

    @property
    def coreg_fmap(self):
        return self._coreg_fmap

    @property
    def coreg_pdmap(self):
        return self.normalized_coreg_pdmap

    @property
    def normalized_coreg_fmap(self):
        return self._normalized_coreg_fmap

    @property
    def normalized_coreg_pdmap(self):
        return self._normalized_coreg_pdmap

    @property
    def smoothed_normalized_coreg_fmap(self):
        return self._smoothed_normalized_coreg_fmap

    @property
    def smoothed_normalized_coreg_pdmap(self):
        return self._smoothed_normalized_coreg_pdmap

    @property
    def t1_data_directory(self):
        return self._t1_data_directory

    @property
    def t1_processed_directory(self):
        return self._t1_processed_directory

    @property
    def t1_image(self):
        return self._t1_image

    @property
    def t1_seg8mat(self):
        return self._t1_seg8mat

    @property
    def t1_bias_corrected(self):
        return self._t1_bias_corrected

    @property
    def t1_deformation_field(self):
        return self._t1_deformation_field

    @property
    def gm_image(self):
        return self._gm_image

    @property
    def wm_image(self):
        return self._wm_image

    @property
    def smoothed_gm_image(self):
        return self._smoothed_gm_image

    @property
    def normalized_gm_image(self):
        return self._normalized_gm_image

    @property
    def smoothed_normalized_gm_image(self):
        return self._smoothed_normalized_gm_image

    @property
    def icv_mask(self):
        return self._icv_mask

    # setters
    @subject_id.setter
    def subject_id(self, value):
        if len(value) < 1:
            raise ValueError("subject_id must be a non-zero length string")
        self._subject_id = str(value)

    @subject_directory.setter
    def subject_directory(self, value):
        if not os.path.isdir(value):
            raise ValueError(f"Invalid directory for subject_directory: {value}")
        self._subject_directory = value

    @asl_directory.setter
    def asl_directory(self, value):
        if not os.path.isdir(value):
            raise ValueError(f"Invalid directory for asl_directory: {value}")
        self._asl_directory = value

    @coreg_method.setter
    def coreg_method(self, value):
        options = ["A", "B"]
        if not str(value).casefold() in (opt.casefold() for opt in options):
            raise ValueError(f"Invalid coreg_method: {value}. Must be one of these options: {*options,}")
        self._coreg_method = value

    @t1_directory.setter
    def t1_directory(self, value):
        if not os.path.isdir(value):
            raise ValueError(f"Invalid directory for t1_directory: {value}")
        self._t1_directory = value

    @aal_invwarp_directory.setter
    def aal_invwarp_directory(self, value):
        if not os.path.isdir(value):
            raise ValueError(f"Invalid directory for aal_invwarp_directory: {value}")
        self._aal_invwarp_directory = value

    @aal_invwarpXgm_directory.setter
    def aal_invwarpXgm_directory(self, value):
        if not os.path.isdir(value):
            raise ValueError(f"Invalid directory for aal_invwarpXgm_directory: {value}")
        self._aal_invwarpXgm_directory = value

    @lobe_invwarp_directory.setter
    def lobe_invwarp_directory(self, value):
        if not os.path.isdir(value):
            raise ValueError(f"Invalid directory for lobe_invwarp_directory: {value}")
        self._lobe_invwarp_directory = value

    @lobe_invwarpXgm_directory.setter
    def lobe_invwarpXgm_directory(self, value):
        if not os.path.isdir(value):
            raise ValueError(f"Invalid directory for lobe_invwarpXgm_directory: {value}")
        self._lobe_invwarpXgm_directory = value

    @aal_masks.setter
    def aal_masks(self, value):
        if not [os.path.isdir(x) for x in value]:
            raise ValueError(f"Invalid directory for aal_masks: {value}")
        self._aal_masks = value

    @lobe_masks.setter
    def lobe_masks(self, value):
        if not [os.path.isdir(x) for x in value]:
            raise ValueError(f"Invalid directory for lobe_masks: {value}")
        self._lobe_masks = value

    @asl_data_subdirectory.setter
    def asl_data_subdirectory(self, value):
        if not os.path.isdir(value):
            raise ValueError(f"Invalid directory for asl_data_subdirectory: {value}")
        self._asl_data_subdirectory = value

    @asl_processed_directory.setter
    def asl_processed_directory(self, value):
        if not os.path.isdir(value):
            raise ValueError(f"Invalid directory for asl_processed_directory: {value}")
        self._asl_processed_directory = value

    @fmap.setter
    def fmap(self, value):
        # TODO: check file extension
        if not os.path.isfile(value):
            raise ValueError(f"Invalid file for fmap: {value}")
        self._fmap = value

    @pdmap.setter
    def pdmap(self, value):
        # TODO: check file extension
        if not os.path.isfile(value):
            raise ValueError(f"Invalid file for pdmap: {value}")
        self._pdmap = value

    @coreg_fmap.setter
    def coreg_fmap(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for coreg_fmap: {value}")
        self._coreg_fmap = value

    @coreg_pdmap.setter
    def coreg_pdmap(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for coreg_pdmap: {value}")
        self._coreg_pdmap = value

    @normalized_coreg_fmap.setter
    def normalized_coreg_fmap(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for normalized_coreg_fmap: {value}")
        self._normalized_coreg_fmap = value

    @normalized_coreg_pdmap.setter
    def normalized_coreg_pdmap(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for normalized_coreg_pdmap: {value}")
        self._normalized_coreg_pdmap = value

    @smoothed_normalized_coreg_fmap.setter
    def smoothed_normalized_coreg_fmap(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for smoothed_normalized_coreg_fmap: {value}")
        self._smoothed_normalized_coreg_fmap = value

    @smoothed_normalized_coreg_pdmap.setter
    def smoothed_normalized_coreg_pdmap(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for smoothed_normalized_coreg_pdmap: {value}")
        self._smoothed_normalized_coreg_pdmap = value

    @t1_data_directory.setter
    def t1_data_directory(self, value):
        if not os.path.isfile(value):
            raise ValueError(f"Invalid file for t1_data_directory: {value}")
        self._t1_data_directory = value

    @t1_processed_directory.setter
    def t1_processed_directory(self, value):
        if not os.path.isdir(value):
            raise ValueError(f"Invalid file for t1_processed_directory: {value}")
        self._t1_processed_directory = value

    @t1_image.setter
    def t1_image(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for t1_image: {value}")
        self._t1_image = value

    @t1_seg8mat.setter
    def t1_seg8mat(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for t1_seg8mat: {value}")
        self._t1_seg8mat = value

    @t1_bias_corrected.setter
    def t1_bias_corrected(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for t1_bias_corrected: {value}")
        self._t1_bias_corrected = value

    @t1_deformation_field.setter
    def t1_deformation_field(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for t1_deformation_field: {value}")
        self._t1_deformation_field = value

    @gm_image.setter
    def gm_image(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for gm_image: {value}")
        self._gm_image = value

    @wm_image.setter
    def wm_image(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for wm_image: {value}")
        self._wm_image = value

    @smoothed_gm_image.setter
    def smoothed_gm_image(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for smoothed_gm_image: {value}")
        self._smoothed_gm_image = value

    @normalized_gm_image.setter
    def normalized_gm_image(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for normalized_gm_image: {value}")
        self._normalized_gm_image = value

    @smoothed_normalized_gm_image.setter
    def smoothed_normalized_gm_image(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for smoothed_normalized_gm_image: {value}")
        self._smoothed_normalized_gm_image = value

    @icv_mask.setter
    def icv_mask(self, value):
        if not os.path.isfile(value) or str(value).endswith(".nii"):
            raise ValueError(f"Invalid file for icv_mask: {value}")
        self._icv_mask = value

    # deleters
    @subject_id.deleter
    def subject_id(self):
        del self._subject_id

    @subject_directory.deleter
    def subject_directory(self):
        del self._subject_directory

    @asl_directory.deleter
    def asl_directory(self):
        del self._asl_directory

    @coreg_method.deleter
    def coreg_method(self):
        del self._coreg_method

    @t1_directory.deleter
    def t1_directory(self):
        del self._t1_directory

    @aal_invwarp_directory.deleter
    def aal_invwarp_directory(self):
        del self._aal_invwarp_directory

    @aal_invwarpXgm_directory.deleter
    def aal_invwarpXgm_directory(self):
        del self._aal_invwarpXgm_directory

    @lobe_invwarp_directory.deleter
    def lobe_invwarp_directory(self):
        del self._lobe_invwarp_directory

    @lobe_invwarpXgm_directory.deleter
    def lobe_invwarpXgm_directory(self):
        del self._lobe_invwarpXgm_directory

    @aal_masks.deleter
    def aal_masks(self):
        del self._aal_masks

    @lobe_masks.deleter
    def lobe_masks(self):
        del self._lobe_masks

    @asl_data_subdirectory.deleter
    def asl_data_subdirectory(self):
        del self._asl_data_subdirectory

    @asl_processed_directory.deleter
    def asl_processed_directory(self):
        del self._asl_processed_directory

    @fmap.deleter
    def fmap(self):
        del self._fmap

    @pdmap.deleter
    def pdmap(self):
        del self._pdmap

    @coreg_fmap.deleter
    def coreg_fmap(self):
        del self._coreg_fmap

    @coreg_pdmap.deleter
    def coreg_pdmap(self):
        del self.normalized_coreg_pdmap

    @normalized_coreg_fmap.deleter
    def normalized_coreg_fmap(self):
        del self._normalized_coreg_fmap

    @normalized_coreg_pdmap.deleter
    def normalized_coreg_pdmap(self):
        del self._normalized_coreg_pdmap

    @smoothed_normalized_coreg_fmap.deleter
    def smoothed_normalized_coreg_fmap(self):
        del self._smoothed_normalized_coreg_fmap

    @smoothed_normalized_coreg_pdmap.deleter
    def smoothed_normalized_coreg_pdmap(self):
        del self._smoothed_normalized_coreg_pdmap

    @t1_data_directory.deleter
    def t1_data_directory(self):
        del self._t1_data_directory

    @t1_processed_directory.deleter
    def t1_processed_directory(self):
        del self._t1_processed_directory

    @t1_image.deleter
    def t1_image(self):
        del self._t1_image

    @t1_seg8mat.deleter
    def t1_seg8mat(self):
        del self._t1_seg8mat

    @t1_bias_corrected.deleter
    def t1_bias_corrected(self):
        del self._t1_bias_corrected

    @t1_deformation_field.deleter
    def t1_deformation_field(self):
        del self._t1_deformation_field

    @gm_image.deleter
    def gm_image(self):
        del self._gm_image

    @wm_image.deleter
    def wm_image(self):
        del self._wm_image

    @smoothed_gm_image.deleter
    def smoothed_gm_image(self):
        del self._smoothed_gm_image

    @normalized_gm_image.deleter
    def normalized_gm_image(self):
        del self._normalized_gm_image

    @smoothed_normalized_gm_image.deleter
    def smoothed_normalized_gm_image(self):
        del self._smoothed_normalized_gm_image

    @icv_mask.deleter
    def icv_mask(self):
        del self._icv_mask
