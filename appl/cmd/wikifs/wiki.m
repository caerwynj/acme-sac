Wiki: module {
	PATH : con "/dis/wiki.dis";
	Wpage: adt {
		typ: int;
		text: string;
		section: int;
		url: string;
	};

	Wdoc: adt {
		author: string;
		comment: string;
		conflict: int;
		time: int;
		wtxt: list of ref Wpage;
	};

	Whist: adt {
		n: int;
		title: string;
		doc: array of ref Wdoc;
		ndoc: int;
		current: int;
	};

	Tcache : con 5;
	Maxmap: con 10*1024*1024;
	Maxfile: con 100*1024;
	Wpara, Wheading, Wbullet, Wlink, Wman, Wplain, Wpre, Nwtxt: con iota;
	Tpage, Tedit, Tdiff, Thistory, Tnew, Toldpage, Twerror, Ntemplate: con iota;

	Sub: adt {
		match: string;
		sub: string;
	};

	Mapel: adt {
		s: string;
		n: int;
	};

	Map: adt {
		el: array of ref Mapel;
		nel: int;
		t: int;
		buf: string;
		qid: Sys->Qid;
	};

	wikidir: string;
	map: ref Map;

	init:			fn(bufio: Bufio);
	nametonum:	fn(s: string):int;
	numtoname:	fn(n: int): string;
	writepage:	fn(num: int, t: int, s: string, title: string): int;
	doctext:		fn(d: ref Wdoc): string;
	allocnum:		fn(title: string, mustbenew:int): int;
	Brdpage:		fn(b: ref Iobuf, rdwline: ref fn(b: ref Iobuf, sep: int): string): list of ref Wpage;
	Brdwhist:		fn(b: ref Iobuf): ref Whist;
	pagetext:		fn(page: list of ref Wpage, dosharp: int): string;
	pagehtml:		fn(page: list of ref Wpage, ty: int): string;
	wBopen:		fn(f: string, mode: int): ref Iobuf;
	Srdwline:		fn(b: ref Iobuf, nil: int): string;
	printpage:		fn(wl: list of ref Wpage);
	setwikidir:		fn(s: string);
	gethistory:	fn(n: int): ref Whist;
	getcurrent:	fn(n: int): ref Whist;
	getcurrentbyname:	fn(s: string): ref Whist;
	tohtml:		fn(h: ref Whist, d: ref Wdoc, ty: int): string;
	totext:		fn(h: ref Whist, d: ref Wdoc, ty: int): string;
	currentmap:	fn(force: int);
};
