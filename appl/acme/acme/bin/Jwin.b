implement Jwin, ESHostobj;

include "sys.m";
	sys: Sys;
	open, print, sprint, fprint, dup, fildes, pread, pctl, read, write,
	OREAD, OWRITE: import sys;
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "arg.m";
	arg: Arg;
include "acmewin.m";
	win: Acmewin;
	Win, Event: import win;
include "string.m";
	str: String;
include "ecmascript.m";
	es: Ecmascript;
	Exec, Obj, Call, Prop, Val, Ref, RefVal, Builtin, ReadOnly, 
	TUndef, TNull, TBool, TNum, TStr, TObj, TRegExp: import es;
	me: ESHostobj;
	
include "web.m";
	web: Web;

Jwin: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

stderr: ref Sys->FD;
pwd: string;
ib, ob: ref Iobuf;
exec: ref Exec;
acmewin: ref Win;

init(nil:ref Draw->Context, args:list of string)
{
	sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
	bufio = load Bufio Bufio->PATH;
	es = load Ecmascript Ecmascript->PATH;
	win = load Acmewin Acmewin->PATH;
	win->init();
	str = load String String->PATH;
	web = load Web Web->PATH;
	web->init0();

	me = load ESHostobj SELF;
	stderr = fildes(2);
	ib = bufio->fopen(fildes(0), Bufio->OREAD);
	ob = bufio->fopen(fildes(1), Bufio->OWRITE);
	es->init();
	nullstrval = es->strval("");
	zeroval = es->numval(0.);
	zerostrval = es->strval("0");
	arg->init(args);
	args = tl args;
	file : string;
	while((c := arg->opt()) != 0) {
		case c {
		'f' => file = arg->earg();
		'*' =>
			fprint(stderr, "%s: bad option %c\n", arg->progname(), c);
		}
	}
	args = arg->argv();
	code:string;
	if(file != nil && len file >= 5 && (file[0:5] == "http:" || file[0:5] == "file:"))
		code = string web->readurl(file);
	else if(file != nil)
		code = readfile(file);
	else
		code = hd args;
	exec = es->mkexec(nil);
	sysobj := mkhostobj(exec, "System");
	es->put(exec, exec.this, "System", es->objval(sysobj));
	acmeobj := mkhostobj(exec, "Acmewin");
	es->put(exec, exec.this, "Acmewin", es->objval(acmeobj));

	{
		acmewin = w := Win.wnew();
		w.wname("Jwin");

		ret := es->eval(exec, code);
		ob.flush();
		if(ret.kind == es->CThrow)
			fprint(stderr, "unhandled error:\n\tvalue:%s\n\treason:%s\n",
				es->toString(exec, ret.val), exec.error);
		spawn mainwin(w, acmeobj);
	}exception exc{
	"*" =>
		postnote(1, pctl(0, nil), "kill");
		fprint(stderr, "fatal error %q executing evalscript: %s\nscript=", exc, exec.error);
	}
}

postnote(t : int, pid : int, note : string) : int
{
	fd := open("#p/" + string pid + "/ctl", OWRITE);
	if (fd == nil)
		return -1;
	if (t == 1)
		note += "grp";
	fprint(fd, "%s", note);
	fd = nil;
	return 0;
}

# return nil if none such, or not an object
getobj(ex : ref Exec, o: ref Obj, prop: string) : ref Obj
{
	if(o != nil) {
		v := es->get(ex, o, prop);
		if(es->isobj(v))
			return es->toObject(ex, v);
	}
	return nil;
}

doexec(nil: ref Win, cmd: string, acmeobj: ref Obj): int
{
	cmd = skip(cmd, "");
	arg: string;
	(cmd, arg) = str->splitl(cmd, " \t\r\n");
	if(arg != nil)
		arg = skip(arg, "");
	case cmd {
	"Del" or "Delete" =>
		return -1;
	* =>
		oscript := getobj(exec, acmeobj, "onexec");
		va := array[2] of ref Val;
		va[0] = es->strval(cmd);
		va[1] = es->strval(arg);
		if(oscript != nil){
			v := es->call(exec, oscript, acmeobj, va, 1).val;
			if(v == es->undefined || v == es->true)
				return 1;
		}
	}
	return 0;
}

dolook(nil: ref Win, cmd: string, acmeobj: ref Obj): int
{
	oscript := getobj(exec, acmeobj, "onlook");
	va := array[1] of ref Val;
	va[0] = es->strval(cmd);
	if(oscript != nil){
		v := es->call(exec, oscript, acmeobj, va, 1).val;
		if(v == es->undefined || v == es->true)
			return 1;
	}
	return 0;
}

skip(s, cmd: string): string
{
	s = s[len cmd:];
	while(s != nil && (s[0] == ' ' || s[0] == '\t' || s[0] == '\n'))
		s = s[1:];
	return s;
}

mainwin(w: ref Win, acmeobj: ref Obj)
{
	c := chan of Event;
	na: int;
	ea: Event;
	s: string;
{
	spawn w.wslave(c);
	loop: for(;;){
		e := <- c;
		if(e.c1 != 'M')
			continue;
		case e.c2 {
		'x' or 'X' =>
			eq := e;
			if(e.flag & 2)
				eq =<- c;
			if(e.flag & 8){
				ea =<- c; 
				na = ea.nb;
				<- c; #toss
			}else
				na = 0;

			if(eq.q1>eq.q0 && eq.nb==0)
				s = w.wread(eq.q0, eq.q1);
			else
				s = string eq.b[0:eq.nb];
			if(na)
				s +=  " " + string ea.b[0:ea.nb];
			#sys->print("exec: %s\n", s);
			n := doexec(w, s, acmeobj);
			if(n == 0)
				w.wwriteevent(ref e);
			else if(n < 0)
				break loop;
		'l' or 'L' =>
			eq := e;
			if(e.flag & 2)
				eq =<-c;
			s = string eq.b[0:eq.nb];
			if(eq.q1>eq.q0 && eq.nb==0)
				s = w.wread(eq.q0, eq.q1);
			n := dolook(w, s, acmeobj);
			if(n == 0)
				w.wwriteevent(ref e);
		}
	}
	postnote(1, pctl(0, nil), "kill");
	w.wdel(1);
	exit;
}exception exc{
	"*" =>
		postnote(1, pctl(0, nil), "kill");
		w.wdel(1);
		fprint(stderr, "fatal error %q executing evalscript: %s\nscript=", exc, exec.error);
}
}



# Helper adts for initializing objects.
# Methods go in prototype, properties go in objects

IVundef, IVnull, IVtrue, IVfalse, IVnullstr, IVzero, IVzerostr, IVarray: con iota;

MethSpec: adt
{
	name: string;
	args: array of string;
};

PropSpec: adt
{
	name: string;
	attr: int;
	initval: int;	# one of IVnull, etc.
};

ObjSpec: adt
{
	name: string;
	methods: array of MethSpec;
	props: array of PropSpec;
};


nullstrval: ref Val;
zeroval: ref Val;
zerostrval: ref Val;

objspecs := array[] of {
	ObjSpec("System",
		array[] of {MethSpec
			("getline", nil),
			("print", array[] of {"string"}),
			("system", array[] of { "string"} ),
#			("readFile", array[] of {"string"} ),
			("readUrl", array[] of { "string"}),
			("write", array[] of { "string"} ) },
		array[] of {PropSpec
			("sysctl", ReadOnly, IVnullstr) }
	),
	ObjSpec("Acmewin",
		array[] of {MethSpec
			("writebody", array[] of {"string"}),
			("read", array[] of {"m", "n"} ),
			("name", array[] of { "string"} ),
			("tagwrite", array[] of {"string"}),
			("clean", nil),
			("setaddr", array[] of {"s"}),
			("replace", array[] of {"s", "t"}),
			("select", array[] of {"string"}),
			("readall", nil)},
		nil
	)
};



readfile(f: string): string
{
	fd := bufio->open(f, Bufio->OREAD);
	if(fd == nil)
		return nil;
	r: string;
	while((s := fd.gets('\n')) != nil)
		r += s;
	return r;
}

# Make a host object with given class.
# Get the prototype from the objspecs array
# (if none yet, make one up and install the methods).
# Put in required properties, with undefined values initially.
# If mainex is nil (it will be for bootstrapping the initial object),
# the prototype has to be filled in later.
mkhostobj(ex : ref Exec, class: string) : ref Obj
{
	ci := specindex(class);
	proto : ref Obj;
	if(ex != nil)
		proto = mkprototype(ex, ci);
	ans := es->mkobj(proto, class);
	initprops(ex, ans, objspecs[ci].props);
	ans.host = me;
	return ans;
}

initprops(ex : ref Exec, o: ref Obj, props: array of PropSpec)
{
	if(props == nil)
		return;
	for(i := 0; i < len props; i++) {
		v := es->undefined;
		case props[i].initval {
		IVundef =>
			v = es->undefined;
		IVnull =>
			v = es->null;
		IVtrue =>
			v = es->true;
		IVfalse =>
			v = es->false;
		IVnullstr =>
			v = nullstrval;
		IVzero =>
			v = zeroval;
		IVzerostr =>
			v = zerostrval;
		IVarray =>
			# need a separate one for each array,
			# since we'll update these rather than replacing
			ao := es->mkobj(ex.arrayproto, "Array");
			es->varinstant(ao, es->DontEnum|es->DontDelete, "length", ref RefVal(es->numval(0.)));
			v = es->objval(ao);
		* =>
			;
		}
		es->varinstant(o, props[i].attr | es->DontDelete, props[i].name, ref RefVal(v));
	}
}

# Return index into objspecs where class is specified
specindex(class: string) : int
{
	for(i := 0; i < len objspecs; i++)
		if(objspecs[i].name == class)
			break;
	if(i == len objspecs)
		fprint(stderr, "EXInternal: couldn't find host object class %s", class);
	return i;
}

# Make a prototype for host object specified by objspecs[ci]
mkprototype(ex : ref Exec, ci : int) : ref Obj
{
	class := objspecs[ci].name;
	prototype := es->mkobj(ex.objproto, class);
	meths := objspecs[ci].methods;
	for(k := 0; k < len meths; k++) {
		name := meths[k].name;
		fullname := class + ".prototype." + name;
		args := meths[k].args;
		es->biinst(prototype, Builtin(name, fullname, args, len args),
			ex.funcproto, me);
	}
	return prototype;
}


# Host objects implementations

get(ex: ref Exec, o: ref Obj, property: string): ref Val
{
	return es->get(ex, o, property);
}

put(ex: ref Exec, o: ref Obj, property: string, val: ref Val)
{
	es->put(ex, o, property, val);
}

canput(ex: ref Exec, o: ref Obj, property: string): ref Val
{
	return es->canput(ex, o, property);
}

hasproperty(ex: ref Exec, o: ref Obj, property: string): ref Val
{
	return es->hasproperty(ex, o, property);
}

delete(ex: ref Exec, o: ref Obj, property: string)
{
	es->delete(ex, o, property);
}

defaultval(ex: ref Exec, o: ref Obj, tyhint: int): ref Val
{
	return es->defaultval(ex, o, tyhint);
}

call(ex: ref Exec, func, nil: ref Obj, args: array of ref Val, nil: int): ref Ref
{
	ans := es->valref(es->true);
	case func.val.str {
	"System.prototype.getline" =>
		s := ib.gets('\n');
		if(s != nil)
			ans = es->valref(es->strval(s));
		else
			ans = es->valref(es->false);
	"System.prototype.print" =>
		s: string;
		for (ai := 0; ai < len args; ai++)
				s += es->toString(ex, es->biarg(args, ai));
		ob.puts(s);
#	"System.prototype.readFile" =>
#		s : string;
#		for (ai := 0; ai < len args; ai++)
#				s += es->toString(ex, es->biarg(args, ai));
#		s = readfile(s);
#		ans = es->valref(es->strval(s));
	"System.prototype.readUrl" =>
		s : string;
		for (ai := 0; ai < len args; ai++)
				s += es->toString(ex, es->biarg(args, ai));
		s = string web->readurl(s);
		ans = es->valref(es->strval(s));
	"System.prototype.postUrl" =>
		s := es->toString(ex, es->biarg(args, 0));
		t  := es->toString(ex, es->biarg(args, 1));
		s = string web->posturl(s, t);
		ans = es->valref(es->strval(s));
	"Acmewin.prototype.writebody" =>
		s : string;
		for (ai := 0; ai < len args; ai++)
				s += es->toString(ex, es->biarg(args, ai));
		acmewin.wwritebody(s);
	"Acmewin.prototype.read" =>
		m := es->toInt32(ex, es->biarg(args, 0));
		n := es->toInt32(ex, es->biarg(args, 1));
		s := acmewin.wread(m, n);
		ans = es->valref(es->strval(s));
	"Acmewin.prototype.name" =>
		s := es->toString(ex, es->biarg(args, 0));
		acmewin.wname(s);
	"Acmewin.prototype.tagwrite" =>
		s := es->toString(ex, es->biarg(args, 0));
		acmewin.wtagwrite(s);
	"Acmewin.prototype.clean" =>
		acmewin.wclean();
	"Acmewin.prototype.setaddr" =>
		s :=  es->toString(ex, es->biarg(args, 0));
		n := acmewin.wsetaddr(s, 1);
		ans = es->valref(es->numval(real n));
	"Acmewin.prototype.replace" =>
		s := es->toString(ex, es->biarg(args, 0));
		t := es->toString(ex, es->biarg(args, 1));
		acmewin.wreplace(s, t);
	"Acmewin.prototype.select" =>
		s := es->toString(ex, es->biarg(args, 0));
		acmewin.wselect(s);
	"Acmewin.prototype.readall" =>
		ans = es->valref(es->strval(acmewin.wreadall()));
	* =>
		es->runtime(ex, nil, "unknown or unimplemented func "+func.val.str+" in host call");
		return nil;
	}
	return ans;
}

construct(nil: ref Exec, nil: ref Obj, nil: array of ref Val): ref Obj
{
	return nil;
}
