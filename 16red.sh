#!/bin/bash

#O código e os comentários estarão em INGLÊS!

#Start date: December 8 2022
#Last Update: December 14 2022
#External help: aakova, TomJo2000
#Purpose: Reduce video filesize to <16MB, optionally format video to 9:16 using black bars and cut formatted video into ≃14.9 second segments.

#TODO: FFmpeg 2-pass and interactive mode (prompt for changes)

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
FFMPEGLOGLEVEL="-loglevel error -stats" #makes ffmpeg hide everything but errors
INTERACTIVEMODE=0
DEBUG=0
bitrate_mode=0
info_checked=0
format_checked=0
flag_all=0
ARRAYINDEX=0

TEMPDIR=$(mktemp -d -t 16red-XXXXX)
if [ $? -eq 1 ]; then
	echo "'mktemp' command failed to create a temporary directory"
	exit 1
fi

trap 'rm -r "${TEMPDIR}"; exit 130' SIGINT

usage() {
	cat <<END
-d : Enables debug output
-h : Shows this prompt
-a : Use all files in \$PWD
-b : Toggles only bitrate mode, faster processing, incertain quality/size (targets 8mb)
-l : Toggles FFmpeg log level, to show all info. Disabled by default
not implemented:
-i : Toggles interactive mode, prompting for certain options

Usage example: ${0} (-b) (-d) file.mp4

END
	exit
}


# reduce() function:
# Reduces input video to a filesize lower than the limit of 16MB
# Global variables used: input_file, filequeue (array), info_checked, output_reduce_filename, output_dir, initial_filesize, bitrate_mode, bitrate, FFMPEGLOGLEVEL, TEMPDIR, filesize_reduction_total
# External programs used: ffmpeg
# Requires: infocheck()

reduce() {

	for input_file in "${filequeue[@]}"; do

		[[ "${info_checked}" -eq 0 ]] && infocheck

		# if something wrong happens in infocheck() and doesn't exit with an error, go for the next file
		[[ "$?" -eq 2 ]] && {

		info_checked=0
		input_file="${filequeue[0]}"
		infocheck

		}

		output_reduce_filename="${input_file}"
		output_dir="${PWD}/vid-${input_file}"
		mkdir -p "${output_dir}"

		if [[ "${initial_filesize}" -ge 16000 ]]; then
		

			#shellcheck disable=SC2086 #$FFMPEGLOGLEVEL doesn't work while "quoted"
			if [[ "${bitrate_mode}" -eq 1 ]]; then

				ffmpeg $FFMPEGLOGLEVEL -y -i "${input_file}" -c:v libx264 -profile:v baseline -level 3.0 -pix_fmt yuv420p -b:v "${bitrate}"k "${TEMPDIR}/${output_reduce_filename}"

			else

				[[ "${DEBUG}" -eq 1 ]] && echo -e "\nreduce() : found '${input_file}'\nbitrate='${bitrate}'"

				echo "${input_file} : Pass 1"
				ffmpeg $FFMPEGLOGLEVEL -y -i "${input_file}" -c:v libx264 -pix_fmt yuv420p -b:v "${bitrate}"k -pass 1 -vsync cfr -f null /dev/null &&	\
				echo "${input_file} : Pass 2" && \
				ffmpeg $FFMPEGLOGLEVEL -i "${input_file}" -c:v libx264 -pix_fmt yuv420p -b:v "${bitrate}"k -pass 2 -c:a copy "${TEMPDIR}/${output_reduce_filename}"

			fi

			reduce_checked=1
			infocheck
			echo "${filesize_reduction_total}"
			mv "${TEMPDIR}/${output_reduce_filename}" "${output_dir}"
			filequeue=( "${filequeue[@]:0:$ARRAYINDEX}" "${filequeue[@]:(($ARRAYINDEX+1))}" )
			format

		else

			echo "Target video under 16MB, skipping"; #TODO add $INTERACTIVEMODE
			filequeue=( "${filequeue[@]:0:$ARRAYINDEX}" "${filequeue[@]:(($ARRAYINDEX+1))}" )
			format

		fi

	done

}



# infocheck() function:
# Gathers video data, such as filesize, length and ratio
# Global variables used: info_checked, initial_filesize, input_file, file_aspectratio, length, DEBUG, bitrate_mode, bitrate, reduce_checked, final_filesize, filesize_reduction_total
# Local variables used:
# External programs used: du, ffprobe
# Requires: reduce()


infocheck() {
	if [[ $info_checked -eq 0 ]]; then

		initial_filesize="$(cut -f1 <<< "$(du -k "$input_file")")"

		if [[ "${initial_filesize}" -eq 0 ]]; then

			if [[ "${flag_all}" -eq 1 ]]; then

				echo "Error: $input_file file size is 0, removing from queue"

				#unsets the current file in queue, go for the next
				filequeue=( "${filequeue[@]:0:$ARRAYINDEX}" "${filequeue[@]:(($ARRAYINDEX+1))}" )
				input_file="${filequeue[0]}"

				[[ "${#filequeue[@]}" -eq 0 ]] && { echo "Error: no more files in filequeue, aborting..."; exit 1; }

				initial_filesize="$(cut -f1 <<< "$(du -k "$input_file")")"

			else

				echo "Error: file size is 0, aborting"
				exit 1

			fi

		fi

		file_aspectratio=$(cut -d "=" -f2 <<< "$(ffprobe -loglevel error -show_entries stream=display_aspect_ratio -of default=nw=1 "$input_file")")

		[[ -z "$file_aspectratio" ]] && {	echo "Error: video could not get processed by FFprobe, cannot continue. Aborting...";	exit 1; }
		length=$(printf '%.*f\n' 0 "$(ffprobe -i "$input_file" -loglevel error -show_entries format=duration -of csv="p=0")") # output in seconds

		[[ "${DEBUG}" -eq 1 ]] && cat <<END
DEBUG : infocheck() variables:

initial_filesize : ${initial_filesize}
file_aspectratio : ${file_aspectratio}
length : ${length}
info_checked : ${info_checked}
END

		bitrate=$( printf '%.*f\n' 0 $(( 16000*4/length - 128))) #half the bitrate minus audio bitrate
		info_checked=1

	fi

	# this only runs when reduce() has run at least once, due to $reduce_checked, then resets for future use of the function
	if [[ $reduce_checked -eq 1 ]]; then

		final_filesize=$(cut -f1 <<< "$(du -k "${TEMPDIR}/${output_reduce_filename}")")
		filesize_reduction_total=$(( initial_filesize - final_filesize ))
		if [[ "${final_filesize}" -ge 16000 ]]; then
			echo "Output filesize above 16MB, retrying with a lower bitrate"
			bitrate=$((bitrate-256))
			reduce_checked=0
			reduce
			info_checked=0
		fi
	fi
}

# format() function:
# Format video into 9:16 aspect-ratio
# Global variables used: output_dir, input_file; file_aspectratio, FFMPEGLOGLEVEL, TEMPDIR
# Local variables used:
# External programs used: ffmpeg
# Requires: smallcut()

format() {

	[[ ! -d "${output_dir}" ]] && {
	output_dir="${PWD}/vid-${input_file}"
	mkdir -p "${output_dir}"
	}

	if [[ "${file_aspectratio}" != "9:16" ]]; then

		[[ "${DEBUG}" -eq 1 ]] && echo "format() starting using $input_file"
		
		#shellcheck disable=SC2086
		
		ffmpeg $FFMPEGLOGLEVEL -y -i "${input_file}" -vf 'scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:-1:-1:color=black' "${TEMPDIR}/s-${input_file}"
		mv "${TEMPDIR}/s-${input_file}" "${output_dir}";
		format_checked=1
		smallcut

	else

		[[ "${DEBUG}" -eq 1 ]] && echo -e "format() : ${input_file} has the correct aspect-ratio, skipping...\n"
		smallcut

	fi

}


# smallcut() function:
# Cuts input video into smaller ≃14.9 second files (prevents going over with minimal impact)
# Global variables used: format_checked, smallcut_input, output_dir, input_file, TEMPDIR, FFMPEGLOGLEVEL
# Local variables used: total_cuts, cutloop, cut_files(array), output_smallcut_filename
# External programs used: ffmpeg, bc
# Requires: infocheck()


smallcut() {

	[[ "${format_checked}" -eq 1 ]] && smallcut_input="${output_dir}/s-${input_file}" || smallcut_input="${input_file}"
	# If format() has run successfully, change $smallcut_input to it's output, if not set to input_file, as it's already formatted

	local _total_cuts=$(( length/15 ))
	local _cut_count=0

	for ((_cutloop=0; _cutloop <= _total_cuts; _cutloop++)); do

		echo "Cut $((_cutloop+1))"
		local _output_smallcut_filename="${TEMPDIR}/s-${_cutloop}-${input_file}"
		#shellcheck disable=SC2086
		ffmpeg $FFMPEGLOGLEVEL -ss "${_cut_count}" -i "${smallcut_input}" -t 14.900 "${_output_smallcut_filename}"
		_cut_count=$( bc <<< "${_cut_count} + 14.900" )
		_cut_files+=("${_output_smallcut_filename}")

	done

	mkdir -p "${output_dir}"
	mv "${_cut_files[@]}" "${output_dir}"
}


while getopts ":dhabli" options; do
             # ^ silent mode getopts
	case ${options} in
		d) DEBUG=1 ;;
		h) usage; exit ;;
		a) flag_all=1 ;;
		b) bitrate_mode=1 ;;
		l) FFMPEGLOGLEVEL="" ;;
		i) INTERACTIVEMODE=1 ;;
		\?) echo "-${OPTARG}: Invalid option" 1>&2 ; exit 1 ;;
		:) echo "Error : -${OPTARG} : Needs an argument" 1>&2 ; exit 1 ;;
	esac
done

#Print variables if $DEBUG is on

[[ "${DEBUG}" -eq 1 ]] &&	cat <<END
16red starting
Temporary Directory location: "${TEMPDIR}"
FFMPEGLOGLEVEL: "${FFMPEGLOGLEVEL}"
Arguments passed: "$*"
Number of arguments passed: "$#"
bitrate_mode = $bitrate_mode

END

[[ $# -ge 2 ]] && shift $((OPTIND-1))

[[ "${flag_all}" -eq 0 ]] && {

		for argument_validation in "$@"; do

			if [[ "${argument_validation}" =~ $SUPPORTED_EXTENSIONS && -e "${argument_validation}" ]]; then
				argument="${argument_validation}"
				[[ -d "${argument}" ]] && {
					echo "Passed argument is a directory, aborting..."
					exit 1
				}
				break
				# if nothing matches, this passes "" (nothing), seeking alternatives to this
			fi

		done

		[[ "${DEBUG}" -eq 1 ]] && echo -e "Argument passed: ${argument_validation}\nArgument validated: ${argument}"

		if [[ ! "${argument}" =~ $SUPPORTED_EXTENSIONS || -z "${argument}" ]]; then

			if [[ "${#filequeue[@]}" -eq 0 ]]; then
				echo "No files in filequeue, did you forget to specify a file?"
				exit 1
			fi

			#if no argument matches, it causes the last argument to be passed to $argument, this double checks it
			echo "${argument} : Passed video does not exist, is not supported or it is an option"
			exit 1

		fi

		[[ -f "${argument}" ]] && filequeue+=("${argument}")
		[[ "${DEBUG}" -eq 1 ]] && echo "getopts : '${argument}' added to filequeue, it now has ${#filequeue[@]} item(s)"

		reduce

}

[[ "${flag_all}" -eq 1 ]] && {

	for file in "$@"; do
		[[ "$file" =~ ${SUPPORTED_EXTENSIONS} && ! -d "${file}" ]] &&	{
			echo "File argument detected, but -a was passed, ignoring...";
			break
		}
	done

	for file in *; do

		[[ "$file" =~ ${SUPPORTED_EXTENSIONS} && ! -d "${file}" ]] &&	filequeue+=("${file}")

	done
	
	if [[ "${#filequeue[@]}" -eq 0 ]]; then
		echo "No valid files found"
	fi

	[[ "${DEBUG}" -eq 1 ]] && echo "Files found: " "${filequeue[@]}"
	reduce

}

[ -z "$*" ] && usage #SC2198