implement Ipquery;

include "sys.m";
	sys: Sys;

include "draw.m";

include "bufio.m";

include "attrdb.m";
	attrdb: Attrdb;
	Attr, Tuples, Dbentry, Db: import attrdb;

include "ip.m";
	ip: IP;
include "ipattr.m";
	ipattr: IPattr;
	
include "arg.m";

Ipquery: module
{
	init:	fn(nil: ref Draw->Context, nil: list of string);
};

usage()
{
	sys->fprint(sys->fildes(2), "usage: ipquery attr [value [rattr]]\n");
	raise "fail:usage";
}

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;

	dbfile := "/lib/ndb/local";
	arg := load Arg Arg->PATH;
	if(arg == nil)
		badload(Arg->PATH);
	arg->init(args);
	arg->setusage("ipquery  [-f dbfile] attr value rattr...");
	while((o := arg->opt()) != 0)
		case o {
		'f' =>	dbfile = arg->earg();
		* =>	arg->usage();
		}
	args = arg->argv();
	if(len args < 3)
		arg->usage();
	attr := hd args;
	args = tl args;
	value := hd args;
	rattr :=  tl args;

	attrdb = load Attrdb Attrdb->PATH;
	if(attrdb == nil)
		badload(Attrdb->PATH);
	err := attrdb->init();
	if(err != nil)
		error(sys->sprint("can't init Attrdb: %s", err));
	ip = load IP IP->PATH;
	if(ip == nil)
		badload(IP->PATH);
	ip->init();
	ipattr = load IPattr IPattr->PATH;
	if(ipattr == nil)
		badload(IPattr->PATH);
	ipattr->init(attrdb, ip);
	
	db := Db.open(dbfile);
	if(db == nil)
		error(sys->sprint("can't open %s: %r", dbfile));
	
	if(len rattr == 1){
		(match, es) := ipattr->findnetattr(db, attr, value, hd rattr);
		if(es != nil)
			sys->fprint(sys->fildes(2), "%s\n", err);
		else	
			sys->print("%s\n", match);
		exit;
	}
	(matches, es) := ipattr->findnetattrs(db, attr, value, rattr);
	if(matches == nil || es != nil){
		sys->fprint(sys->fildes(2), "%s\n", err);
		exit;
	}
	sys->print("%q=%q", attr, value);
	for(; matches != nil; matches = tl matches){
		(nil, nattr) := hd matches;
		for(; nattr != nil; nattr = tl nattr){
			na := hd nattr;
			for(al:=na.pairs; al != nil; al = tl al)
				sys->print(" %q=%q", (hd al).attr, (hd al).val); 
		}
	}
	sys->print("\n");
}

badload(s: string)
{
	error(sys->sprint("can't load %s: %r", s));
}

error(s: string)
{
	sys->fprint(sys->fildes(2), "query: %s\n", s);
	raise "fail:error";
}
