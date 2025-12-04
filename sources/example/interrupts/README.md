# Interrupts & CIA

### Clock Constant
```
NTSC = 3579545 ticks per second
PAL  = 3546895 ticks per second
```

### VBLANK duration
```
NTSC = ~0.0166s
PAL  = ~0.0199s
```

### System Frequencies (Master Oscillator)
```
NTSC	=	28.636360 MHz
PAL 	=	28.375160 MHz
```

### Raster Line Duration

| Standard | Cycles per Raster Line | Raster Line Duration (μs) |
|----------|------------------------|---------------------------|
| NTSC     | 1820                   | ≈63.5555 μs               |
| PAL      | 1816                   | ≈63.9996 μs               |


### CIA Timer A / Timer B Tick Duration

|Amiga Video Standard|CIA Clock Frequency (E-Clock)|Tick Duration (μs)  |
|--------------------|-----------------------------|--------------------|
|NTSC                |0.715909 MHz                 |≈1.3968 μs          |
|PAL                 |0.709379 MHz                 |≈1.4097 μs          |

### CIAA TOD (Vertical Sync)

|Standard|Frequency                    |Tick Duration          |
|--------|-----------------------------|-----------------------|
|NTSC    |60 Hz                        |16666.67 μs (16.6 ms) |
|PAL     |50 Hz                        |20000.00 μs (20 ms)   |

### CIAB TOD (Horizontal Sync)

|Standard|Frequency                    |Tick Duration|
|--------|-----------------------------|-------------|
|NTSC    |≈15.734 kHz                  |≈63.56 μs    |
|PAL     |≈15.625 kHz                  |≈64.00 μs    |


