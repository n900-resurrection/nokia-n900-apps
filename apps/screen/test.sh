TEST_NAME=screen
need_pkg screen
export TERM=xterm
ok in-path sh -c 'command -v screen'
ok no-missing-libs sh -c '! ldd /opt/screen/bin/screen 2>&1 | grep -q "not found"'
t version 'Screen version 5.0.2' sh -c 'screen --version | cut -c1-20'
ok new-session sh -c 'screen -dmS stest sleep 30 && sleep 1 && screen -ls | grep -q stest'
ok send-and-hardcopy sh -c 'screen -dmS stest2 sh && sleep 1 && screen -S stest2 -X stuff "echo screen-works\n" && sleep 1 && screen -S stest2 -X hardcopy /home/user/screen-hc.txt && sleep 1 && grep -q screen-works /home/user/screen-hc.txt'
ok quit-sessions sh -c 'screen -S stest -X quit; screen -S stest2 -X quit; sleep 1; ! screen -ls | grep -qE "stest"'
rm -f /home/user/screen-hc.txt
summary
