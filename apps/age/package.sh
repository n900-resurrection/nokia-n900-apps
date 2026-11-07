#!/bin/bash
# Package the built age as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/age deb
# Output: /project/build/deb/age_<VERSION>-<REV>_armel.deb   (command line tools: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=age
VERSION="${VERSION:-1.2.1}"
STAGE="$PROJ/build/deb/stage-$PKG"
for b in age age-keygen; do
    [ -x "$PROJ/build/out/$b-$VERSION/$b" ] || { echo "Missing $b in build/out/$b-$VERSION, run build.sh first (make build)"; exit 1; }
done

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/age/bin" "$STAGE/opt/age/share/doc/age" "$STAGE/usr/bin"
for b in age age-keygen; do
    install -m 755 "$PROJ/build/out/$b-$VERSION/$b" "$STAGE/opt/age/bin/$b"
    ln -s "../../opt/age/bin/$b" "$STAGE/usr/bin/$b"
done
LIC=$(ls "$PROJ"/build/go/gopath/pkg/mod/filippo.io/age@v$VERSION/LICENSE 2>/dev/null | head -1)
[ -n "$LIC" ] && install -m 644 "$LIC" "$STAGE/opt/age/share/doc/age/LICENSE"

SECTION=user/utilities
DEPENDS="libc6"
DISPLAY_NAME="age"
SHORT_DESC="age $VERSION simple file encryption (age, age-keygen)"
LONG_DESC="age $VERSION: encrypts files with a passphrase (age -p file > file.age) or for public keys (age-keygen -o key.txt; age -r <public key> file > file.age;
age -d -i key.txt file.age). Small, modern (X25519, ChaCha20-Poly1305), no configuration like gpg. Built for Maemo 5 with Go (static).
Upstream: https://age-encryption.org"
MAINTAINER="elPytel (build of upstream age by Filippo Valsorda and contributors)"
debpack_build
