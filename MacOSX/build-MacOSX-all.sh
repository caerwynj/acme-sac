#!/dis/sh.dis
load std; autoload=std

cd /sys
run /sys/MacOSX/386/profile
mk nuke install clean

run /sys/MacOSX/power/profile 
mk nuke install
cd /sys/emu/MacOSX
mk -f mkfile-x nuke
mk -f mkfile-x install clean

cd /sys
mk nuke
