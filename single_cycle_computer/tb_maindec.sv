//////////////////////////////////////////////////////////////////////////////////
// The Cooper Union
// ECE 251 Spring 2026
// Engineer: Jayden Chen
//
//      Module Name: tb_maindec
//      Description: Testbench for main decoder
//
// Tests:
//      All 6 defined opcodes — verify all 9 control signals
//      Undefined opcode     — verify all outputs are x
//////////////////////////////////////////////////////////////////////////////////
`ifndef TB_MAINDEC
`define TB_MAINDEC

`timescale 1ns/100ps

`include "maindec.sv"

module tb_maindec;

    logic [5:0] op;
    logic       memtoreg, memwrite;
    logic       branch, alusrc;
    logic       regdst, regwrite;
    logic       jump;
    logic [1:0] aluop;

    maindec dut (
        .op(op),
        .memtoreg(memtoreg), .memwrite(memwrite),
        .branch(branch),     .alusrc(alusrc),
        .regdst(regdst),     .regwrite(regwrite),
        .jump(jump),         .aluop(aluop)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    task check_ctrl;
        input       exp_regwrite, exp_regdst, exp_alusrc;
        input       exp_branch,   exp_memwrite, exp_memtoreg;
        input       exp_jump;
        input [1:0] exp_aluop;
        input string test_name;
        begin
            #1;
            if (regwrite  !== exp_regwrite  ||
                regdst    !== exp_regdst    ||
                alusrc    !== exp_alusrc    ||
                branch    !== exp_branch    ||
                memwrite  !== exp_memwrite  ||
                memtoreg  !== exp_memtoreg  ||
                jump      !== exp_jump      ||
                aluop     !== exp_aluop) begin
                $display("FAIL [%s]", test_name);
                $display("       got: regwrite=%b regdst=%b alusrc=%b branch=%b memwrite=%b memtoreg=%b jump=%b aluop=%b",
                          regwrite, regdst, alusrc, branch, memwrite, memtoreg, jump, aluop);
                $display("  expected: regwrite=%b regdst=%b alusrc=%b branch=%b memwrite=%b memtoreg=%b jump=%b aluop=%b",
                          exp_regwrite, exp_regdst, exp_alusrc, exp_branch,
                          exp_memwrite, exp_memtoreg, exp_jump, exp_aluop);
                fail_count++;
            end else begin
                $display("PASS [%s]", test_name);
                pass_count++;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_maindec.vcd");
        $dumpvars(0, tb_maindec);

        $display("\n=== MAIN DECODER TESTBENCH ===\n");

        $display("--- R-Type ---");
        op = 6'b000000;
        check_ctrl(1,1,0, 0,0,0, 0, 2'b10, "R-Type");

        $display("--- LW ---");
        op = 6'b100011;
        check_ctrl(1,0,1, 0,0,1, 0, 2'b00, "LW");

        $display("--- SW ---");
        op = 6'b101011;
        check_ctrl(0,0,1, 0,1,0, 0, 2'b00, "SW");

        $display("--- BEQ ---");
        op = 6'b000100;
        check_ctrl(0,0,0, 1,0,0, 0, 2'b01, "BEQ");

        $display("--- ADDI ---");
        op = 6'b001000;
        check_ctrl(1,0,1, 0,0,0, 0, 2'b00, "ADDI");

        $display("--- J ---");
        op = 6'b000010;
        check_ctrl(0,0,0, 0,0,0, 1, 2'b00, "J");

        $display("--- Undefined ---");
        op = 6'b111111;
        #1;
        if (regwrite === 1'bx && regdst === 1'bx && alusrc === 1'bx &&
            branch   === 1'bx && memwrite === 1'bx && memtoreg === 1'bx &&
            jump === 1'bx && aluop === 2'bxx) begin
            $display("PASS [Undefined opcode]: all outputs = x");
            pass_count++;
        end else begin
            $display("FAIL [Undefined opcode]: expected all x, got regwrite=%b regdst=%b alusrc=%b branch=%b memwrite=%b memtoreg=%b jump=%b aluop=%b",
                      regwrite, regdst, alusrc, branch, memwrite, memtoreg, jump, aluop);
            fail_count++;
        end

        $display("--- Mutual Exclusivity spot checks ---");
        op = 6'b101011; #1; // SW:   memwrite=1
        if (memwrite !== 1'b1) begin
            $display("FAIL [SW memwrite]: expected 1, got %b", memwrite);
            fail_count++;
        end else begin
            $display("PASS [SW memwrite=1 distinguishes SW from ADDI]");
            pass_count++;
        end

        op = 6'b100011; #1; // LW:   memtoreg=1
        if (memtoreg !== 1'b1) begin
            $display("FAIL [LW memtoreg]: expected 1, got %b", memtoreg);
            fail_count++;
        end else begin
            $display("PASS [LW memtoreg=1 distinguishes LW from ADDI]");
            pass_count++;
        end

        op = 6'b000010; #1; // J:    jump=1, regwrite=0
        if (jump !== 1'b1 || regwrite !== 1'b0) begin
            $display("FAIL [J jump/regwrite]: jump=%b regwrite=%b", jump, regwrite);
            fail_count++;
        end else begin
            $display("PASS [J jump=1 regwrite=0 distinguishes J from all others]");
            pass_count++;
        end

        $display("\n=== RESULTS: %0d passed, %0d failed ===\n", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL MAINDEC TESTS PASSED");
        else
            $display("SOME MAINDEC TESTS FAILED");

        $finish;
    end

endmodule

`endif // TB_MAINDEC