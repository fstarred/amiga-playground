# Scripts
Here we find some CLI scripts, OS1.3 compatible, that allow to do some tasks in a efficent way.<br>

## General usage
from the CLI window:
```
execute <script_name> <args1> <arg2> ...
```

## ReDCrop

### Description
Reduce depth for source iff image and crop it, converting to an interleaved raw image. <br>
The output filename format is <SOURCE>.raw

### Arguments
SOURCE - the iff image file<br>
X - x position for crop<br>
Y - y position for crop<br>
WIDTH - crop width <br>
HEIGHT - crop height<br>
DEPTH - final depth of the image<br>
