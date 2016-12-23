implement Createuser;

include "sys.m";
	sys: Sys;

include "daytime.m";
	daytime: Daytime;

include "draw.m";

include "keyring.m";
	kr: Keyring;

Createuser: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

stderr, stdin, stdout: ref Sys->FD;
keydb := "/mnt/keys";
argv0: string;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	kr = load Keyring Keyring->PATH;

	stdin = sys->fildes(0);
	stdout = sys->fildes(1);
	stderr = sys->fildes(2);

	argv0 = hd args;
	args = tl args;

	if (sys->bind("#s", "/chan", Sys->MCREATE) == -1) {
		sys->fprint(stderr, "createuser: bind #s failed: %r\n");
		return;
	}
	fio := sys->file2chan("/chan", "createuser");
	if (fio == nil) {
		sys->fprint(stderr, "createuser: couldn't make /chan/createuser: %r\n");
		return;
	}

	spawn srv(fio);
}

getuser(id: string): (string, array of byte, int, string)
{
	(ok, nil) := sys->stat(keydb);
	if(ok < 0)
		return (nil, nil, 0, sys->sprint("can't stat %s: %r", id));
	dbdir := keydb+"/"+id;
	(ok, nil) = sys->stat(dbdir);
	if(ok < 0)
		return (nil, nil, 0, nil);
	fd := sys->open(dbdir+"/secret", Sys->OREAD);
	if(fd == nil)
		return (nil, nil, 0, sys->sprint("can't open %s/secret: %r", id));
	d: Sys->Dir;
	(ok, d) = sys->fstat(fd);
	if(ok < 0)
		return (nil, nil, 0, sys->sprint("can't stat %s/secret: %r", id));
	l := int d.length;
	secret: array of byte;
	if(l > 0){
		secret = array[l] of byte;
		if(sys->read(fd, secret, len secret) != len secret)
			return (nil, nil, 0, sys->sprint("error reading %s/secret: %r", id));
	}

	fd = sys->open(dbdir+"/expire", Sys->OREAD);
	if(fd == nil)
		return (nil, nil, 0, sys->sprint("can't open %s/expiry: %r", id));
	b := array[32] of byte;
	n := sys->read(fd, b, len b);
	if(n <= 0)
		return (nil, nil, 0, sys->sprint("error reading %s/expiry: %r", id));
	return (dbdir, secret, int string b[0:n], nil);
}

eq(a, b: array of byte): int
{
	if(len a != len b)
		return 0;
	for(i := 0; i < len a; i++)
		if(a[i] != b[i])
			return 0;
	return 1;
}

putsecret(dir: string, secret: array of byte): int
{
	fd := sys->create(dir+"/secret", Sys->OWRITE, 8r600);
	if(fd == nil)
		return -1;
	return sys->write(fd, secret, len secret);
}

putexpiry(dir: string, expiry: int): int
{
	fd := sys->open(dir+"/expire", Sys->OWRITE);
	if(fd == nil)
		return -1;
	return sys->fprint(fd, "%d", expiry);
}

adduser(id, pw: string): string
{
	daytime = load Daytime Daytime->PATH;
	if(daytime == nil) {
		sys->fprint(stderr, "%s: can't load Daytime: %r\n", argv0);
		raise "fail:load";
	}

	(dbdir, secret, expiry, err) := getuser(id);
	if(dbdir == nil){
		if(err != nil){
			sys->fprint(stderr, "%s: can't get auth info for %s in %s: %s\n", argv0, id, keydb, err);
			raise "fail:no key";
		}
		sys->print("new account\n");
	}else
		return "id already exists";

	newsecret: array of byte;
	if(pw != ""){
		pwbuf := array of byte pw;
		newsecret = array[Keyring->SHA1dlen] of byte;
		kr->sha1(pwbuf, len pwbuf, newsecret, nil);
	} else {
		return "empty password";
	}

	# get expiration time (midnight of date specified)
	now := daytime->now();
	tm := daytime->local(now);
	tm.sec = 59;
	tm.min = 59;
	tm.hour = 23;
	tm.year += 10;
	newexpiry := daytime->tm2epoch(tm);	# set expiration date to 23:59:59 ten years from today

	dbdir = keydb+"/"+id;
	fd := sys->create(dbdir, Sys->OREAD, Sys->DMDIR|8r700);
	if(fd == nil){
		sys->fprint(stderr, "%s: can't create account %s: %r\n", argv0, id);
		return "fail:create user";
	}
	if(putsecret(dbdir, newsecret) < 0){
		sys->fprint(stderr, "%s: can't update secret for %s: %r\n", argv0, id);
		return "fail:update";
	}
	if(putexpiry(dbdir, newexpiry) < 0){
		sys->fprint(stderr, "%s: can't update expiry time for %s: %r\n", argv0, id);
		return "fail:update";
	}
	return nil;
}


srv(fio: ref Sys->FileIO)
{
	sys->pctl(Sys->NEWPGRP, nil);
	for (;;) alt {
	(off, count, fid, rc) := <-fio.read =>
		if (rc == nil)
			continue;
		rc <-= (nil, nil);
	(off, data, fid, wc) := <-fio.write =>
		if (wc == nil)
			continue;
		error : string = nil;
		(n, f) := sys->tokenize(string data, " \t\n\r");
		if(n != 2)
			error = "arg";
		else
			error = adduser(hd f, hd tl f);
		if(error != nil)
			wc <-= (0, error);
		else
			wc <-= (len data, nil);
	}
}
