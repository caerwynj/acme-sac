Midi: module {
	PATH : con "/dis/lib/midi.dis";
	
	# Meta events
	SEQNUM, 
	TEXT, 
	COPYRIGHT, 
	TRACK, 
	INSTRUMENT, 
	LYRICS,
	MARKER, 
	CUE: con iota;
	EOT: 	con 16r2F;	# End of Track
	TEMPO:	con 16r51;
	
	# Control events;
	NOTEOFF: 	con 16r8;
	NOTEON: 		con 16r9;
	AFTERTOUCH: 	con 16ra;
	CONTROLLER: 	con 16rb;
	PROGCHG: 	con 16rc;
	CHANAFTERTOUCH: con 16rd;
	PITCHBEND: 	con 16re;

	Header: adt {
		id: string;
		length: int;
		format: int;
		numtracks: int;
		division: int;
		tpb: int;	#tick per beat
		istimecode : int;
		tracks: array of ref Track;
	};
	
	Track: adt {
		id: string;
		length: int;
		
		events: array of ref Event;
	};
	
	Event: adt {
		delta: int;
		pick {
		Meta =>
			etype: int;
			data: array of byte;
		Sysex =>
			etype: int;
			data: array of byte;
		Control =>
			etype: int;
			mchannel: int;
			param1: int;
			param2: int;
		}
	};
	init: fn(bufio: Bufio);
	read: fn(io: ref Iobuf): ref Header;
};
