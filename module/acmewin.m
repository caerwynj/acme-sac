Acmewin : module {
	PATH: con "/dis/lib/acmewin.dis";
	EVENTSIZE : con 256;

	init : fn();

Win : adt {
	winid : int;
	addr : ref Sys->FD;
	body : ref Bufio->Iobuf;
	ctl : ref Sys->FD;
	data : ref Sys->FD;
	event : ref Sys->FD;
	buf : array of byte;
	bufp : int;
	nbuf : int;

	wnew : fn() : ref Win;
	wwritebody : fn(w : self ref Win, s : string);
	wread : fn(w : self ref Win, m : int, n : int) : string;
	wclean : fn(w : self ref Win);
	wname : fn(w : self ref Win, s : string);
	wdormant : fn(w : self ref Win);
	wevent : fn(w : self ref Win, e : ref Event);
	wshow : fn(w : self ref Win);
	wtagwrite : fn(w : self ref Win, s : string);
	wwriteevent : fn(w : self ref Win, e : ref Event);
	wslave : fn(w : self ref Win, c : chan of Event);
	wreplace : fn(w : self ref Win, s : string, t : string);
	wsetaddr: fn(w: self ref Win, s: string, errok: int): int;
	wselect : fn(w : self ref Win, s : string);
	wsetdump : fn(w : self ref Win, s : string, t : string);
	wdel : fn(w : self ref Win, n : int) : int;
	wreadall : fn(w : self ref Win) : string;

 	ctlwrite : fn(w : self ref Win, s : string);
 	getec : fn(w : self ref Win) : int;
 	geten : fn(w : self ref Win) : int;
 	geter : fn(w : self ref Win, s : array of byte) : (int, int);
 	openfile : fn(w : self ref Win, s : string) : ref Sys->FD;
 	openbody : fn(w : self ref Win, n : int);
};

Event : adt {
	c1 : int;
	c2 : int;
	q0 : int;
	q1 : int;
	flag : int;
	nb : int;
	nr : int;
	b : array of byte;
	r : array of int;
};

};
