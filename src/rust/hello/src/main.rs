// Test program for Rust on the N900: std, threads, time, files and a local TCP connection (what a real client needs).
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::{fs, thread, time};

fn main() {
    println!("Hello from Rust on the N900 ({} {})", std::env::consts::OS, std::env::consts::ARCH);
    // threads and channels
    let (tx, rx) = std::sync::mpsc::channel();
    let handles: Vec<_> = (0..4).map(|i| { let tx = tx.clone(); thread::spawn(move || tx.send(i * i).unwrap()) }).collect();
    for h in handles { h.join().unwrap(); }
    drop(tx);
    println!("threads: sum of squares = {}", rx.iter().sum::<i32>());
    // time and files
    let t = time::SystemTime::now().duration_since(time::UNIX_EPOCH).unwrap().as_secs();
    fs::write("/tmp/hello-rust.txt", format!("{t}\n")).unwrap();
    println!("file: {}", fs::read_to_string("/tmp/hello-rust.txt").unwrap().trim());
    let _ = fs::remove_file("/tmp/hello-rust.txt");
    // TCP over the loopback interface (a server thread and a client)
    let l = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = l.local_addr().unwrap().port();
    let srv = thread::spawn(move || {
        let (mut s, _) = l.accept().unwrap();
        let mut b = [0u8; 16];
        let n = s.read(&mut b).unwrap();
        s.write_all(&b[..n]).unwrap();
    });
    let mut c = TcpStream::connect(("127.0.0.1", port)).unwrap();
    c.write_all(b"ping").unwrap();
    let mut b = [0u8; 4];
    c.read_exact(&mut b).unwrap();
    srv.join().unwrap();
    println!("tcp: {}", String::from_utf8_lossy(&b));
}
