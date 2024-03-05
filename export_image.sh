#!/bin/bash
#set -x

# Set defaults
function set_defaults() {
    LOGENTRIES_URL="data.logentries.com"
    LOGENTRIES_PORT="10000"
    LOGENTRIES_TOKEN=""
}

OUTPUT_TEXT="output.txt"
CLEANUP_FILES="${OUTPUT_TEXT}"

set_defaults

function usage() {
    # Reset variables to default
    set_defaults

	echo ""
	echo "$(basename ${BASH_SOURCE}) - Convert image to different format"
	echo ""
	echo "Usage: $(basename ${BASH_SOURCE}) -i input_file -o output_file [options] [convert options]"
	echo ""
	echo "Options:"
	echo "-h, --help                  Show brief help."
	echo "-v, --verbose               Verbose output." # Is more a script debug mode
 	echo "-i, --input                 Input file or URI. Mandatory."
 	echo "-o, --output                Output file. Mandatory. Set \"-\" to send directly to standard output."
 	echo "-lt, --logentries-token     Logentries token. If not given no logging performed."
 	echo "-lu, --logentries-url       Logentries url. Default \"${LOGENTRIES_URL}\"."
 	echo "-lp, --logentries-port      Logentries port. Default \"${LOGENTRIES_PORT}\"."
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
    INPUT_FILE=$(basename "$(echo ${URL} | cut -d@ -f2 | cut -d/ -f2- | cut -d? -f1)")
    ${WGET} -q -O "${INPUT_FILE}" "${URL}"
fi

# Sanitize input file (remove special chars, convert spaces to underscore")
INVALID_REGEX='[ :?"\\]'
if [[ ${INPUT_FILE} =~ ${INVALID_REGEX} ]]; then
    SANITIZED_INPUT=${INPUT_FILE//[:?\']}
    SANITIZED_INPUT=${SANITIZED_INPUT// /_}
    SANITIZED_INPUT=$(basename ${SANITIZED_INPUT})

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
    exit 1;
fi

# Build convert command, NOTE: order of commands is very important for ImageMagick convert
COMMAND="${CONVERT} ${INPUT_FILE} ${REMAINING} ${OUTPUT_FILE}"

# Execute
${COMMAND} 2>&1 | tee ${OUTPUT_TEXT}
CONVERSION_CODE=${PIPESTATUS[0]}

if [ ${CONVERSION_CODE} -eq 0 ]
then
  echo "Successfully converted image and saved to ${OUTPUT_FILE}"
  log "INFO: Successfully converted ${INPUT_FILE}"
else
  echo "Failed to convert image"
  log "ERROR: Failed to convert \"${INPUT_FILE}\"; Info: ${INFO}; exit code: ${CONVERSION_CODE}; command and output:" ${COMMAND} `cat ${OUTPUT_TEXT}`
fi

# Cleanup
rm -f ${CLEANUP_FILES} 2>&1 >/dev/null

exit ${CONVERSION_CODE}
