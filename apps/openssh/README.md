# openssh

OpenSSH 10.6p2 (client and server) for Maemo 5, with a private static OpenSSL 3 and zlib, in `/opt/openssh`. The system OpenSSH is 5.1 from 2009. See the blog post [A modern OpenSSH on the N900](https://n900-resurrection.github.io/) for the ciphers, the configuration and the measured speed.

Build: `make -C apps/openssh build deb` (Workshop). The build patches the rlimit sandbox of OpenSSH (`build.sh`): the kernel 2.6.28 has no seccomp filter, and the sandbox set the limit of open files to 0, which made `poll()` fail with `EINVAL` in the key exchange. The server is configured for **keys only**; the default configuration is `/opt/openssh/etc/sshd_config.default`, copied to `sshd_config` by `postinst` when there is none (your changes to `sshd_config` survive an upgrade).

## Two kinds of the package

| revision | kind | what it does |
|---|---|---|
| `1maemo5` | **parallel** | everything in `/opt/openssh`, the system OpenSSH is not touched. Client as `ssh-modern`, `scp-modern`, `sftp-modern`, `ssh-keygen-modern`. The server is not started (by hand: `/opt/openssh/sbin/sshd`, port **2222**). Brings `openssh-switch`. |
| `1maemo7` | **replacing** | the same files, and it takes the place of `openssh-client`, `openssh-server` and `openssh-common` (`Provides`, `Replaces`, `Conflicts`: dpkg **removes the old packages** when it installs this one). `/usr/bin/ssh` and the others are links into `/opt/openssh`, the upstart job `/etc/event.d/sshd` starts the new server on port **22** (and starts it again when it dies), `/etc/init.d/ssh` stays for the SSH switch of gothi (`start`/`stop` go through the job). |

The kind is chosen by the number of the revision (`package.sh`): `make deb REV=1maemo7` builds the replacing one. Not included in either: `ssh-keyscan`, `ssh-copy-id`, `ssh-keysign`.

## Moving from the old server to the new one

Prerequisite: your public key in `/home/user/.ssh/authorized_keys` and/or `/root/.ssh/authorized_keys` (passwords are refused), and the parallel package installed.

1. **Check** (changes nothing): `openssh-switch check`. It tests the configuration for port 22 (`sshd -t`, the host keys), counts the authorized keys, checks that passwords are off, and that the old server is the upstart job `sshd`.
2. **Backup** of the files of the old OpenSSH: `openssh-switch backup` writes `/root/ssh-5.1-backup.tgz` (mode 600: `/etc/ssh` holds the private host keys, which is why it is not on the memory card). `trial` makes it when it is missing.
3. **Trial with a safety timer**: `openssh-switch trial` (180 s, or `trial 300`). It starts the timer first, then stops the old server (`stop sshd`) and starts the new one on port 22. **Running sessions stay.** Open a second terminal at once and log in (as `user` and as `root` with a key), try `scp`/`sftp`. If you do nothing, or the new server does not start or does not hold the port, the old one comes back by itself (`start sshd`).
4. **Confirm**: `openssh-switch confirm` keeps the new server and stops the timer. This lasts only **until the next reboot** (the upstart job still starts the old server), which is deliberate: a mistake cannot survive a restart.
5. **Replace the old packages**: install the replacing package (`1maemo7`). dpkg removes `openssh-client`, `-server` and `-common`; its `postinst` stops the server of the trial, runs `sshd -t` and **only if the configuration passes** starts the upstart job (a broken configuration is not started, with a warning). From then on the new server is started by upstart at every boot.

`openssh-switch status` shows what listens on the port, which server it is and what the timer is doing; `openssh-switch revert` puts the old server back by hand.

**If something goes wrong after step 5** and you still have a session: `openssh-switch restore` unpacks the backup over the system and starts the old server (the old dpkg entries are gone, so the files come back without packages; reinstall the old packages when the network allows). If the new package is installed but no server runs, `start sshd` (and `sshd -t` tells what is wrong).

## Tests

- `bash tests/test_switch.sh`: the script against fake `start`, `stop`, `netstat` and a fake sshd (30 tests: check, backup, trial with and without confirm, the timer bringing the old server back, a server that does not start, restore).
- `bash tests/test_package.sh`: the two `.deb` files: control fields, files and links, the upstart job, the init script, and the logic of `postinst` with fake commands in a temporary tree (45 tests). Build both kinds first.
- `make -C apps/openssh test` on the phone: library check, `sshd -t`, host keys and a real login on the loopback only (port 2299, a throw-away key) that guards the sandbox fix.
- `make -C apps/openssh qemu-test`: sshd, ssh and sftp over loopback under qemu-user.

**Not tested for real:** the replacing package has never been installed on a phone (dpkg removing the old packages, the upstart job taking over at boot). Everything around it is tested with fakes, and the steps before it (the trial) test the same server binary and configuration on the real port 22. Read the steps above before you run the last one.
