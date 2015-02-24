#!/bin/bash
set -x

input_file="$1"
output_file="$2"
profile_file="profile.icc"
srgb_profile_file="sRGB.icm"
size="200"
logentries_token="f9021350-5368-4f48-9f08-3d28522ef158"
logentries_url="data.logentries.com"
logentries_port="10000"

profile_output=`convert $input_file $profile_file 2>&1`

if [ $? -eq 0 ]
then
  echo "Color profile found"
  conversion_output=`convert -profileee $profile_file $input_file -profile $srgb_profile_file -thumbnail $size\x$size\> -density 72 $output_file 2>&1`
else
  echo "No color profile found"
  conversion_output=`convert $input_file -profile $srgb_profile_file -thumbnail $sizex$size\> -density 72 $output_file 2>&1`
fi

conversion_code=$?

if [ $conversion_code -eq 0 ]
then
  echo "Successfully converted image and saved to $output_file"
  { echo "$logentries_token INFO: Successfully converted $input_file"; } | telnet $logentries_url $logentries_port
else
  echo "Failed to convert image"
  { echo "$logentries_token ERROR: Failed to convert $input_file: $conversion_output"; } | telnet $logentries_url $logentries_port
fi

exit $conversion_code
