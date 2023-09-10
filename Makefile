# Makefile exists for snap
#
ROOT=/home/pi/github/acme-sac
objtype=arm

all: utils/mk/mk
	./utils/mk/mk install

mk: makemk.sh
	./makemk.sh
