use mips_32_assembler::lexer::Lexer;

fn main() {
    let source = ".text\nmain: addi $t0, $zero, 42\n# comment\n.data\nmsg: .asciiz \"hello\\n\"";
    let mut lexer = Lexer::new(source);
    let tokens = lexer.tokenize();
    
    for token in tokens {
        println!("{:?}", token);
    }
}