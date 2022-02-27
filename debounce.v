
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

// Multi-button debouncer.
module debounce #(
    parameter DEBOUNCE_TIME = 400_000, // ~4ms
    parameter BUTTONS = 4,
) (
    input wire  clk,
    input wire [BUTTONS-1:0] btn,
    output wire [BUTTONS-1:0] val,
    output wire [BUTTONS-1:0] strb,
);
    reg [BUTTONS-1:0] last_btn, btn_change, strobe;
    reg [23:0] timer [0:BUTTONS-1];

    genvar i;
    generate 
        for (i = 0; i < BUTTONS; i = i + 1) begin
            always @(posedge clk) begin
                if (last_btn[i] != btn[i]) begin
                    btn_change[i] <= 1;
                    timer[i] <= 0;
                    strobe[i] <= 0;
                end else if (btn_change[i]) begin
                    if (timer[i] > DEBOUNCE_TIME) begin
                        btn_change[i] <= 0;
                        strobe[i] <= 1;
                    end else begin
                        timer[i] <= timer[i] + 1;
                        strobe[i] <= 0;
                    end
                end else if (strobe[i]) begin
                    strobe[i] <= 0;
                end
                
                last_btn[i] <= btn[i];
            end
        end
    endgenerate

    assign val = last_btn;
    assign strb = strobe;
endmodule