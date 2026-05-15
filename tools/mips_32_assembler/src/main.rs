use std::env;
use std::fs;
use std::io::{self, BufWriter, Write};
use std::process;

use mips_32_assembler::elf::write_elf;
use mips_32_assembler::emitter::Emitter;
use mips_32_assembler::lexer::Lexer;
use mips_32_assembler::parser::Parser;

fn prompt(label: &str) -> String {
    print!("{}", label);
    io::stdout().flush().unwrap();
    let mut buf = String::new();
    io::stdin().read_line(&mut buf).unwrap();
    buf.trim().to_string()
}

fn main() {
    let args: Vec<String> = env::args().collect();

    let input_path = if args.len() > 1 {
        args[1].clone()
    } else {
        prompt("Input file: ")
    };

    let source = fs::read_to_string(&input_path).unwrap_or_else(|e| {
        eprintln!("error: cannot read '{}': {}", input_path, e);
        process::exit(1);
    });

    let output_path = if args.len() > 2 {
        args[2].clone()
    } else {
        prompt("Output file: ")
    };

    let tokens = Lexer::new(&source).tokenize();
    let ast = Parser::new(tokens).parse();

    let mut emitter = Emitter::new();
    if let Err(e) = emitter.assemble(&ast) {
        eprintln!("assembly error: {}", e);
        process::exit(1);
    }

    let entry = emitter
        .symbols()
        .get("main")
        .copied()
        .unwrap_or(0x0040_0000);

    let out_file = fs::File::create(&output_path).unwrap_or_else(|e| {
        eprintln!("error: cannot create '{}': {}", output_path, e);
        process::exit(1);
    });

    let mut writer = BufWriter::new(out_file);

    if let Err(e) = write_elf(&mut writer, emitter.text_segment(), emitter.data_segment(), entry) {
        eprintln!("error writing ELF: {}", e);
        process::exit(1);
    }

    let text_words = emitter.text_segment().len();
    let data_bytes = emitter.data_segment().len();

    println!(
        "assembled '{}' -> '{}'  ({} instruction{}, {} data byte{})",
        input_path,
        output_path,
        text_words,
        if text_words == 1 { "" } else { "s" },
        data_bytes,
        if data_bytes == 1 { "" } else { "s" },
    );

    if !emitter.symbols().is_empty() {
        println!("symbols:");
        let mut syms: Vec<_> = emitter.symbols().iter().collect();
        syms.sort_by_key(|(_, v)| *v);
        for (name, addr) in syms {
            println!("  {:<16} 0x{:08x}", name, addr);
        }
    }
}