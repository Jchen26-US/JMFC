//////////////////////////////////////////////////////////////////////////////////
// The Cooper Union
// ECE 251 Spring 2026
// Engineer: Jayden Chen
//
//      Module Name: tb_regfile
//      Description: Testbench for 32-bit RISC Register File
//
// Tests:
//    - Hardwired zero register (Reg 0)
//    - Synchronous write (posedge clk)
//    - Combinational read (ra1, ra2)
//    - Write enable (we3) logic
//////////////////////////////////////////////////////////////////////////////////
`ifndef TB_REGFILE
`define TB_REGFILE

`timescale 1ns/100ps

`include "regfile.sv"

module tb_regfile;
    parameter n = 32;
    parameter r = 5;

    // ---------------- PORT DEFINITIONS ----------------
    logic          clk;
    logic          we3;
    logic [r-1:0]  ra1, ra2, wa3;
    logic [n-1:0]  wd3;
    logic [n-1:0]  rd1, rd2;

    // ---------------- UNIT UNDER TEST ----------------
    regfile #(n, r) dut (
        .clk(clk), .we3(we3),
        .ra1(ra1), .ra2(ra2), .wa3(wa3),
        .wd3(wd3), .rd1(rd1), .rd2(rd2)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    // ---------------- CLOCK GENERATION ----------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ---------------- TEST TASK ----------------
    task check_reg;
        input [n-1:0] expected_rd1;
        input [n-1:0] expected_rd2;
        input [511: 0] test_name;
        begin
            #1; // Small delay to allow combinational reads to settle
            if (rd1 !== expected_rd1 || rd2 !== expected_rd2) begin
                $display("FAIL [%s]: ra1=%d ra2=%d | rd1=0x%h (exp 0x%h), rd2=0x%h (exp 0x%h)", 
                          test_name, ra1, ra2, rd1, expected_rd1, rd2, expected_rd2);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [%s]: rd1=0x%h rd2=0x%h", test_name, rd1, rd2);
                pass_count = pass_count + 1;
            end
        end
    endtask

    // ---------------- MAIN TEST VECTORS ----------------
    initial begin
        $dumpfile("tb_regfile.vcd");
        $dumpvars(0, tb_regfile);

        $display("\n=== REGISTER FILE TESTBENCH ===\n");

        // Initialize inputs
        we3 = 0; ra1 = 0; ra2 = 0; wa3 = 0; wd3 = 0;

        // --- Test 1: Hardwired Zero ---
        $display("--- Testing Register 0 ---");
        wa3 = 5'd0; wd3 = 32'hFFFFFFFF; we3 = 1;
        @(posedge clk); #1; // Try to write to reg 0
        ra1 = 5'd0;
        check_reg(32'h0, 32'h0, "Reg 0 remains 0 after write attempt");

        // --- Test 2: Standard Write and Read ---
        $display("--- Testing Basic Write/Read ---");
        wa3 = 5'd8; wd3 = 32'hDEADBEEF; we3 = 1; // Write to $t0 (8)
        @(posedge clk); #1; 
        we3 = 0; // Disable write
        ra1 = 5'd8; ra2 = 5'd0;
        check_reg(32'hDEADBEEF, 32'h0, "Write 0xDEADBEEF to Reg 8");

        // --- Test 3: Dual Port Read ---
        $display("--- Testing Dual Read ---");
        wa3 = 5'd9; wd3 = 32'hCAFEBABE; we3 = 1; // Write to $t1 (9)
        @(posedge clk); #1;
        we3 = 0;
        ra1 = 5'd8; ra2 = 5'd9;
        check_reg(32'hDEADBEEF, 32'hCAFEBABE, "Read Reg 8 and Reg 9 simultaneously");

        // --- Test 4: Write Enable Logic ---
        $display("--- Testing Write Enable ---");
        wa3 = 5'd8; wd3 = 32'h00000000; we3 = 0; // we3 is OFF
        @(posedge clk); #1;
        ra1 = 5'd8;
        check_reg(32'hDEADBEEF, 32'hCAFEBABE, "Reg 8 value preserved when we3=0");

        // --- Test 5: $0 read on both ports independently ---
        $display("--- Testing Reg 0 on ra2 ---");
        ra1 = 5'd8; ra2 = 5'd0;
        check_reg(32'hDEADBEEF, 32'h0, "ra2=$0 always reads 0");

        // --- Test 6: Boundary register $31 ---
        $display("--- Testing Reg 31 ---");
        wa3 = 5'd31; wd3 = 32'h12345678; we3 = 1;
        @(posedge clk); #1;
        we3 = 0;
        ra1 = 5'd31; ra2 = 5'd31;
        check_reg(32'h12345678, 32'h12345678, "Write/read Reg 31");

        // --- Test 7: Overwrite existing register ---
        $display("--- Testing Overwrite ---");
        wa3 = 5'd8; wd3 = 32'hAAAAAAAA; we3 = 1;
        @(posedge clk); #1;
        we3 = 0;
        ra1 = 5'd8;
        check_reg(32'hAAAAAAAA, 32'h12345678, "Reg 8 overwritten to 0xAAAAAAAA");

        // --- Test 8: Synchronous write / combinational read on same reg ---
        // Use reg 8 which already holds 0xAAAAAAAA — overwrite it and confirm
        // combinational read still sees old value before the posedge
        $display("--- Testing Sync Write vs Comb Read ---");
        wa3 = 5'd8; wd3 = 32'hBEEFCAFE; we3 = 1;
        ra1 = 5'd8; // read reg 8 before posedge — should still see 0xAAAAAAAA
        #1;
        check_reg(32'hAAAAAAAA, 32'h12345678, "Read reg 8 before write completes = old value");
        @(posedge clk); #1;
        we3 = 0;
        check_reg(32'hBEEFCAFE, 32'h12345678, "Read reg 8 after write = 0xBEEFCAFE");

        // --- Summary ---
        $display("\n=== RESULTS: %0d passed, %0d failed ===\n", pass_count, fail_count);

        if (fail_count == 0)
            $display("ALL REGFILE TESTS PASSED");
        else
            $display("SOME REGFILE TESTS FAILED");

        $finish;
    end

endmodule
`endif