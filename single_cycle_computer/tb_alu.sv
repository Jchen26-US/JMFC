//////////////////////////////////////////////////////////////////////////////////
// The Cooper Union
// ECE 251 Spring 2023
//
//     Module Name: tb_alu
//     Description: Testbench for 32-bit RISC-based CPU ALU (MIPS)
//
// Tests:
//   Combinational: AND, OR, ADD, NOR, SUB, SLT, MFLO, MFHI
//   Clocked:       MULT, DIV (results captured on negedge clk)
//////////////////////////////////////////////////////////////////////////////////
`ifndef TB_ALU
`define TB_ALU

`timescale 1ns/100ps

`include "alu.sv"

module tb_alu;
    parameter n = 32;

    logic              clk;
    logic [(n-1):0]    a, b;
    logic [3:0]        alucontrol;
    logic [(n-1):0]    result;
    logic              zero;

    alu #(n) dut (
        .clk        (clk),
        .a          (a),
        .b          (b),
        .alucontrol (alucontrol),
        .result     (result),
        .zero       (zero)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;

    task check_result;
        input [63:0]   expected;   // top 32 bits used only for HiLo checks
        input          check_zero;
        input [1:0]    zero_expected; // 2=don't care, 1=expect 1, 0=expect 0
        input [127:0]  test_name;
        logic [(n-1):0] exp32;
        begin
            exp32 = expected[31:0];
            #1; // let combinational logic settle
            if (result !== exp32) begin
                $display("FAIL [%s]: alucontrol=4'b%4b a=0x%8h b=0x%8h | result=0x%8h, expected=0x%8h",
                          test_name, alucontrol, a, b, result, exp32);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [%s]: result=0x%8h", test_name, result);
                pass_count = pass_count + 1;
            end
            if (check_zero && zero_expected !== 2) begin
                if (zero !== zero_expected[0]) begin
                    $display("FAIL [%s] ZERO FLAG: got %b, expected %b",
                              test_name, zero, zero_expected[0]);
                    fail_count = fail_count + 1;
                end else begin
                    $display("PASS [%s] ZERO FLAG: zero=%b", test_name, zero);
                    pass_count = pass_count + 1;
                end
            end
        end
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);

        a = 0; b = 0; alucontrol = 4'bxxxx;
        @(negedge clk); // align to negedge so mult/div can settle

        $display("\n=== ALU TESTBENCH ===\n");

        $display("--- AND ---");
        alucontrol = 4'b0000;

        a = 32'hFFFF_FFFF; b = 32'h0000_0000;
        check_result(32'h0000_0000, 1, 1, "AND: all-ones & zero");

        a = 32'hFFFF_FFFF; b = 32'hFFFF_FFFF;
        check_result(32'hFFFF_FFFF, 1, 0, "AND: all-ones & all-ones");

        a = 32'hA5A5_A5A5; b = 32'h5A5A_5A5A;
        check_result(32'h0000_0000, 1, 1, "AND: checkerboard");

        a = 32'hDEAD_BEEF; b = 32'hFFFF_FFFF;
        check_result(32'hDEAD_BEEF, 1, 0, "AND: mask with all-ones");

        $display("--- OR ---");
        alucontrol = 4'b0001;

        a = 32'h0000_0000; b = 32'h0000_0000;
        check_result(32'h0000_0000, 1, 1, "OR: zero|zero");

        a = 32'hA5A5_A5A5; b = 32'h5A5A_5A5A;
        check_result(32'hFFFF_FFFF, 1, 0, "OR: checkerboard complement");

        a = 32'hDEAD_0000; b = 32'h0000_BEEF;
        check_result(32'hDEAD_BEEF, 1, 0, "OR: upper|lower halves");

        $display("--- ADD ---");
        alucontrol = 4'b0010;

        a = 32'd0;  b = 32'd0;
        check_result(32'd0, 1, 1, "ADD: 0+0");

        a = 32'd15; b = 32'd27;
        check_result(32'd42, 1, 0, "ADD: 15+27=42");

        a = 32'hFFFF_FFFF; b = 32'd1;
        check_result(32'h0000_0000, 1, 1, "ADD: overflow wrap");

        a = 32'h7FFF_FFFF; b = 32'd1;
        check_result(32'h8000_0000, 1, 0, "ADD: signed overflow");

        $display("--- NOR ---");
        alucontrol = 4'b0011;

        a = 32'h0000_0000; b = 32'h0000_0000;
        check_result(32'hFFFF_FFFF, 1, 0, "NOR: 0 NOR 0 = all-ones");

        a = 32'hFFFF_FFFF; b = 32'h0000_0000;
        check_result(32'h0000_0000, 1, 1, "NOR: all-ones NOR 0");

        a = 32'hA5A5_A5A5; b = 32'h5A5A_5A5A;
        check_result(32'h0000_0000, 1, 1, "NOR: checkerboard NOR complement");

        $display("--- SUB ---");
        alucontrol = 4'b0110;

        a = 32'd42; b = 32'd42;
        check_result(32'd0, 1, 1, "SUB: 42-42=0 (zero flag)");

        a = 32'd100; b = 32'd58;
        check_result(32'd42, 1, 0, "SUB: 100-58=42");

        a = 32'd0; b = 32'd1;
        check_result(32'hFFFF_FFFF, 1, 0, "SUB: 0-1 = 0xFFFFFFFF");

        $display("--- SLT ---");
        alucontrol = 4'b0111;

        a = 32'd5;  b = 32'd10;
        check_result(32'd1, 1, 0, "SLT: 5 < 10 => 1");

        a = 32'd10; b = 32'd5;
        check_result(32'd0, 1, 1, "SLT: 10 < 5 => 0 (zero flag)");

        a = 32'd7;  b = 32'd7;
        check_result(32'd0, 1, 1, "SLT: 7 < 7 => 0 (zero flag)");

        // Signed: negative vs positive
        a = 32'hFFFF_FFFF; b = 32'd1; // -1 (signed) < 1
        check_result(32'd1, 1, 0, "SLT: -1 < 1 => 1 (signed)");

        a = 32'd1; b = 32'hFFFF_FFFF; // 1 > -1 (signed)
        check_result(32'd0, 1, 1, "SLT: 1 < -1 => 0 (signed, zero flag)");

        $display("--- MULT (via MFLO/MFHI) ---");

        // 6 * 7 = 42 — fits in LO, HI = 0
        a = 32'd6; b = 32'd7;
        alucontrol = 4'b1000;
        @(negedge clk); #1; // wait for HiLo to latch

        alucontrol = 4'b0100; // MFLO
        check_result(32'd42, 0, 2, "MULT: MFLO 6*7=42");

        alucontrol = 4'b0101; // MFHI
        check_result(32'd0, 0, 2, "MULT: MFHI 6*7 hi=0");

        // Large mult: 0xFFFF_FFFF * 2 => LO=0xFFFF_FFFE, HI=0x0000_0001
        a = 32'hFFFF_FFFF; b = 32'd2;
        alucontrol = 4'b1000;
        @(negedge clk); #1;

        alucontrol = 4'b0100; // MFLO
        check_result(32'hFFFF_FFFE, 0, 2, "MULT: MFLO 0xFFFFFFFF*2 lo");

        alucontrol = 4'b0101; // MFHI
        check_result(32'h0000_0001, 0, 2, "MULT: MFHI 0xFFFFFFFF*2 hi");

        $display("--- DIV (via MFLO/MFHI) ---");

        // 100 / 7 = quotient 14, remainder 2
        a = 32'd100; b = 32'd7;
        alucontrol = 4'b1001;
        @(negedge clk); #1;

        alucontrol = 4'b0100; // MFLO = quotient
        check_result(32'd14, 0, 2, "DIV: MFLO 100/7 quotient=14");

        alucontrol = 4'b0101; // MFHI = remainder
        check_result(32'd2, 0, 2, "DIV: MFHI 100/7 remainder=2");

        // 50 / 5 = 10, remainder 0
        a = 32'd50; b = 32'd5;
        alucontrol = 4'b1001;
        @(negedge clk); #1;

        alucontrol = 4'b0100;
        check_result(32'd10, 0, 2, "DIV: MFLO 50/5 quotient=10");

        alucontrol = 4'b0101;
        check_result(32'd0, 0, 2, "DIV: MFHI 50/5 remainder=0");

        $display("--- ZERO FLAG ---");

        alucontrol = 4'b0010; // ADD
        a = 32'hFFFF_FFFF; b = 32'd1; // wraps to 0
        check_result(32'd0, 1, 1, "ZERO: ADD wrap to 0");

        alucontrol = 4'b0001; // OR
        a = 32'd0; b = 32'd0;
        check_result(32'd0, 1, 1, "ZERO: OR 0|0");

        $display("\n=== RESULTS: %0d passed, %0d failed ===\n", pass_count, fail_count);

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED — review output above");

        $finish;
    end

endmodule

`endif // TB_ALU