implement Ftrans;
include "sys.m";
	sys: Sys;
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "string.m";
	str: String;
include "names.m";
	names: Names;
include "env.m";
	env: Env;
include "arg.m";

Ftrans: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
	translate: fn(name: string): (string, string);
};

After, Before, Cover, Bind, Mount, Warning, Stop: con (1<<iota);

Entry: adt {
	flags: int;
	src: string;
	dst: string;
};

# work backwards from name.
# find most recent bind/mount which has a target that's a parent of the current directory.
# then work back from there.
# that's fine if it was a bind/mount -c, but what if it was -a or -b.
# in that case, we could just say it's ambiguous,
# or we could do some investigation - i.e. find all
# possible targets. but that's probably unnecessary for now.

stoplist: list of string;
ns: list of ref Entry;
cwd: string;
debug := 0;

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	str = load String String->PATH;
	names = load Names Names->PATH;
	env = load Env Env->PATH;

	init := 1;
	if(argv != nil){
		init = hd argv == nil;
		argv = tl argv;
		if(!init && argv != nil && hd argv == "-d"){
			debug = 1;
			argv = tl argv;
		}
	}
	if(!init && argv == nil)
		fail("usage: ftrans [-ai] [name...]");
	readns();

	# stoplist is a set of pairs of names - if we find ourselves underneath
	# the second of the pair, then we return the first of the pair
	# without further investigation. later entries get higher priority.
	if(init)
		stoplist = argv;
	else
		stoplist = str->unquoted(env->getenv("ftrans"));
	if(len stoplist % 2 != 0)
		fail("unevenly paired stoplist");
	if(init)
		return;

	err := 0;
	for(; argv != nil; argv = tl argv){
		(p, e) := translate(hd argv);
		if(p == nil){
			sys->fprint(sys->fildes(2), "ftrans: %q: %s\n", hd argv, e);
			err++;
		}else
			sys->print("%q\n", p);
	}
	if(err)
		raise "fail:error";
}

translate(name: string): (string, string)
{
if(debug) sys->print("translate %s\n", name);
	name = names->cleanname(names->rooted(cwd, name));
	c := candidates(name, name, ns, nil);
if(debug) sys->print("%d candidates\n", len c);
	if(len c > 1){
		info := statancestor(name);
		uc: list of (int, string);
		for(; c != nil; c = tl c){
			if(devmatch(hd c, info))
				uc = hd c :: uc;
		}
		c = uc;
	}
	if(c == nil)
		return (nil, "no possible candidates");
	if(len c > 1){
		s := "";
		for(; c != nil; c = tl c)
			s += " " +(hd c).t1;
		return (nil, "ambiguous candidates"+s);
	}
	if((hd c).t0 == Mount)
		return (nil, "cannot determine origin of mounted device "+ (hd c).t1);
	return (names->cleanname((hd c).t1), nil);
}

statancestor(name: string): ref Sys->Dir
{
	while(name != nil){
		(e, info) := sys->stat(name);
		if(e != -1)
			return ref info;
		name = names->dirname(name);
	}
	fail(sys->sprint("can't stat /: %r"));
	return nil;
}

devmatch(c: (int, string), d: ref Sys->Dir): int
{
	if(c.t0 & (Mount|Stop))
		return 1;
	p := c.t1;
	if(p[0] != '#')
		return 1;
	return p[1] == d.dtype;
}

stop(p: string): (int, string)
{
	for(s := stoplist; s != nil; s = tl tl s){
		(src, dst) := (hd s, hd tl s);
		if(names->isprefix(dst, p))
			return (Bind|Stop, src+"/"+names->relative(p, dst));
	}
	if(p[0] == '#')
		return (Bind, p);
	return (0, nil);
}

candidates(path, allpath: string, ns: list of ref Entry, acc: list of (int, string)): list of (int, string)
{
if(debug)sys->print("{candidates path %q; allpath: %q\n", path, allpath);
	s := stop(allpath);
	if(s.t1 != nil){
if(debug)sys->print("->stop %s}\n", s.t1);
		return s :: acc;
	}

	for(; ns != nil; ns = tl ns){
		e := hd ns;
if(debug)sys->print("prefix? %q %q\n", e.dst, path);
		if(names->isprefix(e.dst, path)){
if(debug)sys->print("found %q\n", e.dst);
			if(e.flags & Warning)
				warning("old kernel and spaces in pathnames, bad move.");
			if(e.flags & Mount)
				acc = mountcandidates(e.src, allpath, tl ns, acc);
			else
				acc = candidates(e.src, e.src+"/"+names->relative(allpath, e.dst), tl ns, acc);
			if(e.flags & Cover)
				break;
		}
	}
if(debug)sys->print("}\n");
	return acc;
}

mountcandidates(src, p: string, nil: list of ref Entry, acc: list of (int, string)): list of (int, string)
{
	# what *can* we do to find the possible origins of a mount?
	return (Mount, "("+src+" "+p+")") :: acc;
}

readns()
{
	f := bufio->open("/prog/"+string sys->pctl(0, nil)+"/ns", Sys->OREAD);
	if(f == nil){
		warning(sys->sprint("cannot open namespace file: %r"));
		return;
	}
	ns = nil;
	cwd = "/";
	while((s := f.gets('\n')) != nil){
		a := str->unquoted(s);
		if(a == nil)			# can't happen...
			continue;
		if(hd a == "cd")
			cwd = hd tl a;
		else{
			e := parseentry(a);
			if(e != nil)
				ns = e :: ns;
		}
	}
}

parseentry(a: list of string): ref Entry
{
	flags := Cover;
	case hd a {
	"bind" =>
		flags |= Bind;
	"mount" =>
		flags |= Mount;
	* =>
		warning("unknown entry in ns: "+hd a);
		return nil;
	}
	if(hd a == "bind")
		flags |= Bind;
	else
		flags |= Mount;
	a = tl a;
	if((hd a)[0] == '-'){
		f := hd a;
		for(i := 1; i < len f; i++){
			case f[i] {
			'b' =>
				flags = (flags & ~ Cover) | Before;
			'a' =>
				flags = (flags & ~ Cover) | After;
			}
		}
		a = tl a;
	}
	if(len a > 2 && (flags & Bind))		# probably old kernel and spaces in filenames
		flags |= Warning;
	return ref Entry(flags, hd a, hd tl a);
}

warning(e: string)
{
	sys->fprint(sys->fildes(2), "ftrans: warning: %s\n", e);
}

fail(e: string)
{
	sys->fprint(sys->fildes(2), "ftrans: %s\n", e);
	raise "fail:error";
}
