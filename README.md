# imagemagick-scripts
ImageMagick Scripts

## convert_image
```bash
convert_image.sh - Convert image

Usage: convert_image.sh -i input_file -o output_file [options] [convert options]

Options:
-h, --help               Show brief help.
-v, --verbose            Verbose output.
-i, --input              Input file or URI. Mandatory.
-o, --output             Output file. Mandatory. Set "-" to send directly to standard
                         output.
-t, --target-profile     Color profile file to apply. Default "./profiles/sRGB.icm".
-p, --page, --layer      Select input page or layer (PDF or PSD). Default "0".
-fp, --ps-formats        Formats to be interpreted as postscript graphic. comma separated
                         list.
                         Those will be checked (with ps2pdf) if are pure vector graphic.
                         Default "EPDF,EPI,EPS,EPSF,EPSI,PDF,PDFA,PS".
-fv, --vector-formats    Formats to be interpreted as vector graphic. comma separated
                         list.
                         Default "MSVG,SVG,SVGZ,AI,PCT,PICT".
-s, --size               Thumbnail size. Default "200x200>".
-d, --density            Density. Default "72".
-q, --quality            JPEG quality. Default "80".
-b, --background         Set background of image, might not be shown (depends on alpha).
                         Default "white".
-a, --alpha              Modify alpha channel of an image. Default "remove".
-lt, --logentries-token  Logentries token. If not given no logging performed.
-lu, --logentries-url    Logentries url. Default "data.logentries.com".
-lp, --logentries-port   Logentries port. Default "10000".

convert options: see 'convert --help'
```

Notes:
- Listing of recognised formats can be get trough ```identify -list format```
- Format of file image can be discovered trough ```convert <image> -print "%m\n" null:```
- Size input format is defined by an ImageMagick [geometry](http://www.imagemagick.org/script/command-line-processing.php#geometry)
- Density input format is defined by an ImageMagick [density](http://www.imagemagick.org/script/command-line-options.php#density)
- Alpha channel manipulation, trough alpha and background params, is defined by ImageMagick [alpha](http://www.imagemagick.org/script/command-line-options.php#alpha); here some [examples](http://www.imagemagick.org/Usage/masking#alpha_channel)

Requirements:
- [Bourne Again SHell](http://www.gnu.org/software/bash/)
- [ImageMagick's convert](http://www.imagemagick.org/script/convert.php)
- [Ghostscript ps2pdf](http://www.ghostscript.com/doc/9.14/Ps2pdf.htm) Usually packaged with ImageMagick distribution.
- [wget](http://www.gnu.org/software/wget/)
- `telnet` - required to log processing to [Logentries](https://logentries.com/)
