import os
import sys
import argparse
from datetime import datetime
from Preprocess import Preprocess


class AslProc:
    # inspired by https://chase-seibert.github.io/blog/2014/03/21/python-multilevel-argparse.html

    def __init__(self, argin: list):
        parser = argparse.ArgumentParser(
            prog="AslProc",
            description="ASL preprocessing functions",
            usage="aslproc <id> <command> [<args>]"
        )
        parser.add_argument(
            'id',
            type=str,
            help="Subject ID")
        commands = [
            "dcm2niix",
            "fmap",
            "segment"
        ]
        parser.add_argument(
            'command',
            choices=commands,
            help='Command to run'
        )

        """parse_args defaults to [1:] for args, but you need to
        exclude the rest of the args too, or validation will fail"""
        args = parser.parse_args(argin[1:3])
        self.id = args.id
        if not hasattr(self, args.command):
            print('Unrecognized command')
            parser.print_help()
            exit(1)
        # use dispatch pattern to invoke method with same name
        getattr(self, args.command)(argin[3:])

    def dcmsort(self) -> None:
        pass

    def dcm2niix(self, argin: list) -> None:
        parser = argparse.ArgumentParser(
            description="Perform DIOCM to Nifti conversion using dcm2niix",
            usage="dcm2niix [OPTIONS]"
        )
        parser.add_argument(
            "-i",
            "--input",
            type=str,
            default=os.getcwd(),
            help="Input directory (default = %(default)s"
        )
        parser.add_argument(
            "-o",
            "--output",
            type=str,
            default=os.getcwd(),
            help="Output directory (default = %(default)s"
        )
        parser.add_argument(
            "-f",
            "--filename",
            type=str,
            default=f"t1_{self._condense_id()}",
            help="Output file name (default = %(default)s)"
        )
        args = self._parse_args(parser, argin)
        pproc = Preprocess()
        pproc.dcm2niix(args.input, args.output, args.filename)

    def to3d(self, argin: list) -> None:
        parser = argparse.ArgumentParser(
            description="Perform AFNI to3d function to create .BRIK and .HEAD files",
            usage="to3d -i [PATH] [OPTIONS]"
        )
        parser.add_argument(
            "-i",
            "--input",
            type=list,
            required=True,
            help="List of raw DICOM files"
        )
        parser.add_argument(
            "-o",
            "--output",
            type=str,
            default=os.getcwd(),
            help="Output directory (default = %(default)s)"
        )
        parser.add_argument(
            "-p",
            "--prefix",
            type=str,
            default=f"zt_{self._condense_id()}_{self._timestamp()}",
            help="Output file name prefix (default = %(default)s)"
        )
        parser.add_argument(
            "-nt",
            type=int,
            help="Number of raw DICOM files"
        )
        parser.add_argument(
            "-tr",
            type=int,
            default=1000,
            help="Repetition time (ms) (default=%(default)d)"
        )
        args = self._parse_args(parser, argin)

    def pcasl_3df(self, argin: list) -> None:
        parser = argparse.ArgumentParser(
            description="Perform GE 3dfpcasl function to create quantitative CBF maps",
            usage="pcasl_3df -i [PATH] [OPTIONS]"
        )
        parser.add_argument(
            "-i", "--input",
            type=str,
            required=True,
            help="Input file"
        )
        parser.add_argument(
            "-o",
            "--outfile",
            type=str,
            default=os.getcwd(),
            help="Output directory (default = %(default)s)"
        )
        parser.add_argument(
            "-p",
            "--prefix",
            type=str,
            default=f"zt_{self._condense_id()}_{self._timestamp()}",
            help="Output file name prefix (default = %(default)s"
        )
        args = self._parse_args(parser, argin)

    def fmap(self, argin: list) -> None:
        parser = argparse.ArgumentParser(
            description="Perform AFNI 3dcalc function to create ASL fmap",
            usage="fmap -i [PATH] [OPTIONS]"
        )
        parser.add_argument(
            "-i",
            "--input",
            required=True,
            type=str,
            help="Input file"
        )
        parser.add_argument(
            "-o",
            "--output",
            type=str,
            default=os.getcwd(),
            help="Output directory (default = %(default)s)"
        )
        parser.add_argument(
            "-f",
            "--filename",
            type=str,
            default=f"asl_fmap_{self._condense_id()}_{self._timestamp()}.nii",
            help="Output file name (default = %(default)s)"
        )
        args = self._parse_args(parser, argin)

    def pdmap(self, argin: list) -> None:
        parser = argparse.ArgumentParser(
            description="Perform AFNI 3dcalc function to create proton density map",
            usage="pdmap -i [PATH] [OPTIONS]"
        )
        parser.add_argument(
            "-i",
            "--input",
            required=True,
            type=str,
            help="Input file"
        )
        parser.add_argument(
            "-o",
            "--output",
            type=str,
            default=os.getcwd(),
            help="Output directory (default = %(default)s)"
        )
        parser.add_argument(
            "-f",
            "--filename",
            type=str,
            default=f"pdmap_{self._condense_id()}_{self._timestamp()}.nii",
            help="Output file name (default = %(default)s)"
        )
        args = self._parse_args(parser, argin)

    def segment(self, argin: list) -> None:
        parser = argparse.ArgumentParser(
            description="Perform T1 segmentation",
            usage="segment -i [PATH] [OPTIONS]"
        )
        parser.add_argument(
            "-i",
            "--input",
            required=True,
            type=str,
            help="Path to T1 .nii file"
        )
        parser.add_argument(
            "-o",
            "--output",
            type=str,
            default=os.getcwd(),
            help="Output directory (default = %(default)s")
        args = self._parse_args(parser, argin)

    def _condense_id(self) -> str:
        return self.id.replace("_", "")

    @staticmethod
    def _parse_args(parser, args: list) -> object:
        return parser.parse_args(args)

    @staticmethod
    def _timestamp() -> str:
        return datetime.now().strftime('%Y%m%d_%H%M%S')


if __name__ == '__main__':
    AslProc(sys.argv)
