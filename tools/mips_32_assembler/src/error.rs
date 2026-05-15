use std::fmt;

#[derive(Debug, Clone)]
pub enum AssemblerError {
    UnknownInstruction(String, usize),
    UnknownRegister(String, usize),
    UnknownLabel(String, usize),
    InvalidOperands(String, usize),
    ImmediateOutOfRange(i64, usize),
}

impl fmt::Display for AssemblerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AssemblerError::UnknownInstruction(s, l) => {
                write!(f, "line {}: unknown instruction '{}'", l, s)
            }
            AssemblerError::UnknownRegister(s, l) => {
                write!(f, "line {}: unknown register '{}'", l, s)
            }
            AssemblerError::UnknownLabel(s, l) => {
                write!(f, "line {}: undefined label '{}'", l, s)
            }
            AssemblerError::InvalidOperands(s, l) => {
                write!(f, "line {}: invalid operands for '{}'", l, s)
            }
            AssemblerError::ImmediateOutOfRange(v, l) => {
                write!(f, "line {}: immediate {} out of range", l, v)
            }
        }
    }
}

impl std::error::Error for AssemblerError {}