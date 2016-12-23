implement Midi;

include "sys.m";
	sys: Sys;
	print, fprint, fildes: import sys;
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;

include "midi.m";

SYSEX: con 16rF0;
SYSEXX: con 16rF7;
META : con 16rFF;

init(b: Bufio)
{
	sys = load Sys Sys->PATH;
	bufio = b;
}

read(io: ref Iobuf): ref Header
{
	hdr := ref Header(nil, 0, 0, 0, 0, 0, 0, nil);
	hdr.id = gid(io);
#	print("%s\n", hdr.id);
	hdr.length = g32(io);
	hdr.format = g16(io);
	hdr.numtracks = g16(io);
	hdr.division = g16(io);
	if(hdr.division & 16r8000){
		fps := real ((hdr.division & 16r7f00)>>8);
		if(fps == 29.0)
			fps = 29.97;
#		fps *= real(hdr.division&16r00ff);
		tpf := hdr.division&16r00ff;
		hdr.tpb = tpf;
		hdr.istimecode = 1;
#		print("frames per second %f, %d\n", fps, tpf);
	}else{
		tpb := hdr.division & 16r7fff;   #ticks per beat or quarter note of music
		hdr.tpb = tpb;
#		print("ticks per beat %d\n", tpb);
	}
	hdr.tracks = array[hdr.numtracks] of ref Track;
#	print("%d, %d, %d, %x\n", hdr.length, hdr.format, hdr.numtracks, hdr.division);
	for(i := 0; i < hdr.numtracks; i++){
		trk := ref Track(nil, 0, nil);
		trk.id = gid(io);
		trk.length = g32(io);
		events := array[2] of ref Event;
		nevent := 0;
#		print("%s %d\n", trk.id, trk.length);
		offset := io.offset() + big trk.length;
		last := 0;
		do{
			if(nevent >= len events)
				events = (array[len events * 2] of ref Event)[0:] = events;
			t := 0;
			t = gv32(io);
			c := io.getb();
#			print("%d, %x %bx\n", t, c, io.offset());
			case c {
			META =>
				mtype := io.getb();
				vlen := gv32(io);
#				print("meta len %d\n", vlen);
				buf := array[vlen] of byte;
				n := io.read(buf, len buf);
				if(n != len buf)
					fprint(fildes(2), "read %d expected %d\n", n, len buf);
#				if(mtype == EOT)
#					print("End of Track\n");
				events[nevent] = ref Event.Meta(t, mtype, buf);
			SYSEX =>
#				print("sysex\n");
				vlen := gv32(io);
				buf := array[vlen] of byte;
				n := io.read(buf, len buf);
				if(n != len buf)
					fprint(fildes(2), "read %d expected %d\n", n, len buf);
				events[nevent] = ref Event.Sysex(t, 0, buf);
			SYSEXX =>
				fprint(fildes(2), "Eep! SysExx\n");
			* =>
				p1, p2 : int;
				status := c;
				if(!(status&16r80)){
					p1 = status;
					status = last;
				}else {
					p1 = io.getb();
				}
				etype := status>>4;
				cnum := (status&16r0f);
#				print("e%x c%d\n", etype, cnum);
				if(etype != PROGCHG && etype != CHANAFTERTOUCH) 
					p2 = io.getb();
				last = status;
				events[nevent] = ref Event.Control(t, etype, cnum, p1, p2);
			}
			nevent++;
		}while(io.offset() < offset);
		trk.events = events[:nevent];
		hdr.tracks[i] = trk;
	}
	return hdr;
}


g32(io: ref Iobuf): int
{
	n := 0;
	for(k :=0; k<4; k++)
		n = (n << 8) | int io.getb();
	return n;
}

g16(io: ref Iobuf): int
{
	n := 0;
	for(k :=0; k<2; k++)
		n = (n << 8) | int io.getb();
	return n;
}

gid(io: ref Iobuf): string
{
	buf  := array[4] of byte;
	io.read(buf, len buf);
	return string buf;
}

gv32(io: ref Iobuf): int
{
	n := 0;
	c := 0;
	if((n = io.getb()) & 16r80){
		n &= 16r7f;
		do{
			n = (n<<7) + ((c=io.getb()) & 16r7f);
		}while (c & 16r80);
	}
	return n;
}
