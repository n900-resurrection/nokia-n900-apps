TEST_NAME=quickjs
need_pkg quickjs
contains version-runs "console" qjs -e 'console.log(typeof console)'
t arithmetic 2 qjs -e 'console.log(1+1)'
t bigint 1180591620717411303424 qjs -e 'console.log(String(2n**70n))'
t json '[2,4,6]' qjs -e 'console.log(JSON.stringify([3,1,2].sort().map(x => x*2)))'
t regexp-named-group 2026 qjs -e 'console.log(/(?<y>\d{4})-\d\d/.exec("on 2026-11").groups.y)'
t private-field 5 qjs -e 'class A { #p = 5; get p() { return this.#p } }; console.log(new A().p)'
t unicode 4 qjs -e 'console.log([..."žluť"].length)'
t exit-code 3 sh -c 'qjs --std -e "std.exit(3)" 2>/dev/null; echo $?'
t stdin-script 42 sh -c 'echo "console.log(6*7)" | qjs /dev/stdin'
t perf-3M-loop-under-60s ok sh -c 'start=$(date +%s); qjs -e "let s=0; for (let i=0;i<3e6;i++) s+=i%7;"; [ $(( $(date +%s) - start )) -lt 60 ] && echo ok'
summary
