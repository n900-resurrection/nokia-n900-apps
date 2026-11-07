# Shared helpers of apps/<app>/make-icon.sh (source it, do not run it): the common look of the icons of the console packages.
# Each application draws its own icon in apps/<app>/make-icon.sh -> apps/<app>/icon.png (256x256, ImageMagick on the host).
# package.sh passes the PNG to debpack_desktop, which makes the 48x48 and 64x64 files. The PNGs are committed;
# run `apps/<app>/make-icon.sh` only to change the design.
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf
BASE='#26323f'      # the dark rounded square of mutt-hildon

# icon_base <convert arguments...> <output.png>: dark rounded square, then the drawing of the application
icon_base() { convert -size 256x256 xc:none -fill "$BASE" -draw 'roundrectangle 8,8 247,247 44,44' "$@"; }
