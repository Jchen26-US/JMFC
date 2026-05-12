//////////////////////////////////////////////////////////////////////////////////
// The Cooper Union
// ECE 251 Spring 2026
// Engineer: Jayden Chen
//
//     Module Name: tb_cpu
//     Description: Testbench for 32-bit MIPS-like single-cycle CPU
//
// Strategy: drive `instr` directly as a register so we don't depend on
// imem or a program file. Supply `readdata` manually for LW tests.
//
// Tests (one instruction per clock cycle):
//   R-type : ADD, SUB, AND, OR, SLT
//   I-type : ADDI, LW, SW, BEQ (not taken), BEQ (taken)
//   J-type : J
//////////////////////////////////////////////////////////////////////////////////
`ifndef TB_CPU
`define TB_CPU

`timescale 1ns/100ps

`include "cpu.sv"
`include "clock.sv"

module tb_cpu;

    // -----------------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------------
    parameter n = 32;

    // Opcodes
    localparam OP_RTYPE = 6'b000000;
    localparam OP_LW    = 6'b100011;
    localparam OP_SW    = 6'b101011;
    localparam OP_BEQ   = 6'b000100;
    localparam OP_ADDI  = 6'b001000;
    localparam OP_J     = 6'b000010;

    // R-type funct codes
    localparam F_ADD = 6'b100000;
    localparam F_SUB = 6'b100010;
    localparam F_AND = 6'b100100;
    localparam F_OR  = 6'b100101;
    localparam F_SLT = 6'b101010;

    // Register indices (MIPS ABI names)
    localparam R_ZERO = 5'd0;
    localparam R_T0   = 5'd8;
    localparam R_T1   = 5'd9;
    localparam R_T2   = 5'd10;

    // -----------------------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------------------
    logic           clk, clk_enable, reset;
    logic [n-1:0]   instr;
    logic [n-1:0]   readdata;
    logic [n-1:0]   pc;
    logic           memwrite;
    logic [n-1:0]   aluout, writedata;

    // -----------------------------------------------------------------------
    // Helpers to build instruction words
    // -----------------------------------------------------------------------
    // R-type:  op[31:26] rs[25:21] rt[20:16] rd[15:11] shamt[10:6] funct[5:0]
    function automatic [31:0] rtype;
        input [4:0] rs, rt, rd;
        input [5:0] funct;
        rtype = {OP_RTYPE, rs, rt, rd, 5'b0, funct};
    endfunction

    // I-type:  op[31:26] rs[25:21] rt[20:16] imm[15:0]
    function automatic [31:0] itype;
        input [5:0]  op;
        input [4:0]  rs, rt;
        input [15:0] imm;
        itype = {op, rs, rt, imm};
    endfunction

    // J-type:  op[31:26] addr[25:0]
    function automatic [31:0] jtype;
        input [25:0] addr;
        jtype = {OP_J, addr};
    endfunction

    // -----------------------------------------------------------------------
    // Instantiate DUT and clock
    // -----------------------------------------------------------------------
    cpu #(n) dut (
        .clk       (clk),
        .reset     (reset),
        .pc        (pc),
        .instr     (instr),
        .memwrite  (memwrite),
        .aluout    (aluout),
        .writedata (writedata),
        .readdata  (readdata)
    );

    clock clk_gen (
        .ENABLE (clk_enable),
        .CLOCK  (clk)
    );

    // -----------------------------------------------------------------------
    // Tracking
    // -----------------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    task check;
        input [n-1:0]  got;
        input [n-1:0]  expected;
        input [1:0]    expect_memwrite; // 2=don't care, 1=assert, 0=deassert
        input [127:0]  test_name;
        begin
            if (got !== expected) begin
                $display("FAIL [%s]: aluout=0x%8h, expected=0x%8h",
                          test_name, got, expected);
                fail_count++;
            end else begin
                $display("PASS [%s]: aluout=0x%8h", test_name, got);
                pass_count++;
            end
            if (expect_memwrite !== 2) begin
                if (memwrite !== expect_memwrite[0]) begin
                    $display("FAIL [%s] MEMWRITE: got %b, expected %b",
                              test_name, memwrite, expect_memwrite[0]);
                    fail_count++;
                end else begin
                    $display("PASS [%s] MEMWRITE: %b", test_name, memwrite);
                    pass_count++;
                end
            end
        end
    endtask

    task check_pc;
        input [n-1:0]  expected_pc;
        input [127:0]  test_name;
        begin
            if (pc !== expected_pc) begin
                $display("FAIL [%s] PC: got 0x%8h, expected 0x%8h",
                          test_name, pc, expected_pc);
                fail_count++;
            end else begin
                $display("PASS [%s] PC: 0x%8h", test_name, pc);
                pass_count++;
            end
        end
    endtask

    // -----------------------------------------------------------------------
    // Main test sequence
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_cpu.vcd");
        $dumpvars(0, tb_cpu);

        // Hold reset high, clock disabled
        clk_enable = 0;
        reset      = 1;
        instr      = 32'b0;
        readdata   = 32'b0;

        // Enable clock while reset is still high — first posedge will
        // latch PC=0 because the async reset holds it there
        #50 clk_enable = 1;
        @(posedge clk); #1;
        check_pc(32'h0, "PC after reset = 0");

        // Release reset cleanly between edges
        @(negedge clk);
        reset = 0;

        $display("\n=== CPU TESTBENCH ===\n");

        // ===================================================================
        // Warmup cycle — registers are uninitialized, skip aluout check
        // ===================================================================
        $display("--- R-Type ---");
        instr = rtype(R_T0, R_T1, R_T2, F_ADD);
        @(posedge clk); #1;
        check_pc(32'h4, "PC after first cycle");

        // ===================================================================
        // ADDI $t0, $zero, 7  — loads 7 into $t0
        // ADDI $t1, $zero, 3  — loads 3 into $t1
        // ===================================================================
        $display("--- I-Type: ADDI (register load) ---");

        instr = itype(OP_ADDI, R_ZERO, R_T0, 16'd7);
        @(posedge clk); #1;
        check(aluout, 32'd7, 2, "ADDI $t0,$zero,7 => aluout=7");

        instr = itype(OP_ADDI, R_ZERO, R_T1, 16'd3);
        @(posedge clk); #1;
        check(aluout, 32'd3, 2, "ADDI $t1,$zero,3 => aluout=3");

        // ===================================================================
        // R-type: $t0=7, $t1=3
        // ===================================================================
        $display("--- R-Type (t0=7, t1=3) ---");

        instr = rtype(R_T0, R_T1, R_T2, F_ADD);
        @(posedge clk); #1;
        check(aluout, 32'd10, 2, "ADD $t2,$t0,$t1 => 10");

        instr = rtype(R_T0, R_T1, R_T2, F_SUB);
        @(posedge clk); #1;
        check(aluout, 32'd4, 2, "SUB $t2,$t0,$t1 => 4");

        instr = rtype(R_T0, R_T1, R_T2, F_AND);
        @(posedge clk); #1;
        check(aluout, 32'd3, 2, "AND $t2,$t0,$t1 => 3");

        instr = rtype(R_T0, R_T1, R_T2, F_OR);
        @(posedge clk); #1;
        check(aluout, 32'd7, 2, "OR  $t2,$t0,$t1 => 7");

        instr = rtype(R_T1, R_T0, R_T2, F_SLT); // rs=$t1=3, rt=$t0=7
        @(posedge clk); #1;
        check(aluout, 32'd1, 2, "SLT $t2,$t1,$t0 (3<7) => 1");

        // ===================================================================
        // SW $t0, 0($zero) — memwrite must assert, writedata must be 7
        // ===================================================================
        $display("--- I-Type: SW ---");
        instr = itype(OP_SW, R_ZERO, R_T0, 16'd0);
        @(posedge clk); #1;
        check(aluout, 32'd0, 1, "SW $t0,0($zero) => addr=0, memwrite=1");
        if (writedata !== 32'd7) begin
            $display("FAIL [SW writedata]: got %0d, expected 7", writedata);
            fail_count++;
        end else begin
            $display("PASS [SW writedata]: writedata=7");
            pass_count++;
        end

        // ===================================================================
        // LW $t2, 0($zero) — memwrite must deassert; aluout is the address
        // ===================================================================
        $display("--- I-Type: LW ---");
        readdata = 32'd42;
        instr = itype(OP_LW, R_ZERO, R_T2, 16'd0);
        @(posedge clk); #1;
        check(aluout, 32'd0, 0, "LW $t2,0($zero) => addr=0, memwrite=0");
        readdata = 32'b0;

        // ===================================================================
        // BEQ not taken — $t0=7, $t1=3, should not branch
        // ===================================================================
        $display("--- I-Type: BEQ ---");
        begin
            logic [31:0] pc_before;
            instr = itype(OP_BEQ, R_T0, R_T1, 16'd4);
            @(posedge clk); #1;
            pc_before = pc;
            @(posedge clk); #1;
            if (pc !== pc_before + 4) begin
                $display("FAIL [BEQ not taken] PC: got 0x%8h, expected 0x%8h",
                          pc, pc_before + 4);
                fail_count++;
            end else begin
                $display("PASS [BEQ not taken] PC: 0x%8h", pc);
                pass_count++;
            end
        end

        // ===================================================================
        // BEQ taken — $t0==$t0, PC = (pc_before+4) + (1<<2) = pc_before+8
        // ===================================================================
        begin
            logic [31:0] pc_before;
            @(posedge clk); #1;
            pc_before = pc;
            instr = itype(OP_BEQ, R_T0, R_T0, 16'd1);
            @(posedge clk); #1;
            if (pc !== pc_before + 8) begin
                $display("FAIL [BEQ taken] PC: got 0x%8h, expected 0x%8h",
                          pc, pc_before + 8);
                fail_count++;
            end else begin
                $display("PASS [BEQ taken] PC: 0x%8h", pc);
                pass_count++;
            end
        end

        // ===================================================================
        // J 5 — PC = {pcplus4[31:28], 26'd5, 2'b00} = 0x00000014
        // ===================================================================
        $display("--- J-Type ---");
        begin
            instr = jtype(26'd5);
            @(posedge clk); #1;
            if (pc !== 32'h14) begin
                $display("FAIL [J 5] PC: got 0x%8h, expected 0x00000014", pc);
                fail_count++;
            end else begin
                $display("PASS [J 5] PC: 0x%8h", pc);
                pass_count++;
            end
        end

        // ===================================================================
        // Summary
        // ===================================================================
        $display("\n=== RESULTS: %0d passed, %0d failed ===\n",
                  pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL CPU TESTS PASSED");
        else
            $display("SOME CPU TESTS FAILED — review output above");

        $finish;
    end

endmodule

`endif // TB_CPU