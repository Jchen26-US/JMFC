//////////////////////////////////////////////////////////////////////////////////
// The Cooper Union
// ECE 251 Spring 2026
// Engineer: Jayden Chen
//
//      Module Name: tb_aludec
//      Description: Testbench for 32-bit RISC ALU decoder
//
// Tests:
//    Immediate/Memory ops (aluop 00, 01) — funct independence verified
//    R-type instructions via aluop 10 (funct mapping)
//    R-type instructions via aluop 11 (default branch — same funct routing)
//    Undefined funct code
//////////////////////////////////////////////////////////////////////////////////
`ifndef TB_ALUDEC
`define TB_ALUDEC

`timescale 1ns/100ps

`include "aludec.sv"

module tb_aludec;

    logic [5:0] funct;
    logic [1:0] aluop;
    logic [3:0] alucontrol;

    aludec dut (
        .funct      (funct),
        .aluop      (aluop),
        .alucontrol (alucontrol)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    task check_ctrl;
        input [3:0]   expected;
        input [127:0] test_name;
        begin
            #1;
            if (alucontrol !== expected) begin
                $display("FAIL [%s]: aluop=%b funct=%b | got %b, expected %b",
                          test_name, aluop, funct, alucontrol, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [%s]: alucontrol=%b", test_name, alucontrol);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_aludec.vcd");
        $dumpvars(0, tb_aludec);

        $display("\n=== ALU DECODER TESTBENCH ===\n");

        // aluop = 00: always ADD regardless of funct (LW / SW / ADDI)

        $display("--- aluop=00: Load/Store/ADDI (funct must be ignored) ---");
        aluop = 2'b00;
        funct = 6'b000000; check_ctrl(4'b0010, "LW/SW funct=000000");
        funct = 6'b100000; check_ctrl(4'b0010, "LW/SW funct=100000 (ADD code)");
        funct = 6'b111111; check_ctrl(4'b0010, "LW/SW funct=111111 (undefined)");
        funct = 6'bxxxxxx; check_ctrl(4'b0010, "LW/SW funct=xxxxxx");

        // -------------------------------------------------------------------
        // aluop = 01: always SUB regardless of funct (BEQ)
        // -------------------------------------------------------------------
        $display("--- aluop=01: Branch Equal (funct must be ignored) ---");
        aluop = 2'b01;
        funct = 6'b000000; check_ctrl(4'b0110, "BEQ funct=000000");
        funct = 6'b100010; check_ctrl(4'b0110, "BEQ funct=100010 (SUB code)");
        funct = 6'b111111; check_ctrl(4'b0110, "BEQ funct=111111 (undefined)");
        funct = 6'bxxxxxx; check_ctrl(4'b0110, "BEQ funct=xxxxxx");

        // aluop = 10: R-type funct decoding

        $display("--- aluop=10: R-Type funct decode ---");
        aluop = 2'b10;
        funct = 6'b100000; check_ctrl(4'b0010, "R-Type: ADD  (100000)");
        funct = 6'b100010; check_ctrl(4'b0110, "R-Type: SUB  (100010)");
        funct = 6'b100100; check_ctrl(4'b0000, "R-Type: AND  (100100)");
        funct = 6'b100101; check_ctrl(4'b0001, "R-Type: OR   (100101)");
        funct = 6'b100111; check_ctrl(4'b0011, "R-Type: NOR  (100111)");
        funct = 6'b101010; check_ctrl(4'b0111, "R-Type: SLT  (101010)");
        funct = 6'b011000; check_ctrl(4'b1000, "R-Type: MULT (011000)");
        funct = 6'b011010; check_ctrl(4'b1001, "R-Type: DIV  (011010)");
        funct = 6'b010010; check_ctrl(4'b0100, "R-Type: MFLO (010010)");
        funct = 6'b010000; check_ctrl(4'b0101, "R-Type: MFHI (010000)");
        funct = 6'b111111; check_ctrl(4'bxxxx, "R-Type: undefined funct");
        funct = 6'b100110; check_ctrl(4'b1010, "R-Type: XOR  (100110)");
        funct = 6'b000000; check_ctrl(4'b1011, "R-Type: SLL  (000000)");
        funct = 6'b000010; check_ctrl(4'b1100, "R-Type: SRL  (000010)");


        // aluop = 11: default branch in the case statement — should also
        // route through the funct lookup the same way aluop=10 does

        $display("--- aluop=11: default branch (same funct routing as aluop=10) ---");
        aluop = 2'b11;
        funct = 6'b100000; check_ctrl(4'b0010, "default aluop: ADD  (100000)");
        funct = 6'b100010; check_ctrl(4'b0110, "default aluop: SUB  (100010)");
        funct = 6'b100100; check_ctrl(4'b0000, "default aluop: AND  (100100)");
        funct = 6'b101010; check_ctrl(4'b0111, "default aluop: SLT  (101010)");
        funct = 6'b011000; check_ctrl(4'b1000, "default aluop: MULT (011000)");
        funct = 6'b111111; check_ctrl(4'bxxxx, "default aluop: undefined funct");
        funct = 6'b100110; check_ctrl(4'b1010, "default aluop: XOR  (100110)");
        funct = 6'b000000; check_ctrl(4'b1011, "default aluop: SLL  (000000)");
        funct = 6'b000010; check_ctrl(4'b1100, "default aluop: SRL  (000010)");

        $display("\n=== RESULTS: %0d passed, %0d failed ===\n", pass_count, fail_count);

        if (fail_count == 0)
            $display("ALL DECODER TESTS PASSED");
        else
            $display("SOME DECODER TESTS FAILED");

        $finish;
    end

endmodule

`endif // TB_ALUDEC