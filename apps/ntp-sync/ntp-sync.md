# ntp-sync

Nastaví systémové hodiny a RTC přes NTP pomocí `ntpd` z BusyBoxu na telefonu.

## Proč
Volba "automatický čas" v nastavení Maemo 5 nepoužívá NTP, ale čas operátora (NITZ přes GSM modem, `clockd`,
`CLOCKD_NET_TIME=yes`). Bez SIM karty nebo sítě operátora proto nefunguje, nejde o mrtvé servery. Baterie RTC bývá
vybitá, takže po restartu je čas špatně. Špatný čas rozbije ověření TLS certifikátů.

## Použití
```sh
ntp-sync -n     # jen dotaz, ukáže odchylku (čas nemění)
ntp-sync        # nastaví čas a zapíše RTC (hwclock -w), jako root
ntp-sync -h     # nápověda
```
- Servery: `/etc/ntp-sync.conf` (jeden na řádek) nebo proměnná `NTP_SERVERS`. Výchozí `pool.ntp.org`, `time.cloudflare.com`, `time.google.com`.
- Hák `/etc/network/if-up.d/ntp-sync` spustí synchronizaci na pozadí po připojení sítě, nejvýše jednou za 10 minut
  (časová značka `/var/run/ntp-sync.stamp`). Zpětný skok hodin značku ignoruje.
- Skript běží minimálně 60 s, pokud žádný server neodpoví, skončí s chybou (1).

## Sestavení
```sh
make -C apps/ntp-sync install     # kontrola syntaxe, balíček a instalace
```
Man stránka `ntp-sync.1` je v balíčku, ale na N900 se nezobrazí: chybí `nroff` a Maemo `/usr/share/man` maže (`docpurge`).
Použij `ntp-sync -h`. Na počítači: `man ./apps/ntp-sync/ntp-sync.1`.

## Ověřeno (2026-11-05)
Hodiny posunuty o 5 minut zpět, `ntp-sync` je opravil (offset +300 s), RTC zapsáno, hák po ručním spuštění doběhl.
Neověřeno: že hák spustí systém při skutečném připojení k Wi-Fi.
