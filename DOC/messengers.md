# Instant messaging na N900: Signal, WhatsApp, Messenger (rešerše)

Stav: rešerše z 2026-11-05. Co je označeno **[ověřeno]**, bylo zjištěno na telefonu nebo ve výsledcích
vyhledávání. **[odhad]** je můj úsudek, zatím nevyzkoušený.

## 1. Co už N900 má [ověřeno na telefonu]
- Telepathy: `telepathy-gabble` (Jabber/XMPP), `telepathy-haze` 0.3.2, `telepathy-ring` (GSM), `telepathy-sofiasip` (SIP), `telepathy-spirit` (Skype).
- `libpurple0` a `pidgin` 2.7.7 a `purple-extra-protocols` (balíčky od komunity "nix"). Haze dělá z libpurple pluginů účty
  v systémovém IM (`account-plugin-haze`). To je původní "rozšiřitelnost přes moduly", kterou jsi měl rád.
- `rtcom-messaging-ui` (konverzace v nativním GUI) a `rtcom-accounts-ui` (správa účtů).
- Tím pádem platí: nový protokol = nový libpurple plugin (soubor `.so` v `/opt/maemo/usr/lib/purple-2/`) a účet v nastavení.
  Plugin se ale musí přeložit pro armel a glibc 2.5 proti libpurple 2.7.7 (API purple2).

## 2. Hlavní překážka: TLS
Všechny tři sítě používají moderní TLS. libpurple na telefonu používá NSS nebo OpenSSL 0.9.8 přes svůj ssl plugin, tedy
nejvýše TLS 1.0 **[odhad, ověřit podle `ssl-nss`/`ssl-gnutls` v libpurple]**. Servery TLS 1.0 odmítnou. Proto plugin
zabudovaný do Pidginu bez nové TLS vrstvy nepoběží, i když se přeloží. Stejný problém jako u Modestu (roadmap.md).
Možnosti: (a) plugin si TLS řeší sám a linkuje OpenSSL 3 staticky (hotová knihovna v `build/deps/openssl-3.5.9`),
(b) klient napsaný v Go nebo jiném jazyce s vlastním TLS, (c) vlastní ssl plugin pro libpurple s OpenSSL 3.

## 3. Podle služby

### Signal
- Oficiální klient pro mobil neexistuje mimo Android a iOS. Cizí klienty připojuješ jako "propojené zařízení" (QR kód).
- **gurk-rs**: terminálový klient v Rustu nad knihovnou **presage** (výsledky vyhledávání). Funkční a udržovaný, ale
  Rust a libsignal (Rust) se na ARMv7 s jádrem 2.6.28 překládat musí zvlášť (podobný problém jako u Go: nový std
  vyžaduje nové jádro; nutný bootstrap a cross-kompilace, **[odhad]** proveditelné, ale pracné).
- **libpurple-signald**: plugin nad démonem `signald` (Java, nelze na N900) **[výsledky vyhledávání]**.
- **signal-cli**: Java, odpadá.
- Doporučení: zkusit **gurk-rs** (nebo `presage` demo) po vyzkoušení Rustu na telefonu stejným způsobem jako Go.

### WhatsApp
- Neoficiální protokol, riziko zablokování čísla (WhatsApp to zakazuje v podmínkách).
- **purple-gowhatsapp** (libpurple plugin přes webové rozhraní, je v seznamech pluginů **[výsledky vyhledávání]**), napsaný v Go
  s knihovnou, která už nemusí odpovídat dnešnímu protokolu **[odhad, ověřit stav projektu]**.
- **whatsmeow** (Go knihovna, základ moderních mostů a klientů) **[moje znalost, nepotvrzeno vyhledáním]**.
  Go na N900 už funguje (apps/go), takže vlastní terminálový klient nad whatsmeow je realistický směr.
- Spoléhat se na jednu neoficiální cestu je křehké. Jistější je most na serveru (mautrix-whatsapp), ale ten jsi zatím zamítl.

### Facebook Messenger
- Starý XMPP chat Facebooku byl vypnut. Dnešní cesta je **purple-facebook** (dequis; používá MQTT protokol Messengeru,
  má zpětný port pro purple2, poslední změny v repozitáři 2024 **[výsledky]**). Facebook může účet označit jako podezřelý.
- 2010 návod pro N900 s `libfacebookarm-1.64.so` je zastaralý a nefunguje **[výsledky, starý příspěvek]**.
- Alternativa: mostní řešení (mautrix-meta). Opět server.

### Telegram (zmíněno pro úplnost)
- `telegram-purple` je plugin pro libpurple 2 **[výsledky]**, závisí na vlastní TLS/kryptografii (libgcrypt/OpenSSL), vyžaduje nové build zde.
- Telegram má otevřený protokol, takže klient v Go je také možný.

### Matrix a XMPP
- XMPP už funguje přes Gabble (jen s TLS problémem u moderních serverů, **[odhad]**).
- Matrix (`purple-matrix`) a mosty mautrix pokryjí Signal, WhatsApp i Messenger z jednoho účtu. Přijde to s serverem, který
  jsi pro teď vyloučil. Za rozhodnutí to stojí, protože na telefonu zůstane jediný jednoduchý klient.

## 4. Cesty, od nejlevnější
1. **Pidgin + libpurple na telefonu** (už nainstalované) a dopsat jen plugin. Překlad pluginu pro purple2 a opravit TLS. Dá se začít
   `purple-facebook` a `purple-gowhatsapp`, protože jsou psané pro purple2.
2. **Terminálový klient v Go** (vlastní nebo nad whatsmeow). Moderní TLS a minimální závislosti.
3. **Rust (gurk-rs/presage) pro Signal**, až bude ověřené, že Rust běží na jádru 2.6.28.
4. **BitlBee** (IRC brána, libpurple): lokální bránu na telefonu spustit a připojit libovolný IRC klient (irssi, weechat).
   Je to terminálová cesta, kterou jsi chtěl v první vlně. **[odhad]**
5. Později: nativní Hildon aplikace nebo integrace do rtcom-messaging přes Telepathy.

## 5. První kroky
1. Ověřit TLS vrstvu libpurple na telefonu (který ssl plugin je, jaké verze TLS umí).
2. Zkusit `finch` nebo Pidgin s XMPP účtem proti modernímu serveru, abychom věděli, zda TLS 1.2 funguje.
3. Přeložit purple-facebook (zpětný port purple2) a zkusit přihlášení na testovacím účtu.
4. Rust: hello world pro armv7 a spuštění na telefonu (obdoba testu Go).
5. Rozhodnout o mostu (mautrix + Matrix) podle toho, co z kroků 1-4 vyjde.

## Zdroje
- [Seznam pluginů Pidginu (petermolnar)](https://code.petermolnar.net/petermolnar/awesome-pidgin-plugins)
- [purple-facebook (dequis)](https://github.com/dequis/purple-facebook)
- [telegram-purple (majn)](https://github.com/majn/telegram-purple)
- [gurk-rs](https://github.com/boxdot/gurk-rs) a [presage](https://github.com/whisperfish/presage/)
- [Příspěvek na talk.maemo.org o Facebook pluginu (2010)](https://talk.maemo.org/archive/index.php/t-39331.html)
