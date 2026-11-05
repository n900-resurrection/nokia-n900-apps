TEST_NAME=jq
need_pkg jq
contains version "jq-1.8" jq --version
t filter-map '[2,4]' sh -c 'echo "{\"a\":[1,2]}" | jq -c ".a|map(.*2)"'
t regex-oniguruma true sh -c 'echo "\"abc\"" | jq "test(\"a.c\")"'
t base64 '"aGVsbG8="' sh -c 'echo "\"hello\"" | jq "@base64"'
t sort-by '["a","b","c"]' sh -c 'echo "[{\"k\":\"b\"},{\"k\":\"c\"},{\"k\":\"a\"}]" | jq -c "sort_by(.k)|map(.k)"'
t raw-output hello sh -c 'echo "{\"s\":\"hello\"}" | jq -r .s'
t invalid-json-fails 5 sh -c 'echo "{" | jq . >/dev/null 2>&1; echo $?'
t unicode 'č' sh -c 'echo "\"\\u010d\"" | jq -r .'
summary
