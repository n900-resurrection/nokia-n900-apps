// HTTPS GET with rustls on the N900: tls-rust [host] [path]. Prints the negotiated TLS version and cipher suite, then the response.
// Default: https://www.howsmyssl.com/a/check (a JSON description of the connection, it includes "tls_version").
use std::io::{Read, Write};
use std::net::TcpStream;
use std::sync::Arc;

fn main() {
    let host = std::env::args().nth(1).unwrap_or_else(|| "www.howsmyssl.com".into());
    let path = std::env::args().nth(2).unwrap_or_else(|| "/a/check".into());
    let roots = rustls::RootCertStore { roots: webpki_roots::TLS_SERVER_ROOTS.to_vec() };
    let config = rustls::ClientConfig::builder().with_root_certificates(roots).with_no_client_auth();
    let name = rustls::pki_types::ServerName::try_from(host.clone()).expect("bad host name");
    let mut conn = rustls::ClientConnection::new(Arc::new(config), name).expect("tls setup");
    let mut sock = TcpStream::connect((host.as_str(), 443)).expect("tcp connect");
    let mut tls = rustls::Stream::new(&mut conn, &mut sock);
    write!(tls, "GET {path} HTTP/1.1\r\nHost: {host}\r\nUser-Agent: tls-rust\r\nConnection: close\r\n\r\n").expect("write");
    let mut body = Vec::new();
    let _ = tls.read_to_end(&mut body); // the server closes without close_notify: the error at the end is harmless
    println!("TLS: {:?}, {:?}", conn.protocol_version().unwrap(), conn.negotiated_cipher_suite().map(|s| s.suite()));
    let text = String::from_utf8_lossy(&body);
    println!("{}", text.lines().take(14).collect::<Vec<_>>().join("\n"));
}
