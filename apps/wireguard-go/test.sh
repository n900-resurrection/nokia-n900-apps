TEST_NAME=wireguard-go
need_pkg wireguard-go
ok in-path sh -c 'command -v wireguard-go && command -v wg && command -v wg-n900'
ok no-missing-libs sh -c '! ldd /opt/wireguard-go/bin/wg 2>&1 | grep -q "not found"'
t version-go 'wireguard-go v0.0.20250522' sh -c 'wireguard-go --version | head -1 | cut -d" " -f1,2'
# key generation and the key pair relation: no network device is created
ok genkey-pubkey sh -c 'k=$(wg genkey) && test "$(echo $k | wc -c)" -eq 45 && echo $k | wg pubkey | grep -qE "^[A-Za-z0-9+/]{43}=$"'
ok genpsk sh -c 'test "$(wg genpsk | wc -c)" -eq 45'
ok helper-usage sh -c 'wg-n900 2>&1 | grep -q usage'
summary
