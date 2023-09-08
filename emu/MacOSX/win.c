// in this file, _Rect is os x Rect,
// _Point is os x Point
#define Point _Point
#define Rect _Rect

#include <Carbon/Carbon.h>
#include <QuickTime/QuickTime.h> // for full screen

#undef Rect
#undef Point

#undef nil

#include "dat.h"
#include "fns.h"
#undef log2
#include <draw.h>
#include <memdraw.h>
#include "cursor.h"
#include "keyboard.h"
#include "keycodes.h"

#define	Kup			Up
#define	Kleft		Left
#define	Kdown		Down
#define	Kright		Right
#define	Kalt		LAlt
#define	Kctl		LCtrl
#define	Kshift		LShift
#define	Kpgup		Pgup
#define	Kpgdown		Pgdown
#define	Khome		Home
#define	Kins		Ins
#define	Kend		End

#define rWindowResource  128

extern void flushmemscreen(Rectangle);
extern void wmtrack(int, int, int, int);

Memimage *gscreen;

static int readybit;
static Rendez	rend;
static int triedscreen;

///
// menu
//
static MenuRef windMenu;
static MenuRef viewMenu;

enum {
	kQuitCmd = 1,
	kFullScreenCmd = 2,
};

static WindowRef theWindow = NULL;
static CGContextRef context;
static CGDataProviderRef dataProviderRef;
static CGImageRef fullScreenImage;
static CGRect devRect;
static CGRect bounds;
static PasteboardRef appleclip;
static _Rect winRect;

static Boolean altPressed = false;
static Boolean cmdPressed = false;
static Boolean button2 = false;
static Boolean button3 = false;
static uint32_t mousebuttons = 0; // bitmask of buttons currently down
static uint32_t mouseX = 0;
static uint32_t mouseY = 0;

static Boolean needflush = false;

static Boolean fullscreen_race = false;

static int
isready(void*a)
{
	return readybit;
}

CGContextRef QuartzContext;

static OSStatus ApplicationQuitEventHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData);
static OSStatus MainWindowEventHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData);
static OSStatus MainWindowCommandHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData);

static void winproc(void *a);
static void flushproc(void *a);

CGRect
max_bounds()
{
	OSErr err;
	CGDirectDisplayID* d; 
	CGDisplayCount c, i;
	CGRect r;
	int bx=0, by=0, rx=0, ry=0;

	err = CGGetActiveDisplayList(0, NULL, &c);
	if(err != noErr)
		sysfatal("can not enumerate active displays");

	d = (CGDirectDisplayID *)malloc(c * sizeof(CGDirectDisplayID));
	if(d == NULL)
		sysfatal("can not allocate memory for display list");

	err = CGGetActiveDisplayList(c, d, &c);
	if(err != noErr)
		sysfatal("can not obtain active display list");

	for (i = 0; i < c; i++) {
		r = CGDisplayBounds(d[i]);
		rx = r.size.width;
		ry = r.size.height;
		if(rx > bx)
			bx = rx;
		if(ry > by)
			by = ry;
	}
	
	return CGRectMake(0,0,bx,by);
}

void
screeninit(void)
{
	int fmt;
	int dx, dy;
	ProcessSerialNumber psn = { 0, kCurrentProcess };
	TransformProcessType(&psn, kProcessTransformToForegroundApplication);
	SetFrontProcess(&psn);

	fmt = XBGR32; //XRGB32;
	devRect = max_bounds();
	dx = devRect.size.width;
	dy = devRect.size.height;

	gscreen = allocmemimage(Rect(0,0,dx,dy), fmt);
	dataProviderRef = CGDataProviderCreateWithData(0, gscreen->data->bdata,
					dx * dy * 4, 0);
	fullScreenImage = CGImageCreate(dx, dy, 8, 32, dx * 4,
				CGColorSpaceCreateDeviceRGB(),
				kCGImageAlphaNoneSkipLast,
				dataProviderRef, 0, 0, kCGRenderingIntentDefault);

	devRect = CGDisplayBounds(CGMainDisplayID());

	kproc("osxscreen", winproc, nil, 0);
	kproc("osxflush", flushproc, nil, 0);
	Sleep(&rend, isready, nil);
}

void
window_resized(void)
{
	GetWindowBounds(theWindow, kWindowContentRgn, &winRect);
	bounds = CGRectMake(0, 0, winRect.right-winRect.left, winRect.bottom - winRect.top);
}

static void
flushproc(void *a)
{
	for(;;) {
		if(needflush) {
			drawqlock();
			QDBeginCGContext(GetWindowPort(theWindow), &context);
			CGContextFlush(context);
			QDEndCGContext(GetWindowPort(theWindow), &context);
			needflush = false;
			drawqunlock();
		}
		usleep(33333);
	}
}

static void
winproc(void *a)
{
	MenuItemIndex index;

	winRect.left = 30;
	winRect.top = 60;
	winRect.bottom = (devRect.size.height * 0.75) + winRect.top;
	winRect.right = (devRect.size.width * 0.75) + winRect.left;

	ClearMenuBar();
	InitCursor();

	CreateStandardWindowMenu(0, &windMenu);
	InsertMenu(windMenu, 0);

	CreateNewMenu(1004, 0, &viewMenu);
	SetMenuTitleWithCFString(viewMenu, CFSTR("View"));
	AppendMenuItemTextWithCFString(viewMenu, CFSTR("Toggle Full Screen"), 0,
								kFullScreenCmd, &index);
	SetMenuItemCommandKey(viewMenu, index, FALSE, 'F');
	InsertMenu(viewMenu, GetMenuID(windMenu));

	DrawMenuBar();
	uint32_t windowAttrs = 0
				| kWindowCloseBoxAttribute
				| kWindowCollapseBoxAttribute
				| kWindowResizableAttribute
				| kWindowStandardHandlerAttribute
				| kWindowFullZoomAttribute
		;

	CreateNewWindow(kDocumentWindowClass, windowAttrs, &winRect, &theWindow);
	SetWindowTitleWithCFString(theWindow, CFSTR("Acme SAC"));

	if(PasteboardCreate(kPasteboardClipboard, &appleclip) != noErr)
		sysfatal("pasteboard create failed");

	const EventTypeSpec app_events[] = {
		{ kEventClassApplication, kEventAppQuit }
	};
	const EventTypeSpec commands[] = {
		{ kEventClassWindow, kEventWindowClosed },
		{ kEventClassWindow, kEventWindowBoundsChanged },
		{ kEventClassCommand, kEventCommandProcess }
	};
	const EventTypeSpec events[] = {
		{ kEventClassTextInput, kEventTextInputUpdateActiveInputArea },
		{ kEventClassTextInput, kEventTextInputUnicodeForKeyEvent },
		{ kEventClassTextInput, kEventTextInputOffsetToPos },
		{ kEventClassTextInput, kEventTextInputPosToOffset },
		{ kEventClassTextInput, kEventTextInputShowHideBottomWindow },
		{ kEventClassTextInput, kEventTextInputGetSelectedText },
		{ kEventClassTextInput, kEventTextInputUnicodeText },
		{ kEventClassTextInput, kEventTextInputFilterText },
		{ kEventClassKeyboard, kEventRawKeyDown },
		{ kEventClassKeyboard, kEventRawKeyModifiersChanged },
		{ kEventClassKeyboard, kEventRawKeyRepeat },
		{ kEventClassMouse, kEventMouseDown },
		{ kEventClassMouse, kEventMouseUp },
		{ kEventClassMouse, kEventMouseMoved },
		{ kEventClassMouse, kEventMouseDragged },
		{ kEventClassMouse, kEventMouseWheelMoved },
	};

	InstallApplicationEventHandler (
								NewEventHandlerUPP (ApplicationQuitEventHandler),
								GetEventTypeCount(app_events),
								app_events,
								NULL,
								NULL);

	InstallApplicationEventHandler (
								NewEventHandlerUPP (MainWindowEventHandler),
								GetEventTypeCount(events),
								events,
								NULL,
								NULL);
						
	InstallWindowEventHandler (
								theWindow,
								NewEventHandlerUPP (MainWindowCommandHandler),
								GetEventTypeCount(commands),
								commands,
								theWindow,
								NULL);

	ShowWindow(theWindow);
	ShowMenuBar();
	window_resized();
	Rectangle rect =  { { 0, 0 }, { bounds.size.width, bounds.size.height } };		
	wmtrack(0, rect.max.x, rect.max.y, 0);
	SelectWindow(theWindow);
	// Run the event loop
	readybit = 1;
	Wakeup(&rend);
	RunApplicationEventLoop();
}

/*
static int
convert_key(UInt32 key, UInt32 charcode)
{
	switch(key) {
	case QZ_IBOOK_ENTER:
	case QZ_RETURN:			return '\n';
	case QZ_ESCAPE: 		return 27;
	case QZ_BACKSPACE:		return '\b';
	case QZ_LALT:			return Kalt;
	case QZ_LCTRL:			return Kctl;
	case QZ_LSHIFT:			return Kshift;
	case QZ_F1:				return KF+1;
	case QZ_F2:				return KF+2;
	case QZ_F3:				return KF+3;
	case QZ_F4:				return KF+4;
	case QZ_F5:				return KF+5;
	case QZ_F6:				return KF+6;
	case QZ_F7:				return KF+7;
	case QZ_F8:				return KF+8;
	case QZ_F9:				return KF+9;
	case QZ_F10:			return KF+10;
	case QZ_F11:			return KF+11;
	case QZ_F12:			return KF+12;
	case QZ_INSERT:			return Kins;
	case QZ_DELETE:			return 0x7F;
	case QZ_HOME:			return Khome;
	case QZ_END:			return Kend;
	case QZ_KP_PLUS:		return '+';
	case QZ_KP_MINUS:		return '-';
	case QZ_TAB:			return '\t';
	case QZ_PAGEUP:			return Kpgup;
	case QZ_PAGEDOWN:		return Kpgdown;
	case QZ_UP:				return Kup;
	case QZ_DOWN:			return Kdown;
	case QZ_LEFT:			return Kleft;
	case QZ_RIGHT:			return Kright;
	case QZ_KP_MULTIPLY:	return '*';
	case QZ_KP_DIVIDE:		return '/';
	case QZ_KP_ENTER:		return '\n';
	case QZ_KP_PERIOD:		return '.';
	case QZ_KP0:			return '0';
	case QZ_KP1:			return '1';
	case QZ_KP2:			return '2';
	case QZ_KP3:			return '3';
	case QZ_KP4:			return '4';
	case QZ_KP5:			return '5';
	case QZ_KP6:			return '6';
	case QZ_KP7:			return '7';
	case QZ_KP8:			return '8';
	case QZ_KP9:			return '9';
	default:				return charcode;
	}
}
*/

enum {
	kF1KeyCode	 = 0x7A,	// Undo
	kF2KeyCode	 = 0x78,	// Cut
	kF3KeyCode	 = 0x63,	// Copy
	kF4KeyCode	 = 0x76,	// Paste
	kF5KeyCode	 = 0x60,
	kF6KeyCode	 = 0x61,
	kF7KeyCode	 = 0x62,
	kF8KeyCode	 = 0x64,
	kF9KeyCode	 = 0x65,
	kF10KeyCode	 = 0x6D,
	kF11KeyCode	 = 0x67,
	kF12KeyCode	 = 0x6F,
	kF13KeyCode	 = 0x69,	// Print Screen
	kF14KeyCode	 = 0x6B,	// Scroll Lock
	kF15KeyCode	 = 0x71,	// Pause
	};

static int
convert_unichar(UInt32 charcode)
{
	switch(charcode) {
	case kEnterCharCode:
	case kReturnCharCode:		return '\n';
	case kEscapeCharCode:		return 27;
	case kBackspaceCharCode:	return '\b';
	case kOptionUnicode:		return Kalt;
	case kControlUnicode:		return Kctl;
	case kShiftUnicode:			return Kshift;
	case kFunctionKeyCharCode:
		switch(charcode) {
		case kF1KeyCode:		return KF+1;
		case kF2KeyCode:		return KF+2;
		case kF3KeyCode:		return KF+3;
		case kF4KeyCode:		return KF+4;
		case kF5KeyCode:		return KF+5;
		case kF6KeyCode:		return KF+6;
		case kF7KeyCode:		return KF+7;
		case kF8KeyCode:		return KF+8;
		case kF9KeyCode:		return KF+9;
		case kF10KeyCode:		return KF+10;
		case kF11KeyCode:		return KF+11;
		case kF12KeyCode:		return KF+12;
		default:				return charcode;
		}
//	case kInsertCharCode:		return Kins;
	case kDeleteCharCode:		return 0x7F;
	case kHomeCharCode:			return Khome;
	case kEndCharCode:			return Kend;
	case kTabCharCode:			return '\t';
	case kPageUpCharCode:		return Kpgup;
	case kPageDownCharCode:		return Kpgdown;
	case kUpArrowCharCode:		return Kup;
	case kDownArrowCharCode:	return Kdown;
	case kLeftArrowCharCode:	return Kleft;
	case kRightArrowCharCode:	return Kright;
	default:					return charcode;
	}
}


void
sendbuttons(int b, int x, int y)
{
//	fprint(2, "sendbuttons:	b: %d; x: %d; y: %d\n", b, x, y);
	mousetrack(b, x, y, 0);
}

static Ptr fullScreenRestore;
static int amFullScreen = 0;
static WindowRef oldWindow = NULL;

static void
leave_full_screen(void)
{
	if(amFullScreen) {
		EndFullScreen(fullScreenRestore, 0);
		theWindow = oldWindow;
		ShowWindow(theWindow);
		amFullScreen = 0;
		window_resized();
		Rectangle rect =  { { 0, 0 }, { bounds.size.width, bounds.size.height } };
		wmtrack(0, rect.max.x, rect.max.y, 0);
		drawqlock();
		flushmemscreen(rect);
		drawqunlock();
	}
}

static void
full_screen(void)
{
	if(!amFullScreen) {
		oldWindow = theWindow;
		HideWindow(theWindow);
		GDHandle device;
		GetWindowGreatestAreaDevice(theWindow, kWindowTitleBarRgn, &device, NULL);
		BeginFullScreen(&fullScreenRestore, device, 0, 0, &theWindow, 0, 0);
		amFullScreen = 1;
		window_resized();
		Rectangle rect =  { { 0, 0 }, { bounds.size.width, bounds.size.height } };
		wmtrack(0, rect.max.x, rect.max.y, 0);
		drawqlock();
		flushmemscreen(rect);
		drawqunlock();
	} else
		leave_full_screen();
}

static OSStatus
handle_unicode(EventRef event)
{
	UInt32 actual_size, i;
	UniChar *text;
	UniCharCount num_chars;
	OSStatus result = noErr;

	// hack to keep sequences like Cmd+f from writing to buffer
	if(! cmdPressed) {
		result = GetEventParameter (event, kEventParamTextInputSendText,
								typeUnicodeText, NULL, 0, &actual_size, NULL);
		if(result == noErr) {
			text = (UniChar*) NewPtr(actual_size);
			result = GetEventParameter (event, kEventParamTextInputSendText,
		   							typeUnicodeText, NULL, actual_size, NULL, text);
			if(result == noErr) {
				num_chars = actual_size / sizeof(UniChar);
				for(i=0; i < num_chars; i++) {
					int key = convert_unichar(text[i]);
					gkbdputc(gkbdq, key);
				}
			}
		}
	}

	return result;
}

static OSStatus
handle_text_input_event(EventRef event)
{
	OSStatus result;

	UInt32 kind = GetEventKind (event);
	switch(kind) {

	case kEventTextInputUnicodeForKeyEvent:
	case kEventTextInputUnicodeText:
//		fprint(2, "unicode input event:\n");
		result = handle_unicode(event);
		break;

	case kEventTextInputUpdateActiveInputArea:
	case kEventTextInputOffsetToPos:	
	case kEventTextInputPosToOffset:
	case kEventTextInputShowHideBottomWindow:
	case kEventTextInputGetSelectedText:
	case kEventTextInputFilterText:
	default:
		result = eventNotHandledErr;
		break;
		
	}
	
	return result;
}

static OSStatus
handle_kbd_event(EventRef event)
{
	OSStatus result = noErr;

	char macCharCodes;
	UInt32 macKeyCode;
	UInt32 macKeyModifiers;

	GetEventParameter(event, kEventParamKeyMacCharCodes, typeChar,
					NULL, sizeof(macCharCodes), NULL, &macCharCodes);
	GetEventParameter(event, kEventParamKeyCode, typeUInt32, NULL,
					sizeof(macKeyCode), NULL, &macKeyCode);
	GetEventParameter(event, kEventParamKeyModifiers, typeUInt32, NULL,
					sizeof(macKeyModifiers), NULL, &macKeyModifiers);

//	fprint(2, "mac char is %04x=%c\n", macCharCodes, macCharCodes);
//	fprint(2, "mac key code is %ld\n", macKeyCode);

	UInt32 kind = GetEventKind (event);
	switch(kind) {

	case kEventRawKeyModifiersChanged:
//		fprint(2, "kbd event:	key modifiers changed!\n");
		switch(macKeyModifiers & (optionKey | cmdKey)) {

		case (optionKey | cmdKey):
			/* due to chording we need to handle the case when both
			 * modifier keys are pressed at the same time.
			 * currently it's only 2-3 snarf and the 3-2 noop
			 */
			 
//			fprint(2, "kbd event:	Opt|Cmd pressed!\n");
			altPressed = true;
			cmdPressed = true;
			if(mousebuttons & 1 || mousebuttons & 2 || mousebuttons & 4) {
				mousebuttons |= 2;	/* set button 2 */
				mousebuttons |= 4;	/* set button 3 */
				button2 = true;
				button3 = true;
				sendbuttons(mousebuttons, mouseX, mouseY);
			}
			break;
		
		case optionKey:
//			fprint(2, "kbd event:	Opt pressed!\n");
			altPressed = true;
			if(mousebuttons & 1 || mousebuttons & 4) {
				mousebuttons |= 2;	/* set button 2 */
				button2 = true;
				sendbuttons(mousebuttons, mouseX, mouseY);
			}
			break;
		
		case cmdKey:
//			fprint(2, "kbd event:	Cmd pressed!\n");
			cmdPressed = true;
			if(mousebuttons & 1 || mousebuttons & 2) {
				mousebuttons |= 4;	/* set button 3 */
				button3 = true;
				sendbuttons(mousebuttons, mouseX, mouseY);
			}
			break;
		
		default:
			if(button2 || button3) {
				if(button2) {
					mousebuttons &= ~2;	/* clear button 2 */
					button2 = false;
				}
				if(button3) {
					mousebuttons &= ~4;	/* clear button 3 */
					button3 = false;
				}
				sendbuttons(mousebuttons, mouseX, mouseY);
			}		
			altPressed = false;
			cmdPressed = false;
			break;
		}
		break;
		
	case kEventRawKeyDown:
	case kEventRawKeyRepeat:
		if(macKeyModifiers == cmdKey) {
			// catch fullscreen toggle key sequences while in fullscreen mode
			if(macCharCodes == 'f' || macCharCodes == 'F') {
				if(fullscreen_race)
					fullscreen_race = false;
				else
					full_screen();
			}
		}
		else {
			if(macKeyCode == QZ_ESCAPE)
				gkbdputc(gkbdq, 27);
			else
				result = eventNotHandledErr;
		}
		break;
						
	default:	
		result = eventNotHandledErr;
		break;

	}

	return result;
}

static OSStatus
handle_mouse_event(EventRef event)
{
	_Point mousePos;
	OSStatus result = GetEventParameter(event, kEventParamMouseLocation, typeQDPoint,
									0, sizeof mousePos, 0, &mousePos);

	if(result == noErr) {
		UInt32 kind = GetEventKind (event);
		switch(kind) {

		case kEventMouseWheelMoved:
		{
			int32_t wheeldelta;
			GetEventParameter(event,kEventParamMouseWheelDelta,typeSInt32,
							0,sizeof(wheeldelta), 0, &wheeldelta);
			mouseX = mousePos.h - winRect.left;
			mouseY = mousePos.v - winRect.top;
			sendbuttons(wheeldelta>0 ? 8 : 16, mouseX, mouseY);
			break;
		}
			
		case kEventMouseUp:
		case kEventMouseDown:
		{
			uint32_t buttons;
			uint32_t modifiers;
			GetEventParameter(event, kEventParamKeyModifiers, typeUInt32,
								0, sizeof(modifiers), 0, &modifiers);
			GetEventParameter(event, kEventParamMouseChord, typeUInt32,
								0, sizeof buttons, 0, &buttons);
			/* simulate other buttons via alt/apple key. like x11 */
			if(modifiers & optionKey) {
//				fprint(2, "mouse event:	Opt pressed!\n");
				mousebuttons = ((buttons & 1) ? 2 : 0);
				altPressed = false;
			} else if(modifiers & cmdKey) {
//				fprint(2, "mouse event:	Cmd pressed!\n");
				mousebuttons = ((buttons & 1) ? 4 : 0);
				cmdPressed = false;
			}
			else
				mousebuttons = (buttons & 1);

			mousebuttons |= ((buttons & 2)<<1);
			mousebuttons |= ((buttons & 4)>>1);
		}
					
		/* Fallthrough */
		
		case kEventMouseMoved:
		case kEventMouseDragged:
			mouseX = mousePos.h - winRect.left;
			mouseY = mousePos.v - winRect.top;
			sendbuttons(mousebuttons, mouseX, mouseY);
			break;
			
		default:
			result = eventNotHandledErr;
			break;

		}
	}
	
	return result;
}

static OSStatus
MainWindowEventHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData)
{
	OSStatus result = noErr;
	result = CallNextEventHandler(nextHandler, event);

	// we need to reset the mouse coordinates to handle simulated button2 and button3 clicks
	mouseX = 0;
	mouseY = 0;
	
	UInt32 class = GetEventClass (event);	
	switch(class) {

	case kEventClassTextInput:
//		fprint(2, "text input event!\n");
		handle_text_input_event(event);			
		break;

	case kEventClassKeyboard:
//		fprint(2, "keyboard event!\n");
		handle_kbd_event(event);
		break;

	case kEventClassMouse:
//		fprint(2, "mouse event!\n");
		handle_mouse_event(event);
		break;
			
	default:
		result = eventNotHandledErr;
		break;

	}
	
	return result;
}

// catch quit events to handle quits from menu, Cmd+Q, applescript, and task switcher
static OSStatus ApplicationQuitEventHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData)
{
	cleanexit(0);
//	QuitApplicationEventLoop();
	return noErr;
}

//default window command handler (from menus)
static OSStatus
MainWindowCommandHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData)
{
	OSStatus result = noErr;
	UInt32 class = GetEventClass (event);
	UInt32 kind = GetEventKind (event);

	result = CallNextEventHandler(nextHandler, event);

	if(class == kEventClassCommand) {
		HICommand theHICommand;
		GetEventParameter(event, kEventParamDirectObject, typeHICommand,
						NULL, sizeof(HICommand), NULL, &theHICommand);

		switch(theHICommand.commandID) {
		
		/* since we won't see this event in full-screen mode we need
		 * to intercept keyboard clicks too (apple-F). here we only turn fullscreen,
		 * there we only turn it off. there is a race because the
		 * way OSX handles keyboard shortcut: we enter here first,
		 * then a keyboard event will be delivered to the app again,
		 * effectively turning the fullscreen off. 
		 *
		 * the appropriate solution is to use an overlay window in
		 * ScreenSaver Level to draw while our app is quiet 
		 */

		case kFullScreenCmd:
			if(fullscreen_race)
				fullscreen_race = false;
			else {
				fullscreen_race = true;
				full_screen();
			}
			break;

		default:
			result = eventNotHandledErr;
			break;
		}
	} else if(class == kEventClassWindow) {
		WindowRef     window;
		GetEventParameter(event, kEventParamDirectObject, typeWindowRef,
						NULL, sizeof(WindowRef), NULL, &window);

		switch(kind) {
		// send a quit carbon event instead of directly calling cleanexit 
		// so that all quits are done in ApplicationQuitEventHandler
		case kEventWindowClosed:
			{
			EventRef quitEvent;
			CreateEvent(NULL,
						kEventClassApplication,
						kEventAppQuit,
						0,
						kEventAttributeNone,
						&quitEvent);
			EventTargetRef target;
			target = GetApplicationEventTarget();
			SendEventToEventTarget(quitEvent, target);
			}
			break;

		// resize window
		case kEventWindowBoundsChanged:
			window_resized();
			Rectangle rect =  { { 0, 0 }, { bounds.size.width, bounds.size.height } };
			wmtrack(0, rect.max.x, rect.max.y, 0);
			drawqlock();
			flushmemscreen(rect);
			drawqunlock();
			break;

		default:
			result = eventNotHandledErr;
			break;
		}
	}

	return result;
}

void
flushmemscreen(Rectangle r)
{
	CGRect rbounds;

	// sanity check.  Trips from the initial "terminal"
	if(r.max.x < r.min.x || r.max.y < r.min.y)
		return;

	rbounds.size.width = r.max.x - r.min.x;
	rbounds.size.height = r.max.y - r.min.y;
	rbounds.origin.x = r.min.x;
	rbounds.origin.y = r.min.y;

	if(rbounds.size.width <= 0 || rbounds.size.height <= 0)
		return;
		
	QDBeginCGContext(GetWindowPort(theWindow), &context);
	
	// The sub-image is relative to our whole screen image.
	CGImageRef subimg = CGImageCreateWithImageInRect(fullScreenImage, rbounds);
	
	// Drawing the sub-image is relative to the window.
	rbounds.origin.y = winRect.bottom - winRect.top - r.min.y - rbounds.size.height;
	CGContextDrawImage(context, rbounds, subimg);
	CGImageRelease(subimg);
	QDEndCGContext(GetWindowPort(theWindow), &context);

	needflush = true;
}

uchar*
attachscreen(Rectangle *r, ulong *chan, int *depth, int *width, int *softscreen)
{	
	if(!triedscreen) {
		triedscreen = 1;
		screeninit();	/* TO DO: call this elsewhere? */
	}
	*r = gscreen->r;
	*chan = gscreen->chan;
	*depth = gscreen->depth;
	*width = gscreen->width;
	*softscreen = 1;

	return gscreen->data->bdata;
}

// PAL - no palette handling.  Don't intend to either.
void
getcolor(ulong i, ulong *r, ulong *g, ulong *b)
{

// PAL: Certainly wrong to return a grayscale.
	 *r = i;
	 *g = i;
	 *b = i;
}

void
setcolor(ulong index, ulong r, ulong g, ulong b)
{
	USED(index); USED(r); USED(g); USED(b);
}

enum{
	SnarfSize=	100*1024
};

static char snarf[3*SnarfSize+1];
static Rune rsnarf[SnarfSize+1];

char*
clipread(void)
{
	CFDataRef cfdata;
	OSStatus err = noErr;
	ItemCount nitems;
	int i;
	char *s;

	// Wow.  This is ridiculously complicated.
	PasteboardSynchronize(appleclip);
	if((err = PasteboardGetItemCount(appleclip, &nitems)) != noErr) {
		fprint(2, "apple pasteboard GetItemCount failed - Error %d\n", (int)err);
		return 0;
	}

	// Yes, based at 1.  Silly API.
	for(i = 1; i <= nitems; i++) {
		PasteboardItemID itemID;
		CFArrayRef flavorTypeArray;
		CFIndex flavorCount;

		if((err = PasteboardGetItemIdentifier(appleclip, i, &itemID)) != noErr){
			fprint(2, "Can't get pasteboard item identifier: %d\n", (int)err);
			return 0;
		}

		if((err = PasteboardCopyItemFlavors(appleclip, itemID, &flavorTypeArray))!=noErr){
			fprint(2, "Can't copy pasteboard item flavors: %d\n", (int)err);
			return 0;
		}

		flavorCount = CFArrayGetCount(flavorTypeArray);
		CFIndex flavorIndex;
		for(flavorIndex = 0; flavorIndex < flavorCount; ++flavorIndex){
			CFStringRef flavorType;
			flavorType = (CFStringRef)CFArrayGetValueAtIndex(flavorTypeArray, flavorIndex);
			if(UTTypeConformsTo(flavorType, CFSTR("public.utf16-plain-text"))){
				if((err = PasteboardCopyItemFlavorData(appleclip, itemID,
					CFSTR("public.utf16-plain-text"), &cfdata)) != noErr){
					fprint(2, "apple pasteboard CopyItem failed - Error %d\n", (int)err);
					return 0;
				}
				CFIndex length = CFDataGetLength(cfdata);
				if(length > sizeof rsnarf) length = sizeof rsnarf;
				CFDataGetBytes(cfdata, CFRangeMake(0, length), (uint8_t *)rsnarf);
				snprint(snarf, sizeof snarf, "%.*S", length/sizeof(Rune), rsnarf);
				CFRelease(cfdata);
				return strdup(snarf);
			}
		}
	}
	return 0;
}

int
clipwrite(char *snarf)
{
	CFDataRef cfdata;
	PasteboardSyncFlags flags;

	runeseprint(rsnarf, rsnarf+nelem(rsnarf), "%s", snarf);
	if(PasteboardClear(appleclip) != noErr){
		fprint(2, "apple pasteboard clear failed\n");
		return 0;
	}
	flags = PasteboardSynchronize(appleclip);
	if((flags&kPasteboardModified) || !(flags&kPasteboardClientIsOwner)){
		fprint(2, "apple pasteboard cannot assert ownership\n");
		return 0;
	}
	cfdata = CFDataCreate(kCFAllocatorDefault, (uchar*)rsnarf, runestrlen(rsnarf)*2);
	if(cfdata == nil){
		fprint(2, "apple pasteboard cfdatacreate failed\n");
		return 0;
	}
	if(PasteboardPutItemFlavor(appleclip, (PasteboardItemID)1,
		CFSTR("public.utf16-plain-text"), cfdata, 0) != noErr){
		fprint(2, "apple pasteboard putitem failed\n");
		CFRelease(cfdata);
		return 0;
	}
	CFRelease(cfdata);
	return 1;
}

void
setpointer(int x, int y)
{
	CGPoint pnt;

	pnt.x = x + winRect.left;
	pnt.y = y + winRect.top;
	CGWarpMouseCursorPosition(pnt);
	// apparently CGWarpMouseCursorPosition doesn't generate a mouse event, so we need to manually update the position
	mousetrack(0, x, y, 0);
}

void
drawcursor(Drawcursor* c)
{
	Cursor crsr;
	uchar *bc, *bs, *ps, *pm;
	int i, j, h, w, bpl;

	if(c->data == nil || c->minx >= c->maxx){
		InitCursor();
		return;
	}
	memset(crsr.data, 0, sizeof(crsr.data));
	memset(crsr.mask, 0, sizeof(crsr.mask));
	ps = (uchar*)crsr.data;
	pm = (uchar*)crsr.mask;
	h = (c->maxy - c->miny)/2;	/* bounds include both masks, strangely */
	bpl = bytesperline(Rect(c->minx, c->miny, c->maxx, c->maxy), 1);
	if((w = bpl) > 2)
		w = 2;
	bc = c->data;
	bs = c->data + h*bpl;
	if(h > 16)
		h = 16;
	for(i = 0; i < h; i++){
		for(j = 0; j < w; j++){
			ps[j] = bs[j];
			pm[j] = bs[j] | bc[j];
		}
		bs += bpl;
		bc += bpl;
		ps += 2;
		pm += 2;
	}
	crsr.hotSpot.h = -c->hotx;
	crsr.hotSpot.v = -c->hoty;
	SetCursor(&crsr);
}
