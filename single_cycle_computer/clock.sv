//////////////////////////////////////////////////////////////////////////////////
// The Cooper Union
// ECE 251 Spring 2026
// Engineer: Jayden Chen and Matthew Jeong
// 
//     Module Name: clock
//     Description: Clock generator; duty cycle = 50%
//
//
//////////////////////////////////////////////////////////////////////////////////
`ifndef CLOCK
`define CLOCK

`timescale 1ns/100ps

module clock
    #(parameter ticks = 10)(
    //
    // ---------------- PORT DEFINITIONS ----------------
    //
    input ENABLE,
    output reg CLOCK
);
    //
    // ---------------- MODULE DESIGN IMPLEMENTATION ----------------
    //
    reg start_clock;
    real clock_on = ticks/2; // duty cycle = 50%
    real clock_off = ticks/2;

    // initialize variables
    initial begin
      CLOCK <= 0;
      start_clock <= 0;
    end

    always begin
        #(ticks/2);
        if (ENABLE)
            CLOCK = ~CLOCK;
        else
            CLOCK = 0;
    end
endmodule

`endif // CLOCK