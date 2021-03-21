# navigate to subject directory
# set "subject" to subject dir path
subject="$1"

# make a condensed subject id
subject_condensed="${subject//_/}"

# rename asl and t1 folders, then make subdirectories in each
# example below; first arg is old file name, second arg is new file name
mv "Contrast_???" "asl###"; mkdir -p $_/{raw,proc,data,images} 2>/dev/null

# move raw image files to raw dir
find "asl###" -name '*' -type f -exec mv -t "asl###/raw" {} + 2>/dev/null

# make mask dir in t1  dir
mkdir -p "${subject}/t1/masks/"{aal,lobes,territories}/{invwarp,invwarpXgm} 2>/dev/null

# rename image files & add .dcm extension
find "$subject" -mindepth 1 ! -name '*.*' -type f -execdir bash -c 'mv -i -- "$1" "${1// /_}.dcm"' Mover {} \;

# run dcm2nii on t1 image
# replace "t1_subjectid" with actual subjectid with NO spaces or separating characters
dcm2niix_afni -f "t1_${subject_condensed" -o "${subject}/t1/proc" "${subject}/t1/raw"

# run fmap make
# where "folder" is the asl folder
folder="asl###"
dcm_count="$(find ${subject}/${folder}/raw -name '*.dcm' | wc -l)"
nt=$(($dcm_count/2))
tr=1000
to3d -prefix "zt_${subject_condensed}_${folder}" -fse -time:zt $nt 2 $tr seq+z "${subject}/${folder}/raw/"*.dcm
3df_pcasl -nex 3 -odata "zt_${subject_condensed}_${folder}"
3dcalc -a "zt_${subject_condensed}_${folder}_fmap+orig.[0]" -datum float -expr 'a' -prefix "asl_fmap_${subject_condensed}_${folder}.nii"
3dcalc -a "zt_${subject_condensed}_${folder}+orig.[1]" -datum float -expr 'a' -prefix "pdmap_${subject_condensed}_${folder}.nii"

#### do spm steps within matlab

#### after spm, run the fsl script