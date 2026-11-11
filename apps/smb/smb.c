/* smb - small SMB2/SMB3 client for the Nokia N900 (Maemo 5), built on libsmb2 (LGPL-2.1, linked statically).
 *
 *   smb [-v 2|3] [-u USER] [-d DOMAIN] [-q] COMMAND ARGS...
 *   smb ls    smb://host/share/dir
 *   smb get   smb://host/share/file [LOCAL|-]
 *   smb put   LOCAL smb://host/share/dir/[name]
 *   smb rm | rmdir | mkdir | stat   smb://host/share/path
 *   smb mv    smb://host/share/old NEW-PATH-IN-SHARE
 *   smb df    smb://host/share
 * Password: $SMB_PASSWORD, or $NTLM_USER_FILE (libsmb2, lines domain:user:password), else asked on the terminal.
 * Without a user the connection is a guest one (empty password). URL options: ?vers=3&seal&sign&sec=ntlmssp
 */
#define _FILE_OFFSET_BITS 64
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

#include "smb2.h"
#include "libsmb2.h"

static int quiet;
static const char *opt_user, *opt_domain;
static int opt_version;

static void die(struct smb2_context *smb2, const char *what)
{
    fprintf(stderr, "smb: %s: %s\n", what, smb2 ? smb2_get_error(smb2) : strerror(errno));
    exit(1);
}

static char *ask_password(const char *user)
{
    static char buf[256];
    struct termios t, old;
    int tty = isatty(0);
    fprintf(stderr, "Password for %s: ", user);
    if (tty) { tcgetattr(0, &old); t = old; t.c_lflag &= ~ECHO; tcsetattr(0, TCSANOW, &t); }
    if (!fgets(buf, sizeof buf, stdin)) buf[0] = 0;
    if (tty) { tcsetattr(0, TCSANOW, &old); fputc('\n', stderr); }
    buf[strcspn(buf, "\r\n")] = 0;
    return buf;
}

/* Parses the URL, connects and returns the context; *path gets the path inside the share ("" = root). */
static struct smb2_context *open_url(const char *urlstr, char **path, char **sharepath)
{
    struct smb2_context *smb2 = smb2_init_context();
    struct smb2_url *url;
    const char *user;
    if (!smb2) die(NULL, "out of memory");
    if (opt_version) smb2_set_version(smb2, opt_version == 3 ? SMB2_VERSION_ANY3 : SMB2_VERSION_ANY2);
    smb2_set_timeout(smb2, 30);
    url = smb2_parse_url(smb2, urlstr);
    if (!url) die(smb2, "URL");
    if (!url->server || !*url->server || !url->share || !*url->share) { fprintf(stderr, "smb: URL needs host and share: smb://host/share[/path]\n"); exit(1); }
    user = opt_user ? opt_user : url->user;
    if (opt_domain || url->domain) smb2_set_domain(smb2, opt_domain ? opt_domain : url->domain);
    if (!user) {
        user = "Guest";
        smb2_set_password(smb2, "");
    } else if (getenv("SMB_PASSWORD")) {
        smb2_set_password(smb2, getenv("SMB_PASSWORD"));
    } else if (!getenv("NTLM_USER_FILE")) {
        smb2_set_password(smb2, ask_password(user));
    }
    if (smb2_connect_share(smb2, url->server, url->share, user) < 0) die(smb2, "connect");
    *path = strdup(url->path ? url->path : "");
    if (sharepath) *sharepath = strdup(url->share);
    smb2_destroy_url(url);
    return smb2;
}

static const char *base_name(const char *p)
{
    const char *s = strrchr(p, '/');
    return s ? s + 1 : p;
}

static void fmt_size(uint64_t n, char *out, size_t len)
{
    if (n >= (1ull << 30)) snprintf(out, len, "%.1fG", n / 1073741824.0);
    else if (n >= (1u << 20)) snprintf(out, len, "%.1fM", n / 1048576.0);
    else if (n >= 1024) snprintf(out, len, "%.1fK", n / 1024.0);
    else snprintf(out, len, "%" PRIu64, n);
}

static int cmd_ls(const char *url)
{
    char *path; struct smb2_context *smb2 = open_url(url, &path, NULL);
    struct smb2dir *dir = smb2_opendir(smb2, path);
    struct smb2dirent *e;
    if (!dir) die(smb2, "opendir");
    while ((e = smb2_readdir(smb2, dir))) {
        char sz[32], when[32]; time_t m = (time_t)e->st.smb2_mtime; struct tm tm;
        if (!strcmp(e->name, ".") || !strcmp(e->name, "..")) continue;
        fmt_size(e->st.smb2_size, sz, sizeof sz);
        localtime_r(&m, &tm); strftime(when, sizeof when, "%Y-%m-%d %H:%M", &tm);
        printf("%c %8s  %s  %s%s\n", e->st.smb2_type == SMB2_TYPE_DIRECTORY ? 'd' : e->st.smb2_type == SMB2_TYPE_LINK ? 'l' : '-',
               e->st.smb2_type == SMB2_TYPE_DIRECTORY ? "" : sz, when, e->name, e->st.smb2_type == SMB2_TYPE_DIRECTORY ? "/" : "");
    }
    smb2_closedir(smb2, dir); smb2_disconnect_share(smb2); smb2_destroy_context(smb2);
    return 0;
}

static void progress(const char *what, uint64_t done, uint64_t total, time_t start)
{
    char a[32], b[32]; time_t el = time(NULL) - start; char r[32];
    if (quiet) return;
    fmt_size(done, a, sizeof a); fmt_size(total, b, sizeof b);
    fmt_size(el ? done / el : done, r, sizeof r);
    fprintf(stderr, "\r%s %s / %s  %s/s   ", what, a, b, r);
}

static int cmd_get(const char *url, const char *local)
{
    char *path; struct smb2_context *smb2 = open_url(url, &path, NULL);
    struct smb2fh *fh = smb2_open(smb2, path, O_RDONLY);
    struct smb2_stat_64 st; uint32_t chunk; uint8_t *buf; int fd = 1, n; uint64_t done = 0; time_t last = 0, start = time(NULL);
    if (!fh) die(smb2, "open");
    if (smb2_fstat(smb2, fh, &st) < 0) die(smb2, "stat");
    if (!local) local = base_name(path);
    if (strcmp(local, "-") && (fd = open(local, O_WRONLY | O_CREAT | O_TRUNC, 0666)) < 0) die(NULL, local);
    chunk = smb2_get_max_read_size(smb2); if (chunk > 1048576) chunk = 1048576;
    buf = malloc(chunk);
    while ((n = smb2_read(smb2, fh, buf, chunk)) > 0) {
        if (write(fd, buf, n) != n) die(NULL, "write");
        done += n;
        if (time(NULL) != last) { last = time(NULL); progress("get", done, st.smb2_size, start); }
    }
    if (n < 0) die(smb2, "read");
    progress("get", done, st.smb2_size, start); if (!quiet) fputc('\n', stderr);
    if (fd != 1) close(fd);
    smb2_close(smb2, fh); smb2_disconnect_share(smb2); smb2_destroy_context(smb2);
    return 0;
}

static int cmd_put(const char *local, const char *url)
{
    char *path; struct smb2_context *smb2 = open_url(url, &path, NULL);
    struct stat st; int fd = open(local, O_RDONLY); uint32_t chunk; uint8_t *buf; int n; uint64_t done = 0; time_t last = 0, start = time(NULL);
    struct smb2fh *fh; char *full;
    if (fd < 0) die(NULL, local);
    fstat(fd, &st);
    if (!*path || path[strlen(path) - 1] == '/') {   /* directory: keep the local name */
        full = malloc(strlen(path) + strlen(base_name(local)) + 1);
        sprintf(full, "%s%s", path, base_name(local));
    } else full = path;
    fh = smb2_open(smb2, full, O_WRONLY | O_CREAT | O_TRUNC);
    if (!fh) die(smb2, "open");
    chunk = smb2_get_max_write_size(smb2); if (chunk > 1048576) chunk = 1048576;
    buf = malloc(chunk);
    while ((n = read(fd, buf, chunk)) > 0) {
        int off = 0;
        while (off < n) {
            int w = smb2_write(smb2, fh, buf + off, n - off);
            if (w < 0) die(smb2, "write");
            off += w;
        }
        done += n;
        if (time(NULL) != last) { last = time(NULL); progress("put", done, st.st_size, start); }
    }
    progress("put", done, st.st_size, start); if (!quiet) fputc('\n', stderr);
    close(fd); smb2_close(smb2, fh); smb2_disconnect_share(smb2); smb2_destroy_context(smb2);
    return 0;
}

static int cmd_simple(const char *cmd, const char *url, const char *arg2)
{
    char *path; struct smb2_context *smb2 = open_url(url, &path, NULL);
    int r = 0;
    if (!strcmp(cmd, "rm")) r = smb2_unlink(smb2, path);
    else if (!strcmp(cmd, "rmdir")) r = smb2_rmdir(smb2, path);
    else if (!strcmp(cmd, "mkdir")) r = smb2_mkdir(smb2, path);
    else if (!strcmp(cmd, "mv")) r = smb2_rename(smb2, path, arg2[0] == '/' ? arg2 + 1 : arg2);
    else if (!strcmp(cmd, "stat")) {
        struct smb2_stat_64 st; char when[32]; time_t m; struct tm tm;
        r = smb2_stat(smb2, path, &st);
        if (r == 0) {
            m = (time_t)st.smb2_mtime; localtime_r(&m, &tm); strftime(when, sizeof when, "%Y-%m-%d %H:%M:%S", &tm);
            printf("type: %s\nsize: %" PRIu64 "\nmodified: %s\n", st.smb2_type == SMB2_TYPE_DIRECTORY ? "directory" : st.smb2_type == SMB2_TYPE_LINK ? "link" : "file", st.smb2_size, when);
        }
    } else if (!strcmp(cmd, "df")) {
        struct smb2_statvfs v; r = smb2_statvfs(smb2, path, &v);
        if (r == 0) {
            char t[32], f[32];
            fmt_size(v.f_blocks * v.f_frsize, t, sizeof t); fmt_size(v.f_bavail * v.f_frsize, f, sizeof f);
            printf("total: %s\nfree: %s\n", t, f);
        }
    }
    if (r < 0) die(smb2, cmd);
    smb2_disconnect_share(smb2); smb2_destroy_context(smb2);
    return 0;
}

static void usage(void)
{
    fprintf(stderr,
        "Usage: smb [-v 2|3] [-u USER] [-d DOMAIN] [-q] COMMAND ARGS\n"
        "  ls URL | get URL [LOCAL|-] | put LOCAL URL | rm URL | mkdir URL | rmdir URL | mv URL NEWPATH | stat URL | df URL\n"
        "  URL: smb://host[:port]/share/path   (password: $SMB_PASSWORD or prompt; no user = guest)\n");
    exit(2);
}

int main(int argc, char **argv)
{
    int c;
    while ((c = getopt(argc, argv, "+v:u:d:qh")) != -1) {
        switch (c) {
        case 'v': opt_version = atoi(optarg); if (opt_version != 2 && opt_version != 3) usage(); break;
        case 'u': opt_user = optarg; break;
        case 'd': opt_domain = optarg; break;
        case 'q': quiet = 1; break;
        default: usage();
        }
    }
    argc -= optind; argv += optind;
    if (argc < 2) usage();
    if (!strcmp(argv[0], "ls") && argc == 2) return cmd_ls(argv[1]);
    if (!strcmp(argv[0], "get") && argc >= 2 && argc <= 3) return cmd_get(argv[1], argc == 3 ? argv[2] : NULL);
    if (!strcmp(argv[0], "put") && argc == 3) return cmd_put(argv[1], argv[2]);
    if (!strcmp(argv[0], "mv") && argc == 3) return cmd_simple("mv", argv[1], argv[2]);
    if (argc == 2 && (!strcmp(argv[0], "rm") || !strcmp(argv[0], "rmdir") || !strcmp(argv[0], "mkdir") ||
                      !strcmp(argv[0], "stat") || !strcmp(argv[0], "df")))
        return cmd_simple(argv[0], argv[1], NULL);
    usage();
    return 2;
}
