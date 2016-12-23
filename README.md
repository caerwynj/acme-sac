Acme is a programmer's text editor, shell, and user interface. It runs on a virtualized operating system, Inferno, that runs hosted on Windows, Linux, Solaris, and MacOSX.

See this video for a nice walk through of Acme: https://www.youtube.com/watch?v=dP1xVpMPn8M

You can build the limbo source tree from inside acme: 

	% cd /appl/ 
	% mk install

To build the Acme.exe follow these steps.

1. Download Install Microsoft Visual Studio Community Edition; include the C++ language package (this is now a custom option).
2. Open a developer command prompt from the Visual Studio start menu folder
3. Launch Acme.exe from inside the command prompt
4. Inside Acme open a command window by clicking the middle mouse button on the word win.
5. At the win command prompt type the following:

	% cd /sys
	% run Nt/profile
	% mk

The mk command will build all the C libraries and inferno emulator. The iacme.exe should be in the /sys/emu/Nt folder.
