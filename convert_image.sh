#!/bin/bash
#set -x

# Set defaults
function set_defaults() {
    TARGET_PROFILE_FILE="./profiles/sRGB.icm"
    SIZE="200x200>"
    PAGE="0"
    DENSITY="72"
    QUALITY="80"
    BACKGROUND="white"
    ALPHA="remove"
    POSTSCRIPT_FORMATS="EPDF,EPI,EPS,EPSF,EPSI,PDF,PDFA,PS"
    VECTOR_FORMATS="MSVG,SVG,SVGZ,AI,PCT,PICT"
    LOGENTRIES_URL="data.logentries.com"
    LOGENTRIES_PORT="10000"
    LOGENTRIES_TOKEN=""
}

PROFILE_FILE="profile.icc"
OUTPUT_TEXT="output.txt"
CLEANUP_FILES="${PROFILE_FILE} ${OUTPUT_TEXT}"

set_defaults

function usage() {
    # Reset variables to default
    set_defaults

	echo ""
	echo "$(basename $0) - Convert image"
	echo ""
	echo "Usage: $(basename $0) -i input_file -o output_file [options] [convert options]"
	echo ""
	echo "Options:"
	echo "-h, --help               Show brief help."
	echo "-v, --verbose            Verbose output." # Is more a script debug mode
 	echo "-i, --input              Input file or URI. Mandatory."
 	echo "-o, --output             Output file. Mandatory. Set \"-\" to send directly to standard output."
 	echo "-t, --target-profile     Color profile file to apply. Default \"${TARGET_PROFILE_FILE}\"."
 	echo "-p, --page, --layer      Select input page or layer (PDF or PSD). Default \"${PAGE}\"."
 	echo "-fp, --ps-formats        Formats to be interpreted as postscript graphic. comma separated list."
 	echo "                         Those will be checked (with ps2pdf) if are pure vector graphic."
 	echo "                         Default \"${POSTSCRIPT_FORMATS}\"."
 	echo "-fv, --vector-formats    Formats to be interpreted as vector graphic. comma separated list."
 	echo "                         Default \"${VECTOR_FORMATS}\"."
 	echo "-s, --size               Thumbnail size. Default \"${SIZE}\"."                         # http://www.imagemagick.org/script/command-line-processing.php#geometry
 	echo "-d, --density            Density. Default \"${DENSITY}\"."                             # http://www.imagemagick.org/script/command-line-options.php#density
 	echo "-q, --quality            JPEG quality. Default \"${QUALITY}\"."
 	echo "-b, --background         Set background of image, might not be shown (depends on alpha)."
 	echo "                         Default \"${BACKGROUND}\"."
 	echo "-a, --alpha              Modify alpha channel of an image. Default \"${ALPHA}\"."      # http://www.imagemagick.org/Usage/masking/#alpha, http://www.imagemagick.org/script/command-line-options.php#alpha
 	echo "-lt, --logentries-token  Logentries token. If not given no logging performed."
 	echo "-lu, --logentries-url    Logentries url. Default \"${LOGENTRIES_URL}\"."
 	echo "-lp, --logentries-port   Logentries port. Default \"${LOGENTRIES_PORT}\"."
	echo ""
	echo "convert options: see 'convert --help'"
	echo ""
}

function usage_exit() {
    echo $@
    usage
    exit 1
}


# Check ImageMagick convert
CONVERT=$(type -P convert)  || { echo "Script requires ImageMagick's convert but it's not installed."; exit 1; }
PS2PDF=$(type -P ps2pdf)  || { echo "Script requires GhostScript ps2pdf but it's not installed."; exit 1; }
WGET=$(type -P wget)  || { echo "Script requires GNU wget, but it's not installed."; exit 1; }

if [[ $# -eq 0 ]]; then
	usage_exit "Mandatory params not set"
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
		-t|--target-profile)
            shift
            if test $# -gt 0; then
                TARGET_PROFILE_FILE=$1
            else
                usage_exit "No profile file given."
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
		-fp|--ps-formats)
		    shift
            if test $# -gt 0; then
                POSTSCRIPT_FORMATS=$1
            else
            	usage_exit "No postscript graphic formats given."
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
	usage_exit "No input file defined. (mandatory)"
fi

# Check if URL input, convert supports it natively but would download every time is called. Download here.
URL_REGEX='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
if [[ ${INPUT_FILE} =~ ${URL_REGEX} ]]; then
    URL=${INPUT_FILE}
    INPUT_FILE=$(basename $(echo ${URL} | cut -d@ -f2 | cut -d/ -f2- | cut -d? -f1))
    ${WGET} -q -O ${INPUT_FILE} ${URL}
fi

# Sanitize input file (remove special chars, convert spaces to underscore")
INVALID_REGEX='[ :?"\\]'
if [[ ${INPUT_FILE} =~ ${INVALID_REGEX} ]]; then
    SANITIZED_INPUT=${INPUT_FILE//[:?\']}
    SANITIZED_INPUT=${SANITIZED_INPUT// /_}

    # @todo: Should check that does not already exists

    # Create symbolic link so that there is no need to copy or move data
    ln -f -s "${INPUT_FILE}" $SANITIZED_INPUT

    INPUT_FILE=$SANITIZED_INPUT
    CLEANUP_FILES+=" $SANITIZED_INPUT"
fi

# Check that output file is set
if [[ "AAA${OUTPUT_FILE}AAA" == "AAAAAA" ]]; then
	usage_exit "No output file defined. (mandatory)"
fi

function log() {
    if [[ ! "AAA${LOGENTRIES_TOKEN}AAA" == "AAAAAA" ]]; then
        echo "${LOGENTRIES_TOKEN} $@" | telnet $LOGENTRIES_URL $LOGENTRIES_PORT >/dev/null 2>&1
    fi
}

### END CONFIGURATION, BEGIN WORK ###

# Check that input file is present
if [[ ! -r ${INPUT_FILE} ]]; then
    echo "Input file \"${INPUT_FILE}\" not readable."
    log "ERROR: Input file \"${INPUT_FILE}\" not readable."
fi

# Test if profile is given
${CONVERT} ${INPUT_FILE}[${PAGE}] "${PROFILE_FILE}" 2>/dev/null
HAS_PROFILE=$?

# Test if is postscript or vector graphic
INFO=`${CONVERT} ${INPUT_FILE}[${PAGE}] -print "%m %w %h %[resolution.x] %[resolution.y]\n" null: 2>/dev/null`
FORMAT=`echo ${INFO} | cut -d' ' -f1`
IS_POSTSCRIPT=`echo "${POSTSCRIPT_FORMATS}" | grep -c -i -e "\(^\|,\)${FORMAT}\(,\|$\)"`
IS_VECTOR=`echo "${VECTOR_FORMATS}" | grep -c -i -e "\(^\|,\)${FORMAT}\(,\|$\)"`

if [ ! ${IS_POSTSCRIPT} -eq 0 ]; then
    echo "Postscript image"

    # Following line could be used for debug mode
    # ${PS2PDF} ${INPUT_FILE} - 2>/dev/null | grep -a --color -i -e "/image\( \|$\)"

    # Test if pure vector postscript image
    if [ `${PS2PDF} ${INPUT_FILE} - 2>/dev/null | grep -c -i -e "/image\( \|$\)"` -eq 0 ]; then
        IS_VECTOR=1
    fi
fi

# Build convert command, NOTE: order of commands is very important for ImageMagick convert
COMMAND="${CONVERT}"

if [ ! ${IS_VECTOR} -eq 0 ]; then
    function max() {
         if [ $1 -gt $2 ]; then echo $1; else echo $2; fi
    }

    DEST_SIZE_X=`expr match "${SIZE}" '\([0-9]\+\).*$'`           # OR ${SIZE%x*}
    DEST_SIZE_Y=`expr match "${SIZE}" '[0-9]\+x\?\([0-9]\+\).*$'` # @todo: refactor eg "72" returns "2" .. ok for now, because we need the max only
    DEST_MAX=$(max ${DEST_SIZE_X} ${DEST_SIZE_Y})

    SRC_SIZE_X=`echo ${INFO} | cut -d' ' -f2`
    SRC_SIZE_Y=`echo ${INFO} | cut -d' ' -f3`
    SRC_MAX=$(max ${DEST_SIZE_X} ${DEST_SIZE_Y})

    DENSITY_X=`expr match "${DENSITY}" '\([0-9]\+\).*$'`
    DENSITY_Y=`expr match "${DENSITY}" '[0-9]\+x\?\([0-9]\+\).*$'` # @todo: same as before
    DENSITY_MAX=$(max ${DENSITY_X} ${DENSITY_Y})

    PRECISION_MULTIPLIER=1000
    INPUT_DENSITY=`expr \( \( ${DEST_MAX} \* ${PRECISION_MULTIPLIER} \) / \( \( ${SRC_MAX} \* ${PRECISION_MULTIPLIER} \) / ${DENSITY_MAX} \) \) + 5`

    echo "Vector graphic image, input density ${INPUT_DENSITY}"

    COMMAND+=" -density ${INPUT_DENSITY}"
fi

if [ ${HAS_PROFILE} -eq 0 ]
then
  echo "Color profile found"

  COMMAND+=" -profile ${PROFILE_FILE}"
else
  echo "No color profile found"
fi

COMMAND+=" ${INPUT_FILE}[${PAGE}]"
COMMAND+=" -profile ${TARGET_PROFILE_FILE}"
COMMAND+=" -background ${BACKGROUND} -alpha ${ALPHA}"
COMMAND+=" -thumbnail ${SIZE}"
COMMAND+=" -density ${DENSITY}"
COMMAND+=" -quality ${QUALITY}"
COMMAND+=" ${REMAINING}"
COMMAND+=" ${OUTPUT_FILE}"

# Execute
${COMMAND} 2>&1 | tee ${OUTPUT_TEXT}
CONVERSION_CODE=${PIPESTATUS[0]}

if [ ${CONVERSION_CODE} -eq 0 ]
then
  echo "Successfully converted image and saved to ${OUTPUT_FILE}"
  log "INFO: Successfully converted ${INPUT_FILE}"
else
  echo "Failed to convert image"
  log "ERROR: Failed to convert ${INPUT_FILE} (exit code: ${CONVERSION_CODE}):" ${COMMAND} `cat ${OUTPUT_TEXT}`
fi

# Cleanup
rm -f ${CLEANUP_FILES} 2>&1 >/dev/null

exit ${CONVERSION_CODE}