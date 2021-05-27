import os
import docker
from imagesort import Sort
from utils.image_builder import check_img
from utils.bind_volumes import create_vols
from utils.condense_id import condense_id


class Preprocess:

    def __init__(self, subj_id: str):
        self.subj_id = condense_id(subj_id)
        self.client = docker.from_env()

        # set images
        self.dcm2niix_img = 'asl/dcm2niix'
        self.afni_img = 'asl/afni'
        self.pcasl_3df_img = 'asl/3df_pcasl'
        self.spm_img = 'asl/spm'
        self.fsl_img = 'asl/fsl'

        # make default volume bindings in container
        self.default_indir = 'mnt/data/in'
        self.default_outdir = 'mnt/data/out'
        self.default_mask_dir = '/mnt/data/masks'

        # within spm container
        self.spm_script_path = '/scripts'

    def sort(self, indir: str) -> None:
        # TODO: add dicomsort here
        """tidy up the sorting by adding necessary subdirectories, adding .dcm extension, and moving the raw files"""
        sorter = Sort()
        sorter.add_subdir(indir)
        sorter.add_dcm_extension(indir)
        dst = os.path.join(indir, "raw")
        sorter.move_raw_files(indir, dst)

    def dcm2niix(self, indir: str, outdir: str = None, fname: str = None) -> None:
        """ Convert DICOM images to Nifti format via dcm2niix """

        # make default fname if needed
        if fname is None:
            fname = f"t1_{self.subj_id}"

        # make docker image if doesn't exist
        check_img(self.dcm2niix_img)

        # setup container volumes
        mapping = {
            indir: self.default_indir,
            outdir: self.default_outdir
        }
        vols = create_vols(mapping)

        # make command to run in container
        cmd = f"dcm2niix -f {fname} -o {outdir} {indir}"

        # run container
        self.client.containers.run(
            image=self.dcm2niix_img,
            command=cmd,
            volumes=vols,
            working_dir=indir,
            remove=True
        )

    def to3d(self, subj_id: str, indir: str, outdir: str = None, fname: str = None, nt: int = None,
             tr: int = 1000) -> None:
        """ Convert raw ASL images to 3D volume via AFNI """

        # make default fname
        if fname is None:
            # split indir to get asl folder name
            # folder structure should follow this setup as established during sorting  '/path/to/aslX/raw'
            asl_id = os.path.normpath(indir).split(os.sep)
            fname = f"zt_{self.subj_id}_{asl_id}"

        # get list of raw .dcm files
        dcm = []
        for file in os.listdir(indir):
            if file.endswith(".dcm"):
                dcm.append(file)

        # set nt
        if nt is None:
            nt = len(dcm) / 2

        # make docker image if doesn't exist
        check_img(self.afni_img, self.client)

        # setup container volumes
        mapping = {
            indir: self.default_indir,
            outdir: self.default_outdir
        }
        vols = create_vols(mapping)

        # make command to run in container
        # not sure if this will work...
        cmd = f"to3d -prefix {fname} -fse -time:zt {nt} 2 {tr} seq+z {dcm}"

        # run container
        self.client.containers.run(
            image=self.afni_img,
            command=cmd,
            volumes=vols,
            working_dir=indir,
            remove=True
        )

    def pcasl_3df(self, file: str) -> None:
        """Create quantitative CBF maps"""

        # make docker image if doesn't exist
        # TODO: pcasl_3df needs its own image
        check_img(self.pcasl_3df_img, self.client)

        # extract filename and path from file
        indir, fname = os.path.dirname(file)

        # setup container volumes
        # the 3df_pcasl command saves its output to the working directory
        mapping = {
            indir: self.default_indir,
        }
        vols = create_vols(mapping)

        # make command to run in container
        cmd = f"3df_pcasl -nex 3 -odata {fname}"

        # run container
        self.client.containers.run(
            image=self.pcasl_3df_img,
            command=cmd,
            volumes=vols,
            working_dir=indir,
            remove=True
        )

    def fmap(self, indir: str, outdir: str = None, fname: str = None) -> None:
        """Create fmap via afni"""

        # make default fname
        if fname is None:
            pass

        # make docker image if doesn't exist
        check_img(self.afni_img, self.client)

        # setup container volumes
        mapping = {
            indir: self.default_indir,
            outdir: self.default_outdir
        }
        vols = create_vols(mapping)

        # make command to run in container
        cmd = ""

        # run container
        self.client.containers.run(
            image=self.afni_img,
            command=cmd,
            volumes=vols,
            working_dir=indir,
            remove=True
        )

    def pdmap(self, indir: str, outdir: str = None, fname: str = None) -> None:
        """Create pdmap via afni"""

        # make default fname
        if fname is None:
            pass

        # make docker image if doesn't exist
        check_img(self.afni_img, self.client)

        # setup container volumes
        mapping = {
            indir: self.default_indir,
            outdir: self.default_outdir
        }
        vols = create_vols(mapping)

        # make command to run in container
        cmd = ""

        # run container
        self.client.containers.run(
            image=self.afni_img,
            command=cmd,
            volumes=vols,
            working_dir=indir,
            remove=True
        )

    def segment(self, file: str, outdir: str = None) -> None:
        """segment t1 image via spm"""

        # make docker image if doesn't exist
        check_img(self.spm_img, self.client)

        # parse files and paths
        fpath, fname = os.path.split(file)

        # setup container volumes
        mapping = {
            fpath: self.default_indir,
            outdir: self.default_outdir
        }
        vols = create_vols(mapping)

        # setup args for script
        spm_script = "segment.m"
        fname_arg = f"{vols[fpath]['''bind''']}/{fname}"
        outdir_arg = f"outdir {vols[outdir]['''bind''']}"

        # make command to run in container
        cmd = f"{self.spm_script_path}/{spm_script} {fname_arg} 'outdir' {outdir_arg}"

        # run container
        self.client.containers.run(
            image=self.spm_img,
            command=cmd,
            volumes=vols,
            working_dir=vols[fpath]['''bind'''],
            remove=True
        )

    def smooth(self, file: str, outdir: str = None, fwhm: tuple = (5, 5, 5), prefix='s') -> None:
        """smooth image via spm"""

        # make docker image if doesn't exist
        check_img(self.spm_img, self.client)

        # parse files and paths
        fpath, fname = os.path.split(file)

        # setup container volumes
        mapping = {
            fpath: self.default_indir,
            outdir: self.default_outdir
        }
        vols = create_vols(mapping)

        # setup args for script
        spm_script = "smooth.m"
        fname_arg = f"{vols[fpath]['''bind''']}/{fname}"
        outdir_arg = f"outdir {vols[outdir]['''bind''']}"
        fwhm_arg = f"fwhm {','.join(map(str, fwhm))}"
        prefix_arg = f"prefix {prefix}"

        # make command to run in container
        cmd = f"{self.spm_script_path}/{spm_script} {fname_arg} 'outdir' {outdir_arg} 'fwhm' {fwhm_arg} \
                'prefix' {prefix_arg}"

        # run container
        self.client.containers.run(
            image=self.spm_img,
            command=cmd,
            volumes=vols,
            working_dir=vols[fpath]['''bind'''],
            remove=True
        )

    def coregister(self, ref: str, src: str, other: str = None, outdir: str = None, fwhm: tuple = (7, 7),
                   interp: int = 7, prefix: str = 'r') -> None:
        """coregister image (ASL and GM) via spm"""

        # make docker image if doesn't exist
        check_img(self.spm_img, self.client)

        # parse files and paths
        ref_fpath, ref_fname = os.path.split(ref)
        src_fpath, src_fname = os.path.split(src)
        if other is not None:
            other_fpath, other_fname = os.path.split(other)

        # setup container volumes
        mapping = {
            ref_fpath: f"{self.default_indir}/ref",
            src_fpath: f"{self.default_indir}/src",
            outdir: self.default_outdir
        }
        if other is not None:
            mapping[other_fpath] = f"{self.default_indir}/other"
        vols = create_vols(mapping)

        # setup args for script
        spm_script = "coregister.m"
        ref_arg = f"{vols[ref_fpath]['''bind''']}/{ref}"
        src_arg = f"{vols[src_fpath]['''bind''']}/{src}"
        if other is not None:
            other_arg = f"{vols[other_fpath]['''bind''']}/{other}"
        outdir_arg = f"outdir {vols[outdir]['''bind''']}"
        fwhm_arg = f"fwhm {','.join(map(str, fwhm))}"
        interp_arg = f"interp {interp}"
        prefix_arg = f"prefix {prefix}"

        # make command to run in container
        cmd = f"{self.spm_script_path}/{spm_script} {ref_arg} {src_arg} 'outdir' {outdir_arg} \
                'fwhm' {fwhm_arg} 'interp' {interp_arg} 'prefix' {prefix_arg}"
        if other is not None:
            cmd = f"{cmd} 'other' {other_arg}"

        # run container
        self.client.containers.run(
            image=self.spm_img,
            command=cmd,
            volumes=vols,
            working_dir=vols[ref_fpath]['''bind'''],
            remove=True
        )

    def normalize(self, file: str, deform_field: str, bias: str, other: str = None, outdir: str = None,
                  interp: int = 7, prefix: str = 'w') -> None:
        """normalize image via spm"""

        # make docker image if doesn't exist
        check_img(self.spm_img, self.client)

        # parse files and paths
        fpath, fname = os.path.split(file)
        deform_fpath, deform_fname = os.path.split(deform_field)
        bias_fpath, bias_fname = os.path.split(bias)
        if other is not None:
            other_fpath, other_fname = os.path.split(other)

        # setup container volumes
        mapping = {
            fpath: self.default_indir,
            deform_fpath: f"{self.default_indir}/deform",
            bias_fpath: f"{self.default_indir}/bias",
            outdir: self.default_outdir
        }
        if other is not None:
            mapping[other_fpath] = f"{self.default_indir}/other"
        vols = create_vols(mapping)

        # setup args for script
        spm_script = 'normalize.m'
        fname = f"{vols[indir]['''bind''']}/{fname}"


        # make command to run in container

        # run container
        self.client.containers.run(
            image=self.spm_img,
            command=cmd,
            volumes=vols,
            working_dir=indir,
            remove=True
        )

    def create_icv_mask(self, subj_id: str, deform_field: str, fov: str, outdir: str = None, fwhm: tuple = (0, 0, 0),
                        prefix: str = 'wt1') -> None:
        """create icv mask via spm"""
        pass

    def create_asl_mask(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """create asl mask via spm"""
        pass

    def calc_global_asl(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """calculate global asl value via spm"""
        pass

    def inverse_warp(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """perform inverse warp on image via spm"""
        pass

    def inverse_warp_gm(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """perform inverse warp on a gm image via spm"""
        pass

    def calc_brain_vols(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """calculate brain volumes via spm"""
        pass

    def fsl_stats(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """calculate ROI ASL values via fsl"""
        pass

