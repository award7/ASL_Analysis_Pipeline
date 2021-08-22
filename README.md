# ASL Analysis Pipeline
## v1.0 (No longer supported)
Various scripts (Bash, Matlab, Python) for processing ASL MRI data.

The pipeline exists in a few stages:
1) setting up the proper directory tree, renaming folders, and adding .dcm extenstions to raw MRI image files.
2) analysis of raw MRI data using dcm2niix, AFNI, SPM, and FSL, all of which called upon via Bash.
3) zipping files

# Prerequisites

The following software is required to perform the pipeline in full:
1. A Linux OS/distro of your liking (e.g. Ubuntu, Arch). A VM with the OS/distro will work.
2. Matlab
3. SPM
4. FSL
5. AFNI
6. Python 3.x with Anaconda
7. dcm2niix
8. 3df_pcasl program (proprietary binary from GE)

AFNI and FSL can only run on Linux. At minimum, if using a VM, AFNI and FSL need to be installed; all other portions can be performed on Windows.

It is assumed that the MRI images were sorted into the appropriate subject folder (e.g. with dicomsort).

Is is assumed that best practices regarding file/directory naming is being used (i.e. no spaces).

# Pipeline

The pipeline workflow (corresponding flags in parentheses):

  1. Rename ASL and T1 folders `--rename T`
  2. Add "raw", "proc", "invwarp", "invwarpXgm" subdirectories in each MRI scan directory `--rename T`
  3. Add ".dcm" to raw MRI image files `--rename T`
  4. Move raw image files to "raw" directory of corresponding MRI scan directory `--rename T`
  5. Reconstruct the ASL image via AFNI and 3df_pcasl `-f`
  6. Reconstruct raw T1 image via AFNI
  7. Segment gray matter via SPM `--segment`
  8. Smooth gray matter via SPM `--smooth`
  9. Coregister the ASL image and PD map to gray matter `-c`
  10. Normalize and smooth the coregistered images `-n`
  11. Create a brainmask image with SPM ICV mask `--mask_icv`
  12. Create an ASL mask `--mask_asl`
  13. Calculate the global perfusion value via SPM `--global`
  14. Apply ROI masks from the AAL atlas in subject-space via SPM `-i`
  15. Restrict ROI masks to gray matter via SPM `-ix`
  16. Caclulate brain volumes for gray matter, white matter, and CSF via SPM `-v`
  17. Calculate ROI perfusion via FSL `-fsl`


# Usage

1. Download this repo, unzip into a folder, and add the folder to your PATH.

2. Navigate (via terminal) to the listing of folders that house the MRI data. The directory tree should follow this design:  
    --> unproc (unprocessed folder housing all subjects that need processed)  
        --> Subject Folder  
            --> ASL folder(s) named with "contrast" or "asl"  
                --> Listing of various MRI scans
            --> T1 folder

3. Run `aslproc.bash -h` to view usage help 
  
  
# Limitations

1) This pipeline is built for the use of pcASL and T1 weighted MRI images
2) This pipeline is built for specific use in the Human Physiology Lab at the University of Wisconsin-Madison. Some of the code is rather specific or static to our needs. We are open to pull requests to make the code more dynamic for easier implementation for other workflows.

# Authors

Aaron Ward 
