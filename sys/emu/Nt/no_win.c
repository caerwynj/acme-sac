#define Unknown win_Unknown
#include	<windows.h>
#undef Unknown
#include	"dat.h"
#include	"fns.h"
#include	"error.h"

#include	"keyboard.h"
#include	"cursor.h"

extern ulong displaychan;

extern void drawend(void);


extern	int	main(int argc, char **argv);

static	HINSTANCE	inst;
static	HINSTANCE	previnst;
static	int		cmdshow;
static	HWND		window;

static	char	*argv0 = "inferno";
static	ulong	*data;

extern	DWORD	PlatformId;
char*	gkscanid = "emu_win32vk";

int WINAPI
WinMain(HINSTANCE winst, HINSTANCE wprevinst, LPSTR cmdline, int wcmdshow)
{
	inst = winst;
	previnst = wprevinst;
	cmdshow = wcmdshow;

	/* cmdline passed into WinMain does not contain name of executable.
	 * The globals __argc and __argv to include this info - like UNIX
	 */
	main(__argc, __argv);
	return 0;
}

void
dprint(char *fmt, ...)
{
	va_list arg;
	char buf[128];

	va_start(arg, fmt);
	vseprint(buf, buf+sizeof(buf), fmt, (LPSTR)arg);
	va_end(arg);
	OutputDebugString("inferno: ");
	OutputDebugString(buf);
}
