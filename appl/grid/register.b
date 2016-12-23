implement Register;

#
# Copyright © 2003 Vita Nuova Holdings Limited.  All rights reserved.
#


include "sys.m";
	sys: Sys;
include "draw.m";
include "sh.m";
include "registries.m";
	registries: Registries;
	Registry, Attributes, Service: import registries;
include "grid/announce.m";
	announce: Announce;
include "arg.m";
include "keyring.m";
	keyring: Keyring;
include "security.m";
	auth: Auth;

registered: ref Registries->Registered;
serverkey: ref Keyring->Authinfo;
algs: list of string;
keyfile: string;
doauth := 1;

Register: module {
	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

init(ctxt: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	keyring = load Keyring Keyring->PATH;
	auth = load Auth Auth->PATH;
	sys->pctl(sys->FORKNS | sys->NEWPGRP, nil);
	registries = load Registries Registries->PATH;
	if (registries == nil)
		badmod(Registries->PATH);
	registries->init();
	announce = load Announce Announce->PATH;
	if (announce == nil)
		badmod(Announce->PATH);
	announce->init();
	arg := load Arg Arg->PATH;
	if (arg == nil)
		badmod(Arg->PATH);

	auth->init();
	attrs := Attributes.new(("proto", "styx") :: ("auth", "infpk1") :: ("resource","kfs") :: nil);
	maxusers := -1;
	autoexit := 0;
	myaddr := "";
	arg->init(argv);
	arg->setusage("register [-u maxusers] [-e exit threshold] [-a attributes] { program }");
	while ((opt := arg->opt()) != 0) {
		case opt {
		'C' =>
			algs = arg->earg() :: algs;
		'A' =>
			doauth = 0;
		'k' =>
			keyfile = arg->earg();
			if (! (keyfile[0] == '/' || (len keyfile > 2 &&  keyfile[0:2] == "./")))
				keyfile = "/usr/" + user() + "/keyring/" + keyfile;
		'm' =>
			attrs.set("memory", memory());
		'u' =>
			if ((maxusers = int arg->earg()) <= 0)
				arg->usage();
		'e' =>
			if ((autoexit = int arg->earg()) < 0)
				arg->usage();
		'S' =>
			myaddr = arg->earg();
		'a' =>
			attr := arg->earg();
			val := arg->earg();
			attrs.set(attr, val);
		}
	}
	if (doauth && algs == nil)
		algs = getalgs();
	if (algs != nil) {
		if (keyfile == nil)
			keyfile = "/usr/" + user() + "/keyring/default";
		serverkey = keyring->readauthinfo(keyfile);
		if (serverkey == nil) {
			sys->fprint(stderr(), "listen: cannot read %s: %r\n", keyfile);
			raise "fail:bad keyfile";
		}
	}
	argv = arg->argv();
	if (argv == nil)
		arg->usage();
	(nil, plist) := sys->tokenize(hd argv, "{} \t\n");
	arg = nil;	
	sysname := readfile("/dev/sysname");

	c : sys->Connection;
	if (myaddr == nil) {
		(addr, conn) := announce->announce();
		if (addr == nil)
			error(sys->sprint("cannot announce: %r"));
		myaddr = addr;
		c = *conn;
	}
	else {
		n: int;
		(n, c) = sys->announce(myaddr);
		if (n == -1)
			error(sys->sprint("cannot announce: %r"));
		(n, nil) = sys->tokenize(myaddr, "*");
		if (n > 1) {
			(nil, lst) := sys->tokenize(myaddr, "!");
			if (len lst >= 3)
				myaddr = "tcp!" + sysname +"!" + hd tl tl lst;
		}
	}
	persist := 0;
	if (attrs.get("name") == nil)
		attrs.set("name", sysname);
	spawn regmonitor(myaddr, attrs, persist);
	mountfd := popen(ctxt, plist);
	spawn listener(c, mountfd, maxusers);
}

regmonitor(addr: string, attrs: ref Attributes, persist: int)
{
	for(;;){
		(n, nil) := sys->stat("/mnt/registry/" + addr);
		if(n != 0)
			regain(addr, attrs, persist);
		sys->sleep(1000*60*10);
	}
}

regain(addr: string, attrs: ref Attributes, persist: int)
{
	err: string;
	reg: ref Registry;
	reg = Registry.new("/mnt/registry");
	if (reg == nil){
		svc := ref Service("net!$registry!registry", Attributes.new(("auth", "infpk1") :: nil));
		reg = Registry.connect(svc, nil, nil);
	}
	if (reg == nil){
		sys->fprint(sys->fildes(2), "Could not find registry: %r\n");
		return;
	}
	(registered, err) = reg.register(addr, attrs, persist);
	if (err != nil) 
		sys->fprint(sys->fildes(2), "%s\n", "could not register with registry: "+err);
}

listener(c: Sys->Connection, mountfd: ref sys->FD, maxusers: int)
{
	for (;;) {
		(n, nc) := sys->listen(c);
		if (n == -1)
			error(sys->sprint("listen failed: %r"));
		dfd := sys->open(nc.dir + "/data", Sys->ORDWR);
		if (maxusers != -1 && nusers >= maxusers)
			sys->fprint(stderr(), "register: maxusers (%d) exceeded!\n", nusers);
		else if (dfd != nil) {
			sync := chan of int;
			addr := readfile(nc.dir + "/remote");
			if (addr == nil)
				addr = "unknown";
			if (addr[len addr - 1] == '\n')
				addr = addr[:len addr - 1];
			spawn proxy(sync, dfd, mountfd, addr);
			<-sync;
		}
	}
}

proxy(sync: chan of int, dfd, mountfd: ref sys->FD, nil: string)
{
	sync <-= sys->pctl(0, nil);
	if(doauth){
		err: string;
		(dfd, err) = auth->server(algs, serverkey, dfd, 1);
		if(dfd == nil){
			sys->fprint(sys->fildes(2), "register: auth failed %s\n", err);
			return;
		}
	}
	sys->pctl(Sys->NEWFD | Sys->NEWNS, 1 :: 2 :: mountfd.fd :: dfd.fd :: nil);
	dfd = sys->fildes(dfd.fd);
	mountfd = sys->fildes(mountfd.fd);
	done := chan of int;
	spawn exportit(dfd, done);
	if (sys->mount(mountfd, nil, "/", sys->MREPL | sys->MCREATE, nil) == -1)
		sys->fprint(stderr(), "register: proxy mount failed: %r\n");
	nusers++;
	<-done;
	nusers--;
}

nusers := 0;
clock(tick: chan of int)
{
	for (;;) {
		sys->sleep(2000);
		tick <-= 1;
	}
}

exportit(dfd: ref sys->FD, done: chan of int)
{
	sys->export(dfd, "/", sys->EXPWAIT);
	done <-= 1;
}

popen(ctxt: ref Draw->Context, argv: list of string): ref Sys->FD
{
	sync := chan of int;
	fds := array[2] of ref Sys->FD;
	sys->pipe(fds);
	spawn runcmd(ctxt, argv, fds[0], sync);
	<-sync;
	return fds[1];
}

runcmd(ctxt: ref Draw->Context, argv: list of string, stdin: ref Sys->FD, sync: chan of int)
{
	pid := sys->pctl(Sys->FORKFD, nil);
	sys->dup(stdin.fd, 0);
	stdin = nil;
	sync <-= pid;
	sh := load Sh Sh->PATH;
	sh->run(ctxt, argv);
}

error(e: string)
{
	sys->fprint(stderr(), "register: %s\n", e);
	raise "fail:error";
}

user(): string
{
	if ((s := readfile("/dev/user")) == nil)
		return "none";
	return s;
}

readfile(f: string): string
{
	fd := sys->open(f, sys->OREAD);
	if(fd == nil)
		return nil;

	buf := array[8192] of byte;
	n := sys->read(fd, buf, len buf);
	if(n < 0)
		return nil;

	return string buf[0:n];	
}

stderr(): ref Sys->FD
{
	return sys->fildes(2);
}

badmod(path: string)
{
	sys->fprint(stderr(), "Register: cannot load %s: %r\n", path);
	exit;
}

killg(pid: int)
{
	if ((fd := sys->open("/prog/" + string pid + "/ctl", Sys->OWRITE)) != nil) {
		sys->fprint(fd, "killgrp");
		fd = nil;
	}
}

memory(): string
{
	s := readfile("/dev/memory");
	(nil, lst) := sys->tokenize(s, " \t\n");
	if (len lst > 2) {
		mem := int hd tl lst;
		mem /= (1024*1024);
		return string mem + "mb";
	}
	return "not known";
}

getalgs(): list of string
{
	sslctl := readfile("#D/clone");
	if (sslctl == nil) {
		sslctl = readfile("#D/ssl/clone");
		if (sslctl == nil)
			return nil;
		sslctl = "#D/ssl/" + sslctl;
	} else
		sslctl = "#D/" + sslctl;
	(nil, alg) := sys->tokenize(readfile(sslctl + "/encalgs") + " " + readfile(sslctl + "/hashalgs"), " \t\n");
	return "none" :: alg;
}
