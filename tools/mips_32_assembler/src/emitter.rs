use std::collections::HashMap;
use crate::parser::{AstNode, DirectiveArg, Operand, ParsedInstruction, Section};
use crate::error::AssemblerError;

const TEXT_BASE: u32 = 0x0040_0000;
const DATA_BASE: u32 = 0x1001_0000;

pub struct Emitter {
    text: Vec<u32>,
    data: Vec<u8>,
    symbols: HashMap<String, u32>,
}

impl Emitter {
    pub fn new() -> Self {
        Emitter {
            text: Vec::new(),
            data: Vec::new(),
            symbols: HashMap::new(),
        }
    }

    pub fn assemble(&mut self, nodes: &[AstNode]) -> Result<(), AssemblerError> {
        self.first_pass(nodes);
        self.second_pass(nodes)
    }

    fn first_pass(&mut self, nodes: &[AstNode]) {
        let mut text_words: u32 = 0;
        let mut data_bytes: u32 = 0;
        let mut section = Section::Text;

        for node in nodes {
            match node {
                AstNode::SectionSwitch(s) => section = s.clone(),

                AstNode::Label(name) => {
                    let addr = match section {
                        Section::Text => TEXT_BASE + text_words * 4,
                        Section::Data => DATA_BASE + data_bytes,
                    };
                    self.symbols.insert(name.clone(), addr);
                }

                AstNode::Instruction(instr) => {
                    if section == Section::Text {
                        text_words += pseudo_word_count(instr);
                    }
                }

                AstNode::Directive { name, args } => {
                    if section == Section::Data {
                        data_bytes += directive_byte_count(name, args);
                    }
                }
            }
        }
    }

    fn second_pass(&mut self, nodes: &[AstNode]) -> Result<(), AssemblerError> {
        let mut section = Section::Text;
        let mut text_word_idx: u32 = 0;

        for node in nodes {
            match node {
                AstNode::SectionSwitch(s) => section = s.clone(),
                AstNode::Label(_) => {}

                AstNode::Instruction(instr) => {
                    if section == Section::Text {
                        let pc = TEXT_BASE + text_word_idx * 4;
                        let words = self.encode_instruction(instr, pc)?;
                        text_word_idx += words.len() as u32;
                        self.text.extend(words);
                    }
                }

                AstNode::Directive { name, args } => {
                    if section == Section::Data {
                        self.emit_directive(name, args)?;
                    }
                }
            }
        }
        Ok(())
    }

    fn encode_instruction(
        &self,
        instr: &ParsedInstruction,
        pc: u32,
    ) -> Result<Vec<u32>, AssemblerError> {
        let ops = &instr.operands;
        let line = instr.line;

        match instr.mnemonic.as_str() {
            "nop" => Ok(vec![0x0000_0000]),

            "move" => {
                let rd = reg(ops, 0, line)?;
                let rs = reg(ops, 1, line)?;
                Ok(vec![r_type(0, rs, 0, rd, 0, 0x21)])
            }

            "li" => {
                let rt = reg(ops, 0, line)?;
                let imm = imm(ops, 1, line)?;
                if imm >= -32768 && imm <= 32767 {
                    Ok(vec![i_type(0x09, 0, rt, imm as u16)])
                } else if imm >= 0 && imm <= 65535 {
                    Ok(vec![i_type(0x0d, 0, rt, imm as u16)])
                } else {
                    let upper = (imm as u32 >> 16) as u16;
                    let lower = (imm as u32 & 0xffff) as u16;
                    Ok(vec![i_type(0x0f, 0, rt, upper), i_type(0x0d, rt, rt, lower)])
                }
            }

            "la" => {
                let rt = reg(ops, 0, line)?;
                let addr = self.resolve_addr(ops, 1, line)?;
                let upper = (addr >> 16) as u16;
                let lower = (addr & 0xffff) as u16;
                Ok(vec![i_type(0x0f, 0, rt, upper), i_type(0x0d, rt, rt, lower)])
            }

            "not" => {
                let rd = reg(ops, 0, line)?;
                let rs = reg(ops, 1, line)?;
                Ok(vec![r_type(0, rs, 0, rd, 0, 0x27)])
            }

            "neg" => {
                let rd = reg(ops, 0, line)?;
                let rs = reg(ops, 1, line)?;
                Ok(vec![r_type(0, 0, rs, rd, 0, 0x22)])
            }

            "beqz" => {
                let rs = reg(ops, 0, line)?;
                let off = self.branch_offset(ops, 1, pc, line)?;
                Ok(vec![i_type(0x04, rs, 0, off as u16)])
            }

            "bnez" => {
                let rs = reg(ops, 0, line)?;
                let off = self.branch_offset(ops, 1, pc, line)?;
                Ok(vec![i_type(0x05, rs, 0, off as u16)])
            }

            "add" => {
                let (rd, rs, rt) = rd_rs_rt(ops, line)?;
                Ok(vec![r_type(0, rs, rt, rd, 0, 0x20)])
            }

            "addu" => {
                let (rd, rs, rt) = rd_rs_rt(ops, line)?;
                Ok(vec![r_type(0, rs, rt, rd, 0, 0x21)])
            }

            "sub" => {
                let (rd, rs, rt) = rd_rs_rt(ops, line)?;
                Ok(vec![r_type(0, rs, rt, rd, 0, 0x22)])
            }

            "subu" => {
                let (rd, rs, rt) = rd_rs_rt(ops, line)?;
                Ok(vec![r_type(0, rs, rt, rd, 0, 0x23)])
            }

            "and" => {
                let (rd, rs, rt) = rd_rs_rt(ops, line)?;
                Ok(vec![r_type(0, rs, rt, rd, 0, 0x24)])
            }

            "or" => {
                let (rd, rs, rt) = rd_rs_rt(ops, line)?;
                Ok(vec![r_type(0, rs, rt, rd, 0, 0x25)])
            }

            "xor" => {
                let (rd, rs, rt) = rd_rs_rt(ops, line)?;
                Ok(vec![r_type(0, rs, rt, rd, 0, 0x26)])
            }

            "nor" => {
                let (rd, rs, rt) = rd_rs_rt(ops, line)?;
                Ok(vec![r_type(0, rs, rt, rd, 0, 0x27)])
            }

            "slt" => {
                let (rd, rs, rt) = rd_rs_rt(ops, line)?;
                Ok(vec![r_type(0, rs, rt, rd, 0, 0x2a)])
            }

            "sltu" => {
                let (rd, rs, rt) = rd_rs_rt(ops, line)?;
                Ok(vec![r_type(0, rs, rt, rd, 0, 0x2b)])
            }

            "sll" => {
                let rd = reg(ops, 0, line)?;
                let rt = reg(ops, 1, line)?;
                let sa = imm(ops, 2, line)? as u8 & 0x1f;
                Ok(vec![r_type(0, 0, rt, rd, sa, 0x00)])
            }

            "srl" => {
                let rd = reg(ops, 0, line)?;
                let rt = reg(ops, 1, line)?;
                let sa = imm(ops, 2, line)? as u8 & 0x1f;
                Ok(vec![r_type(0, 0, rt, rd, sa, 0x02)])
            }

            "sra" => {
                let rd = reg(ops, 0, line)?;
                let rt = reg(ops, 1, line)?;
                let sa = imm(ops, 2, line)? as u8 & 0x1f;
                Ok(vec![r_type(0, 0, rt, rd, sa, 0x03)])
            }

            "sllv" => {
                let rd = reg(ops, 0, line)?;
                let rt = reg(ops, 1, line)?;
                let rs = reg(ops, 2, line)?;
                Ok(vec![r_type(0, rs, rt, rd, 0, 0x04)])
            }

            "srlv" => {
                let rd = reg(ops, 0, line)?;
                let rt = reg(ops, 1, line)?;
                let rs = reg(ops, 2, line)?;
                Ok(vec![r_type(0, rs, rt, rd, 0, 0x06)])
            }

            "srav" => {
                let rd = reg(ops, 0, line)?;
                let rt = reg(ops, 1, line)?;
                let rs = reg(ops, 2, line)?;
                Ok(vec![r_type(0, rs, rt, rd, 0, 0x07)])
            }

            "jr" => {
                let rs = reg(ops, 0, line)?;
                Ok(vec![r_type(0, rs, 0, 0, 0, 0x08)])
            }

            "jalr" => {
                if ops.len() == 1 {
                    let rs = reg(ops, 0, line)?;
                    Ok(vec![r_type(0, rs, 0, 31, 0, 0x09)])
                } else {
                    let rd = reg(ops, 0, line)?;
                    let rs = reg(ops, 1, line)?;
                    Ok(vec![r_type(0, rs, 0, rd, 0, 0x09)])
                }
            }

            "syscall" => Ok(vec![r_type(0, 0, 0, 0, 0, 0x0c)]),
            "break" => Ok(vec![r_type(0, 0, 0, 0, 0, 0x0d)]),

            "mult" => {
                let rs = reg(ops, 0, line)?;
                let rt = reg(ops, 1, line)?;
                Ok(vec![r_type(0, rs, rt, 0, 0, 0x18)])
            }

            "multu" => {
                let rs = reg(ops, 0, line)?;
                let rt = reg(ops, 1, line)?;
                Ok(vec![r_type(0, rs, rt, 0, 0, 0x19)])
            }

            "div" => {
                let rs = reg(ops, 0, line)?;
                let rt = reg(ops, 1, line)?;
                Ok(vec![r_type(0, rs, rt, 0, 0, 0x1a)])
            }

            "divu" => {
                let rs = reg(ops, 0, line)?;
                let rt = reg(ops, 1, line)?;
                Ok(vec![r_type(0, rs, rt, 0, 0, 0x1b)])
            }

            "mfhi" => {
                let rd = reg(ops, 0, line)?;
                Ok(vec![r_type(0, 0, 0, rd, 0, 0x10)])
            }

            "mflo" => {
                let rd = reg(ops, 0, line)?;
                Ok(vec![r_type(0, 0, 0, rd, 0, 0x12)])
            }

            "mthi" => {
                let rs = reg(ops, 0, line)?;
                Ok(vec![r_type(0, rs, 0, 0, 0, 0x11)])
            }

            "mtlo" => {
                let rs = reg(ops, 0, line)?;
                Ok(vec![r_type(0, rs, 0, 0, 0, 0x13)])
            }

            "addi" => {
                let rt = reg(ops, 0, line)?;
                let rs = reg(ops, 1, line)?;
                Ok(vec![i_type(0x08, rs, rt, imm(ops, 2, line)? as u16)])
            }

            "addiu" => {
                let rt = reg(ops, 0, line)?;
                let rs = reg(ops, 1, line)?;
                Ok(vec![i_type(0x09, rs, rt, imm(ops, 2, line)? as u16)])
            }

            "slti" => {
                let rt = reg(ops, 0, line)?;
                let rs = reg(ops, 1, line)?;
                Ok(vec![i_type(0x0a, rs, rt, imm(ops, 2, line)? as u16)])
            }

            "sltiu" => {
                let rt = reg(ops, 0, line)?;
                let rs = reg(ops, 1, line)?;
                Ok(vec![i_type(0x0b, rs, rt, imm(ops, 2, line)? as u16)])
            }

            "andi" => {
                let rt = reg(ops, 0, line)?;
                let rs = reg(ops, 1, line)?;
                Ok(vec![i_type(0x0c, rs, rt, imm(ops, 2, line)? as u16)])
            }

            "ori" => {
                let rt = reg(ops, 0, line)?;
                let rs = reg(ops, 1, line)?;
                Ok(vec![i_type(0x0d, rs, rt, imm(ops, 2, line)? as u16)])
            }

            "xori" => {
                let rt = reg(ops, 0, line)?;
                let rs = reg(ops, 1, line)?;
                Ok(vec![i_type(0x0e, rs, rt, imm(ops, 2, line)? as u16)])
            }

            "lui" => {
                let rt = reg(ops, 0, line)?;
                Ok(vec![i_type(0x0f, 0, rt, imm(ops, 1, line)? as u16)])
            }

            "lw"  => Ok(vec![mem_op(0x23, ops, line)?]),
            "lh"  => Ok(vec![mem_op(0x21, ops, line)?]),
            "lhu" => Ok(vec![mem_op(0x25, ops, line)?]),
            "lb"  => Ok(vec![mem_op(0x20, ops, line)?]),
            "lbu" => Ok(vec![mem_op(0x24, ops, line)?]),
            "sw"  => Ok(vec![mem_op(0x2b, ops, line)?]),
            "sh"  => Ok(vec![mem_op(0x29, ops, line)?]),
            "sb"  => Ok(vec![mem_op(0x28, ops, line)?]),

            "beq" => {
                let rs = reg(ops, 0, line)?;
                let rt = reg(ops, 1, line)?;
                let off = self.branch_offset(ops, 2, pc, line)?;
                Ok(vec![i_type(0x04, rs, rt, off as u16)])
            }

            "bne" => {
                let rs = reg(ops, 0, line)?;
                let rt = reg(ops, 1, line)?;
                let off = self.branch_offset(ops, 2, pc, line)?;
                Ok(vec![i_type(0x05, rs, rt, off as u16)])
            }

            "bgez" => {
                let rs = reg(ops, 0, line)?;
                let off = self.branch_offset(ops, 1, pc, line)?;
                Ok(vec![i_type(0x01, rs, 0x01, off as u16)])
            }

            "bltz" => {
                let rs = reg(ops, 0, line)?;
                let off = self.branch_offset(ops, 1, pc, line)?;
                Ok(vec![i_type(0x01, rs, 0x00, off as u16)])
            }

            "bgtz" => {
                let rs = reg(ops, 0, line)?;
                let off = self.branch_offset(ops, 1, pc, line)?;
                Ok(vec![i_type(0x07, rs, 0, off as u16)])
            }

            "blez" => {
                let rs = reg(ops, 0, line)?;
                let off = self.branch_offset(ops, 1, pc, line)?;
                Ok(vec![i_type(0x06, rs, 0, off as u16)])
            }

            "bgezal" => {
                let rs = reg(ops, 0, line)?;
                let off = self.branch_offset(ops, 1, pc, line)?;
                Ok(vec![i_type(0x01, rs, 0x11, off as u16)])
            }

            "bltzal" => {
                let rs = reg(ops, 0, line)?;
                let off = self.branch_offset(ops, 1, pc, line)?;
                Ok(vec![i_type(0x01, rs, 0x10, off as u16)])
            }

            "j" => {
                let target = self.jump_target(ops, 0, line)?;
                Ok(vec![j_type(0x02, target)])
            }

            "jal" => {
                let target = self.jump_target(ops, 0, line)?;
                Ok(vec![j_type(0x03, target)])
            }

            other => Err(AssemblerError::UnknownInstruction(other.to_string(), line)),
        }
    }

    fn branch_offset(
        &self,
        ops: &[Operand],
        idx: usize,
        pc: u32,
        line: usize,
    ) -> Result<i16, AssemblerError> {
        match ops.get(idx) {
            Some(Operand::Immediate(v)) => Ok(*v as i16),
            Some(Operand::LabelRef(name)) => {
                let target = self
                    .symbols
                    .get(name)
                    .copied()
                    .ok_or_else(|| AssemblerError::UnknownLabel(name.clone(), line))?;
                let offset = ((target as i64) - (pc as i64 + 4)) / 4;
                if !(-32768..=32767).contains(&offset) {
                    return Err(AssemblerError::ImmediateOutOfRange(offset, line));
                }
                Ok(offset as i16)
            }
            _ => Err(AssemblerError::InvalidOperands(instr_name_at(ops), line)),
        }
    }

    fn jump_target(&self, ops: &[Operand], idx: usize, line: usize) -> Result<u32, AssemblerError> {
        let addr = self.resolve_addr(ops, idx, line)?;
        Ok((addr >> 2) & 0x03FF_FFFF)
    }

    fn resolve_addr(&self, ops: &[Operand], idx: usize, line: usize) -> Result<u32, AssemblerError> {
        match ops.get(idx) {
            Some(Operand::LabelRef(name)) => self
                .symbols
                .get(name)
                .copied()
                .ok_or_else(|| AssemblerError::UnknownLabel(name.clone(), line)),
            Some(Operand::Immediate(v)) => Ok(*v as u32),
            _ => Err(AssemblerError::InvalidOperands(String::new(), line)),
        }
    }

    fn emit_directive(
        &mut self,
        name: &str,
        args: &[DirectiveArg],
    ) -> Result<(), AssemblerError> {
        match name {
            "asciiz" | "ascii" => {
                if let Some(DirectiveArg::Str(s)) = args.first() {
                    self.data.extend_from_slice(s.as_bytes());
                    if name == "asciiz" {
                        self.data.push(0);
                    }
                }
            }
            "word" => {
                for arg in args {
                    let val: u32 = match arg {
                        DirectiveArg::Int(v) => *v as u32,
                        DirectiveArg::Ident(label) => {
                            self.symbols.get(label).copied().unwrap_or(0)
                        }
                        _ => 0,
                    };
                    self.data.extend_from_slice(&val.to_be_bytes());
                }
            }
            "half" => {
                for arg in args {
                    if let DirectiveArg::Int(v) = arg {
                        self.data.extend_from_slice(&(*v as u16).to_be_bytes());
                    }
                }
            }
            "byte" => {
                for arg in args {
                    if let DirectiveArg::Int(v) = arg {
                        self.data.push(*v as u8);
                    }
                }
            }
            "space" => {
                if let Some(DirectiveArg::Int(n)) = args.first() {
                    for _ in 0..*n {
                        self.data.push(0);
                    }
                }
            }
            "align" => {
                if let Some(DirectiveArg::Int(n)) = args.first() {
                    let align = 1u32 << n;
                    let len = self.data.len() as u32;
                    let rem = len % align;
                    if rem != 0 {
                        for _ in 0..(align - rem) {
                            self.data.push(0);
                        }
                    }
                }
            }
            _ => {}
        }
        Ok(())
    }

    pub fn text_segment(&self) -> &[u32] {
        &self.text
    }

    pub fn data_segment(&self) -> &[u8] {
        &self.data
    }

    pub fn symbols(&self) -> &HashMap<String, u32> {
        &self.symbols
    }
}

fn r_type(opcode: u8, rs: u8, rt: u8, rd: u8, shamt: u8, funct: u8) -> u32 {
    ((opcode as u32) << 26)
        | ((rs as u32) << 21)
        | ((rt as u32) << 16)
        | ((rd as u32) << 11)
        | ((shamt as u32) << 6)
        | (funct as u32)
}

fn i_type(opcode: u8, rs: u8, rt: u8, imm: u16) -> u32 {
    ((opcode as u32) << 26)
        | ((rs as u32) << 21)
        | ((rt as u32) << 16)
        | (imm as u32)
}

fn j_type(opcode: u8, target: u32) -> u32 {
    ((opcode as u32) << 26) | (target & 0x03FF_FFFF)
}

fn mem_op(opcode: u8, ops: &[Operand], line: usize) -> Result<u32, AssemblerError> {
    let rt = reg(ops, 0, line)?;
    match ops.get(1) {
        Some(Operand::MemOffset { offset, base }) => {
            Ok(i_type(opcode, *base, rt, *offset as i16 as u16))
        }
        _ => Err(AssemblerError::InvalidOperands(String::new(), line)),
    }
}

fn reg(ops: &[Operand], idx: usize, line: usize) -> Result<u8, AssemblerError> {
    match ops.get(idx) {
        Some(Operand::Register(r)) => Ok(*r),
        _ => Err(AssemblerError::InvalidOperands(String::new(), line)),
    }
}

fn imm(ops: &[Operand], idx: usize, line: usize) -> Result<i64, AssemblerError> {
    match ops.get(idx) {
        Some(Operand::Immediate(v)) => Ok(*v as i64),
        _ => Err(AssemblerError::InvalidOperands(String::new(), line)),
    }
}

fn rd_rs_rt(ops: &[Operand], line: usize) -> Result<(u8, u8, u8), AssemblerError> {
    Ok((reg(ops, 0, line)?, reg(ops, 1, line)?, reg(ops, 2, line)?))
}

fn pseudo_word_count(instr: &ParsedInstruction) -> u32 {
    match instr.mnemonic.as_str() {
        "li" => match instr.operands.get(1) {
            Some(Operand::Immediate(v)) => {
                if *v >= -32768 && *v <= 65535 { 1 } else { 2 }
            }
            _ => 2,
        },
        "la" => 2,
        _ => 1,
    }
}

fn directive_byte_count(name: &str, args: &[DirectiveArg]) -> u32 {
    match name {
        "asciiz" => match args.first() {
            Some(DirectiveArg::Str(s)) => s.len() as u32 + 1,
            _ => 0,
        },
        "ascii" => match args.first() {
            Some(DirectiveArg::Str(s)) => s.len() as u32,
            _ => 0,
        },
        "word" => args.len() as u32 * 4,
        "half" => args.len() as u32 * 2,
        "byte" => args.len() as u32,
        "space" => match args.first() {
            Some(DirectiveArg::Int(n)) => *n as u32,
            _ => 0,
        },
        _ => 0,
    }
}

fn instr_name_at(ops: &[Operand]) -> String {
    let _ = ops;
    String::new()
}