# YouTube na N900: stav klientů (rešerše 2026-11-05)

**Ověřeno ve Workshopu (2026-11-05):** `yt-dlp` 2026.10.26 (z PyPI, `pip install --target build/pylibs yt-dlp yt-dlp-ejs`) s naším **QuickJS** (`apps/quickjs`, pod `qemu-arm`)
vypíše formáty videa i stáhne soubor: `[youtube] [jsc:quickjs] Solving JS challenges using quickjs`, výsledek platné MP4 (formát 18, H.264 + AAC, 240p až 360p).
Na samotném telefonu zatím neběželo. Webové zdroje o starých klientech jsou z let 2010 až 2014, aktuální vlákna jsem nenašel.
Příkaz ve Workshopu: `PYTHONPATH=build/pylibs python3 -m yt_dlp --js-runtimes quickjs:/project/build/bin/qjs -f 18 URL` (`build/bin/qjs` je obálka `qemu-arm -L sysroot qjs`).

## Dřívější klienty
| Klient | Stav |
|---|---|
| **cuteTube** (Qt, autor marxoft; [vlákno](https://talk.maemo.org/showthread.php?t=65854), zdroje na GitHubu marxoft: qyoutube a cutetube2) | Nejlepší klient pro Maemo 5. Závisí na knihovně qyoutube, která dešifruje adresy videí z `base.js` přehrávače. YouTube ji mění, takže se opakovaně rozbila (opravy: pull requesty #1 až #4 u qyoutube, regulár pro dešifrování se musel měnit). Dnes pravděpodobně nefunguje. |
| **MediaBox** (plugin YouTube) | V novějších vláknech hlášeno „nic nefunguje (YouTube, MediaBox, cuteTube)“. Zdroj pluginu jsem nenašel. |
| **Minitube**, **MyTube**, Flash ve webovém prohlížeči | Z doby 2010 až 2011, přes zrušené API nebo Flash. Mrtvé. |

## Zdrojové kódy a patch
Ano, cuteTube i qyoutube mají zdrojové kódy na GitHubu (marxoft). Oprava ale není jednorázová: YouTube dnes vyžaduje spuštění JavaScriptu
přehrávače (výzvy `n`/`sig`) a tokeny. Zastaralou Qt knihovnu na tohle opravovat nemá smysl, protože údržba je neustálý závod.

## Realistická cesta: yt-dlp + přehrávač
Extrakci dělá **yt-dlp**, který se aktualizuje několikrát týdně, a na telefonu zůstane jen přehrávač (mpv, mplayer, gst jsou na telefonu):
- yt-dlp dnes potřebuje **Python 3.10+** (máme 3.11.18 včetně `pip`, `ssl` s TLS 1.3, `ctypes`, `lzma`) a pro YouTube **externí JavaScriptový běh** (Deno, Node 20+, Bun, nebo QuickJS) plus balíček `yt-dlp-ejs`.
  Deno, Node ani Bun pro armel glibc 2.5 neexistují. **QuickJS** je malý program v C a dá se přeložit stejným postupem jako ostatní aplikace (kandidát na `make quickjs`).
- N900 přehraje spolehlivě jen H.264 do 480p (DSP). yt-dlp se volí formátem, například `-f "best[height<=480][ext=mp4]"`.
- Rozhraní: skript ve stylu mutt-hildon (Hildon, hledání, seznam, přehrání), nebo bez rozhraní jen odkaz z prohlížeče do `yt-dlp` a mpv.
- Alternativa bez JavaScriptu: instance **Invidious** nebo **Piped** na domácím serveru jako zdroj (ne přímo YouTube), pak by stačil HTTPS klient. Spolehlivost těchto projektů v roce 2026 jsem neověřil.

## Navržený postup
1. ~~Ověřit yt-dlp s QuickJS~~ hotovo ve Workshopu. Dál: nainstalovat `quickjs` a yt-dlp (`pip` z našeho Pythonu 3.11, přibližně 5 MB) na telefon a stáhnout testovací video tam.
2. ~~Přeložit QuickJS~~ hotovo (`make quickjs`).
3. Přehrání 480p přes mpv/mplayer s kontrolou plynulosti.
4. Hildon rozhraní přes ctypes ([hildon-python3.md](hildon-python3.md)).
