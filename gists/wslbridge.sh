#!/bin/bash
# fixed wsl bridge as described here https://stackoverflow.com/questions/58794164/conemu-doesnt-work-with-wsl-since-windows-update
mkdir -p /u/downloads
url="https://github.com/Biswa96/wslbridge2/releases/download/v0.5/wslbridge2_cygwin_x86_64.7z"
/usr/bin/wget "${url}" -O /u/downloads/wslbridge2.7z
url="https://cygwin.com/snapshots/x86_64/cygwin1-20200909.dll.xz"
/usr/bin/wget "${url}" -O /u/downloads/cygwin1.dll.xz
cd /u/downloads
/usr/bin/xz --decompress cygwin1.dll.xz
/usr/bin/7z x wslbridge2.7z
# at this point, the necessary files will be in c:\u\downloads on the windows side
cd "/mnt/c/Program Files/ConEmu/ConEmu/wsl"
mv cygwin1.dll cygwin1.dll.old
cp /u/downloads/cygwin1.dll .
mv /u/downloads/rawpty.exe .
mv /u/downloads/wslbridge2-backend .
mv /u/downloads/wslbridge2.exe .

