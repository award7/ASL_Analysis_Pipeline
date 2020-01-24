#!/bin/bash

myvm="C:/Users/atward/Documents/Virtual Machines/Ubuntu/Ubuntu.vmx"
usr="SchrageLab"
pass="Welcome1"

vmrun -T player start "$myvm"
vmrun -T player -gu usr -gp pass runScriptInGuest "$myvm" -interactive "" "/bin/bash script1.bash"
