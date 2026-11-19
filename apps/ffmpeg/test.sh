TEST_NAME=ffmpeg
need_pkg ffmpeg
D=$(mktemp -d /home/user/ffmpeg-test.XXXXXX)
contains version "ffmpeg version 9" ffmpeg -version
contains h264-decoder "h264" ffmpeg -hide_banner -decoders
contains aac-decoder " aac " ffmpeg -hide_banner -decoders
contains mp4-demuxer "mov,mp4" ffmpeg -hide_banner -demuxers
# a test video made on the phone: 25 black frames 64x64 (raw) -> MPEG-4 in MP4 -> decoded again
t encode-mp4 0 sh -c "head -c 153600 /dev/zero | ffmpeg -v error -y -f rawvideo -pix_fmt yuv420p -s 64x64 -r 25 -i pipe:0 -c:v mpeg4 $D/t.mp4; echo \$?"
t frames-decoded 25 sh -c "ffmpeg -v error -i $D/t.mp4 -map 0:v -c:v rawvideo -f null pipe:1 -stats 2>&1 | tr '\r' '\n' | grep -o 'frame= *[0-9]*' | tail -1 | tr -dc 0-9"
t remux-copy 0 sh -c "ffmpeg -v error -y -i $D/t.mp4 -c copy -movflags +faststart $D/r.mp4; echo \$?"
t missing-file-fails 254 sh -c "ffmpeg -v quiet -i $D/none.mp4 -f null - ; echo \$?"
rm -rf "$D"
summary
