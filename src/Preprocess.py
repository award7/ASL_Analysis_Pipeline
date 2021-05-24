import os
import docker
from imagesort import Sort
from DockerImageBuilder import Builder


# decorators
def validate_args(func):
    def wrapper(**kwargs):
        if 'subj_id' in kwargs:
            subj_id = kwargs['subj_id']
            if not type(subj_id) == str:
                raise TypeError(f"{subj_id} is required to be a string")
        if 'indir' in kwargs:
            indir = kwargs['indir']
            if not os.path.isdir(indir):
                raise NotADirectoryError(f"{indir} is not a valid directory")
        if 'outdir' in kwargs:
            outdir = kwargs['outdir']
            if outdir is not None:
                if not os.path.isdir(outdir):
                    raise NotADirectoryError(f"{outdir} is not a valid directory")
            else:
                kwargs['outdir'] = kwargs.get('indir')
        if 'infile' in kwargs:
            infile = kwargs['infile']
            if not os.path.isfile(infile):
                raise FileNotFoundError(f"{infile} not found")
            else:
                # strip away path if needed
                kwargs['infile'] = os.path.split(infile)[1]
        if 'fname' in kwargs:
            fname = kwargs['fname']
            if fname is not None:
                # remove file extension (just in case)
                kwargs['fname'] = os.path.splitext(str(fname))[0]
        func(**kwargs)

    return wrapper


class Preprocess:

    def __init__(self, subj_id: str = None):
        self.client = docker.from_env()
        self.builder = Builder(self.client)
        self.subj_id = subj_id

    def sort(self, indir: str) -> None:
        # TODO: add dicomsort here
        """tidy up the sorting by adding necessary subdirectories, adding .dcm extension, and moving the raw files"""
        sorter = Sort()
        sorter.add_subdir(indir)
        sorter.add_dcm_extension(indir)
        dst = os.path.join(indir, "raw")
        sorter.move_raw_files(indir, dst)

    def dcm2niix(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """ Convert DICOM images to Nifti format via dcm2niix """

        # make default fname if needed
        if fname is None:
            fname = f"t1_{self._condense_id(subj_id)}"

        """ make docker image if doesn't exist """
        img = "asl/dcm2niix"
        self._check_for_image(img)

        """ setup container parameters """
        vols = self._get_generic_vols(indir, outdir)

        """ run container """
        cmd = f"dcm2niix -f {fname} -o /mnt/data/out /mnt/data/in"
        self._run_container(img, cmd, vols=vols)

    # @validate_args
    def to3d(self, subj_id: str, indir: str, outdir: str = None, fname: str = None, nt: int = 0,
             tr: int = 1000) -> None:
        """ Convert raw ASL images to 3D volume via AFNI """

        # make default fname
        if fname is None:
            basename = os.path.basename(indir)
            fname = f"zt_{self._condense_id(subj_id)}_{basename}"

        # get list of raw .dcm files
        dcm = []
        for file in os.listdir(indir):
            if file.endswith(".dcm"):
                dcm.append(file)

        # set nt
        if nt == 0:
            nt = len(dcm) / 2

        """ make docker image if doesn't exist """
        img = "asl/afni"
        self._check_for_image(img)

        """ setup container parameters """
        vols = self._get_generic_vols(indir, outdir)

        """ run container """
        cmd = f"to3d -prefix {fname} -fse -time:zt {nt} 2 {tr} seq+z {dcm}"
        self._run_container(cmd, img, vols=vols, wd="/mnt/data/in")

    # @validate_args
    def pcasl_3df(self, subj_id: str, infile: str) -> None:
        """ Create quantitative CBF maps """

        """ make docker image if doesn't exist """
        # TODO: pcasl_3df actually needs its own image
        img = "asl/afni"
        self._check_for_image(img)

        """ setup container parameters """
        indir = os.path.split(os.path.abspath(infile))[0]
        vols = self._get_generic_vols(indir)

        """ run container """
        cmd = f"3df_pcasl -nex 3 -odata {infile}"
        self._run_container(cmd, img, vols=vols, wd="/mnt/data/in")

    # @validate_args
    def fmap(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """Create fmap via afni"""

        """ make docker image if doesn't exist """
        img = "asl/afni"
        self._check_for_image(img)

        """ setup container parameters """
        vols = self._get_generic_vols(indir, outdir)

        """ run container """
        # cmd = f"to3d -prefix {fname} -fse -time:zt {nt} 2 {tr} seq+z {dcm}"
        # self._run_container(cmd, img, vols=vols, wd="/mnt/data/in")

    # @validate_args
    def pdmap(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """Create pdmap via afni"""

        """ make docker image if doesn't exist """
        img = "asl/afni"
        self._check_for_image(img)

        """ setup container parameters """
        vols = self._get_generic_vols(indir, outdir)

        """ run container """
        # cmd = f"to3d -prefix {fname} -fse -time:zt {nt} 2 {tr} seq+z {dcm}"
        # self._run_container(cmd, img, vols=vols, wd="/mnt/data/in")

    def segment(self, indir: str, outdir: str = None, fname: str = None) -> None:
        """segment t1 image via spm"""

        """make docker image if doesn't exist"""
        img = "asl/spm"
        self._check_for_image(img)

        """setup container parameters"""
        script_host = "C:/Users/atward/Desktop"
        script_mnt = "/mnt/data/script/segment.m"
        vols = self._get_generic_vols(indir, outdir, script_host)
        arg0 = f"{vols['indir']}/{fname}"
        arg1 = f"{vols['outdir']}"

        """run container"""
        cmd = f"{script_mnt} {arg0} {arg1}"
        self._run_container(img, cmd, vols=vols)

    # @validate_args
    def smooth(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """smooth image via spm"""
        pass

    # @validate_args
    def coregister(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """coregister image (ASL and GM) via spm"""
        pass

    # @validate_args
    def normalize(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """normalize image via spm"""
        pass

    # @validate_args
    def create_icv_mask(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """create icv mask via spm"""
        pass

    # @validate_args
    def create_asl_mask(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """create asl mask via spm"""
        pass

    # @validate_args
    def calc_global_asl(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """calculate global asl value via spm"""
        pass

    # @validate_args
    def inverse_warp(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """perform inverse warp on image via spm"""
        pass

    # @validate_args
    def inverse_warp_gm(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """perform inverse warp on a gm image via spm"""
        pass

    # @validate_args
    def calc_brain_vols(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """calculate brain volumes via spm"""
        pass

    # @validate_args
    def fsl_stats(self, subj_id: str, indir: str, outdir: str = None, fname: str = None) -> None:
        """calculate ROI ASL values via fsl"""
        pass

    # helper fcns
    def _check_for_image(self, img: str) -> None:
        try:
            self.client.images.get(img)
        except docker.errors.ImageNotFound:
            # strip 'asl/' from img name
            method = img.split('/')[-1]
            # use dispatcher design pattern to call method
            getattr(self.builder, method)()

    def _run_container(self, img: str, cmd: str, name: str = None, vols: dict = None, wd: str = None) -> None:
        if wd is None:
            wd = "/mnt/data/in"

        self.client.containers.run(
            image=img,
            command=cmd,
            name=name,
            volumes=vols,
            working_dir=wd,
            remove=True
        )

    @staticmethod
    def _condense_id(subj_id: str) -> str:
        return subj_id.replace("_", "")

    @staticmethod
    def _get_generic_vols(indir: str, outdir: str = None, mask: str = None, script: str = None) -> dict:
        if outdir is None:
            outdir = indir

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

        if mask is not None:
            vols[mask] = {
                'bind': '/mnt/data/mask',
                'mode': 'rw'
            }

        if script is not None:
            vols[script] = {
                'bind': '/mnt/data/script',
                'mode': 'rw'
            }

        return vols
