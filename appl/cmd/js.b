implement Js;

# Most of the code below is copied from /appl/charon/jscript.b

include "sys.m";
	sys : Sys;
	print, fprint, fildes: import sys;
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "arg.m";
	arg: Arg;
include "ecmascript.m";
	es: Ecmascript;
	Exec, Obj, Call, Prop, Val, Ref, RefVal, Builtin, ReadOnly, 
	TUndef, TNull, TBool, TNum, TStr, TObj, TRegExp: import es;
me: ESHostobj;

Js: module{
	init:fn(nil:ref Draw->Context, args:list of string);

	get:		fn(ex: ref Exec, o: ref Obj, property: string): ref Val;
	put:		fn(ex: ref Exec, o: ref Obj, property: string, val: ref Val);
	canput:		fn(ex: ref Exec, o: ref Obj, property: string): ref Val;
	hasproperty:	fn(ex: ref Exec, o: ref Obj, property: string): ref Val;
	delete:		fn(ex: ref Exec, o: ref Obj, property: string);
	defaultval:	fn(ex: ref Exec, o: ref Obj, tyhint: int): ref Val;
	call:		fn(ex: ref Exec, func, this: ref Obj, args: array of ref Val, eval: int): ref Ref;
	construct:	fn(ex: ref Exec, func: ref Obj, args: array of ref Val): ref Obj;
};

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
			("readFile", array[] of {"string"} ),
			("write", array[] of { "string"} ) },
		array[] of {PropSpec
			("sysctl", ReadOnly, IVnullstr) }
	),
	ObjSpec("File",
		array[] of {MethSpec
			("read", nil) },
		nil
	)
};


stderr: ref Sys->FD;
ib, ob: ref Iobuf;

init(nil:ref Draw->Context, args:list of string)
{
	sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
	bufio = load Bufio Bufio->PATH;
	es = load Ecmascript Ecmascript->PATH;
	
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
	if(file != nil)
		code = readfile(file);
	else
		code = hd args;
	exec := es->mkexec(nil);
	sysobj := mkhostobj(exec, "System");
	es->put(exec, exec.this, "System", es->objval(sysobj));
	{
		ret := es->eval(exec, code);
		ob.flush();
		if(ret.kind == es->CThrow)
			fprint(stderr, "unhandled error:\n\tvalue:%s\n\treason:%s\n",
				es->toString(exec, ret.val), exec.error);
		if(0)
		if(ret.kind == Ecmascript->CNormal)
		case ret.val.ty {
		TUndef =>
			print("undef\n");
		TNull =>
			print("null\n");
		TBool =>
			if(ret.val.num == 1.)
				print("true\n");
			else
				print("false\n");
		TNum =>
			print("%g\n", ret.val.num);
		TStr =>
			print("%s\n", ret.val.str);
		* =>
			print("other\n");
		}
	}exception exc{
	"*" =>
		fprint(stderr, "fatal error %q executing evalscript: %s\nscript=", exc, exec.error);
	}
}

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

call(ex: ref Exec, func, this: ref Obj, args: array of ref Val, eval: int): ref Ref
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
	"System.prototype.readFile" =>
		s : string;
		for (ai := 0; ai < len args; ai++)
				s += es->toString(ex, es->biarg(args, ai));
		s = readfile(s);
		ans = es->valref(es->strval(s));
	* =>
		es->runtime(ex, nil, "unknown or unimplemented func "+func.val.str+" in host call");
		return nil;
	}
	return ans;
}

construct(ex: ref Exec, func: ref Obj, args: array of ref Val): ref Obj
{
	return nil;
}

