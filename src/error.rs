// Names the operation and the input, so the UI's message is enough to act on.
#[derive(Debug)]
pub struct PhilemonError {
    pub where_: String,
    pub path: String,
    pub msg: String,
}

pub fn from_io(where_: &str, path: &str, e: &std::io::Error) -> PhilemonError {
    PhilemonError {
        where_: where_.to_string(),
        path: path.to_string(),
        msg: e.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn carries_operation_path_and_message() {
        let io = std::io::Error::new(std::io::ErrorKind::PermissionDenied, "denied");
        let e = from_io("list", "/root", &io);
        assert_eq!(e.where_, "list");
        assert_eq!(e.path, "/root");
        assert!(e.msg.contains("denied"));
    }
}
