TEST_NAME=nplay
need_pkg nplay
need_pkg ffmpeg
D=$(mktemp -d /home/user/nplay-test.XXXXXX)
contains usage "Usage: nplay" sh -c "nplay 2>&1 | head -3"
t no-file-fails 1 sh -c "nplay -b $D/none.mp4 >/dev/null 2>&1; echo \$?"
# a test video made with ffmpeg: 25 black frames 64x64 (MPEG-4), and a silent-less sound-only case
sh -c "head -c 153600 /dev/zero | ffmpeg -v error -y -f rawvideo -pix_fmt yuv420p -s 64x64 -r 25 -i pipe:0 -c:v mpeg4 $D/t.mp4"
contains benchmark-25-frames "25 frames shown, 0 dropped" nplay -b $D/t.mp4
contains skip-start "0 frames shown" nplay -b -s 5 $D/t.mp4
contains two-files "25 frames shown" nplay -b $D/t.mp4 $D/t.mp4
rm -rf "$D"
summary
