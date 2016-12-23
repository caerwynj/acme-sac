#!/dis/sh.dis
load std; autoload=std

cd /sys
run /sys/MacOSX/386/profile
mk nuke
mk install && mk clean
cd /sys/emu/MacOSX
mk -f mkfile-x nuke
mk -f mkfile-x install && mk -f mkfile-x clean
