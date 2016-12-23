implement Colors;

include "sys.m";
	sys: Sys;
include "draw.m";
	draw: Draw;
	Display, Point, Rect, Image: import draw;
include "wmclient.m";
	wmclient: Wmclient;
	Window: import wmclient;
include "menuhit.m";
	menuhit: Menuhit;
	Menu, Mousectl: import menuhit;

Colors: module {
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

display: ref Display;
tmpi: ref Image;
ZP  := Point(0,0);

init(ctxt: ref Draw->Context, nil: list of string)
{
	spawn init1(ctxt);
}

init1(ctxt: ref Draw->Context)
{
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	wmclient = load Wmclient Wmclient->PATH;
	wmclient->init();
	menuhit = load Menuhit Menuhit->PATH;
	menu := ref Menu(array[] of {"exit"}, nil, 0);

	w := wmclient->window(ctxt, "clock", Wmclient->Appl);	# Plain?
	display = w.display;
	tmpi = display.newimage(((0,0), (1, 1)), Draw->RGB24, 0, 0);

	w.reshape(Rect((0, 0), (256, 256)));
	w.startinput("ptr" :: nil);
	w.onscreen(nil);
	i := cmap((256,256));
	w.image.draw(w.image.r, i, nil, ZP);
	menuhit->init(w);

	for(;;) alt {
	p := <-w.ctxt.ptr =>
		if(!w.pointer(*p) && p.buttons &1)
			color(p.xy);
		else if(p.buttons & 2){
			mc := ref Mousectl(w.ctxt.ptr, p.buttons, p.xy, p.msec);
			n := menuhit->menuhit(p.buttons, mc, menu, nil);
			if(n == 0)
				exit;
		}
	ctl := <-w.ctl or
	ctl = <-w.ctxt.ctl =>
		w.wmctl(ctl);
		if(ctl != nil && ctl[0] == '!')
			w.image.draw(w.image.r, cmap((w.image.r.dx(), w.image.r.dy())), nil, ZP);
	}
}

color(p: Point)
{
	r, g, b: int;
	col: string;

	cr := display.image.r;
	if(p.in(cr)){
		p = p.sub(cr.min);
		p.x = (16*p.x)/cr.dx();
		p.y = (16*p.y)/cr.dy();
		(r, g, b) = display.cmap2rgb(16*p.y+p.x);
		col = string (16*p.y+p.x);
	}else{
		tmpi.draw(tmpi.r, display.image, nil, p);
		data := array[3] of byte;
		ok := tmpi.readpixels(tmpi.r, data);
		if(ok != len data)
			return;
		(r, g, b) = (int data[2], int data[1], int data[0]);
		c := display.rgb2cmap(r, g, b);
		(r1, g1, b1) := display.cmap2rgb(c);
		if (r == r1 && g == g1 && b == b1)
			col = string c;
		else
			col = "~" + string c;
	}
	sys->print("{col:%s #%.6X r%d g%d b%d}\n", col, (r<<16)|(g<<8)|b, r, g, b);

}

cmap(size: Point): ref Image
{
	# use writepixels because it's much faster than allocating all those colors.
	img := display.newimage(((0, 0), size), Draw->CMAP8, 0, 0);
	if (img == nil){
		sys->print("colors: cannot make new image: %r\n");
		return nil;
	}

	dy := (size.y / 16 + 1);
	buf := array[size.x * dy] of byte;

	for(y:=0; y<16; y++){
		for (i := 0; i < size.x; i++)
			buf[i] = byte (16*y + (16*i)/size.x);
		for (i = 1; i < dy; i++)
			buf[size.x*i:] = buf[0:size.x];
		img.writepixels(((0, (y*size.y)/16), (size.x, ((y+1)*size.y) / 16)), buf);
	}
	return img;
}
