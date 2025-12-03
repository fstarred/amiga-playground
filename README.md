# Amiga playground

Amiga assembly code playground, it includes examples, simple demos, trainers, etc..

## Native tools

* Asm-One (v1.02 / v1.20)
* IFF-Converter (many versions were produced, they are more or less all good)

## External tools

* [XnConvert](https://www.xnview.com/en/xnconvert) - an image converter to multiple formats
* [Amigeconv](https://github.com/tditlu/amigeconv) - a graphics converter for different Amiga bitplanes, chunky & palette formats

## How to run 

1. Download and run your favourite version of Asm-One; all the demo and examples here were tested with **1.02** and **1.20**
2. [Setup the environment](#setup-env) properly
3. Select the workspace memory (100 KB is good)
4. Load the source (command 'R')
5. Type 'a' (assemble) and then type 'j' (jump)

<a id="setup-env"></a>
## Setup environment

Before diving into any assembler, in order to succesfully assemble the sources of this repository you need to assign volumes with the following commands:

```
assign SOURCES: <your_drawer>:amiga-playground/sources
assign RESOURCES: <your_drawer>:amiga-playground/resources
assign INCLUDE: <your_drawer>:asm-one/asm-one1.02/Include
```

Notice that for the **INCLUDE:** volume, you can use the **Asm-One 1.02** disk with the already included "Include" directory or the **NDK39.lha** package

**Prior Workbench 2.04**

You can use the ASSIGN commands from **s:StartupII** file

**From Workbench 2.04 and newer**

You can use the ASSIGN commands from **s:User-Startup** file

## Asm-One

### 1.02 

**WB Installation**

Insert Asm-One v1.02 disk, then copy all contents from df0: to <dest-dir>, for instance:

```
copy df0: to dh1:Asm-One1.02 ALL
```

If you want to use _req.library_:
```
copy df0:libs/req.library to dh0:Libs/
```

### 1.20

**WB Installation**

Extract Asm-One v1.20 lha on <dest-dir>, for instance:

```
lha -x asmonev120.lha dh1:asm-one120
```

if you want to assign volume SOURCES: from WB1.3, you want to edit _s:startup-sequence_:
```
ASSIGN SOURCES: <source_dir>
```

If you want to use _reqtools.library_, search for reqtools13.library, then:
```
copy reqtools13.library to dh0:Libs/reqtools.library
```

## External links

* http://corsodiassembler.ramjam.it/index_en.htm
* http://amigadev.elowar.com/
* https://invidious.grimore.org/
* http://www.pjhutchison.org/emulation/AmigaAsmTutorial.txt
* http://coppershade.org/
* https://flashtro.com/category/source/ctsource/amigasources/

