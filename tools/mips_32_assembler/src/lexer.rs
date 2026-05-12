#[derive(Debug, Clone, PartialEq)]

pub enum Token {
    Identifier(String),
    Label(String),
    Directive(String),
    Register(String),
    IntLiteral(i64),
    StringLiteral(String),
    Comma,
    LParen,
    RParen,
    Newline,
    EOF,
}

pub struct Lexer <'a> {
    source: &'a str,
    position: usize,
    current_line: usize,
}

impl<'a> Lexer <'a> {
    pub fn new(source: &'a str) -> Self {
        Lexer {
            source,
            position: 0,
            current_line: 1,
        }
            
    }

    pub fn current(&self) -> Option<u8> {
        self.source.as_bytes().get(self.position).copied()
    }

    pub fn peek(&self) -> Option<u8> {
        self.source.as_bytes().get(self.position+1).copied()
 
    }

    pub fn advance(&mut self) -> Option<u8> {
        let dum = self.current();
        self.position += 1;
        dum
    }

    pub fn consume_while(&mut self, condition: impl Fn(u8) -> bool) -> &str {
        let start_pos = self.position;
        
        while let Some(current_byte) = self.current() {
            if condition(current_byte) {
                self.position += 1;
            }
            
            else {
                break;
            }
        }

        &self.source[start_pos..self.position]
    }

    pub fn tokenize(&mut self) -> Vec<Token> {
        let mut tokens: Vec<Token> = Vec::new();
        loop {
            match self.current() {
                None => {
                    tokens.push(Token::EOF);
                    break;
                },

                Some(b'\n') => {
                    tokens.push(Token::Newline);
                    self.current_line += 1;
                    self.advance();
                },

                Some(b' ' | b'\t') => {
                    self.advance();
                },

                Some(b',') => {
                    tokens.push(Token::Comma);
                    self.advance();
                },

                Some(b'(') => {
                    tokens.push(Token::LParen);
                    self.advance();
                },

                Some(b')') => {
                    tokens.push(Token::RParen);
                    self.advance();
                },

                Some(b'#') => {
                    self.consume_while(|c| c != b'\n');
                },

                Some(b'$') => {
                    let token = self.lex_register();
                    tokens.push(token);
                    
                },

                Some(b'.') => {
                    let token = self.lex_directive();
                    tokens.push(token);
                },

                Some(c) if c.is_ascii_alphabetic() => {
                    let token = self.lex_identifier();
                    tokens.push(token);
                },

                Some(b'-') | Some(b'0'..=b'9') => {
                    let token = self.lex_number();
                    tokens.push(token);
                },

                Some(b'"') => {
                    let token = self.lex_string();
                    tokens.push(token);
                },
 
                Some(_) => {
                    self.advance();
                }

            }
        }

        tokens
    }

    pub fn lex_register(&mut self) -> Token {
        self.advance();
        Token::Register(self.consume_while(|c| c.is_ascii_alphanumeric()).to_string())
    }

    pub fn lex_directive(&mut self) -> Token {
        self.advance();
        Token::Directive(self.consume_while(|c| c.is_ascii_alphabetic()).to_string())

    }

    pub fn lex_identifier(&mut self) -> Token {
        let dum = self.consume_while(|c| c.is_ascii_alphanumeric() || (c == b'_')).to_string();

        if self.current() == Some(b':') {
            self.advance();
            Token::Label(dum)
        }

        else {
            Token::Identifier(dum)
        }        
    }

    pub fn lex_number(&mut self) -> Token {
        let mut neg = 1;

        if self.current() == Some(b'-') {
            neg = -1;
            self.advance();
        }

        if self.source[self.position..].starts_with("0x") {
            self.advance();
            self.advance();
            let digits = self.consume_while(|c| c.is_ascii_hexdigit());
            Token::IntLiteral(i64::from_str_radix(digits, 16).unwrap()*neg)
        } 
        
        else if self.source[self.position..].starts_with("0b") {
            self.advance();
            self.advance();
            let digits = self.consume_while(|c| c == b'0' || c == b'1');
            Token::IntLiteral(i64::from_str_radix(digits, 2).unwrap()*neg)
        }

        else {
            let digits = self.consume_while(|c| c.is_ascii_alphanumeric()).to_string();
            Token::IntLiteral(digits.parse::<i64>().unwrap()*neg)

        }
    }

    pub fn lex_string(&mut self) -> Token {
        self.advance();
        
        let mut str_literal = String::new();

        loop {
            match self.current() {
                Some(b'"') => {
                    self.advance();
                    break;
                },

                Some(b'\\') => {
                    self.advance();
                    match self.current() {
                        Some(b'n') => {
                            str_literal.push('\n');
                            self.advance();
                        },

                        Some(b't') => {
                            str_literal.push('\t');
                            self.advance();
                        },

                        Some(b'\\') => {
                            str_literal.push('\\');
                            self.advance();
                        },

                        Some(b'"') => {
                            str_literal.push('"');
                            self.advance();
                        },

                        _ => {
                            break;
                        }

                    }
                },

                Some(c) => {
                    str_literal.push(c as char);
                    self.advance();
                },
                
                _ => {
                    break;
                }
            }
        }

        Token::StringLiteral(str_literal)
    }

}

