TEST_NAME=abuse
need_pkg abuse
ok binary-present test -x /opt/abuse/bin/abuse
ok no-missing-libs sh -c '! ldd /opt/abuse/bin/abuse 2>&1 | grep -q "not found"'
ok game-data sh -c 'test -d /opt/abuse/share/games/abuse && test -n "$(ls /opt/abuse/share/games/abuse | head -1)"'
ok link-in-path sh -c 'command -v abuse >/dev/null'
ok menu-entry test -f /usr/share/applications/hildon/abuse.desktop
# the game needs a screen: with a display it must stay running for a few seconds
if [ -n "${DISPLAY:-}" ]; then
    ok starts sh -c 'abuse -nosound >/dev/null 2>&1 & p=$!; sleep 6; kill -0 $p; r=$?; kill $p 2>/dev/null; exit $r'
else
    skip starts "no X display here: start Abuse from the menu on the phone"
fi
summary
