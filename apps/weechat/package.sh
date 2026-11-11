#!/bin/bash
# Package the built WeeChat as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/weechat deb
# Output: /project/build/deb/weechat_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=weechat
VERSION="${VERSION:-4.10.4}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/weechat" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/weechat/share/doc/weechat"
cp -a "$OUT/root/." "$STAGE/"
# without headers and the pkg-config file (only needed to build plugins); the stripped binaries
rm -rf "$STAGE/opt/weechat/include" "$STAGE/opt/weechat/lib/pkgconfig"
install -m 755 "$OUT/weechat" "$STAGE/opt/weechat/bin/weechat"
find "$STAGE/opt/weechat/lib" -name "*.so" -exec arm-linux-gnueabi-strip {} +
ln -s "../../opt/weechat/bin/weechat" "$STAGE/usr/bin/weechat"
install -m 644 "$OUT/COPYING" "$STAGE/opt/weechat/share/doc/weechat/COPYING"

SECTION=user/network
DEPENDS="libc6 (>= 2.5), curl"
DISPLAY_NAME="WeeChat"
SHORT_DESC="WeeChat $VERSION chat client (IRC)"
LONG_DESC="WeeChat $VERSION: an extensible chat client in the terminal. Start it in a terminal (weechat), then /server add libera irc.libera.chat/6697 -tls,
/connect libera, /join #channel. /help lists the commands. TLS 1.2/1.3 (GnuTLS, CA bundle of the curl package; keep the phone clock correct, ntp-sync).
Built for Maemo 5 with static GnuTLS, libgcrypt, libcurl and ncursesw (UTF-8); no scripting languages, no relay, no spell checker. Upstream: https://weechat.org"
MAINTAINER="elPytel (build of upstream WeeChat by Sébastien Helleu)"
debpack_build
