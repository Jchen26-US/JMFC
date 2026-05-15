use std::io::{self, Write};

pub fn write_text_mem<W: Write>(w: &mut W, text: &[u32]) -> io::Result<()> {
    for word in text {
        writeln!(w, "{:08x}", word)?;
    }
    Ok(())
}

pub fn write_data_mem<W: Write>(w: &mut W, data: &[u8]) -> io::Result<()> {
    for chunk in data.chunks(4) {
        let mut word = [0u8; 4];
        word[..chunk.len()].copy_from_slice(chunk);
        writeln!(w, "{:08x}", u32::from_be_bytes(word))?;
    }
    Ok(())
}