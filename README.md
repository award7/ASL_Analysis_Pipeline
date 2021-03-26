# ASL_Analysis_Pipeline
Various scripts (Bash, Matlab, Python) for processing ASL MRI data using AFNI and SPM.

The pipeline exists in a few stages:
1) setting up the proper directory tree, renaming folders, and adding .dcm extenstions to raw MRI image files
2) analysis of raw MRI data using dcm2niix, AFNI, SPM, and FSL, all of which called upon via Bash
3) analyzing the calculated perfusion values via Python to prep for statistical analysis
4) zipping files

# Prerequisites

The following software is required to perform the pipeline in full:
1) A Linux OS/distro of your liking (e.g. Ubuntu, Arch). A VM with the OS/distro will work.
2) Matlab
3) SPM
4) FSL
5) AFNI
6) Python 3.x with Anaconda
7) dcm2niix
8) GE 3df_pcasl script

AFNI and FSL can only run on Linux. At minimum, if using a VM, AFNI and FSL need to be installed; all other portions can be performed on Windows.

It is assumed that the MRI images were sorted via Dicom sort into the appropriate subject folder.

Is is assumed that best practices regarding file/directory naming is being used (i.e. no spaces).

# Deployment

1) Clone this repo and add the folder to your PATH

2) Navigate (via terminal) to the listing of folders that house the MRI data. The directory tree should follow this design:
  --> unproc %unprocessed folder housing all subjects that need processed
    --> Subject Folder
      --> "ASL_Data"
        --> Listing of various MRI scans
        
3) Run []
  This will do the following by running the following scripts:
  a) rename ASL and T1 folders [].bash 
  b) add "raw" and "proc" subdirectories in each MRI scan directory [].bash 
  c) add ".dcm" to raw MRI image files [].bash
  d) move raw image files to "raw" directory of corresponding MRI scan directory

4a) If all necessary software is on the Linux environment and enough processing power is devoted to it, then run the following:
Run aslproc_linux.bash to run the entrie pipeline
  This will only work if all necessary software is on the Linux OS. So if you have a VM with only select software (e.g. AFNI), it will  not function properly.
  This will do the following by running the following scripts:
  Use AFNI and GE 3df_pcasl to reconstruct the ASL image- brik.bash
  Use dcm2niix to reconstruct the raw T1 image- [].bash
  Use SPM to segment gray matter- segment.bash
  Use SPM to smooth gray matter- smooth.bash
  Use SPM to coregister the ASL image to gray matter- coreg.bash
  Use SPM to normalize and smooth the coregistered image- normalize.bash
  Use SPM to create a brainmask image- bmask.bash
  Use SPM to calculate the global perfusion value- asl_global.bash
  *Include portions about aal atlas and fsl
  
4b) If only select software is on the Linux environemnt, then do the following in Linux:
Run brik.bash
    
  
# Limitations

1) This pipeline is built for the use of pcASL and T1 weighted MRI images
2) This pipeline is built for specific use in the Human Physiology Lab at the University of Wisconsin-Madison. Some of the code is rather specific or static to our needs. We are open to pull requests to make the code more dynamic for easier implementation for other workflows.

# Authors

Aaron Ward 
