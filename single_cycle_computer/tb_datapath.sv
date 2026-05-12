//////////////////////////////////////////////////////////////////////////////////
// The Cooper Union
// ECE 251 Spring 2026
// Engineer: Jayden Chen
//
//     Module Name: tb_datapath
//     Description: Testbench for 32-bit MIPS-like datapath
//
// Strategy: drive control signals manually (no controller), feed instr
// directly, and track PC cycle-by-cycle.
//
// Tests:
//   Reset                  — PC=0
//   ADDI $t0, $zero, 7    — I-type, loads register before R-type tests
//   ADDI $t1, $zero, 3    — I-type
//   ADD  $t2, $t0, $t1    — R-type, aluout=10
//   SUB  $t2, $t0, $t1    — R-type, aluout=4
//   AND  $t2, $t0, $t1    — R-type, aluout=3
//   OR   $t2, $t0, $t1    — R-type, aluout=7
//   SLT  $t2, $t1, $t0    — R-type, aluout=1
//   LW   $t2, 0($zero)    — I-type, readdata→result
//   SW   $t0, 4($zero)    — I-type, writedata=7, aluout=4
//   BEQ  not taken        — pcsrc=0, PC+=4
//   BEQ  taken            — pcsrc=1, PC jumps
//   J                     — jump=1, PC={pc+4[31:28],addr,2'b00}
//////////////////////////////////////////////////////////////////////////////////
`ifndef TB_DATAPATH
`define TB_DATAPATH

`timescale 1ns/100ps

`include "datapath.sv"

module tb_datapath;
    parameter n = 32;

    // -----------------------------------------------------------------------
    // Opcodes / funct (for building instr words inline)
    // -----------------------------------------------------------------------
    localparam OP_RTYPE = 6'b000000;
    localparam OP_ADDI  = 6'b001000;
    localparam OP_LW    = 6'b100011;
    localparam OP_SW    = 6'b101011;
    localparam OP_BEQ   = 6'b000100;
    localparam OP_J     = 6'b000010;

    localparam F_ADD = 6'b100000;
    localparam F_SUB = 6'b100010;
    localparam F_AND = 6'b100100;
    localparam F_OR  = 6'b100101;
    localparam F_SLT = 6'b101010;

    localparam R_ZERO = 5'd0;
    localparam R_T0   = 5'd8;
    localparam R_T1   = 5'd9;
    localparam R_T2   = 5'd10;

    // -----------------------------------------------------------------------
    // Instruction helpers
    // -----------------------------------------------------------------------
    function automatic [31:0] rtype;
        input [4:0] rs, rt, rd; input [5:0] funct;
        rtype = {OP_RTYPE, rs, rt, rd, 5'b0, funct};
    endfunction

    function automatic [31:0] itype;
        input [5:0] op; input [4:0] rs, rt; input [15:0] imm;
        itype = {op, rs, rt, imm};
    endfunction

    function automatic [31:0] jtype;
        input [25:0] addr;
        jtype = {OP_J, addr};
    endfunction

    // -----------------------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------------------
    logic           clk, reset;
    logic           memtoreg, pcsrc;
    logic           alusrc, regdst;
    logic           regwrite, jump;
    logic [3:0]     alucontrol;
    logic           zero;
    logic [n-1:0]   pc, instr, aluout, writedata, readdata;

    // -----------------------------------------------------------------------
    // DUT
    // -----------------------------------------------------------------------
    datapath #(n) dut (
        .clk(clk), .reset(reset),
        .memtoreg(memtoreg), .pcsrc(pcsrc),
        .alusrc(alusrc), .regdst(regdst),
        .regwrite(regwrite), .jump(jump),
        .alucontrol(alucontrol),
        .zero(zero), .pc(pc),
        .instr(instr), .aluout(aluout),
        .writedata(writedata), .readdata(readdata)
    );

    // -----------------------------------------------------------------------
    // Clock
    // -----------------------------------------------------------------------
    initial clk = 0;
    always  #5 clk = ~clk;

    // -----------------------------------------------------------------------
    // Tracking
    // -----------------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    // Check aluout and zero flag
    task check_alu;
        input [n-1:0]  exp_aluout;
        input          exp_zero;
        input [1:0]    check_zero; // 2=don't care
        input [511:0]  test_name;
        begin
            #1;
            if (aluout !== exp_aluout) begin
                $display("FAIL [%s] ALUOUT: got 0x%h, expected 0x%h",
                          test_name, aluout, exp_aluout);
                fail_count++;
            end else begin
                $display("PASS [%s] ALUOUT: 0x%h", test_name, aluout);
                pass_count++;
            end
            if (check_zero != 2) begin
                if (zero !== exp_zero) begin
                    $display("FAIL [%s] ZERO: got %b, expected %b",
                              test_name, zero, exp_zero);
                    fail_count++;
                end else begin
                    $display("PASS [%s] ZERO: %b", test_name, zero);
                    pass_count++;
                end
            end
        end
    endtask

    // Check PC value
    task check_pc;
        input [n-1:0]  exp_pc;
        input [511:0]  test_name;
        begin
            if (pc !== exp_pc) begin
                $display("FAIL [%s] PC: got 0x%h, expected 0x%h",
                          test_name, pc, exp_pc);
                fail_count++;
            end else begin
                $display("PASS [%s] PC: 0x%h", test_name, pc);
                pass_count++;
            end
        end
    endtask

    // -----------------------------------------------------------------------
    // Control signal helpers — set all signals for a given instruction type
    // -----------------------------------------------------------------------
    task set_rtype;
        input [3:0] aluctl;
        begin
            regdst = 1; alusrc = 0; memtoreg = 0;
            regwrite = 1; pcsrc = 0; jump = 0;
            alucontrol = aluctl;
        end
    endtask

    task set_itype_alu; // ADDI
        input [3:0] aluctl;
        begin
            regdst = 0; alusrc = 1; memtoreg = 0;
            regwrite = 1; pcsrc = 0; jump = 0;
            alucontrol = aluctl;
        end
    endtask

    task set_lw;
        begin
            regdst = 0; alusrc = 1; memtoreg = 1;
            regwrite = 1; pcsrc = 0; jump = 0;
            alucontrol = 4'b0010; // ADD for address
        end
    endtask

    task set_sw;
        begin
            regdst = 0; alusrc = 1; memtoreg = 0;
            regwrite = 0; pcsrc = 0; jump = 0;
            alucontrol = 4'b0010;
        end
    endtask

    task set_beq;
        begin
            regdst = 0; alusrc = 0; memtoreg = 0;
            regwrite = 0; jump = 0;
            alucontrol = 4'b0110; // SUB
        end
    endtask

    // -----------------------------------------------------------------------
    // Main sequence
    // PC tracks exactly: each instruction increments PC by 4 on posedge clk.
    // We check PC *after* the posedge that clocks it in.
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_datapath.vcd");
        $dumpvars(0, tb_datapath);

        $display("\n=== DATAPATH TESTBENCH ===\n");

        // Init all controls
        reset = 1; regwrite = 0; jump = 0; pcsrc = 0;
        alusrc = 0; regdst = 0; memtoreg = 0;
        alucontrol = 4'b0010;
        instr = 32'b0; readdata = 32'b0;

        // ===================================================================
        // Reset: PC should be 0
        // ===================================================================
        $display("--- Reset ---");
        @(posedge clk); #1;
        check_pc(32'h0, "PC after reset");
        @(negedge clk); reset = 0;

        // ===================================================================
        // ADDI $t0, $zero, 7   (PC=0x0 → 0x4)
        // ===================================================================
        $display("--- ADDI $t0, $zero, 7 ---");
        instr = itype(OP_ADDI, R_ZERO, R_T0, 16'd7);
        set_itype_alu(4'b0010);
        @(posedge clk); #1;
        check_pc(32'h4, "PC after ADDI t0");
        check_alu(32'd7, 1'b0, 0, "ADDI t0=7");

        // ===================================================================
        // ADDI $t1, $zero, 3   (PC=0x4 → 0x8)
        // ===================================================================
        $display("--- ADDI $t1, $zero, 3 ---");
        instr = itype(OP_ADDI, R_ZERO, R_T1, 16'd3);
        set_itype_alu(4'b0010);
        @(posedge clk); #1;
        check_pc(32'h8, "PC after ADDI t1");
        check_alu(32'd3, 1'b0, 0, "ADDI t1=3");

        // ===================================================================
        // ADD $t2, $t0, $t1   (PC=0x8 → 0xC)   aluout=10
        // ===================================================================
        $display("--- ADD $t2, $t0, $t1 ---");
        instr = rtype(R_T0, R_T1, R_T2, F_ADD);
        set_rtype(4'b0010);
        @(posedge clk); #1;
        check_pc(32'hC, "PC after ADD");
        check_alu(32'd10, 1'b0, 0, "ADD t0+t1=10");

        // ===================================================================
        // SUB $t2, $t0, $t1   (PC=0xC → 0x10)  aluout=4
        // ===================================================================
        $display("--- SUB $t2, $t0, $t1 ---");
        instr = rtype(R_T0, R_T1, R_T2, F_SUB);
        set_rtype(4'b0110);
        @(posedge clk); #1;
        check_pc(32'h10, "PC after SUB");
        check_alu(32'd4, 1'b0, 0, "SUB t0-t1=4");

        // ===================================================================
        // AND $t2, $t0, $t1   (PC=0x10 → 0x14) aluout=3 (7&3)
        // ===================================================================
        $display("--- AND $t2, $t0, $t1 ---");
        instr = rtype(R_T0, R_T1, R_T2, F_AND);
        set_rtype(4'b0000);
        @(posedge clk); #1;
        check_pc(32'h14, "PC after AND");
        check_alu(32'd3, 1'b0, 0, "AND 7&3=3");

        // ===================================================================
        // OR $t2, $t0, $t1    (PC=0x14 → 0x18) aluout=7 (7|3)
        // ===================================================================
        $display("--- OR $t2, $t0, $t1 ---");
        instr = rtype(R_T0, R_T1, R_T2, F_OR);
        set_rtype(4'b0001);
        @(posedge clk); #1;
        check_pc(32'h18, "PC after OR");
        check_alu(32'd7, 1'b0, 0, "OR 7|3=7");

        // ===================================================================
        // SLT $t2, $t1, $t0   (PC=0x18 → 0x1C) aluout=1 (3<7)
        // ===================================================================
        $display("--- SLT $t2, $t1, $t0 ---");
        instr = rtype(R_T1, R_T0, R_T2, F_SLT);
        set_rtype(4'b0111);
        @(posedge clk); #1;
        check_pc(32'h1C, "PC after SLT");
        check_alu(32'd1, 1'b0, 0, "SLT 3<7=1");

        // ===================================================================
        // SW $t0, 4($zero)    (PC=0x1C → 0x20)
        // aluout = $zero + 4 = 4, writedata = $t0 = 7
        // ===================================================================
        $display("--- SW $t0, 4($zero) ---");
        instr = itype(OP_SW, R_ZERO, R_T0, 16'd4);
        set_sw;
        @(posedge clk); #1;
        check_pc(32'h20, "PC after SW");
        check_alu(32'd4, 1'b0, 2, "SW addr=4");
        if (writedata !== 32'd7) begin
            $display("FAIL [SW writedata]: got %0d, expected 7", writedata);
            fail_count++;
        end else begin
            $display("PASS [SW writedata]: writedata=7");
            pass_count++;
        end

        // ===================================================================
        // LW $t2, 4($zero)    (PC=0x20 → 0x24)
        // aluout = $zero + 4 = 4 (address), readdata fed as 42
        // ===================================================================
        $display("--- LW $t2, 4($zero) ---");
        readdata = 32'd42;
        instr = itype(OP_LW, R_ZERO, R_T2, 16'd4);
        set_lw;
        @(posedge clk); #1;
        check_pc(32'h24, "PC after LW");
        check_alu(32'd4, 1'b0, 2, "LW addr=4");
        readdata = 32'b0;

        // ===================================================================
        // BEQ $t0, $t1, +1  — NOT taken ($t0=7 != $t1=3)
        // (PC=0x24 → 0x28)
        // ===================================================================
        $display("--- BEQ not taken ($t0 != $t1) ---");
        instr = itype(OP_BEQ, R_T0, R_T1, 16'd1);
        set_beq;
        pcsrc = 0; // not taken
        @(posedge clk); #1;
        check_pc(32'h28, "PC after BEQ not taken");
        check_alu(32'd4, 1'b0, 0, "BEQ sub: 7-3=4, zero=0");

        // ===================================================================
        // BEQ $t0, $t0, +2  — TAKEN ($t0 == $t0)
        // PC=0x28, pcplus4=0x2C, branch offset = 2<<2 = 8
        // target = 0x2C + 8 = 0x34
        // ===================================================================
        $display("--- BEQ taken ($t0 == $t0) ---");
        instr = itype(OP_BEQ, R_T0, R_T0, 16'd2);
        set_beq;
        // zero will assert combinationally — use it to drive pcsrc
        #1; pcsrc = zero; // zero=1 since t0-t0=0
        @(posedge clk); #1;
        check_pc(32'h34, "PC after BEQ taken (0x2C + 8 = 0x34)");
        check_alu(32'h0, 1'b1, 1, "BEQ sub: t0-t0=0, zero=1");
        pcsrc = 0;

        // ===================================================================
        // J to address 5   — PC = {pcplus4[31:28], 26'd5, 2'b00}
        // pcplus4 = 0x34+4 = 0x38, so target = {4'b0, 5, 2'b00} = 0x14
        // ===================================================================
        $display("--- J 5 ---");
        instr = jtype(26'd5);
        regwrite = 0; pcsrc = 0; jump = 1;
        alucontrol = 4'b0010;
        @(posedge clk); #1;
        check_pc(32'h14, "PC after J 5 => 0x14");

        // ===================================================================
        // Summary
        // ===================================================================
        $display("\n=== RESULTS: %0d passed, %0d failed ===\n",
                  pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL DATAPATH TESTS PASSED");
        else
            $display("SOME DATAPATH TESTS FAILED — review output above");

        $finish;
    end

endmodule

`endif // TB_DATAPATH