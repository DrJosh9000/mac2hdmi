# mac2hdmi

My own attempts at using FPGAs to capture Macintosh Plus video output.
Based on samples from [Project F](https://projectf.io) and
[SymbiFlow](https://symbiflow-examples.readthedocs.io).

## Goal

Given:

* an early Macintosh logic board (128k, 512k/e, Plus) removed from its ordinary
  case and analog circuit,
* a power supply (e.g.Meanwell RT-65 B), 
* a 5V to 3V3 level shifter (e.g. some resistors),
* a boot device (e.g. Floppy Emu),  
* a modern computer monitor, and 
* an FPGA, 
  
boot the Macintosh and see what it is trying to display.

## Status

* ✅ Builds with SymbiFlow
* ✅ Reads Macintosh video source without any flickering
* ✅ Outputs 1024x768 video using PmodVGA
* ✅ Targets Arty A7 (`arty_35`, `xc7a35tcsg324-1` device)
* ❌ HDMI
* ❌ Other FPGA targets
* ❌ Audio capture
  
## Next steps

Target the Tang Nano 4K using Project Apicula (or the Gowin IDE if it comes 
down to it), including HDMI out.

## Building & using

After getting SymbiFlow set up:

1. `. prepare.sh` (activates Conda environment)
2. `make` (all the build steps - synthesis, placement, routing, packing, etc)
3. `./upload.sh` (sends bitstream to device)
