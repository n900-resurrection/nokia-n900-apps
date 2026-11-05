TEST_NAME=bash5
need_pkg bash5
b() { bash5 -c "$@"; }
t version 5 b 'echo ${BASH_VERSINFO[0]}'
# $$ is expanded by bash5 itself; a lone command would be exec'ed (and readlink would report itself), hence the variable.
t binary /opt/bash5/bin/bash b 'p=$(readlink /proc/$$/exe); echo $p'
t assoc-array 2 b 'declare -A m=([a]=1 [b]=2); echo ${m[b]}'
t mapfile 3 b 'mapfile -t x < <(printf "a\nb\nc\n"); echo ${#x[@]}'
t printf-time "$(date +%F)" b 'printf "%(%F)T\n" -1'
t transform-U ABC b 'v=abc; echo ${v@U}'
t nameref 5 b 'a=5; declare -n r=a; echo $r'
t wait-n 0 b 'sleep 1 & sleep 2 & wait -n; echo $?'
t coproc HI b 'coproc C { tr a-z A-Z; }; echo hi >&${C[1]}; exec {C[1]}>&-; read -u ${C[0]} x; echo $x'
t globstar yes b 'shopt -s globstar; mkdir -p /tmp/gs/d/e; touch /tmp/gs/d/e/f.txt; cd /tmp/gs; set -- d/**/*.txt; [ "$1" = d/e/f.txt ] && echo yes; rm -r /tmp/gs'
t array-slice "b c" b 'x=(a b c d); echo "${x[*]:1:2}"'
t regex-match bc b '[[ abcd =~ (b.) ]] && echo ${BASH_REMATCH[1]}'
t pipestatus 3 b 'f(){ return 3; }; f | cat; echo ${PIPESTATUS[0]}'
t trap TRAPPED b 'trap "echo TRAPPED; exit 0" TERM; kill -TERM $$; sleep 1'
t shebang-script 5 sh -c 'printf "#!/usr/bin/bash5\necho \${BASH_VERSINFO[0]}\n" > /tmp/s5.sh; chmod +x /tmp/s5.sh; /tmp/s5.sh; rm /tmp/s5.sh'
t system-bash-untouched 3 sh -c '/bin/bash -c "echo \${BASH_VERSINFO[0]}"'
summary
