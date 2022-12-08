#!/bin/bash

#O código e os comentários estarão em INGLÊS! 

#Start date: December 8 2022
#Last Update: December 8 2022
#External help: aakova, TomJo2000
#Purpose: Reduce video filesize to <16MB, optionally format video to 9:16 using black bars and cut formatted video into ≃14.9 second segments.

#Dependency check:

if ! command -v ffmpeg &> /dev/null ; then
	echo "'FFmpeg' was not found in the current user install"
	exit
fi

if ! command -v bc &> /dev/null ; then
	echo "'bc' was not found in the current user install"
	exit
fi

#Setting variables

SUPPORTED_EXTENSIONS="^.*\.(mkv|mov|mp4)['\"]?$"
FFMPEGLOGLEVEL="\-loglevel error" #makes ffmpeg hide everything but errors
DEBUG=0 

TEMPDIR=$(mktemp -d -t 16red-XXXXX)
if [ $? -eq 1 ]; then
	echo "'mktemp' command failed to create a temporary directory"
	exit
fi

#Print variables if $DEBUG is on

if [ "${DEBUG}" -eq 1 ]; then
	cat <<END
16red starting
Temporary Directory location: "${TEMPDIR}"
FFMPEGLOGLEVEL: "${FFMPEGLOGLEVEL}"
END
fi

usage() {
	cat <<END
	-d : Enables debug output
	-h : Shows this prompt
	-f : Specify file to be used e.g. ${0} -f 'file.mp4'
	-a : Use all files in \$PWD
	-b : Shows default FFmpeg info for each processed file 
END
	exit
}



# reduce() function:
# Reduces input video to a filesize lower than the limit of 16MB 
# Global variables used: 
# Local variables used: 
# External programs used: ffmpeg
# Requires: sizecheck()

reduce() {
	if [[ "${input_file}" =~ ${SUPPORTED_EXTENSIONS} ]]; then
:	
	else 
		echo "${input_file} is not supported"
	fi
	
}



# sizecheck() function:
# Check processed video filesize
# Global variables used:
# Local variables used: 
# External programs used: du 

sizecheck() {

: #placeholder

}

# format() function:
# Format video into 9:16 aspect-ratio
# Global variables used: 
# Local variables used: 
# External programs used: ffprobe, ffmpeg

format() {

: #placeholder

}


# smallcut() function:
# Cuts input video into smaller ≃14.9 second files (prevents going over with minimal impact)
# Global variables used: smallcut_input, total, outdir
# Local variables used: cut_count, cutloop, cut_count(array)
# External programs used: ffmpeg, bc

smallcut() {
	for ((cutloop=0; cutloop <= total; cutloop++)); do
		echo "Cut ${cutloop}"
		local cut_count=0
		local output_smallcut_filename="${TEMP}/s-${cutloop}-${input_file}"
		ffmpeg -y "${FFMPEGLOGLEVEL}" -stats -ss "${cut_count}" -i "${smallcut_input}" -t 14.900 "${output_smallcut_filename}"
		cut_count=$( bc <<< "${cut_count} + 14.900" )
		cut_files+=("${output_smallcut_filename}")
	done
	mkdir -p "${outdir}"
	mv "${cut_files{@}}" "${outdir}"
}



while getopts "dhf:ab" options; do 
	case ${options} in
		d) DEBUG=1 ;;

		h) usage ;;
		
		b) FFMPEGLOGLEVEL="" ;; 

		a)
			flag_all=1
			for file in *; do
				[[ $file =~ ${SUPPORTED_EXTENSIONS} ]] && filequeue+=("${file}")
				reduce #function 
			done
			;;

		f)
			echo "fileinput..." 
			;;
			
		\?) "${OPTARG}: Invalid option" 1>&2 ;;

		:) "${OPTARG}: Needs an argument" ;;	
	esac
done
[ -z "$*" ] && usage #SC2198
