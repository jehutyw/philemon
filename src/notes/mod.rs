mod links;
mod store;
#[cfg(test)]
mod tests;

use crate::json::{escape, field_str};
use std::io::{self, BufRead, Read, Write};
use std::path::Path;

// Dedicated, lazy process: reading or saving a note never blocks the listing backend.
pub fn run() -> i32 {
    let stdin = io::stdin();
    let mut input = stdin.lock();
    let mut output = io::stdout().lock();
    loop {
        let mut line = String::new();
        // Two note bodies, JSON escaping, and protocol overhead; a bounded allocation.
        match input.by_ref().take((store::LIMIT * 12 + 65536) as u64).read_line(&mut line) {
            Ok(0) => break,
            Ok(_) if line.ends_with('\n') => {},
            _ => return 2,
        }
        let answer = reply(&line);
        if writeln!(output, "{answer}").and_then(|()| output.flush()).is_err() { break; }
    }
    0
}

fn reply(line: &str) -> String {
    let id = crate::json::field_usize(line, "id").unwrap_or(0);
    match request(line) {
        Ok((path, text)) => format!("{{\"id\":{id},\"ok\":true,\"path\":\"{}\",\"text\":\"{}\"}}", escape(&path), escape(&text)),
        Err(e) => format!("{{\"id\":{id},\"ok\":false,\"error\":\"{}\"}}", escape(&e)),
    }
}

fn request(line: &str) -> Result<(String, String), String> {
    let field = |key| field_str(line, key).ok_or_else(|| format!("Missing {key}."));
    let vault = field("vault")?;
    let path = field("path")?;
    let command = field("c")?;
    let target = if command == "resolve" {
        links::resolve(Path::new(&vault), Path::new(&path), &field("link")?)?
    } else {
        store::target(Path::new(&vault), Path::new(&path))?
    };
    let text = match command.as_str() {
        "load" | "reload" | "resolve" => store::read(&target)?,
        "save" => store::save(&target, &field("original")?, &field("text")?)?,
        _ => return Err("Unknown note operation.".into()),
    };
    Ok((target.to_str().ok_or("This path is not UTF-8.")?.into(), text))
}
