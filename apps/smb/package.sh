#!/bin/bash
# Package the built smb client as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/smb deb
# Output: /project/build/deb/smb_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=smb
VERSION="${VERSION:-0.1}"
LIBVERSION="${LIBVERSION:-6.3}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/src/libsmb2-libsmb2-$LIBVERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/$PKG" ] || { echo "Missing $OUT/$PKG, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/$PKG" "$STAGE/opt/$PKG/bin/$PKG"
ln -s "../../opt/$PKG/bin/$PKG" "$STAGE/usr/bin/$PKG"
install -m 644 "$SRC/LICENCE-LGPL-2.1.txt" "$STAGE/opt/$PKG/share/doc/$PKG/COPYING.libsmb2"
install -m 644 "$PROJ/apps/smb/smb.c" "$STAGE/opt/$PKG/share/doc/$PKG/smb.c"
cat > "$STAGE/opt/$PKG/share/doc/$PKG/README" <<DOC
smb $VERSION: small SMB2/SMB3 client for Maemo 5.
It is statically linked with libsmb2 $LIBVERSION (LGPL-2.1, https://github.com/sahlberg/libsmb2).
The source of the client (smb.c) is in this directory; to relink against another libsmb2, build smb.c with it.
DOC

SECTION=user/network
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="SMB client"
SHORT_DESC="SMB2/SMB3 command-line client (ls, get, put, ...)"
LONG_DESC="Small client for Windows/Samba/NAS shares over SMB 2 and 3 (NTLMSSP, signing and
encryption of SMB 3), built on libsmb2 $LIBVERSION and statically linked. Commands: ls, get,
put, rm, mkdir, rmdir, mv, stat, df. No SMB 1 and no kernel mount (the kernel has no cifs).
Usage: smb ls smb://host/share/ ; smb -u user get smb://host/share/file"
debpack_build
