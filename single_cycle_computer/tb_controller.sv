//////////////////////////////////////////////////////////////////////////////////
// The Cooper Union
// ECE 251 Spring 2026
// Engineer: Jayden Chen
//
//      Module Name: tb_controller
//      Description: Testbench for 32-bit RISC CPU controller (MIPS)
//
// Tests:
//    R-type instructions (mapping through aluop and funct)
//    Memory ops (LW, SW)
//    Control flow (BEQ - zero flag dependency, J)
//    RegWrite inhibition for MULT/DIV
//////////////////////////////////////////////////////////////////////////////////
`ifndef TB_CONTROLLER
`define TB_CONTROLLER

`timescale 1ns/100ps

`include "controller.sv"

module tb_controller;

    // ---------------- PORT DEFINITIONS ----------------
    logic [5:0] op, funct;
    logic       zero;
    logic       memtoreg, memwrite, pcsrc, alusrc;
    logic       regdst, regwrite, jump;
    logic [3:0] alucontrol;

    // ---------------- UNIT UNDER TEST ----------------
    controller dut (
        .op(op), .funct(funct), .zero(zero),
        .memtoreg(memtoreg), .memwrite(memwrite),
        .pcsrc(pcsrc), .alusrc(alusrc),
        .regdst(regdst), .regwrite(regwrite),
        .jump(jump), .alucontrol(alucontrol)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    // Checks all 7 control signals + ALUControl
    task check_ctrl;
        input [6:0]   expected_sigs; // regwrite, regdst, alusrc, branch/pcsrc, memwrite, memtoreg, jump
        input [3:0]   expected_alu;
        input [511:0] test_name;
        
        logic [6:0] actual_sigs;
        begin
            #1;
            actual_sigs = {regwrite, regdst, alusrc, pcsrc, memwrite, memtoreg, jump};
            
            if (actual_sigs !== expected_sigs || alucontrol !== expected_alu) begin
                $display("FAIL [%s]: op=%b funct=%b zero=%b", test_name, op, funct, zero);
                $display("      Sigs(RW,RD,AS,PS,MW,M2R,J): got %b, expected %b", actual_sigs, expected_sigs);
                $display("      ALUControl: got %b, expected %b", alucontrol, expected_alu);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [%s]: Sigs=%b ALU=%b", test_name, actual_sigs, alucontrol);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_controller.vcd");
        $dumpvars(0, tb_controller);

        $display("\n=== CPU CONTROLLER TESTBENCH ===\n");

        // --- R-Type Instructions (Op=000000) ---
        $display("--- R-Type (Op=000000) ---");
        op = 6'b000000; zero = 0;
        
        funct = 6'b100000; check_ctrl(7'b1100000, 4'b0010, "R-Type: ADD");
        funct = 6'b100010; check_ctrl(7'b1100000, 4'b0110, "R-Type: SUB");
        
        // Test MULT/DIV RegWrite inhibition
        funct = 6'b011000; check_ctrl(7'b0100000, 4'b1000, "R-Type: MULT (RegWrite should be 0)");
        funct = 6'b011010; check_ctrl(7'b0100000, 4'b1001, "R-Type: DIV (RegWrite should be 0)");

        // --- Memory Instructions ---
        $display("--- Memory Instructions ---");
        funct = 6'bxxxxxx;
        
        op = 6'b100011; check_ctrl(7'b1010010, 4'b0010, "LW (Load Word)");
        op = 6'b101011; check_ctrl(7'b0010100, 4'b0010, "SW (Store Word)");

        // --- Branch and Jump ---
        $display("--- Control Flow ---");
        op = 6'b000100; // BEQ
        zero = 1; check_ctrl(7'b0001000, 4'b0110, "BEQ: Taken (zero=1)");
        zero = 0; check_ctrl(7'b0000000, 4'b0110, "BEQ: Not Taken (zero=0)");

        op = 6'b000010; // J
        check_ctrl(7'b0000001, 4'b0010, "J (Jump)");

        // --- Summary ---
        $display("\n=== RESULTS: %0d passed, %0d failed ===\n", pass_count, fail_count);

        if (fail_count == 0)
            $display("ALL CONTROLLER TESTS PASSED");
        else
            $display("SOME CONTROLLER TESTS FAILED");

        $finish;
    end

endmodule

`endif // TB_CONTROLLER