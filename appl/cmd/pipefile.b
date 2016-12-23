implement pipefile;

include "sys.m";
include "draw.m";
include "sh.m";
include "arg.m";

TEMP: con "/n/temp";

sys: Sys;
sh: Sh;

pipefile: module
{
	init: fn(nil: ref Draw->Context, argv: list of string);
};

connect(cmd: string, fd0, fd1: ref Sys->FD)
{
	sys->pctl(Sys->FORKFD|Sys->NEWPGRP, nil);
	sys->dup(fd0.fd, 0);
	sys->dup(fd1.fd, 1);
	fd0 = fd1 = nil;
	sh->run(nil, "sh" :: "-c" :: cmd :: nil);
}

init(nil: ref Draw->Context, argv: list of string)
{
	ifd0, ifd1, fd0, fd1: ref Sys->FD;
	rcmd, wcmd, file: string = nil;
	dupflag: int = 0;

	sys = load Sys Sys->PATH;
	if((sh = load Sh Sh->PATH) == nil)
		fatal("can't load " + Sh->PATH);
	if((arg := load Arg Arg->PATH) == nil)
		fatal("can't load " + Arg->PATH);

	arg->init(argv);
	arg->setusage("pipefile [-d] [-r command] [-w command] file");
	while(( c:= arg->opt()) != 0)
		case c {
		'd' => dupflag = 1;
		'r' => rcmd = arg->earg();
		'w' => wcmd = arg->earg();
		* => arg->usage();
		}
	argv = arg->argv();

	if(len argv != 1 || (rcmd == nil && wcmd == nil))
		arg->usage();
	if(rcmd == nil)
		rcmd = "/dis/cat.dis";
	if(wcmd == nil)
		wcmd = "/dis/cat.dis";
	arg = nil;

	file = hd argv;
	if(dupflag){
		if((ifd0 = sys->open(file, sys->OREAD)) == nil)
			fatal("open " + file);
		ifd1 = ref Sys->FD(sys->dup(ifd0.fd, -1));
	}else{
		if((ifd0 = sys->open(file, sys->OREAD)) == nil)
			fatal("open " + file);
		if((ifd1 = sys->open(file, sys->OWRITE)) == nil)
			fatal("open " + file);
	}

	if(sys->bind("#|", TEMP, sys->MREPL) < 0)
		fatal("bind pipe " + TEMP);
	if(sys->bind(TEMP + "/data", file, sys->MREPL) < 0)
		fatal("bind " + TEMP + "/data " + file);

	if((fd0 = sys->open(TEMP + "/data1", sys->OREAD)) == nil)
		fatal("open " + TEMP + "/data1");
	spawn connect(wcmd, fd0, ifd1);
	fd0 = ifd1 = nil;
	if((fd1 = sys->open(TEMP + "/data1", sys->OWRITE)) == nil)
		fatal("open " + TEMP + "/data1");
	spawn connect(rcmd, ifd0, fd1);
	ifd0 = fd1 = nil;
	sys->unmount(nil, TEMP);
}

fatal(s: string)
{
	sys->fprint(sys->fildes(2), "pipefile: %s: %r\n", s);
	exit;
}
