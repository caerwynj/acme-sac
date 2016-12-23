implement Sort;

include "sys.m";
	sys: Sys;
	fprint, fildes, remove: import sys;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "draw.m";
include "arg.m";
include "string.m";
	str: String;

Sort: module
{
	init:	fn(nil: ref Draw->Context, args: list of string);
};

usage()
{
	sys->fprint(sys->fildes(2), "usage: sort [-n] [file]\n");
	raise "fail:usage";
}

Nline: con 10000;
Nmerge: con 10;
Incr: con 2000;		# growth quantum for record array

ntemp := 0;
nline := 0;
lines: array of string;
lineno := 0;

stdout: ref Iobuf;

fcmp: ref fn(a, b: string): int;

init(nil : ref Draw->Context, args : list of string)
{
	bio : ref Bufio->Iobuf;

	sys = load Sys Sys->PATH;
	stderr := sys->fildes(2);
	bufio = load Bufio Bufio->PATH;
	if (bufio == nil) {
		sys->fprint(stderr, "sort: cannot load %s: %r\n", Bufio->PATH);
		raise "fail:bad module";
	}
	Iobuf: import bufio;
	str = load String String->PATH;
	arg := load Arg Arg->PATH;
	if (arg == nil) {
		sys->fprint(stderr, "sort: cannot load %s: %r\n", Arg->PATH);
		raise "fail:bad module";
	}

	nflag := 0;
	rflag := 0;
	arg->init(args);
	fcmp = acmp;
	while ((opt := arg->opt()) != 0) {
		case opt {
		'n' =>
			nflag = 1;
			fcmp = ncmp;
		'r' =>
			rflag = 1;
		* =>
			usage();
		}
	}
	args = arg->argv();
	if (len args > 1)
		usage();
	if (args != nil) {
		bio = bufio->open(hd args, Bufio->OREAD);
		if (bio == nil) {
			sys->fprint(stderr, "sort: cannot open %s: %r\n", hd args);
			raise "fail:open file";
		}
	}
	else
		bio = bufio->fopen(sys->fildes(0), Bufio->OREAD);
	dofile(bio);
	stdout = bufio->fopen(sys->fildes(1), Bufio->OWRITE);
	if(ntemp){
		tempout();
		mergeout(stdout);
	}else
		printout(stdout);
	stdout.close();
	done(nil);
}

acmp(a, b: string): int
{
	return a > b;
}

ncmp(a, b: string): int
{
	(n, nil) := str->toint(a, 10);
	(m, nil) := str->toint(b, 10);
	return n > m;
}

mergesort(a, b: array of string, r: int)
{
	if (r > 1) {
		m := (r-1)/2 + 1;
		mergesort(a[0:m], b[0:m], m);
		mergesort(a[m:r], b[m:r], r-m);
		b[0:] = a[0:r];
		for ((i, j, k) := (0, m, 0); i < m && j < r; k++) {
			if (fcmp(b[i],b[j]))
				a[k] = b[j++];
			else
				a[k] = b[i++];
		}
		if (i < m)
			a[k:] = b[i:m];
		else if (j < r)
			a[k:] = b[j:r];
	}
}

tempfile(n:int):string
{
	dir := "/tmp";
	pid := sys->pctl(0, nil);
	return sys->sprint("%s/sort.%.4d.%.5d", dir, pid%10000,n);
}

dofile(bio: ref Iobuf)
{
	for(;;){
		s := bio.gets('\n');
		if(s == nil)
			break;
		if(nline >= Nline)
			tempout();
		if(nline >= len lines)
			lines = (array[len lines + Incr] of string)[0:] = lines;
		lines[nline++] = s;
		lineno++;
	}
}

printout(b: ref Iobuf)
{
	mergesort(lines, array[nline] of string, nline);
	for (i := 0; i < nline; i++)
		b.puts(lines[i]);
	nline = 0;
}

tempout()
{
	mergesort(lines, array[nline] of string, nline);
	tf := tempfile(ntemp);
	ntemp++;
	f := bufio->create(tf, Bufio->OWRITE, 8r666);
	if(f == nil){
		fprint(fildes(2), "sort:create %s: %r\n", tf);
		exit;
	}
	for (i := 0; i < nline; i++)
		f.puts(lines[i]);
	nline = 0;
	f.close();
}

mergeout(bio: ref Iobuf)
{
	n := 0;
	for(i:=0; i < ntemp; i+= n){
		n = ntemp - i;
		if(n > Nmerge){
			tf := tempfile(ntemp);
			ntemp++;
			f := bufio->create(tf, Bufio->OWRITE, 8r666);
			if(f == nil){
				fprint(fildes(2), "sort:create %s: %r\n", tf);
				exit;
			}
			n = Nmerge;
			mergefiles(i, n, f);
			f.close();
		}else
			mergefiles(i, n, bio);
	}
}

Merge: adt {
	line: string;
	fd: ref Iobuf;
};

mergefiles(t, n: int, b: ref Iobuf)
{
	mp := array[n] of { * => ref Merge};
	mmp := array[n] of ref Merge;
	m: array of ref Merge;
	nn := 0;

	m = mp[0:];

	for(i := 0; i < n; i++) {
		tf := tempfile(t+i);
		f := bufio->open(tf, Bufio->OREAD);
		if(f == nil){
			fprint(fildes(2), "sort:create %s: %r\n", tf);
			exit;
		}
		m[0].fd = f;
		mmp[nn] = m[0];

		l := m[0].fd.gets('\n');
		if(l == nil)
			continue;
		nn++;
		m[0].line = l;

		m = m[1:];
	}

	for(;;){
		sort(mmp, array[nn] of ref Merge, nn);
		m = mmp[0:];
		if(nn == 0)
			break;
		for(;;){
			l := m[0].line;
			b.puts(l);
			l = m[0].fd.gets('\n');
			if(l == nil){
				nn--;
				mmp[0] = mmp[nn];
				break;
			}
			m[0].line = l;
			if(nn > 1 && fcmp(mmp[0].line,mmp[1].line))
				break;
		}
		
	}

	m = mp[0:];
	for(i = 0; i < n; i++)
		m[i].fd.close();
}

sort(a, b: array of ref Merge, r: int)
{
	if (r > 1) {
		m := (r-1)/2 + 1;
		sort(a[0:m], b[0:m], m);
		sort(a[m:r], b[m:r], r-m);
		b[0:] = a[0:r];
		for ((i, j, k) := (0, m, 0); i < m && j < r; k++) {
			if (fcmp(b[i].line, b[j].line))
				a[k] = b[j++];
			else
				a[k] = b[i++];
		}
		if (i < m)
			a[k:] = b[i:m];
		else if (j < r)
			a[k:] = b[j:r];
	}
}

done(xs: string)
{
	for(i := 0; i < ntemp; i++)
		remove(tempfile(i));
	if(xs != nil)
		fprint(fildes(2), "%s\n", xs);
	exit;
}
