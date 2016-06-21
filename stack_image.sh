#!/bin/bash
#set -x

# Set defaults
function set_defaults() {
    COLUMNS="1"
    COLUMN_X_OFFSET="0"
    COLUMN_Y_OFFSET="0"
    ROWS="3"
    ROW_X_OFFSET="-50"
    ROW_Y_OFFSET="50"
    COLS_MODE="lr"
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
 	echo "-cm, --column-mode       Append strategy for columns to generate the front image: \"left-to-right\" (short \"lr\"), \"bottom-to-top\" (short \"bt\"), \"right-to-left\" (short \"rl\") or \"top-to-bottom\" (short \"tb\"). Default \"${COLS_MODE}\"."
 	echo "-cx, --column-x-offset   Column placement offset on X-axis (in pixels). Default \"${COLUMN_X_OFFSET}\"."
 	echo "-cy, --column-y-offset   Column placement offset on Y-axis (in pixels). Default \"${COLUMN_Y_OFFSET}\"."
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
		-cx|--column-x-offset)
            shift
            if test $# -gt 0; then
                COLUMN_X_OFFSET=$1
            else
                usage_exit "No column x offset given."
            fi
			shift
			;;
        -cy|--column-y-offset)
            shift
            if test $# -gt 0; then
                COLUMN_Y_OFFSET=$1
            else
                usage_exit "No column y offset given."
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

# Check that output file is set
if [[ "AAA${OUTPUT_FILE}AAA" == "AAAAAA" ]]; then
	usage_exit "No output file defined. (mandatory)"
fi

# Check column modes
case "$COLS_MODE" in
	lr|ltr|left+to-right|east)
	    FRONT_COMPOSITION="E"
		;;
	rl|rtl|right-to-left|west)
	    FRONT_COMPOSITION="W"
		;;
	bt|btt|bottom-to-top|north)
		FRONT_COMPOSITION="N"
        ;;
	tb|ttb|top-to-bottom|south)
		FRONT_COMPOSITION="S"
        ;;
    *)
        usage_exit "Invalid append mode, must be \"left-to-right\", \"bottom-to-top\", \"right-to-left\" or \"top-to-bottom\"."
    	;;
esac

function log() {
    if [[ ! "AAA${LOGENTRIES_TOKEN}AAA" == "AAAAAA" ]]; then
        echo "${LOGENTRIES_TOKEN} $@" | telnet ${LOGENTRIES_URL} ${LOGENTRIES_PORT} >/dev/null 2>&1
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


# Note: To generate the front image (driven by columns) we could use convert's "-/+" append function, but this does not
#       permits to set an offset, therefore we are going to grab the input image(s) size and do the positioning on our own
declare -a IMAGE_WIDTHS
declare -a IMAGE_HEIGHTS

# Split input files and grab its infos
declare -a INPUT_FILES
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
        ln -f -s "${INPUT_FILES[$i]}" ${SANITIZED_INPUT}

        INPUT_FILES[$i]=${SANITIZED_INPUT}
        CLEANUP_FILES+=" ${SANITIZED_INPUT}"
    fi

    check_input_exists ${INPUT_FILES[$i]}

    # Grab image infos
    INFO=`${CONVERT} "${INPUT_FILES[$i]}[0]" -print "%w %h\n" null: 2>/dev/null`

    IMAGE_WIDTHS[$i]=`echo ${INFO} | cut -d' ' -f1`
    IMAGE_HEIGHTS[$i]=`echo ${INFO} | cut -d' ' -f2`
done

# Override columns if more than one input file is given
if [[ ${#INPUT_FILES[@]} -gt 1 ]]; then
	COLUMNS=${#INPUT_FILES[@]}
fi

# Build convert command, NOTE: order of commands is very important for ImageMagick convert
COMMAND="${CONVERT}"

# Build front image (driven by columns)
CURRENT_X_POS="0"
CURRENT_Y_POS="0"
MIN_X="0"
MIN_Y="0"

function calculate_next_front_position() {
    INDEX=$@
    PREV_INDEX=0

    # Image INDEX can be 0 only if we are working with COLUMNS == 1
    if [[ ${INDEX} -ne 0 ]]; then
        PREV_INDEX=$(($INDEX - 1))
    fi

    # Note: Images have to be collated as would be on a table,
    #       therefore have to internally move the coordinates to the bottom-left corner,
    #       but return values for the top-left one (correction has to be done only for the "lr" and "rl" compositions on the Y axis)

    # Check column modes
    case "$FRONT_COMPOSITION" in
        lr|ltr|left+to-right|east|E)
            CURRENT_X_POS=$(${BC} <<< "${CURRENT_X_POS} + ${IMAGE_WIDTHS[$PREV_INDEX]}                             + ${COLUMN_X_OFFSET}")
            CURRENT_Y_POS=$(${BC} <<< "${CURRENT_Y_POS} + ${IMAGE_HEIGHTS[$PREV_INDEX]} - ${IMAGE_HEIGHTS[$INDEX]} + ${COLUMN_Y_OFFSET}")
            ;;
        rl|rtl|right-to-left|west|W)
            CURRENT_X_POS=$(${BC} <<< "${CURRENT_X_POS}                                 - ${IMAGE_WIDTHS[$INDEX]}  - ${COLUMN_X_OFFSET}")
            CURRENT_Y_POS=$(${BC} <<< "${CURRENT_Y_POS} + ${IMAGE_HEIGHTS[$PREV_INDEX]} - ${IMAGE_HEIGHTS[$INDEX]} + ${COLUMN_Y_OFFSET}")
            ;;
        tb|ttb|top-to-bottom|south|S)
            CURRENT_X_POS=$(${BC} <<< "${CURRENT_X_POS}                                                            + ${COLUMN_X_OFFSET}")
            CURRENT_Y_POS=$(${BC} <<< "${CURRENT_Y_POS} + ${IMAGE_HEIGHTS[$PREV_INDEX]}                            + ${COLUMN_Y_OFFSET}")
            ;;
        bt|btt|bottom-to-top|north|N)
            CURRENT_X_POS=$(${BC} <<< "${CURRENT_X_POS}                                                            + ${COLUMN_X_OFFSET}")
            CURRENT_Y_POS=$(${BC} <<< "${CURRENT_Y_POS}                                 - ${IMAGE_HEIGHTS[$INDEX]} - ${COLUMN_Y_OFFSET}")
            ;;
    esac

    # Get min values, needed for the row compositions to avoid gaps, they will be the origin for row calculations
    if [[ ${CURRENT_X_POS} -lt  ${MIN_X} ]] ; then
        MIN_X=${CURRENT_X_POS}
    fi

    if [[ ${CURRENT_Y_POS} -lt  ${MIN_Y} ]] ; then
        MIN_Y=${CURRENT_Y_POS}
    fi
}

if [[ $COLUMNS -gt 1 ]]; then
    COMMAND+=" ( ${INPUT_FILES[0]}[0] "

    if [[ ${#INPUT_FILES[@]} -gt 1 ]]; then
        for i in `seq 1 $(($COLUMNS - 1))`; do
            calculate_next_front_position ${i}

            COMMAND+=" ( ${INPUT_FILES[$i]}[0] -repage +${CURRENT_X_POS}+${CURRENT_Y_POS} )"
        done
    else
        for i in `seq 1 $(($COLUMNS - 1))`; do
            calculate_next_front_position 0

            COMMAND+=" ( +clone -repage +${CURRENT_X_POS}+${CURRENT_Y_POS} )"
        done
    fi

    COMMAND+=" -background transparent -layers merge )"
else
    COMMAND+=" ${INPUT_FILES[0]}[0]"
fi

# Build rows (from behind to front)
if [[ ${ROWS} -gt 1 ]]; then
    CURRENT_X_OFFSET=${MIN_X}
    CURRENT_Y_OFFSET=${MIN_Y}

    for i in `seq 1 $((${ROWS} - 1))`; do
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
