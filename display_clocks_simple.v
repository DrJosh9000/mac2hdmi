`timescale 1ns / 1ps
`default_nettype none

// Project F: Display Clocks
// (C)2019 Will Green, Open source hardware released under the MIT License
// Learn more at https://projectf.io

// Modified by Josh Deprez. Three key differences:
// 1) Defaults to 65 MHz for 1024x768 (XGA) at 60 Hz.
// 2) Uses MMCME2_ADV instead of MMCME2_BASE, because the latter does not build
//    in SymbiFlow (yet?).
// 3) Only produces the 1x clock, not the 5x clock needed for HDMI. 

module display_clocks_simple #(
    parameter MULT=13,                // clock multiplier (2-64)
    parameter DIV=20,                 // clock divider (1-128)
    parameter IN_PERIOD=10.0          // period of i_clk in ns (100 MHz = 10.0 ns)
    )
    (
    input  wire i_clk,      // input clock
    input  wire i_rst,      // reset (active high)
    output wire o_clk,      // pixel clock
    output wire o_locked    // clock locked? (active high)
    );

    wire clk_fb;  // internal clock feedback
    wire clk_pre;

    MMCME2_ADV #(
        .COMPENSATION("INTERNAL"),      // Dunno if this is needed?
        .BANDWIDTH("OPTIMIZED"),        // Jitter programming (OPTIMIZED, HIGH, LOW)
        .CLKFBOUT_MULT_F(MULT),         // Multiply value for all CLKOUT (2.0 - 64.0).
        .CLKFBOUT_PHASE(0.0),           // Phase offset in degrees of CLKFB (-360.000-360.000).
        .CLKIN1_PERIOD(IN_PERIOD),      // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
        // CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
        .CLKOUT0_DIVIDE_F(1.0),         // Divide amount for CLKOUT0 (1-128).
        .CLKOUT1_DIVIDE(1),
        .CLKOUT2_DIVIDE(1),
        .CLKOUT3_DIVIDE(1),
        .CLKOUT4_DIVIDE(1),
        .CLKOUT5_DIVIDE(1),
        // CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT2_DUTY_CYCLE(0.5),
        .CLKOUT3_DUTY_CYCLE(0.5),
        .CLKOUT4_DUTY_CYCLE(0.5),
        .CLKOUT5_DUTY_CYCLE(0.5),
        // CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
        .CLKOUT0_PHASE(0.0),
        .CLKOUT1_PHASE(0.0),
        .CLKOUT2_PHASE(0.0),
        .CLKOUT3_PHASE(0.0),
        .CLKOUT4_PHASE(0.0),
        .CLKOUT5_PHASE(0.0),
        .DIVCLK_DIVIDE(DIV),     // Master division value (1-106)
        .REF_JITTER1(0.010),            // Reference input jitter in UI (0.000-0.999).
        .STARTUP_WAIT("FALSE")          // Delays DONE until MMCM is locked (FALSE, TRUE)
    )
    MMCM_inst (
        /* verilator lint_off PINCONNECTEMPTY */
        // Clock Outputs: 1-bit (each) output: User configurable clock outputs
        .CLKOUT0(clk_pre),              // 1-bit output: CLKOUT0
        .CLKOUT1(),                     // 1-bit output: CLKOUT1
        .CLKOUT2(),                     // 1-bit output: CLKOUT2
        .CLKOUT3(),                     // 1-bit output: CLKOUT3
        .CLKOUT4(),                     // 1-bit output: CLKOUT4
        .CLKOUT5(),                     // 1-bit output: CLKOUT5
        // Feedback Clocks: 1-bit (each) output: Clock feedback ports
        .CLKFBOUT(clk_fb),              // 1-bit output: Feedback clock
        // Status Ports: 1-bit (each) output: MMCM status ports
        .LOCKED(o_locked),              // 1-bit output: LOCK
        // Clock Inputs: 1-bit (each) input: Clock input
        .CLKIN1(i_clk),                 // 1-bit input: Clock
        // Control Ports: 1-bit (each) input: PLL control ports
        //.PWRDWN(),                      // 1-bit input: Power-down
        /* verilator lint_on PINCONNECTEMPTY */
        .RST(i_rst),                    // 1-bit input: Reset
        // Feedback Clocks: 1-bit (each) input: Clock feedback ports
        .CLKFBIN(clk_fb)                // 1-bit input: Feedback clock
    );

    // explicitly buffer output clocks
    BUFG bufg_clk_pix(.I(clk_pre), .O(o_clk));

endmodule
