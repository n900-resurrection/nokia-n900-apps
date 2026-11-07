// Test of an async runtime on the N900: tokio timers, tasks, a TCP echo over the loopback interface and an HTTPS request (tokio-rustls).
// async-rust [host]: the host of the HTTPS test (default www.howsmyssl.com, path /a/check); "local" skips the network test.
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};

#[tokio::main]
async fn main() {
    let t0 = Instant::now();
    // timers and tasks
    let tasks: Vec<_> = (1..=4u64).map(|i| tokio::spawn(async move { tokio::time::sleep(Duration::from_millis(50 * i)).await; i * i })).collect();
    let mut sum = 0;
    for t in tasks { sum += t.await.unwrap(); }
    println!("tasks: sum of squares = {sum} after {} ms", t0.elapsed().as_millis());
    // TCP echo on the loopback interface
    let l = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = l.local_addr().unwrap().port();
    tokio::spawn(async move {
        let (mut s, _) = l.accept().await.unwrap();
        let mut b = [0u8; 16];
        let n = s.read(&mut b).await.unwrap();
        s.write_all(&b[..n]).await.unwrap();
    });
    let mut c = TcpStream::connect(("127.0.0.1", port)).await.unwrap();
    c.write_all(b"ping").await.unwrap();
    let mut b = [0u8; 4];
    c.read_exact(&mut b).await.unwrap();
    println!("echo: {}", String::from_utf8_lossy(&b));
    // HTTPS (TLS 1.3)
    let host = std::env::args().nth(1).unwrap_or_else(|| "www.howsmyssl.com".into());
    if host != "local" {
        let roots = tokio_rustls::rustls::RootCertStore { roots: webpki_roots::TLS_SERVER_ROOTS.to_vec() };
        let config = tokio_rustls::rustls::ClientConfig::builder().with_root_certificates(roots).with_no_client_auth();
        let connector = tokio_rustls::TlsConnector::from(Arc::new(config));
        let name = tokio_rustls::rustls::pki_types::ServerName::try_from(host.clone()).unwrap();
        let tcp = TcpStream::connect((host.as_str(), 443)).await.unwrap();
        let mut tls = connector.connect(name, tcp).await.unwrap();
        tls.write_all(format!("GET /a/check HTTP/1.1\r\nHost: {host}\r\nConnection: close\r\n\r\n").as_bytes()).await.unwrap();
        let mut body = Vec::new();
        let _ = tls.read_to_end(&mut body).await;
        let text = String::from_utf8_lossy(&body);
        println!("https: {}", text.lines().next().unwrap_or(""));
        println!("tls: {}", text.split("\"tls_version\":\"").nth(1).and_then(|r| r.split('"').next()).unwrap_or("?"));
    }
    println!("done in {} ms", t0.elapsed().as_millis());
}
