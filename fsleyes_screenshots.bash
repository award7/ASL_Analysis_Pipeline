#!/usr/bin/env bash

#fsleyes images
#https://users.fmrib.ox.ac.uk/~paulmc/fsleyes/userdoc/latest/command_line.html

#want a screenshot of:
#Raw NIFTI image
#segmented volumes (GM, WM)
#smoothed GM
#ASL raw
#ASL coregistered img
#aal img
#roi imgs



########
#Ortho view
fsleyes render --scene ortho \
	-hc \
	-bg 0.0 0.0 0.0 \
	-fg 1.0 1.0 1.0 \
	-p 3 \
	--worldLoc 0 0 0 \
	-lo horizontal \
	-of test.png \
	"$filename" \
	-n "$filename" \
	--overlayType volume \
	--alpha 100.0 \
	--brightness 50.0 \
	--contrast 50.0 \
	--cmap brain_colours_nih \
	--negativeCmap greyscale \
	--interpolation spline \
	--numSteps 100 \
	--blendFactor 0.1 \
	--smoothing 0 \
	--resolution 100 \
	--numInnerSteps 10 \
	--volume 0

##########

fsleyes render -s lightbox -hc -cb -cbl 'left' -zx Z -ss 10 \
        -of test.png \
        r0197-C02-Laal.nii -o #-cm brain_colours_nih
~                                                        
#file name of the output screenshot file
#set to something
outfile = "$SubjectID_Scan_View.png"

#3d volume pic
#perhaps save this in fsleyes rather than a .png? <--- what, Aaron? Why did you ask this??
fsleyes render --scene 3d --outfile [outfile.png] file [display0pts]

#standard orthographic view
#outfile is the save name and file type
#file is the input file with options following
fsleyes render --scene ortho --outfile [outfile.png] file [display0pts]

#lightbox view that provides multiple slices at different layers
#outfile is the save name and file type
#file is the input file with options following
#ss is slice spacing with the number being in mm
#zr is the slice range in mm, starting from 0
fsleyes render --scene lightbox --outfile [outfile.png] file [display0pts] -zx Z -ss 10 -zr 0 100 -std1mm #can make specific layout in fsl then load it directly


#ss is slice spacing with the number being in mm
#zr is the slice range in mm, starting from 0
fsleyes render --scene lightbox --outfile [outfile.png] $aslimg -zx Z -ss 10 -zr 0 100 -std1mm 
