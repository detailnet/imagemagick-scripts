#!/bin/bash
#set -x

input_file="$1"
output_file="$2"
profile_file="profile.icc"
srgb_profile_file="sRGB.icm"
size="200"

convert "$input_file" "$profile_file"

if [ $? -eq 0 ]
then
  echo "Color profile found"
  convert -profile $profile_file $input_file -profile $srgb_profile_file -thumbnail $size\x$size\> -density 72 $output_file
else
  echo "No color profile found"
  convert $input_file -profile $srgb_profile_file -thumbnail $sizex$size\> -density 72 $output_file
fi

if [ $? -eq 0 ]
then
  echo "Successfully converted image and saved to $output_file"
else
  echo "Failed to convert image"
fi

exit $?
