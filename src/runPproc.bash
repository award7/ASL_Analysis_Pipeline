#!/usr/bin/env bash

### Run T1 and ASL preprocessing pipeline in SPM
# Portion of pipeline is written in .m for faster performance vs. individual calls to MATLAB for each step
function runPproc() {
  echo
  echo "##### T1 and ASL preprocessing in SPM..."
  runMatlab "pproc('$arr_subj_matlab','$analysis_array_matlab','$coreg_method')"
}

### wrapper to execute .m functions easier
function runMatlab() {
    matlab -nodesktop -nodisplay -r "try $1; catch exception; display(getReport(exception)); pause(1); end; exit;"
}

# entry point
# 1=arr_subj_matlab 
# 2=analysis_array_matlab
# 3=coreg_method

runPproc "$1" "$2" "$3"