"""CLI parser for asl processing"""

import os
import sys
import argparse
# from preprocess import Preprocess


class AslProc:
    # inspired by https://chase-seibert.github.io/blog/2014/03/21/python-multilevel-argparse.html

    def __init__(self, argin: list):
        """CLI arg parser for ASL Preprocessing"""

        parser = argparse.ArgumentParser(
            prog="AslProc",
            description="ASL preprocessing functions",
            usage="aslproc <id> <command> [<args>]"
        )

        parser.add_argument(
            'id',
            type=str,
            help="Subject ID"
        )

        commands = [
            "all"
            "dcmsort",
            "dcm2niix",
            "to3d",
            "pcasl_3df",
            "fmap",
            "pdmap",
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

    def all(self) -> None:
        """ do all preprocessing steps """
        pass

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
            default=f"t1_{self._condense_id()}"
        )

        args = self._parse_args(parser, argin)
        # pproc = Preprocess(self.id)
        # pproc.dcm2niix(args.input, args.output, args.filename)
        print(args)

    def to3d(self, argin: list) -> None:
        parser = argparse.ArgumentParser(
            description="Perform AFNI to3d function to create .BRIK and .HEAD files",
            usage="to3d [OPTIONS]"
        )

        parser.add_argument(
            "-i",
            "--input",
            type=str,
            default=os.getcwd(),
            help="Input directory (default=%(default)s)"
        )

        parser.add_argument(
            "-o",
            "--output",
            type=str,
            default=os.getcwd(),
            help="Output directory (default=%(default)s)"
        )

        parser.add_argument(
            "-p",
            "--prefix",
            type=str,
            default="zt",
            help="Output file name prefix (default=%(default)s)"
        )

        parser.add_argument(
            "-tr",
            type=int,
            default=1000,
            help="Repetition time (ms) (default=%(default)d)"
        )
        
        args = self._parse_args(parser, argin)
        print(args)

    def pcasl_3df(self, argin: list) -> None:
        parser = argparse.ArgumentParser(
            description="Perform GE 3dfpcasl function to create quantitative CBF maps",
            usage="pcasl_3df [FILE]"
        )
        parser.add_argument(
            "file",
            type=str,
            help="Input file"
        )
        parser.add_argument(
            "-o",
            "--output",
            type=str,
            help="Output directory"
        )
        args = self._parse_args(parser, argin)
        print(args)

    def fmap(self, argin: list) -> None:
        parser = argparse.ArgumentParser(
            description="Perform AFNI 3dcalc function to create an ASL fmap",
            usage="fmap [FILE] [OPTIONS]"
        )
        parser.add_argument(
            "file",
            type=str,
            help="Input file"
        )
        parser.add_argument(
            "-o",
            "--output",
            type=str,
            help="Output directory"
        )
        parser.add_argument(
            "-p",
            "--prefix",
            type=str,
            default="asl_fmap",
            help="Output file name prefix (default=%(default)s)"
        )
        args = self._parse_args(parser, argin)
        print(args)

    def pdmap(self, argin: list) -> None:
        parser = argparse.ArgumentParser(
            description="Perform AFNI 3dcalc function to create a proton density map",
            usage="pdmap [FILE] [OPTIONS]"
        )
        parser.add_argument(
            "file",
            type=str,
            help="Input file"
        )
        parser.add_argument(
            "-o",
            "--output",
            type=str,
            help="Output directory"
        )
        parser.add_argument(
            "-p",
            "--prefix",
            type=str,
            default="pdmap",
            help="Output file name prefix (default = %(default)s)"
        )
        args = self._parse_args(parser, argin)
        print(args)

    def segment(self, argin: list) -> None:
        parser = argparse.ArgumentParser(
            description="Perform T1 segmentation",
            usage="segment [FILE] [OPTIONS]"
        )

        parser.add_argument(
            "file",
            type=str,
            help="T1 .nii file"
        )

        parser.add_argument(
            "-o",
            "--output",
            type=str,
            default=os.getcwd(),
            help="Output directory (default = %(default)s"
        )

        args = self._parse_args(parser, argin)

    def smooth(self, argin: list) -> None:
        pass

    def coreg(self, argin: list) -> None:
        pass

    def normalize(self, argin: list) -> None:
        pass

    def mask_icv(self, argin: list) -> None:
        pass

    def mask_asl(self, argin: list) -> None:
        pass

    def invwarp(self, argin: list) -> None:
        pass

    def invwarpxgm(self, argin: list) -> None:
        pass

    def calc_global(self, argin: list) -> None:
        pass

    def calc_roi(self, argin: list) -> None:
        parser = argparse.ArgumentParser(
            description="Calculate ROI perfusion using fslmaths",
            usage="calc_roi [OPTIONS]"
        )

        parser.add_argument(
            ""
        )

    def calc_volumes(self, argin: list) -> None:
        pass

    def _condense_id(self) -> str:
        return self.id.replace("_", "")

    @staticmethod
    def _parse_args(parser, args: list) -> object:
        return parser.parse_args(args)


if __name__ == '__main__':
    AslProc(sys.argv)
