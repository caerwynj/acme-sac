cwd=`pwd`
export ACME_HOME=`dirname $cwd`
PATH=$PATH:$cwd/Linux/cmd
mkdir -p lib
cd lib9
./build.sh
cd ../libdraw
./build.sh
cd ../libinterp
./build.sh
cd ../libkeyring
./build.sh
cd ../libmath
./build.sh
cd ../libmemdraw
./build.sh
cd ../libmemlayer
./build.sh
cd ../libmp
./build.sh
cd ../libsec
./build.sh
cd ../emu/Linux
./build.sh

