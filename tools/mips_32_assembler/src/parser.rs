use crate::lexer::Token;

#[derive(Debug, Clone, PartialEq)]
pub enum Operand {
    Register(u8),
    Immediate(i32),
    LabelRef(String),
    MemOffset { offset: i32, base: u8 },
}

#[derive(Debug, Clone, PartialEq)]
pub struct ParsedInstruction {
    pub mnemonic: String,
    pub operands: Vec<Operand>,
    pub line: usize,
}

#[derive(Debug, Clone, PartialEq)]
pub enum DirectiveArg {
    Str(String),
    Int(i64),
    Ident(String),
}

#[derive(Debug, Clone, PartialEq)]
pub enum AstNode {
    Instruction(ParsedInstruction),
    Label(String),
    Directive { name: String, args: Vec<DirectiveArg> },
    SectionSwitch(Section),
}

#[derive(Debug, Clone, PartialEq)]
pub enum Section {
    Text,
    Data,
}

pub struct Parser {
    tokens: Vec<Token>,
    position: usize,
    line: usize,
}

impl Parser {
    pub fn new(tokens: Vec<Token>) -> Self {
        Parser {
            tokens,
            position: 0,
            line: 1,
        }
    }

    pub fn current(&self) -> Option<&Token> {
        self.tokens.get(self.position)
    }

    pub fn advance(&mut self) -> Option<&Token> {
        let t = self.tokens.get(self.position);
        if matches!(t, Some(Token::Newline)) {
            self.line += 1;
        }
        self.position += 1;
        t
    }

    fn skip_newlines(&mut self) {
        while matches!(self.current(), Some(Token::Newline)) {
            self.advance();
        }
    }

    pub fn parse(&mut self) -> Vec<AstNode> {
        let mut nodes = Vec::new();

        loop {
            self.skip_newlines();

            match self.current() {
                None | Some(Token::EOF) => break,

                Some(Token::Label(name)) => {
                    let name = name.clone();
                    nodes.push(AstNode::Label(name));
                    self.advance();
                }

                Some(Token::Directive(name)) => {
                    let name = name.clone();
                    self.advance();
                    match name.as_str() {
                        "text" => nodes.push(AstNode::SectionSwitch(Section::Text)),
                        "data" => nodes.push(AstNode::SectionSwitch(Section::Data)),
                        _ => {
                            let args = self.parse_directive_args();
                            nodes.push(AstNode::Directive { name, args });
                        }
                    }
                }

                Some(Token::Identifier(name)) => {
                    let name = name.clone();
                    let line = self.line;
                    self.advance();
                    let instr = self.parse_instruction(name, line);
                    nodes.push(AstNode::Instruction(instr));
                }

                Some(_) => {
                    self.advance();
                }
            }
        }

        nodes
    }

    fn parse_directive_args(&mut self) -> Vec<DirectiveArg> {
        let mut args = Vec::new();
        loop {
            match self.current() {
                None | Some(Token::EOF) | Some(Token::Newline) => break,
                Some(Token::Comma) => {
                    self.advance();
                }
                Some(Token::StringLiteral(s)) => {
                    args.push(DirectiveArg::Str(s.clone()));
                    self.advance();
                }
                Some(Token::IntLiteral(n)) => {
                    args.push(DirectiveArg::Int(*n));
                    self.advance();
                }
                Some(Token::Identifier(s)) => {
                    args.push(DirectiveArg::Ident(s.clone()));
                    self.advance();
                }
                _ => {
                    self.advance();
                }
            }
        }
        args
    }

    fn parse_instruction(&mut self, mnemonic: String, line: usize) -> ParsedInstruction {
        let mut operands = Vec::new();

        loop {
            match self.current() {
                None | Some(Token::EOF) | Some(Token::Newline) => break,

                Some(Token::Comma) => {
                    self.advance();
                }

                Some(Token::Register(r)) => {
                    let num = reg_to_num(r).unwrap_or(0);
                    operands.push(Operand::Register(num));
                    self.advance();
                }

                Some(Token::IntLiteral(n)) => {
                    let n = *n as i32;
                    self.advance();
                    if matches!(self.current(), Some(Token::LParen)) {
                        self.advance();
                        if let Some(Token::Register(r)) = self.current() {
                            let base = reg_to_num(r).unwrap_or(0);
                            self.advance();
                            if matches!(self.current(), Some(Token::RParen)) {
                                self.advance();
                            }
                            operands.push(Operand::MemOffset { offset: n, base });
                        }
                    } else {
                        operands.push(Operand::Immediate(n));
                    }
                }

                Some(Token::LParen) => {
                    self.advance();
                    if let Some(Token::Register(r)) = self.current() {
                        let base = reg_to_num(r).unwrap_or(0);
                        self.advance();
                        if matches!(self.current(), Some(Token::RParen)) {
                            self.advance();
                        }
                        operands.push(Operand::MemOffset { offset: 0, base });
                    }
                }

                Some(Token::Identifier(s)) => {
                    operands.push(Operand::LabelRef(s.clone()));
                    self.advance();
                }

                _ => {
                    self.advance();
                }
            }
        }

        ParsedInstruction { mnemonic, operands, line }
    }
}

pub fn reg_to_num(name: &str) -> Option<u8> {
    match name {
        "zero" => Some(0),
        "at" => Some(1),
        "v0" => Some(2),
        "v1" => Some(3),
        "a0" => Some(4),
        "a1" => Some(5),
        "a2" => Some(6),
        "a3" => Some(7),
        "t0" => Some(8),
        "t1" => Some(9),
        "t2" => Some(10),
        "t3" => Some(11),
        "t4" => Some(12),
        "t5" => Some(13),
        "t6" => Some(14),
        "t7" => Some(15),
        "s0" => Some(16),
        "s1" => Some(17),
        "s2" => Some(18),
        "s3" => Some(19),
        "s4" => Some(20),
        "s5" => Some(21),
        "s6" => Some(22),
        "s7" => Some(23),
        "t8" => Some(24),
        "t9" => Some(25),
        "k0" => Some(26),
        "k1" => Some(27),
        "gp" => Some(28),
        "sp" => Some(29),
        "fp" | "s8" => Some(30),
        "ra" => Some(31),
        _ => name.parse::<u8>().ok().filter(|&n| n < 32),
    }
}