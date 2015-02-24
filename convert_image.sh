#!/bin/bash
#set -x

function usage() {
	echo ""
	echo "$(basename $0) - Convert images"
	echo ""
	echo "Usage: $(basename $0) -i input_file [options] [convert options]"
	echo ""
	echo "options:"
	echo "-h, --help               Show brief help."
	echo "-v, --verbose            Verbose output." # Is more a script debug mode
 	echo "-i, --input              Input file. Mandatory."
 	echo "-o, --output             Output file. Default \"-\"."
 	echo "-p, --page, --layer      Select input page or layer (PDF or PSD). Default \"0\"."
 	echo "-fv, --vector-formats    Formats to be interpreted as vector graphic. comma separated list."
 	echo "                         Default "SVG,EPS". Note: to identify format of image use:"
 	echo "                         \"convert <image> -print "%m\n" null:\""
 	echo "                         Listing recognised formats: \"identify -list format\""
 	echo "-id, --input-density     Input density, used only for vector graphic images."
 	echo "                         Default \"1200\"."
 	echo "                         Note: high values cause high load and  performance issues."
 	echo "-s, --size               Thumbnail size. Default \"200x200>\"."                     # http://www.imagemagick.org/script/command-line-processing.php#geometry
 	echo "-d, --density            Density. Default \"72\"."                                  # http://www.imagemagick.org/script/command-line-options.php#density
 	echo "-q, --quality            JPEG quality. Default \"80\"."
 	echo "-b, --background         Set background of image, might not be shown (depends on alpha)."
 	echo "                         Default \"white\"."
 	echo "-a, --alpha              Modify alpha channel of an image. Default \"remove\"."      # http://www.imagemagick.org/Usage/masking/#alpha, http://www.imagemagick.org/script/command-line-options.php#alpha
 	echo "-lt, --logentries-token  Logentries token. If not given no logging performed."
 	echo "-lu, --logentries-url    Logentries url. Default \"data.logentries.com\"."
 	echo "-lp, --logentries-port   Logentries port. Default \"10000\"."
	echo ""
	echo "convert options: see 'convert --help'"
	echo ""
}

function usage_exit() {
    echo $@
    usage
    exit 1
}

# Set defaults
PROFILE_FILE="profile.icc"
SRGB_PROFILE_FILE="sRGB.icm"
SIZE="200x200>"
PAGE="0"
DENSITY="72"
QUALITY="80"
BACKGROUND="white"
ALPHA="remove"
VECTOR_FORMATS="SVG,EPS"
INPUT_DENSITY="1200"
OUTPUT_FILE="-"
LOGENTRIES_URL="data.logentries.com"
LOGENTRIES_PORT="10000"
LOGENTRIES_TOKEN=""


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
                usage_exit "No input file given."
            fi
			shift
			;;
        -o|--output)
            shift
            if test $# -gt 0; then
                OUTPUT_FILE=$1
            else
                usage_exit "No output file given."
             fi
			shift
			;;
		-s|--size)
		    shift
            if test $# -gt 0; then
                SIZE=$1
            else
                usage_exit "No size given.";
            fi
			shift
		    ;;
		-p|--page|--layer)
		    shift
            if test $# -gt 0; then
                PAGE=$1
            else
                usage_exit "No page given.";
            fi
			shift
		    ;;
		-d|--density)
		    shift
            if test $# -gt 0; then
                DENSITY=$1
            else
            	usage_exit "No density given."
            fi
			shift
		    ;;
		-id|--input-density)
		    shift
            if test $# -gt 0; then
                INPUT_DENSITY=$1
            else
            	usage_exit "No input density given."
            fi
			shift
		    ;;
		-fv|--vector-formats)
		    shift
            if test $# -gt 0; then
                VECTOR_FORMATS=$1
            else
            	usage_exit "No vector graphic formats given."
            fi
			shift
		    ;;
		-q|--quality)
		    shift
            if test $# -gt 0; then
                QUALITY=$1
            else
            	usage_exit "No quality given."
            fi
			shift
		    ;;
		-a|--alpha)
		    shift
            if test $# -gt 0; then
                ALPHA=$1
            else
            	usage_exit "No alpha given."
            fi
			shift
		    ;;
		-b|--background)
		    shift
            if test $# -gt 0; then
                BACKGROUND=$1
            else
            	usage_exit "No background given."
            fi
			shift
		    ;;
		-lt|--logentries-token)
		    shift
            if test $# -gt 0; then
                LOGENTRIES_TOKEN=$1
            else
            	usage_exit "No token given."
            fi
			shift
		    ;;
		-lu|--logentries-url)
		    shift
            if test $# -gt 0; then
                LOGENTRIES_URL=$1
            else
            	usage_exit "No url given."
            fi
			shift
		    ;;
		-lp|--logentries-port)
		    shift
            if test $# -gt 0; then
                LOGENTRIES_PORT=$1
            else
            	usage_exit "No port given."
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

function log() {
    if [[ ! "AAA${LOGENTRIES_TOKEN}AAA" == "AAAAAA" ]]; then
        echo "${LOGENTRIES_TOKEN} $@" | telnet $LOGENTRIES_URL $LOGENTRIES_PORT >/dev/null 2>&1
    fi
}

# Test if profile is given
${CONVERT} "${INPUT_FILE}[${PAGE}]" "${PROFILE_FILE}" 2>/dev/null
HAS_PROFILE=$?

# Test if is vector graphic
FORMAT=`${CONVERT} "${INPUT_FILE}[${PAGE}]" -print "%m\n" null: 2>/dev/null`
IS_VECTOR=`echo "${VECTOR_FORMATS}" | grep -c -i -e "\(^\|,\)${FORMAT}\(,\|$\)"`

# Build convert command, NOTE: order of commands is very important for convert
COMMAND="${CONVERT}"

if [ ! ${IS_VECTOR} -eq 0 ]; then
    echo "Vector graphic image."
    COMMAND="${COMMAND} -density ${INPUT_DENSITY}"
fi

if [ ${HAS_PROFILE} -eq 0 ]
then
  echo "Color profile found"

  COMMAND="${COMMAND} -profile ${PROFILE_FILE}"
else
  echo "No color profile found"
fi

COMMAND="${COMMAND} ${INPUT_FILE}[${PAGE}] -profile ${SRGB_PROFILE_FILE}"
COMMAND="${COMMAND} -background ${BACKGROUND} -alpha ${ALPHA}"
COMMAND="${COMMAND} -thumbnail ${SIZE}"
COMMAND="${COMMAND} -density ${DENSITY}"
COMMAND="${COMMAND} -quality ${QUALITY}"
COMMAND="${COMMAND} ${REMAINING}"
COMMAND="${COMMAND} ${OUTPUT_FILE}"

# Execute
${COMMAND} 2>&1 | tee output.txt
CONVERSION_CODE=${PIPESTATUS[0]}

if [ ${CONVERSION_CODE} -eq 0 ]
then
  echo "Successfully converted image and saved to ${OUTPUT_FILE}"
  log "INFO: Successfully converted ${INPUT_FILE}"
else
  echo "Failed to convert image"
  log "ERROR: Failed to convert $input_file (${CONVERSION_CODE}):" ${COMMAND} `cat output.txt`
fi

exit ${CONVERSION_CODE}