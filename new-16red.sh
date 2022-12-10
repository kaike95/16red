#!/bin/bash

#O código e os comentários estarão em INGLÊS! 

#Start date: December 8 2022
#Last Update: December 9 2022
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
bitrate_mode=0

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
	-b : Toggles bitrate mode, faster processing, incertain quality/size

not implemented:
	-i : Toggles interactive mode, prompting for certain options 
END
	exit
}


# reduce() function:
# Reduces input video to a filesize lower than the limit of 16MB 
# Global variables used: input_file, filequeue (array), info_checked, output_reduce_filename, bitrate, bitrate_mode, filesize_reduction_total, output_dir
# External programs used: ffmpeg
# Requires: infocheck()

reduce() {
	for input_file in "${filequeue[@]}"; do
		infocheck
		output_reduce_filename="${input_file}"
		output_dir="${PWD}/vid-${input_file}"
		echo "info_checked = $info_checked"
		
		if [[ bitrate_mode -eq 1 ]]; then
			ffmpeg -y -i "${input_file}" -c:v libx264 -profile:v baseline -level 3.0 -pix_fmt yuv420p -b "${bitrate}"k "${TEMPDIR}/${output_reduce_filename}"
			mv "${TEMPDIR}/${output_reduce_filename}" "${output_dir}"
			reduce_checked=1
			infocheck
			echo "${filesize_reduction_total}"
		fi

		echo "reduce() : found '${input_file}', now do ffmpeg 2-pass" #TODO ffmpeg 2pass implementation 
	done
}



# infocheck() function:
# Gathers video data, such as filesize, length and ratio
# Global variables used:
# Local variables used: 
# External programs used: du, ffprobe
# Requires: reduce()


infocheck() {

	if [[ $info_checked -eq 0 ]]; then
		initial_filesize=$(cut -f1 <<< "$(du -k "$input_file")")
		file_aspectratio=$(cut --bytes=22-25 <<< "$(ffprobe -loglevel error -show_entries stream=display_aspect_ratio -of default=nw=1 "$input_file")")
		#the cut command here is very sensitive to changes to ffprobe's output
		
		length=$(printf '%.*f\n' 0 "$(ffprobe -i "$input_file" -loglevel error -show_entries format=duration -of csv="p=0")") # output in seconds
		
		[ "${bitrate_mode}" -eq 1 ] && bitrate=$( printf '%.*f\n' 0 $(( 16000*4/length ))) #half the bitrate
		
		info_checked=1
	fi

	# this only runs when reduce() has run at least once, due to $reduce_checked, then resets for future use of the function
	if [[ $reduce_checked -eq 1 ]]; then
		final_filesize=$(cut -f1 <<< "$(du -k "${output_reduce_filename}")")
		filesize_reduction_total=$(( initial_filesize - final_filesize ))
		reduce_checked=0 
		reduce
		info_checked=0
	fi
}

# format() function:
# Format video into 9:16 aspect-ratio
# Global variables used: file_aspectratio, FFMPEGLOGLEVEL, input_file, TEMPDIR, output_dir
# Local variables used: 
# External programs used: ffprobe, ffmpeg

format() {

	if [[ "${file_aspectratio}" != "9:16" ]]; then
		ffmpeg "${FFMPEGLOGLEVEL}" -stats -i "${input_file}" -vf 'scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:-1:-1:color=black' "${TEMPDIR}/s-${input_file}"
		mv "${TEMPDIR}/s-${input_file}" "${output_dir}";
	else
		[[ "${DEBUG}" -eq 1 ]] && echo -e "format() : ${input_file} has the correct aspect-ratio, skipping...\n"
		return
	fi

}


# smallcut() function:
# Cuts input video into smaller ≃14.9 second files (prevents going over with minimal impact)
# Global variables used: smallcut_input, output_dir
# Local variables used: total_cuts, cutloop, cut_count(array), output_smallcut_filename
# External programs used: ffmpeg, bc
# Requires: infocheck()

# !!! smallcut_input != input_file

smallcut() {
	
	local total_cuts=$(( length/15 ))
	
	for ((cutloop=0; cutloop <= total_cuts; cutloop++)); do
		echo "Cut ${cutloop}"
		local cut_count=0
		local output_smallcut_filename="${TEMP}/s-${cutloop}-${input_file}"
		ffmpeg -y "${FFMPEGLOGLEVEL}" -stats -ss "${cut_count}" -i "${smallcut_input}" -t 14.900 "${output_smallcut_filename}"
		cut_count=$( bc <<< "${cut_count} + 14.900" )
		cut_files+=("${output_smallcut_filename}")
	done

	mkdir -p "${output_dir}"
	mv "${cut_files{@}}" "${output_dir}"
}



while getopts "dhf:abi" options; do 
	case ${options} in
		d) DEBUG=1 ;;

		h) usage ;;
	
		f)
			for argument in "$@"; do

				if [[ "${argument}" =~ ${SUPPORTED_EXTENSIONS} ]]; then
				
					if [[ ! "${argument}" =~ ${SUPPORTED_EXTENSIONS} || -z "${argument}" ]]; then 
						#if no argument matches, it causes the last argument to be passed to $input_file, this double checks it
						echo "${argument} : Passed video is not supported or it is an option"
						exit 1
					fi
					
					filequeue+=("${argument}")
					echo "getopts : '${argument}' added to filequeue, it now has ${#filequeue[@]} item(s)"
					reduce

				else 
					continue
					
				fi
			
			done	
			;;

		a)
			flag_all=1
			for file in *; do
				[[ "$file" =~ ${SUPPORTED_EXTENSIONS} ]] &&	filequeue+=("${file}")
			done
			reduce
			;;

		b) bitrate_mode=1 ;;

		i) FFMPEGLOGLEVEL="" ;; 

		\?) "${OPTARG}: Invalid option" 1>&2 ;;

		:) "${OPTARG}: Needs an argument" ;;

	esac
done

[ -z "$*" ] && usage #SC2198
