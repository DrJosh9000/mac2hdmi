/*
   Copyright 2022 Josh Deprez

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

`timescale 1ns / 1ps
`default_nettype none

// Macintosh Plus to VGA converter.
// Based in part on samples from Project F and SymbiFlow.
module top(
    input  wire CLK, // 100 MHz
    input  wire RST_BTN,
    input  wire [3:0] BTN,    // used to adjust sampling parameters
    input  wire [13:0] CK_IO, // first 14 chipKit I/O. video in on 5, 6, 7.
    output wire [3:0] LED,    // not used, but here for debugging
    // Attach PmodVGA to Pmod connectors JB and JC.
    // Attach those here.
    output wire VGA_HS,
    output wire VGA_VS,
    output wire [3:0] VGA_R,
    output wire [3:0] VGA_G,
    output wire [3:0] VGA_B,
);

    // Some stuff I don't understand (yet) to do with buffering the clock.
    wire clk;
    BUFG bufg_clk(.I(CLK), .O(clk));

    // Output pixel clock.
    wire vga_clk;       // output pixel clock
    wire vga_clk_lock;  // clock is stable?
    display_clocks_simple #(      
        .MULT(6.5), // XGA (1024x768) uses a 65 MHz pixel clock
        .DIV(10),   //  == 100 MHz * 6.5 / 10
        .IN_PERIOD(10.0)  // Input to the MMCM is 10ns period (100 MHz).
    )
    display_clocks_inst
    (
       .i_clk(CLK),
       .i_rst(~RST_BTN), 
       .o_clk(vga_clk),
       .o_locked(vga_clk_lock)
    );

    // Output display timings
    wire signed [15:0] vga_sx;  // horizontal screen position (signed)
    wire signed [15:0] vga_sy;  // vertical screen position (signed)
    wire vga_hsync;             // horizontal sync
    wire vga_vsync;             // vertical sync
    wire vga_de;                // display enable
    wire vga_frame;             // frame start

    // These values are known for each resolution (VESA).
    display_timings #(   // 640x480  800x600  1024x768 1280x720 1920x1080
        .H_RES(1024),    //     640      800      1024     1280      1920
        .V_RES(768),     //     480      600       768      720      1080
        .H_FP(24),       //      16       40        24      110        88
        .H_SYNC(136),    //      96      128       136       40        44
        .H_BP(160),      //      48       88       160      220       148
        .V_FP(3),        //      10        1         3        5         4
        .V_SYNC(6),      //       2        4         6        5         5
        .V_BP(29),       //      33       23        29       20        36
        .H_POL(1),       //       0        1         1        1         1
        .V_POL(1)        //       0        1         1        1         1
    )
    display_timings_inst (
        .i_pix_clk(vga_clk),
        .i_rst(!vga_clk_lock),
        .o_hs(vga_hsync),
        .o_vs(vga_vsync),
        .o_de(vga_de),
        .o_frame(vga_frame),
        .o_sx(vga_sx),
        .o_sy(vga_sy)
    );

    // Framebuffer.
    localparam FB_WIDTH  = 512;
    localparam FB_HEIGHT = 384;
    localparam FB_PIXELS = FB_WIDTH * FB_HEIGHT;
    localparam FB_ADDRW  = $clog2(FB_PIXELS);
    localparam FB_DATAW  = 1;

    reg fb_we;  // write enable
    wire [FB_ADDRW-1:0] fb_addr_write;  // address to write to
    wire [FB_ADDRW-1:0] fb_addr_read;   // address to read from
    wire [FB_DATAW-1:0] fb_colr_write;  // value to write
    wire [FB_DATAW-1:0] fb_colr_read;   // value that was read
    bram_sdp #(
        .WIDTH(FB_DATAW),
        .DEPTH(FB_PIXELS),
    ) bram_inst (
        .clk_write(clk),     // write on the global 100 MHz clock
        .clk_read(vga_clk),  // read on the output 65 MHz clock
        .we(fb_we),
        .addr_write(fb_addr_write),
        .addr_read(fb_addr_read),
        .data_in(fb_colr_write),
        .data_out(fb_colr_read),
    );

    // Consume video feed from macintosh logic board
    wire VIDEO_IN, HSYNC_IN, VSYNC_IN;
    assign VIDEO_IN = CK_IO[7];
    assign HSYNC_IN = CK_IO[6];
    assign VSYNC_IN = CK_IO[5];

    // Sample the incoming video stream.
    // The mac's pixel clock happens to be the system clock (15.6672 MHz).
    // Use a 16-bit counter to read the video stream every 6 or 7 main clocks
    // 15.6672 / 100 = 0.156672, or just less than 1/6
    // which is also approximately 5133 / 32768.
    // Each time the counter exceeds 32768, that's a new pixel.
    // By resetting the counter on each HSYNC pulse it only has to be accurate
    // enough for no more than 704 pixels (time between HSYNC pulses).
    localparam CTRW = 16;       // width of the counter register
    localparam CTR_INC = 5133;
    reg [CTRW-1:0] ctr_inc = CTR_INC;  // how much to add on each clk.

    // The pixel clock being read is exactly when the values change between each
    // pixel, so delay sampling the video signal by some offset.
    reg [3:0] samp_ctr, samp_offset = 2;

    // Use the buttons to adjust the clock and the sample offset.
    wire [3:0] btn_val, btn_strb;
    debounce #(
        DEBOUNCE_TIME = 400_000,
        BUTTONS = 4,
    )
    debounce (
        .clk(clk),
        .btn(BTN),
        .val(btn_val),
        .strb(btn_strb),
    );
    always @(posedge clk) begin
        if (btn_strb[0] && btn_val[0]) begin
            ctr_inc <= ctr_inc - 1;
        end
        if (btn_strb[1] && btn_val[1]) begin
            ctr_inc <= ctr_inc + 1;
        end
        if (btn_strb[2] && btn_val[2]) begin
            samp_offset <= samp_offset - 1;
        end
        if (btn_strb[3] && btn_val[3]) begin
            samp_offset <= samp_offset + 1;
        end
    end

    // Count how long it has been since either an input VSYNC or HSYNC.
    // Once the counter reaches all bits (0xffffff), disable the output to save
    // energy. (Counting to 2**24 takes about 1/6 sec.)
    reg [23:0] get_signal_ctr;
    wire get_signal_n = &get_signal_ctr;

    // These next two localparams were found with trial and error, but could
    // probably be derived from documentation (and made adjustable).
    localparam PX_START = -177;  // px reset to this value on negedge of hsync
    localparam PY_START = -8;    // py reset to this value on posedge of vsync
    reg [CTRW-1:0] mac_ctr;  // the counter used to approximate the mac clock
    // Catch the input signals in registers to make edge detection more reliable
    reg last_vsync, last_hsync, last_video, last_vsync1, last_hsync1, last_video1;
    reg signed [15:0] px, py; // Macintosh screen position (= framebuffer pos).

    assign fb_addr_write = {py[8:0], px[8:0]};  // = py * FB_WIDTH + px;
    assign fb_colr_write = last_video1;

    always @(posedge clk) begin
        // On posedge of vsync, reset py.
        if (!last_vsync1 && last_vsync) begin // vsync posedge
            py <= PY_START;
            get_signal_ctr <= 0;
        // On negedge of hsync, reset px, resync the mac clock estimate,
        // and increment py (go to the next line).
        end else if (last_hsync1 && !last_hsync) begin  // hsync negedge
            mac_ctr <= 0;
            py <= py + 1;
            px <= PX_START;
            get_signal_ctr <= 0;
        // On the estimated start of a pixel, reset samp_ctr and subtract 32768
        // from the mac clock estimator, and proceed to the next pixel
        // horizontally.
        end else if (mac_ctr[CTRW-1]) begin // pixel clock
            samp_ctr <= 0;
            mac_ctr <= mac_ctr[CTRW-2:0] + ctr_inc;
            px <= px + 1;
        // Otherwise, update the mac clock estimator and sample counter.
        // Enable writing to the framebuffer if the sample offset is reached and
        // the coordinates are in the frame.
        end else begin
            samp_ctr <= samp_ctr + 1;
            mac_ctr <= mac_ctr + ctr_inc;
            fb_we <= (samp_ctr == samp_offset && px >= 0 && px < 512 && py >= 0 && py < 342);
            get_signal_ctr <= get_signal_ctr + !get_signal_n;
        end
        // Put everything in registers.
        last_video1 <= ~last_video;
        last_vsync1 <= last_vsync;
        last_hsync1 <= last_hsync;
        last_video <= VIDEO_IN;
        last_vsync <= VSYNC_IN;
        last_hsync <= HSYNC_IN;
    end

    // Now back to the output buffer. Read the framebuffer.
    // Since it is being pixel-doubled, each framebuffer line is read twice.
    // Project F says that a linebuffer would be more effective, but this works
    // pretty well for me...
    assign fb_addr_read = {vga_sy[9:1], vga_sx[9:1]}; // = (sy/2)*FB_WIDTH + (sx/2);

    // Again, register all the values in order to ensure the video signal is 
    // perfectly synchronised.
    // Delay using them for 1 clock (because reading from the framebuffer takes
    // one clock cycle).
    reg [3:0] pix_out;
    reg vga_de1, hs1, vs1, vga_de2, hs2, vs2;
    always @(posedge vga_clk) begin
        pix_out <= vga_de1 && fb_colr_read ? 4'hf : 4'h0;
        hs2 <= hs1;
        vs2 <= vs1;
        vga_de1 <= vga_de && !get_signal_n;
        hs1 <= vga_hsync && !get_signal_n;
        vs1 <= vga_vsync && !get_signal_n;
    end

    // Finally: VGA Output
    assign VGA_HS   = hs2;
    assign VGA_VS   = vs2;
    assign VGA_R    = pix_out;
    assign VGA_G    = pix_out;
    assign VGA_B    = pix_out;
endmodule