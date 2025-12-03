# Audio notes

### System 

Clock Constant
```
NTSC = 3579545 ticks per second
PAL  = 3546895 ticks per second
```

VBLANK duration
```
NTSC = ~0.0166s
PAL  = ~0.0199s
```

### Period and frequency for simple waveforms

Get frequency from a simple waveform
```
                    Clock Constant      
   Frequency = -----------------------
               Sample length * Period
```

Calculate period of a simple waveform

```
                     Clock Constant             
   Period =    ------------------------- 
               Sample length * FreqTarget
```


  Table 5-7: Equal-tempered Octave for a 16 Byte Sample

```
 NTSC     PAL             Ideal   Actual NTSC  Actual PAL
Period  Period   Note   Frequency  Frequency   Frequency
------  ------   ----   --------- -----------  ----------
 254     252      A       880.0      880.8       879.7
 240     238      A#      932.3      932.2       931.4
 226     224      B       987.8      989.9       989.6
 214     212      C      1046.5     1045.4      1045.7
 202     200      C#     1108.7     1107.5      1108.4
 190     189      D      1174.7     1177.5      1172.9
 180     178      D#     1244.5     1242.9      1245.4
 170     168      E      1318.5     1316.0      1319.5
 160     159      F      1396.9     1398.3      1394.2
 151     150      F#     1480.0     1481.6      1477.9
 143     141      G      1568.0     1564.5      1572.2
 135     133      G#     1661.2     1657.2      1666.8				   
```

### Limitations on Selection for Sampling Period

In order to save buffers, the hardware is designed to handle **28,867 samples/second**.

```
                         Clock Constant
   Minumum period = -----------------------
                     28,867 samples/second
```

### Determine time duration of any sample

get duration in seconds
```
Duration (s) = Sample length / Original recorded frequency
```

get duration in seconds given a played period
```
                 Sample length * Period
Duration (s) = --------------------------
                    Clock Constant
```
get raster lines that occurs until the sample ends
```
                 Duration (s)
Rasters = --------------------------
               VBLANK duration
```
               

