Menuhit: module {
	PATH: con "/dis/lib/menuhit.dis";
	Menu : adt {
		item : array of string;
		gen: ref fn(i: int):string;
		lasthit: int;
	};
	
	Mousectl : adt {
		ptr: chan of ref Draw->Pointer;
		buttons: int;
		xy: Point;
		msec: int;
	};
	init: fn(w: ref Wmclient->Window);
	menuhit: fn(but: int, mc: ref Mousectl, menu: ref Menu, scr: ref Draw->Screen):int;
};
