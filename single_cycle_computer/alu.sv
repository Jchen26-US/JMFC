//////////////////////////////////////////////////////////////////////////////////
// The Cooper Union
// ECE 251 Spring 2023
// Engineer: Prof Rob Marano
// 
//     Create Date: 2023-02-07
//     Module Name: alu
//     Description: 32-bit RISC-based CPU alu (MIPS)
//
// Revision: 1.0
// see https://github.com/Caskman/MIPS-Processor-in-Verilog/blob/master/ALU32Bit.v
//////////////////////////////////////////////////////////////////////////////////
`ifndef ALU
`define ALU

`timescale 1ns/100ps

module alu
    #(parameter n = 32)(
    //
    // ---------------- PORT DEFINITIONS ----------------
    //
    input  logic        clk,
    input  logic [(n-1):0] a, b,
    input  logic [3:0]  alucontrol,
    output logic [(n-1):0] result,
    output logic        zero
);
    //
    // ---------------- MODULE DESIGN IMPLEMENTATION ----------------
    //
    logic [(2*n-1):0] HiLo;

    assign zero = (result == {n{1'b0}}); // zero result control signal 

    // initialize the internal HiLo register used in multiplying two 32-bit numbers = a 64-bit number.
    initial
        begin
            HiLo = 64'b0;
        end

    always @(a,b,alucontrol) begin
        case (alucontrol)
            4'b0000: result = a & b;             // and
            4'b0001: result = a | b;             // or
            4'b0010: result = a + b;             // add
            4'b0011: result = ~(a | b);          // nor
            4'b0100: result = HiLo[(n-1):0];     // MFLO
            4'b0101: result = HiLo[(2*n-1):n];   // MFHI
            4'b0110: result = a + (~b) + 1;            // sub 2's complement (a+b)
            4'b0111: begin                       // slt
                                if (a[31] != b[31])
                                    result = a[31] ? 1 : 0;
                                else
                                    result = (a < b) ? 1 : 0;
            end
            4'b1010: result = a^b; //xor
            4'b1011: result = a << b[4:0]; //sll
            4'b1100: result = a >> b[4:0]; //srl
            default: result = {n{1'bx}};         // default for mult/div combinational output
        endcase
    end

    //Multiply and divide results are only stored at clock falling edge.
    always @(negedge clk) begin
        case (alucontrol)
            4'b1000: HiLo = a * b; // mult
            4'b1001: // div
            begin
                HiLo[(n-1):0] = a / b;
                HiLo[(2*n-1):n] = a % b;
            end
        endcase
    end
endmodule

`endif // ALU
