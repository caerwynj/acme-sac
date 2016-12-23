implement Lens;

include "sys.m";
	sys: Sys;
include "draw.m";
	draw: Draw;
	Display, Font, Rect, Point, Image, Screen, Pointer: import draw;
	display: ref Display;
include "wmclient.m";
	wmclient: Wmclient;
	Window: import wmclient;
include "menuhit.m";
	menuhit: Menuhit;
	Menu, Mousectl: import menuhit;

# related to us
disp, screen, color: ref Image;
brdr: Rect;
ptrchan: chan of Pointer;
zoom: int;
window: ref Image;

Lens: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

init(ctxt: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	wmclient = load Wmclient Wmclient->PATH;
	menuhit = load Menuhit Menuhit->PATH;
	menu := ref Menu(array[] of {"exit"}, nil, 0);


	display = ctxt.display;	# assume always works
	disp = display.image;
	
	brdr = Rect((0,0), (300, 300));
	
	sys->pctl(Sys->NEWPGRP, nil);
	wmclient->init();
	w := wmclient->window(ctxt, "Lens", Wmclient->Appl);
	w.reshape(Rect((0, 0), (300, 300)));
	w.startinput("kbd"::"ptr" :: nil);
	w.onscreen(nil);
	menuhit->init(w);
	window = w.image;
	screen = display.newimage(brdr, display.image.chans, 0, Draw->Red);
	if(screen == nil)
		sys->fprint(sys->fildes(2), "no image memory (screen): %r\n");
	w.image.draw(w.image.r, screen, nil, (0,0));
	
	color = display.newimage(Rect((0, 0), (1, 1)), display.image.chans, 1, Draw->Red);
	if(color == nil)
		sys->fprint(sys->fildes(2), "no image memory (color): %r\n");

	ptrchan = chan of Pointer;
	zoom = 5;
	spawn lens();
	for(;;) alt{
	ctl := <-w.ctl or
	ctl = <-w.ctxt.ctl =>
		w.wmctl(ctl);
		if(ctl != nil && ctl[0] == '!'){
			w.image.draw(w.image.r, screen, nil, (0,0));
		screen = display.newimage(Rect((0,0), (w.image.r.dx(), w.image.r.dy())), display.image.chans, 0, Draw->Red);
		window = w.image;
		}
	p := <-w.ctxt.ptr =>
		ptrchan <-= *p;
		if(!w.pointer(*p)  && (p.buttons & (1|2))){
			mc := ref Mousectl(w.ctxt.ptr, p.buttons, p.xy, p.msec);
			n := menuhit->menuhit(p.buttons, mc, menu, nil);
			if(n == 0){
				postnote(1, sys->pctl(0, nil), "kill");
				exit;
			}
		}
	k := <-w.ctxt.kbd =>
		processkbd(k);
	}
}

postnote(t : int, pid : int, note : string) : int
{
	fd := sys->open("#p/" + string pid + "/ctl", Sys->OWRITE);
	if (fd == nil)
		return -1;
	if (t == 1)
		note += "grp";
	sys->fprint(fd, "%s", note);
	fd = nil;
	return 0;
}

processkbd(kbd: int)
{
	case kbd {
		'1' or '2' or '3' or '4' or '5' or '6' or '7' or '8' or '9' => zoom = kbd-16r30;
		'0' => zoom = 10;
	}
}

flush()
{
	window.draw(window.r, screen, nil, (0,0));
}

lens()
{
	p: Point;
	r: Rect;
	ptr: Pointer;
	x, y, i, j: int;
	xoff, yoff: int;

	for(;;) {
		ptr = <- ptrchan;

		xoff = screen.r.dx()/(2*zoom);
		yoff = screen.r.dy()/(2*zoom);

		p = ptr.xy;
		if(p.x < disp.r.min.x + xoff)
			p.x = disp.r.min.x + xoff;
		if(p.x > disp.r.max.x - xoff)
			p.x = disp.r.max.x - xoff;
		if(p.y < disp.r.min.y + yoff)
			p.y = disp.r.min.y + yoff;
		if(p.y > disp.r.max.y - yoff)
			p.y = disp.r.max.y - yoff;

		# zoom == 1 is a special case, optimize
		if(zoom == 1) {
			screen.draw(screen.r, disp, nil, p.sub(Point(xoff, yoff)));
			flush();
			continue;
		}

		i = 0;
		for (x = p.x-xoff; x < p.x+xoff; x++) {
			j = 0;
			for (y = p.y-yoff; y < p.y+yoff; y ++) {
				r = Rect((i, j), (i+zoom, j+zoom));

				color.draw(color.r, disp, nil, Point(x, y));
				screen.draw(r, color, nil, color.r.min);
				j+=zoom;
			}
			i+=zoom;
		}
		flush();
	}
}