Dictm: module {
	Entry: adt {
		start: array of byte;
		end: array of byte;
		doff: big;
	};

	init: fn(b: Bufio, u: Utils, bd, bo: ref Iobuf );
	printentry: fn(e: Entry, cmd: int);
	nextoff: fn(fromoff: big): big;
	printkey: fn();
	mkindex: fn();
};
