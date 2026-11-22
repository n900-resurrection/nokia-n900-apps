# copyparty on the N900

A file server in one Python program ([copyparty](https://github.com/9001/copyparty), MIT, by ed): a computer or tablet on the same network
opens the address of the phone in a browser and downloads or uploads files. No software is needed on the other side.

## Use
Menu **File server**, or in a terminal:

```
copyparty-share            # run in the foreground, Ctrl-C stops it
copyparty-share start      # run in the background
copyparty-share stop | status | url | passwd | config
```

It prints the address (one line per network connection that has one, e.g. `http://192.168.1.50:3923/`) and the login. The first start makes
`~/.copyparty/share.conf`: the folder `MyDocs` is shared, the user is `n900`, the password is random (`copyparty-share passwd` makes a new one).
Without the login the server shows nothing.

Settings: edit `~/.copyparty/share.conf` ([format](https://github.com/9001/copyparty#accounts-and-volumes)) and restart. Another
folder = another `[/name]` section with a real path and `accs:` below it. `copyparty --help` lists every option.

## Notes
- The first start after the installation takes a few seconds (the bytecode is compiled by the installer). The server uses about 30 MB of memory, and the phone
  has only 245 MB, so close other applications first.
- Thumbnails, the file index and uploads deduplication are off. A folder in RAM (`/tmp`) is read-only (copyparty protects the data from being lost).
- The server listens on every network connection. It speaks plain HTTP: at home, on a hotspot or over USB networking it is fine, on an open network or
  the internet it is not (the password travels in clear text).
- The package contains the unpacked official release `copyparty-en.py` (checked by SHA-256 when built), not a modified copy.
