Acme is a programmer's text editor, shell, and user interface. It runs on a virtualized operating system, Inferno, that runs hosted on Windows, Linux, Solaris, and MacOSX.

See this video for a nice walk through of Acme: https://www.youtube.com/watch?v=dP1xVpMPn8M

You can build the limbo source tree from inside acme: 
```
	% cd /appl/ 
	% mk install
```

To build the acme runtime `emu`  follow these steps on the host command line

```
	% ./makemk.sh
	% mk install
```

The `mk` command will build all the C libraries and inferno emulator. 