pub enum Operand {
    Register(u8),                         // resolved to number 0-31
    Immediate(i32),                       // a number
    LabelRef(String),                     // unresolved label
    MemOffset { offset: i32, base: u8 }, // 8($sp)
}
pub struct ParsedInstruction {
    pub mnemonic: String,
    pub operands: Vec<Operand>,
    pub line: usize,
}