#!/bin/bash

function usage() {
	echo ""
	echo "$(basename $0) - Convert images"
	echo ""
	echo "Usage: $(basename $0) -i input_file [options] [convert options]"
	echo ""
	echo "options:"
	echo "-h, --help               Show brief help"
	echo "-v, --verbose            Verbose output" # chenge to debug
 	echo "-i, --input              Input file. Mandatory"
 	echo "-o, --output             Output file. Default -"
 	echo "-s, --size               Thumbnail size. Default 200x200>" # http://www.imagemagick.org/script/command-line-processing.php#geometry
 	echo "-d, --density            Density. Default 72"
	echo ""
	echo "convert options: see 'convert --help'"
	echo ""
}

# Set defaults
PROFILE_FILE="profile.icc"
SRGB_PROFILE_FILE="sRGB.icm"
SIZE="200x200>"
DENSITY="72"
OUTPUT_FILE="-"

# Check ImageMagick convert
CONVERT=$(type -P convert)  || { echo "Script requires ImageMagick's convert but it's not installed."; exit 1; }
#BC=$(type -P bc)  || { echo "Script requires the binary calculator 'bc' but it's not installed."; exit 1; }

if [[ $# -eq 0 ]]; then
	usage
	exit 0
fi

# Get options
while test $# -gt 0; do
	case "$1" in
		-h|--help)
			usage
			exit 0
			;;
		-v|--verbose)
		    shift
		    set -x
            ;;
        -i|--input)
            shift
            if test $# -gt 0; then
                INPUT_FILE=$1
            else
            	echo "No input file given."
            	usage
            	exit 1
            fi
			shift
			;;
        -o|--output)
            shift
            if test $# -gt 0; then
                OUTPUT_FILE=$1
            else
            	echo "No output file given."
            	usage
            	exit 1
            fi
			shift
			;;
		-s|--size)
		    shift
            if test $# -gt 0; then
                SIZE=$1
            else
            	echo "No size given."
            	usage
            	exit 1
            fi
			shift
		    ;;
		-d|--density)
		    shift
            if test $# -gt 0; then
                DENSITY=$1
            else
            	echo "No density given."
            	usage
            	exit 1
            fi
			shift
		    ;;
		*)
			break
			;;
	esac
done

REMAINING=$@


# Check that input file is set
if [[ "AAA${INPUT_FILE}AAA" == "AAAAAA" ]]; then
	echo "No input file defined. (mandatory)"
	usage
	exit 1
fi


# Test if profile is given
${CONVERT} ${INPUT_FILE} ${PROFILE_FILE} 2>/dev/null
HAS_PROFILE=$?

# Build convert command, not order of commands is important for convert
COMMAND="${CONVERT}"

if [ ${HAS_PROFILE} -eq 0 ]
then
  echo "Color profile found"

  COMMAND="${COMMAND} -profile ${PROFILE_FILE}"
else
  echo "No color profile found"
fi

COMMAND="${COMMAND} ${INPUT_FILE} -profile ${SRGB_PROFILE_FILE}"
COMMAND="${COMMAND} -thumbnail ${SIZE}"
COMMAND="${COMMAND} -density ${DENSITY}" #http://www.imagemagick.org/script/command-line-options.php#density
COMMAND="${COMMAND} ${REMAINING}"
COMMAND="${COMMAND} ${OUTPUT_FILE}"

# Execute
${COMMAND}
RC=$?

if [ ${RC} -eq 0 ]
then
  echo "Successfully converted image and saved to ${OUTPUT_FILE}"
else
  echo "No color profile found"
  echo "Failed to convert image"
fi

exit ${RC}
