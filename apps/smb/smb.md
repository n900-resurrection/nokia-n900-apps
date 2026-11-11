# smb 0.1 for Maemo 5

A small SMB2/SMB3 client (`smb`) on [libsmb2](https://github.com/sahlberg/libsmb2) 6.3 (LGPL-2.1, linked statically, no Kerberos). The phone kernel (2.6.28) has no `cifs`, so shares cannot be mounted;
this tool copies files and manages them over the network. SMB 1 is not supported on purpose.

```sh
make -C apps/smb install     # build (when out of date), deb, scp, dpkg -i
make -C apps/smb test        # 7 tests on the phone (usage and errors, no server needed)

smb -u alice ls  smb://nas/share/photos/
smb -u alice get smb://nas/share/photos/a.jpg            # to ./a.jpg  (or: get URL LOCAL, get URL -)
smb -u alice put /home/user/MyDocs/DCIM/b.jpg smb://nas/share/photos/
smb -u alice mkdir | rm | rmdir | stat | df  smb://nas/share/path
smb -u alice mv smb://nas/share/old.txt new/name.txt     # second argument is a path inside the share
```

- URL: `smb://[domain;][user@]host[:port]/share/path`, options after `?`: `vers=3`, `seal` (SMB 3 encryption), `sign`, `sec=ntlmssp`. Flags `-v 2|3`, `-u USER`, `-d DOMAIN`, `-q` (no progress) go before the command.
- Password: `$SMB_PASSWORD`, or `$NTLM_USER_FILE` (libsmb2: lines `domain:user:password`), otherwise it is asked on the terminal without echo. Never put it into the URL or arguments. Without a user the connection is a guest one.
- Authentication is NTLMSSP (NTLMv2). Servers that require Kerberos only are not supported.
- Installs to `/opt/smb`, link `/usr/bin/smb`. Source of the client: [smb.c](smb.c); the library is built by [build-lib.sh](build-lib.sh) (with [endian-compat.h](endian-compat.h): glibc 2.5 has no `htobe32` and friends).

## Verified

- Against Samba 4.19 (Ubuntu 24.04) in the Workshop, the ARM binary under qemu-user: `ls`, `get` and `put` of a 3 MB file (checksum compared), `mkdir`, `mv`, `stat`, `rm`, `rmdir`, `df`, with SMB 2 and SMB 3, a wrong password is reported as `STATUS_LOGON_FAILURE`.
- On the phone: installation and the 7 offline tests.

## Not verified yet

- A real transfer from the phone to a server on the LAN (NAS, Windows share), speed on the phone CPU, SMB 3 encryption and signing against a real server, guest access.
- `shares` (listing the shares of a server) is missing; the share name must be known.
