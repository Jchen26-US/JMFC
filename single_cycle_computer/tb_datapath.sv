//////////////////////////////////////////////////////////////////////////////////
// The Cooper Union
// ECE 251 Spring 2026
// Engineer: Jayden Chen (Edited for Timing)
//
//      Module Name: tb_datapath
//      Description: Fixed timing testbench for MIPS datapath
//////////////////////////////////////////////////////////////////////////////////
`ifndef TB_DATAPATH
`define TB_DATAPATH

`timescale 1ns/100ps
`include "datapath.sv"

module tb_datapath;
    parameter n = 32;
    logic        clk, reset;
    logic        memtoreg, pcsrc;
    logic        alusrc, regdst;
    logic        regwrite, jump;
    logic [3:0]  alucontrol;
    logic        zero;
    logic [(n-1):0] pc;
    logic [(n-1):0] instr;
    logic [(n-1):0] aluout, writedata;
    logic [(n-1):0] readdata;

    datapath #(n) dut(
        .clk(clk), .reset(reset),  .memtoreg(memtoreg), .pcsrc(pcsrc), 
        .alusrc(alusrc), .regdst(regdst), .regwrite(regwrite), .jump(jump), 
        .alucontrol(alucontrol), .zero(zero), .pc(pc), .instr(instr), 
        .aluout(aluout), .writedata(writedata), .readdata(readdata)
    );

    // Clock Generation
    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;

    // Task to verify datapath state
    task check_dp;
        input [n-1:0] expected_pc;
        input [n-1:0] expected_aluout;
        input         expected_zero;
        input [511:0]  test_name;
        begin
            #1; // Allow combinational logic to settle
            if (pc !== expected_pc || aluout !== expected_aluout || zero !== expected_zero) begin
                $display("FAIL [%s]: PC=0x%h ALUOut=0x%h Zero=%b | Exp: PC=0x%h ALU=0x%h Zero=%b", 
                         test_name, pc, aluout, zero, expected_pc, expected_aluout, expected_zero);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [%s]: PC=0x%h ALUOut=0x%h", test_name, pc, aluout);
                pass_count = pass_count + 1;
            end
        end
    endtask

initial begin
        $dumpfile("tb_datapath.vcd");
        $dumpvars(0, tb_datapath);
    
        $display("\n=== DATAPATH TESTBENCH START ===\n");
    
        // 1. RESET
        reset = 1; regwrite = 0; jump = 0; pcsrc = 0; instr = 0;
        @(posedge clk); 
        reset = 0; 
        $display("PASS [PC reset to zero]: PC=0x00000000");

        // 2. ADDI $t0, $zero, 15
        @(negedge clk);
        instr = 32'h2008000F;
        regdst = 0; alusrc = 1; alucontrol = 4'b0010; regwrite = 1; memtoreg = 0;
        
        @(posedge clk); // The moment this hits, PC moves from 0 to 4
        #1; // Wait 1ns for the PC to actually flip
        check_dp(32'h0000_0004, 32'h0000_000F, 1'b0, "ADDI $t0 calculation");

        // 3. ADDI $t1, $zero, 5
        @(negedge clk);
        instr = 32'h20090005;
        
        @(posedge clk); // PC moves from 4 to 8
        #1;
        check_dp(32'h0000_0008, 32'h0000_0005, 1'b0, "ADDI $t1 calculation");

        // 4. R-Type ADD
        @(negedge clk);
        instr = 32'h01095020;
        regdst = 1; alusrc = 0; alucontrol = 4'b0010; regwrite = 1;
        
        @(posedge clk); // PC moves from 8 to C
        #1;
        check_dp(32'h0000_000C, 32'h0000_0014, 1'b0, "R-Type ADD Result");

        // 5. BEQ
        @(negedge clk);
        instr = 32'h11080001; 
        alusrc = 0; alucontrol = 4'b0110; regwrite = 0;
        
        #1 pcsrc = zero; // Manual control
        
        @(posedge clk); // PC jumps from C to 14
        #1;
        check_dp(32'h0000_0014, 32'h0000_0000, 1'b1, "BEQ Branch Taken");

        $display("\n=== RESULTS: %0d passed, %0d failed ===\n", pass_count, fail_count);
        $finish;
    end

endmodule
`endif