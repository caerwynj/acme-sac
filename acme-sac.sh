#!/bin/sh

acmedir=`dirname "$0"`
SYSHOST=MacOSX
OBJTYPE=386
EMU=emu
osMajorVer=`uname -r | cut -f1 -d.`

if ( uname -s | grep -i linux >/dev/null ); then
	SYSHOST=Linux
fi

if ( uname -p | grep -i power >/dev/null ); then
        OBJTYPE=power
fi

if [ "$SYSHOST" = "MacOSX" ] && [ "$osMajorVer" -lt 8 ]; then
	EMU=emu-x11
fi

case `uname -m` in
	armv7l)
		OBJTYPE=arm
		;;
	aarch64)
		OBJTYPE=arm64
		;;
	x86_64)
		OBJTYPE=amd64
		;;
	*)
		break
		;;
esac

case $1 in
	-x|-x11|-X|-X11)
		if [ -f $SYSHOST/$OBJTYPE/bin/emu-x11 ]; then
			EMU=emu-x11
		fi
		shift 1
		;;
	*)
		break
		;;
esac

if [ "$EMU" = "emu-x11" ]; then
	export DISPLAY=":0"
	if [[ $osMajorVer < 9 ]]; then
		open /Applications/Utilities/X11.app
	fi	
fi

cd $acmedir
echo $acmedir/$SYSHOST/$OBJTYPE/bin/$EMU 
./$SYSHOST/$OBJTYPE/bin/$EMU -r $acmedir $*
