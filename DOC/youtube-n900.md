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


## gPodder 2.20.3 with yt-dlp (2026-11-06)
The old YouTube code of gPodder (get_video_info) no longer works and the Python 2.5 of the N900 speaks TLS 1.0 only, so `apps/gpodder/ytdlp.patch` adds the module `gpodder/ytdlp.py`:
- **HTTPS through curl 8** (`/opt/curl/bin/curl`, package `curl`): feeds (`feedcore.py`) and downloads of episodes (`download.py`, with resume and progress for the GUI). Plain HTTP stays with urllib.
- **YouTube through yt-dlp** (`~/.local/bin/yt-dlp --js-runtimes quickjs:/usr/bin/qjs`, format `18/b[height<=480][ext=mp4]/...`): `youtube.py` resolves a watch link to the direct URL; a download then goes through curl. Links with `https://`, `youtu.be`, `shorts` are recognised.
- yt-dlp writes temporary files while it solves the JavaScript challenge; the `/tmp` of the phone is a 1 MB tmpfs ("No space left on device"), so `TMPDIR=~/.gpodder/tmp` is set for it.
- Checked on the phone (Python 2.5, without installing the package): the https feed of a YouTube channel (atom10, parsed by feedparser), resolving a video and downloading it (MP4, 629 kB). Checked in the emulator (`make emulator`) the same plus the GUI start.
- Not done: streaming (the media player cannot use the https URL, so download first and then play), playing the downloaded file (MAFW is mocked in the emulator, so only the real phone can tell), the "Add podcast" dialog with a YouTube URL in the GUI.

## Decision: YouTube on the phone stays minimal (2026-11-06)
Measured on the N900 (256 MB RAM, ARM Cortex-A8): yt-dlp needs **257 s and 260 s** to resolve one video, because QuickJS solves the JavaScript challenge of YouTube and holds over 110 MB (the phone swaps).
A cache (`--cache-dir`) does not help: the second run took as long and no cache files appeared. Clients that need no JavaScript do not work today (checked on the PC with yt-dlp 2026.10.26):
`android_vr` returns a URL (itag 18) that YouTube refuses with HTTP 403, even for yt-dlp itself; `ios`, `mweb`, `web_safari` return "No video formats found"; `tv` returns "page needs to be reloaded".
So the phone does not stream YouTube any more: the stream through the local curl proxy works for podcasts and any https media, but resolving a YouTube link would freeze gPodder for minutes.
- **gPodder 2.20.3-2maemo4:** playing a YouTube episode that is not downloaded shows "Resolving a YouTube link takes several minutes on this device. Please download the video first and play it afterwards." and does nothing else.
- **Downloading works** in the background (download threads of gPodder); slow, but it needs no attention. The downloaded MP4 plays in the media player.
- **Further plan:** no more YouTube development on the phone. YouTube goes to a server (yt-dlp downloads channels into the Jellyfin library) and the phone plays from Jellyfin, see [TODO.md](../TODO.md).
