Utils: module
{
	PATH: con "/dis/dict/utils.dis";

	linelen: int;
	breaklen: int;
	outinhibit: int;
	debug: int;
	
	Assoc: adt {
		key: string;
		val: int;
	};
	
	Nassoc: adt {
		key: int;
		val: int;
	};
	
	init: fn(b: Bufio, bo: ref Iobuf);
	err: fn(s: string);
	outrune: fn(r: int);
	outrunes: fn(rp: string);
	outnl: fn(ind: int);
	fold: fn(rp: string): string;
	liglookup: fn(acc: int, r: int): int;
	changett: fn(curtab: array of int, newtab: array of int, starting: int): array of int;
	looknassoc: fn(tab: array of  Nassoc, n: int, key: int): int;
	lookassoc: fn(tab: array of  Assoc, n: int, key: string): int;
};
