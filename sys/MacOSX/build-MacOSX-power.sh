#!/dis/sh.dis
load std; autoload=std

cd /sys
run /sys/MacOSX/Power/profile
mk nuke
mk install && mk clean
