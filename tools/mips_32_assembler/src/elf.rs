use std::io::{self, Write};

const ET_EXEC: u16 = 2;
const EM_MIPS: u16 = 8;
const EV_CURRENT: u32 = 1;
const ELFCLASS32: u8 = 1;
const ELFDATA2MSB: u8 = 2;
const ELFOSABI_NONE: u8 = 0;

const PT_LOAD: u32 = 1;
const PF_X: u32 = 0x1;
const PF_W: u32 = 0x2;
const PF_R: u32 = 0x4;

const SHT_NULL: u32 = 0;
const SHT_PROGBITS: u32 = 1;
const SHT_STRTAB: u32 = 3;
const SHF_WRITE: u32 = 0x1;
const SHF_ALLOC: u32 = 0x2;
const SHF_EXECINSTR: u32 = 0x4;

const EF_MIPS_NOREORDER: u32 = 0x0000_0001;
const EF_MIPS_ABI_O32: u32 = 0x0000_1000;
const EF_MIPS_ARCH_32: u32 = 0x5000_0000;

const TEXT_VADDR: u32 = 0x0040_0000;
const DATA_VADDR: u32 = 0x1001_0000;
const ELF_HDR_SZ: u32 = 52;
const PHDR_SZ: u32 = 32;
const SHDR_SZ: u32 = 40;

pub fn write_elf<W: Write>(
    w: &mut W,
    text: &[u32],
    data: &[u8],
    entry: u32,
) -> io::Result<()> {
    let text_bytes: Vec<u8> = text.iter().flat_map(|word| word.to_be_bytes()).collect();
    let has_data = !data.is_empty();
    let phnum: u16 = if has_data { 2 } else { 1 };

    let text_off = align_up(ELF_HDR_SZ + phnum as u32 * PHDR_SZ, 4);
    let data_off = align_up(text_off + text_bytes.len() as u32, 4);
    let shstr_off = data_off + data.len() as u32;

    let shstrtab: &[u8] = if has_data {
        b"\0.text\0.data\0.shstrtab\0"
    } else {
        b"\0.text\0.shstrtab\0"
    };

    let shnum: u16 = if has_data { 4 } else { 3 };
    let shstrndx: u16 = shnum - 1;
    let shoff = align_up(shstr_off + shstrtab.len() as u32, 4);

    let flags = EF_MIPS_ARCH_32 | EF_MIPS_ABI_O32 | EF_MIPS_NOREORDER;

    let mut ident = [0u8; 16];
    ident[0] = 0x7f;
    ident[1] = b'E';
    ident[2] = b'L';
    ident[3] = b'F';
    ident[4] = ELFCLASS32;
    ident[5] = ELFDATA2MSB;
    ident[6] = EV_CURRENT as u8;
    ident[7] = ELFOSABI_NONE;

    w.write_all(&ident)?;
    w16(w, ET_EXEC)?;
    w16(w, EM_MIPS)?;
    w32(w, EV_CURRENT)?;
    w32(w, entry)?;
    w32(w, ELF_HDR_SZ)?;
    w32(w, shoff)?;
    w32(w, flags)?;
    w16(w, ELF_HDR_SZ as u16)?;
    w16(w, PHDR_SZ as u16)?;
    w16(w, phnum)?;
    w16(w, SHDR_SZ as u16)?;
    w16(w, shnum)?;
    w16(w, shstrndx)?;

    write_phdr(w, text_off, TEXT_VADDR, text_bytes.len() as u32, PF_R | PF_X)?;

    if has_data {
        write_phdr(w, data_off, DATA_VADDR, data.len() as u32, PF_R | PF_W)?;
    }

    pad(w, text_off - (ELF_HDR_SZ + phnum as u32 * PHDR_SZ))?;

    w.write_all(&text_bytes)?;
    pad(w, data_off - (text_off + text_bytes.len() as u32))?;

    if has_data {
        w.write_all(data)?;
    }

    w.write_all(shstrtab)?;
    pad(w, shoff - (shstr_off + shstrtab.len() as u32))?;

    write_shdr(w, 0, SHT_NULL, 0, 0, 0, 0, 0, 0, 0, 0)?;

    write_shdr(
        w,
        1,
        SHT_PROGBITS,
        SHF_ALLOC | SHF_EXECINSTR,
        TEXT_VADDR,
        text_off,
        text_bytes.len() as u32,
        0,
        0,
        4,
        0,
    )?;

    if has_data {
        write_shdr(
            w,
            7,
            SHT_PROGBITS,
            SHF_ALLOC | SHF_WRITE,
            DATA_VADDR,
            data_off,
            data.len() as u32,
            0,
            0,
            4,
            0,
        )?;
        write_shdr(w, 13, SHT_STRTAB, 0, 0, shstr_off, shstrtab.len() as u32, 0, 0, 1, 0)?;
    } else {
        write_shdr(w, 7, SHT_STRTAB, 0, 0, shstr_off, shstrtab.len() as u32, 0, 0, 1, 0)?;
    }

    Ok(())
}

fn write_phdr<W: Write>(
    w: &mut W,
    file_off: u32,
    vaddr: u32,
    size: u32,
    flags: u32,
) -> io::Result<()> {
    w32(w, PT_LOAD)?;
    w32(w, file_off)?;
    w32(w, vaddr)?;
    w32(w, vaddr)?;
    w32(w, size)?;
    w32(w, size)?;
    w32(w, flags)?;
    w32(w, 4)
}

#[allow(clippy::too_many_arguments)]
fn write_shdr<W: Write>(
    w: &mut W,
    sh_name: u32,
    sh_type: u32,
    sh_flags: u32,
    sh_addr: u32,
    sh_offset: u32,
    sh_size: u32,
    sh_link: u32,
    sh_info: u32,
    sh_addralign: u32,
    sh_entsize: u32,
) -> io::Result<()> {
    w32(w, sh_name)?;
    w32(w, sh_type)?;
    w32(w, sh_flags)?;
    w32(w, sh_addr)?;
    w32(w, sh_offset)?;
    w32(w, sh_size)?;
    w32(w, sh_link)?;
    w32(w, sh_info)?;
    w32(w, sh_addralign)?;
    w32(w, sh_entsize)
}

fn w16<W: Write>(w: &mut W, v: u16) -> io::Result<()> {
    w.write_all(&v.to_be_bytes())
}

fn w32<W: Write>(w: &mut W, v: u32) -> io::Result<()> {
    w.write_all(&v.to_be_bytes())
}

fn pad<W: Write>(w: &mut W, n: u32) -> io::Result<()> {
    for _ in 0..n {
        w.write_all(&[0u8])?;
    }
    Ok(())
}

fn align_up(v: u32, align: u32) -> u32 {
    (v + align - 1) & !(align - 1)
}