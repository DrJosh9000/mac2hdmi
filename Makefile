current_dir := ${CURDIR}
TOP := top

SOURCES := ${current_dir}/bram_sdp.v \
           ${current_dir}/debounce.v \
           ${current_dir}/display_clocks_simple.v \
           ${current_dir}/display_timings.v \
           ${current_dir}/top.v 

# TODO: support other boards - I defaulted to arty_35 because
# that's what I got
TARGET=arty_35
PCF := ${current_dir}/arty_vga.pcf

include ${current_dir}/common/common.mk