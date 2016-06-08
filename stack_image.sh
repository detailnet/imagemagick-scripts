#!/bin/bash
#set -x

# Set defaults
function set_defaults() {
    COLUMNS="1"
    ROWS="3"
    ROW_X_OFFSET="-50"
    ROW_Y_OFFSET="50"
    COLS_MODE="rl"
    LOGENTRIES_URL="data.logentries.com"
    LOGENTRIES_PORT="10000"
    LOGENTRIES_TOKEN=""
}

set_defaults

function usage() {
    # Reset variables to default
    set_defaults

	echo ""
	echo "$(basename $0) - Stack image(s)"
	echo ""
	echo "Usage: $(basename $0) -i input_file[,input_file] -o output_file [options] [convert options]"
	echo ""
	echo "This script best works with images with a correct alpha channel set, and always with a transparent background."
	echo ""
	echo "Options:"
	echo "-h, --help               Show brief help."
	echo "-v, --verbose            Verbose output." # Is more a script debug mode
 	echo "-i, --input              Input file(s) or URI(s). Comma separated. Mandatory."
 	echo "-o, --output             Output file. Mandatory. Set \"-\" to send directly to standard output."
 	echo "-c, --columns            Column count, ignored if more than one input file is provided. Default \"${COLUMNS}\"."
 	echo "-cm, --column-mode       Append strategy for column: \"right-to-left\" (short \"rl\") or \"top-to-bottom\" (short \"tb\"). Default \"${COLS_MODE}\"."
 	echo "-r, --rows               Rows count, Default \"${ROWS}\"."
 	echo "-rx, --row-x-offset      Row placement offset on X-axis (in pixels). Default \"${ROW_X_OFFSET}\"."
 	echo "-ry, --row-y-offset      Row placement offset on Y-axis (in pixels). Default \"${ROW_Y_OFFSET}\"."
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
WGET=$(type -P wget)  || { echo "Script requires GNU wget, but it's not installed."; exit 1; }
BC=$(type -P bc)  || { echo "Script requires the Basic Calculator, but it's not installed."; exit 1; }

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
                usage_exit "No input file(s) given."
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
        -c|--columns)
            shift
            if test $# -gt 0; then
                COLUMNS=$1
            else
                usage_exit "No columns given."
            fi
			shift
			;;
        -cm|--column-mode)
            shift
            if test $# -gt 0; then
                COLS_MODE=$1
            else
                usage_exit "No column mode given."
            fi
			shift
			;;
        -r|--rows)
            shift
            if test $# -gt 0; then
                ROWS=$1
            else
                usage_exit "No rows given."
            fi
			shift
			;;
        -rx|--row-x-offset)
            shift
            if test $# -gt 0; then
                ROW_X_OFFSET=$1
            else
                usage_exit "No row x offset given."
            fi
			shift
			;;
        -ry|--row-y-offset)
            shift
            if test $# -gt 0; then
                ROW_Y_OFFSET=$1
            else
                usage_exit "No row y offset given."
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

# Split input files
IFS=',' read -ra INPUT_FILES <<< "$INPUT_FILE"

# Check if URL input, convert supports it natively but would download every time is called. Download here.
URL_REGEX='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'

for ((i=0; i<${#INPUT_FILES[@]}; i++)); do
    # @todo should check that the provided filename are unique

    if [[ ${INPUT_FILES[$i]} =~ ${URL_REGEX} ]]; then
        URL=${INPUT_FILES[$i]}
        INPUT_FILES[$i]=$(basename "$(echo ${URL} | cut -d@ -f2 | cut -d/ -f2- | cut -d? -f1)")
        ${WGET} -q -O "${INPUT_FILES[$i]}" "${URL}"
    fi

    # Sanitize input file (remove special chars, convert spaces to underscore")
    INVALID_REGEX='[ :?"\\]'
    if [[ ${INPUT_FILES[$i]} =~ ${INVALID_REGEX} ]]; then
        SANITIZED_INPUT=${INPUT_FILES[$i]//[:?\']}
        SANITIZED_INPUT=${SANITIZED_INPUT// /_}

        # @todo: Should check that does not already exists

        # Create symbolic link so that there is no need to copy or move data
        ln -f -s "${INPUT_FILES[$i]}" $SANITIZED_INPUT

        INPUT_FILES[$i]=$SANITIZED_INPUT
        CLEANUP_FILES+=" $SANITIZED_INPUT"
    fi
done

# Check that output file is set
if [[ "AAA${OUTPUT_FILE}AAA" == "AAAAAA" ]]; then
	usage_exit "No output file defined. (mandatory)"
fi

# Check column modes
case "$COLS_MODE" in
	rl|rtl|right-to-left)
	    COL_MERGE_CMD="+append"
		;;
	tb|ttb|top-to-bottom)
		COL_MERGE_CMD="-append"
        ;;
    *)
        usage_exit "Invalid append mode, must be \"right-to-left\" or \"top-to-bottom\"."
    	;;
esac


function log() {
    if [[ ! "AAA${LOGENTRIES_TOKEN}AAA" == "AAAAAA" ]]; then
        echo "${LOGENTRIES_TOKEN} $@" | telnet $LOGENTRIES_URL $LOGENTRIES_PORT >/dev/null 2>&1
    fi
}

function check_input_exists() {
    # Check that input file is present
    if [[ ! -r $@ ]]; then
        echo "Input file \"$@\" not readable."
        log "ERROR: Input file \"$@\" not readable."
        exit 1;
    fi
}

### END CONFIGURATION, BEGIN WORK ###

# Override columns if more than one input file is given
if [[ ${#INPUT_FILES[@]} -gt 1 ]]; then
	COLUMNS=${#INPUT_FILES[@]}
fi

# Build convert command, NOTE: order of commands is very important for ImageMagick convert
COMMAND="${CONVERT}"

check_input_exists ${INPUT_FILES[0]}

if [[ $COLUMNS -gt 1 ]]; then
    COMMAND+=" ( ${INPUT_FILES[0]} "

    if [[ ${#INPUT_FILES[@]} -gt 1 ]]; then
        for i in `seq 1 $(($COLUMNS - 1))`; do
          check_input_exists ${INPUT_FILES[$i]}
          COMMAND+=" ${INPUT_FILES[$i]}"
        done
    else
        for i in `seq 1 $(($COLUMNS - 1))`; do
            COMMAND+=" ( +clone )"
        done
    fi

    COMMAND+=" ${COL_MERGE_CMD} )"
else
    COMMAND+=" ${INPUT_FILES[0]}"
fi

if [[ $ROWS -gt 1 ]]; then
    CURRENT_X_OFFSET="0"
    CURRENT_Y_OFFSET="0"

    for i in `seq 1 $(($ROWS - 1))`; do
       CURRENT_X_OFFSET=$(${BC} <<< "${CURRENT_X_OFFSET} + ${ROW_X_OFFSET}")
       CURRENT_Y_OFFSET=$(${BC} <<< "${CURRENT_Y_OFFSET} + ${ROW_Y_OFFSET}")

       COMMAND+=" ( +clone -repage +${CURRENT_X_OFFSET}+${CURRENT_Y_OFFSET} )"
    done
fi

COMMAND+=" -background transparent -layers merge"

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
  log "ERROR: Failed to convert; Info: ${INFO}; exit code: ${CONVERSION_CODE}; command and output:" ${COMMAND} `cat ${OUTPUT_TEXT}`
fi

# Cleanup
rm -f ${CLEANUP_FILES} 2>&1 >/dev/null

exit ${CONVERSION_CODE}
