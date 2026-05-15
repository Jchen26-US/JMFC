use std::env;
use std::fs;
use std::io::{self, BufWriter, Write};
use std::process;

use mips_32_assembler::emitter::Emitter;
use mips_32_assembler::lexer::Lexer;
use mips_32_assembler::memfile::{write_data_mem, write_text_mem};
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

    let output_name = if args.len() > 2 {
        args[2].clone()
    } else {
        prompt("Output name (without extension): ")
    };

    let tokens = Lexer::new(&source).tokenize();
    let ast = Parser::new(tokens).parse();

    let mut emitter = Emitter::new();
    if let Err(e) = emitter.assemble(&ast) {
        eprintln!("assembly error: {}", e);
        process::exit(1);
    }

    let text_path = format!("{}.mem", output_name);
    let text_file = fs::File::create(&text_path).unwrap_or_else(|e| {
        eprintln!("error: cannot create '{}': {}", text_path, e);
        process::exit(1);
    });
    let mut text_writer = BufWriter::new(text_file);
    if let Err(e) = write_text_mem(&mut text_writer, emitter.text_segment()) {
        eprintln!("error writing text mem: {}", e);
        process::exit(1);
    }

    if !emitter.data_segment().is_empty() {
        let data_path = format!("{}_data.mem", output_name);
        let data_file = fs::File::create(&data_path).unwrap_or_else(|e| {
            eprintln!("error: cannot create '{}': {}", data_path, e);
            process::exit(1);
        });
        let mut data_writer = BufWriter::new(data_file);
        if let Err(e) = write_data_mem(&mut data_writer, emitter.data_segment()) {
            eprintln!("error writing data mem: {}", e);
            process::exit(1);
        }
        println!("wrote '{}'  and  '{}_data.mem'", text_path, output_name);
    } else {
        println!("wrote '{}'", text_path);
    }

    println!(
        "{} instruction{}, {} data byte{}",
        emitter.text_segment().len(),
        if emitter.text_segment().len() == 1 { "" } else { "s" },
        emitter.data_segment().len(),
        if emitter.data_segment().len() == 1 { "" } else { "s" },
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