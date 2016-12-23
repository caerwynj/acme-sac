#!/dis/sh.dis
load std; autoload=std

cd /sys
run /sys/Linux/profile
mk nuke
mk install && mk clean
#rm -rf /tmp/*
