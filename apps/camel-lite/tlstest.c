/* Connects to an IMAP server over implicit TLS through camel-lite (the OpenSSL backend) and prints the greeting
 * and the CAPABILITY answer. Usage: tlstest imap.centrum.cz 993. Needs no account and no password. */
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <camel/camel.h>
#include <camel/camel-net-utils.h>
#include <camel/camel-tcp-stream-ssl.h>

static void show(CamelStream *s, const char *what)
{
	char buf[512];
	ssize_t n = camel_stream_read(s, buf, sizeof buf - 1);
	if (n < 0) { printf("%s: read error\n", what); return; }
	buf[n] = 0;
	printf("%s: %s", what, buf);
}

int main(int argc, char **argv)
{
	const char *host = argc > 1 ? argv[1] : "imap.centrum.cz";
	const char *port = argc > 2 ? argv[2] : "993";
	CamelException ex;
	struct addrinfo hints, *ai;
	CamelTcpStream *s;
	static CamelService fake;  /* the stream only reads service->session (for certificate prompts) */

	setvbuf(stdout, NULL, _IONBF, 0);
	printf("start\n");
	g_thread_init(NULL);
	g_type_init();
	camel_init("/home/user/.camel-tlstest", FALSE);
	printf("camel_init done\n");
	camel_exception_init(&ex);
	memset(&hints, 0, sizeof hints);
	hints.ai_socktype = SOCK_STREAM;
	ai = camel_getaddrinfo(host, port, &hints, &ex);
	if (!ai) { printf("resolve failed: %s\n", camel_exception_get_description(&ex)); return 2; }
	printf("resolved\n");
	s = camel_tcp_stream_ssl_new(&fake, host, CAMEL_TCP_STREAM_SSL_ENABLE_TLS);
	printf("stream created\n");
	if (camel_tcp_stream_connect(s, ai) != 0) { printf("TLS connect failed\n"); return 3; }
	printf("TLS connected to %s:%s\n", host, port);
	show(CAMEL_STREAM(s), "greeting");
	camel_stream_write(CAMEL_STREAM(s), "a1 CAPABILITY\r\n", 15);
	show(CAMEL_STREAM(s), "capability");
	return 0;
}
