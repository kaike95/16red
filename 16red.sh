#!/bin/bash

#O código e os comentários estarão em INGLÊS!

#Start date: December 8 2022
#Last Update: December 31 2023
#External help: aakova, TomJo2000
#Purpose: Reduce video filesize to <16MB, optionally format video to 9:16 using black bars and cut formatted video into ≃14.9 second segments.

#Dependency check:

error() {
	>&2 echo -e "\033[0;31mError: ${1:-on line $LINENO - not specified}\033[0m"
	exit "${2}"
}

command -v ffmpeg &> /dev/null || error "'FFmpeg' was not found in the current user install" 1

#Setting variables

FFMPEGLOGLEVEL="-v 16 -stats" #makes ffmpeg/ffprobe hide everything but errors
INTERACTIVEMODE=0
DEBUG=0
reduce_only=0
bitrate_mode=0
info_checked=0
format_checked=0
flag_all=0
ARRAYINDEX=0
TEMPDIR=$(mktemp -d -t 16red-XXXXX) || error "'mktemp' command failed to create a temporary directory" 1

quit() { # this does not work as intended, ffmpeg gets killed first by SIGINT and then this function runs
	(( quit_counter )) && {
		rm -r "${TEMPDIR}"
		exit 130
	} || echo -e "\n\033[0;33mPress one more time to end process. This will delete processing files.\033[0m"
	((quit_counter++))
}

debug() {
	(( DEBUG )) && echo -e "\033[0;33m$*\033[0m"
	return 0
}

usage() {
	cat <<END
-d : Enables debug output
-h : Shows this prompt
-a : Use all files in \$PWD
-b : Toggles only bitrate mode, faster processing, incertain quality/size (targets 8mb)
-l : Toggles FFmpeg log level to normal. Disabled by default
-m : Enables -movflag faststart, might take longer to start but helps with playback issues
-f : Only reduces the video size, doesn't format into 9:16
Usage example: ${0} (-b) (-d) file.mp4

END
	exit
}


# reduce() function:
# Reduces input video to a filesize lower than the limit of 16MB
# Global variables used: input_file, filequeue (array), info_checked, output_reduce_filename, output_dir, initial_filesize, bitrate_mode, FFMPEGLOGLEVEL, movflag, bitrate, TEMPDIR, reduce_only
# External programs used: ffmpeg
# Requires: infocheck()

reduce() {

	for input_file in "${filequeue[@]}"; do

		(( info_checked )) || infocheck

		# if something wrong happens in infocheck() and doesn't exit with an error, go for the next file
		(( "$?" == 2 )) && {

		info_checked=0
		input_file="${filequeue[0]}"
		infocheck

		}

		output_reduce_filename="${input_file}"
		output_dir="${PWD}/vid-${input_file}"
		mkdir -p "${output_dir}" || error "Could not create a directory in $PWD" 1

		if (( initial_filesize >= 16000 )); then
		

			#shellcheck disable=SC2086 #$FFMPEGLOGLEVEL doesn't work while "quoted"
			if (( bitrate_mode )); then

				ffmpeg $FFMPEGLOGLEVEL -y -i "${input_file}" -c:v libx264 -profile:v baseline -level 3.0 -pix_fmt yuv420p -b:v "${bitrate}"k $movflag "${TEMPDIR}/${output_reduce_filename}"

			else

				debug "\nreduce() : found '${input_file}'\nbitrate='${bitrate}'"

				debug "${input_file} : Pass 1"
				ffmpeg $FFMPEGLOGLEVEL -y -i "${input_file}" -c:v libx264 -pix_fmt yuv420p -b:v "${bitrate}"k -pass 1 -vsync cfr -f null /dev/null &&	\
				debug "${input_file} : Pass 2" && \
				ffmpeg $FFMPEGLOGLEVEL -i "${input_file}" -c:v libx264 -pix_fmt yuv420p -b:v "${bitrate}"k -pass 2 -c:a copy $movflag "${TEMPDIR}/${output_reduce_filename}"

			fi

			reduce_checked=1
			infocheck
			mv "${TEMPDIR}/${output_reduce_filename}" "${output_dir}" 2> /dev/null  || error "mv returned non-0 exit code" 1
			echo "Finished reducing '${input_file}'"

		else

			echo "Target video under 16MB, skipping"; #TODO add $INTERACTIVEMODE

		fi

			filequeue=( "${filequeue[@]:0:$ARRAYINDEX}" "${filequeue[@]:(($ARRAYINDEX+1))}" )
			(( reduce_only )) || format

	done
}


# infocheck() function:
# Gathers video data, such as filesize, length and ratio
# Global variables used: info_checked, initial_filesize, dusize, input_file, file_aspectratio, length, lengthseconds, DEBUG, bitrate_mode, bitrate, reduce_checked, final_filesize
# External programs used: du, ffprobe
# Requires: reduce()
# Required by: reduce(), format(), smallcut()


infocheck() {
	if (( ! info_checked )); then

		dusize="$(du -k "${input_file}" 2> /dev/null)" || error "'du' returned a non-0 exit code" 1
		initial_filesize="$(cut -f1 <<< "$dusize")"

		if (( ! initial_filesize )); then

			if (( flag_all )); then

				debug "$input_file file size is 0, removing from queue"

				# unsets the current file in queue, go for the next
				filequeue=( "${filequeue[@]:0:$ARRAYINDEX}" "${filequeue[@]:(($ARRAYINDEX+1))}" )
				(( "${#filequeue[@]}" )) || error "no more files in filequeue, aborting..." 1

				input_file="${filequeue[0]}"

				dusize="$(du -k "${input_file}" 2> /dev/null)" || error "'du' returned a non-0 exit code" 1
				initial_filesize="$(cut -f1 <<< "$dusize")"

			else

				error "file size is 0, aborting" 1

			fi

		fi

		file_aspectratio=$(ffprobe "${input_file}" -show_entries stream=display_aspect_ratio -of csv=p=0:nk=1 -v 0 2> /dev/null ) \
			|| error "ffprobe returned a non-0 exit code" 1
		#https://ffmpeg.org/ffprobe.html#compact_002c-csv

		[[ -z "$file_aspectratio" ]] && error "video could not get processed by FFprobe, cannot continue. Aborting..." 1

		lengthseconds="$(ffprobe -i "${input_file}" -v 16 -show_entries format=duration -of csv="p=0")" \
			|| error "ffprobe returned a non-0 exit code" 1
		length=$(printf '%.*f\n' 0 "$lengthseconds")
		(( DEBUG )) && cat <<END

DEBUG : infocheck() variables:

initial_filesize : ${initial_filesize}
file_aspectratio : ${file_aspectratio}
length : ${length}
info_checked : ${info_checked}
END

		bitrate=$(printf '%.*f\n' 0 $((16000*4/length - 128))) #half the bitrate minus audio bitrate
		info_checked=1

	fi

	# this only runs when reduce() has run at least once, due to $reduce_checked, then resets for future use of the function
	if (( reduce_checked )); then
		
		dusize="$(du -k "${TEMPDIR}/${output_reduce_filename}" 2> /dev/null)"
		final_filesize=$(cut -f1 <<< "$dusize")
		if (( final_filesize >= 16000 )); then
			echo "Output filesize above 16MB, retrying with a lower bitrate"
			((bitrate-256))
			reduce_checked=0
			reduce
			info_checked=0
		fi
	fi
}

# format() function:
# Format video into 9:16 aspect-ratio
# Global variables used: output_dir, input_file, file_aspectratio, FFMPEGLOGLEVEL, movflag, bitrate, TEMPDIR
# External programs used: ffmpeg
# Requires: smallcut(), infocheck()

format() {

	[[ ! -d "${output_dir}" ]] && {
	output_dir="${PWD}/vid-${input_file}"
	mkdir -p "${output_dir}"
	}

	if [[ "${file_aspectratio}" != "9:16" ]]; then

		debug "format() starting using $input_file"

		#shellcheck disable=SC2086
		ffmpeg $FFMPEGLOGLEVEL -y -i "${input_file}" -vf 'scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:-1:-1:color=black' $movflag -b:v "${bitrate}"k "${TEMPDIR}/s-${input_file}"
		mv "${TEMPDIR}/s-${input_file}" "${output_dir}" 2> /dev/null || error "mv returned a non-0 exit code" 1;
		format_checked=1
		echo "Finished formatting '${input_file}' to 9:16"
		smallcut

	else

		debug "format() : ${input_file} has the correct aspect-ratio of 9:16, skipping..."
		smallcut

	fi

}


# smallcut() function:
# Cuts input video into smaller ≃14.9 second files (prevents going over with minimal impact)
# Global variables used: format_checked, smallcut_input, output_dir, input_file, length, TEMPDIR, FFMPEGLOGLEVEL
# Local variables used: total_cuts, cut_count, cut_count_final, cutloop, cut_files(array), output_smallcut_filename, copyflag, movflag, bitrate
# External programs used: ffmpeg
# Requires: infocheck()
# Required by: format()

smallcut() {

	(( format_checked )) && smallcut_input="${output_dir}/s-${input_file}" || smallcut_input="${input_file}"
	# If format() has run successfully, change $smallcut_input to it's output, if not set to input_file, as it's already formatted

	local _total_cuts=$(( length/15 ))

	(( _total_cuts < 1 )) && {
		echo "Passed video is smaller than 15 seconds, skipping cuts..."
		return 0
	}

	local _cut_count=0
	local _cut_count_final=0
	local _copyflag="-c copy"

	for ((_cutloop=0; _cutloop <= _total_cuts; _cutloop++)); do

		echo "Cut $((_cutloop+1))"
		local _output_smallcut_filename="${TEMPDIR}/s-${_cutloop}-${input_file}"
		#shellcheck disable=SC2086
		ffmpeg $FFMPEGLOGLEVEL -ss "${_cut_count_final}" -i "${smallcut_input}" -t 14.900 $_copyflag $movflag -b:v "${bitrate}"k "${_output_smallcut_filename}"

		# -c copy is fine for the first, but for the remaining this can cause playback problems
		_copyflag=""

		# replaces bc with scientific notation using printf # shell-tips.com/bash/math-arithmetic-calculation
		_cut_count=$((149+_cut_count))
		_cut_count_final=$(printf %.1f "$((_cut_count))e-1")

		_cut_files+=("${_output_smallcut_filename}")

	done

	mkdir -p "${output_dir}"
	mv "${_cut_files[@]}" "${output_dir}" || error "mv returned non-0 exit code" 1
}

(( $# )) || usage # no args

while getopts ":dhablmfi" options; do
             # ^ silent mode getopts
	case ${options} in
		d) DEBUG=1 ;;
		h) usage ;;
		a) flag_all=1 ;;
		b) bitrate_mode=1 ;;
		l) FFMPEGLOGLEVEL="" ;;
		m) movflag="-movflags faststart" ;;
		f) reduce_only=1 ;;
		i) INTERACTIVEMODE=1 ;;
		\?) error "-${OPTARG}: Invalid option" 1 ;;
		:) error "-${OPTARG} : Needs an argument" 1 ;;
	esac
done

#Print variables if $DEBUG is on

(( DEBUG )) && cat <<END
16red starting...

Temporary Directory location: "${TEMPDIR}"
FFMPEGLOGLEVEL: "${FFMPEGLOGLEVEL}"
Arguments passed: "$*"
Number of arguments passed: "$#"
bitrate_mode = $bitrate_mode

END

(( $# > 2 )) && shift "$((OPTIND-1))"

if (( flag_all )); then

	for file in *; do

		[[ "$(file -b --mime-type "${file}")" =~ "video" && ! -d "${file}" ]] && filequeue+=("${file}")
		debug "getopts : '${valid_argument}' added to filequeue, it now has ${#filequeue[@]} item(s)"

	done

	(( "${#filequeue[@]}" )) || error "No valid files found" 1

	debug "Files found: " "${filequeue[@]}"

else

	for argument_validation in "$@"; do

		if [[ "$(file -b --mime-type "${argument_validation}")" =~ "video" && -e "${argument_validation}" ]]; then
			valid_argument="${argument_validation}"
			[[ -d "${argument_validation}" ]] && error "${argument_validation} is a directory, aborting..." 1
			break
			# if nothing matches, this passes "" (nothing), seeking alternatives to this
		fi

	done

	debug "Argument passed: ${argument_validation}\nArgument validated: ${valid_argument}"

	if [[ ! "$(file -b --mime-type "${valid_argument}")" =~ "video" || -z "${valid_argument}" ]]; then

		(( "${#filequeue[@]}" )) ||	error "No files in filequeue, did you forget to specify a file?" 1

		#if no argument matches, it causes the last argument to be passed to $argument, this double checks it
		error "${valid_argument} : Passed video does not exist, is not supported or it is an option" 1

	fi

	[[ -f "${valid_argument}" ]] && filequeue+=("${valid_argument}")
	debug "getopts : '${valid_argument}' added to filequeue, it now has ${#filequeue[@]} item(s)"

fi

reduce
