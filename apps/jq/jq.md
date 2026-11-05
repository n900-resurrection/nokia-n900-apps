# jq 1.8 pro Maemo 5

JSON procesor (filtry, transformace). Potřebný například pro Audiobookshelf API.

```sh
make -C apps/jq install      # build (když je zastaralý), deb, scp, dpkg -i
make -C apps/jq test         # 9 testů na telefonu
echo '{"a":[1,2]}' | jq -c '.a|map(.*2)'      # [2,4]
```
- Instaluje do `/opt/jq`, odkaz `/usr/bin/jq`. Regulární výrazy: oniguruma je součástí zdrojů a je zalinkovaná staticky.
- Dokumentace (manuál) se nestaví (potřebuje ruby). Použij `jq --help` nebo https://jqlang.org/manual/.
- Chybný JSON: návratový kód 5 (ne 2).
