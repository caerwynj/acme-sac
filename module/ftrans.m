Ftrans: module {
	PATH: con "/dis/ftrans.dis";
	init: fn(nil: ref Draw->Context, argv: list of string);
	translate: fn(name: string): (string, string);
};
