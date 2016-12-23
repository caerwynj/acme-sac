implement Pop3;
 
include "sys.m";
	sys : Sys;
include "draw.m";
include "bufio.m";
	bufio : Bufio;
include "timers.m";
	timers: Timers;
	Timer: import timers;
include "pop3.m";
include "keyring.m";
include "asn1.m";
include "pkcs.m";
include "sslsession.m";
include "ssl3.m";
	ssl3: SSL3;
	Context: import ssl3;
# Inferno supported cipher suites: RSA_EXPORT_RC4_40_MD5
ssl_suites := array [] of {
	byte 0, byte 16r03,	# RSA_EXPORT_WITH_RC4_40_MD5
	byte 0, byte 16r04,	# RSA_WITH_RC4_128_MD5
	byte 0, byte 16r05,	# RSA_WITH_RC4_128_SHA
	byte 0, byte 16r06,	# RSA_EXPORT_WITH_RC2_CBC_40_MD5
	byte 0, byte 16r07,	# RSA_WITH_IDEA_CBC_SHA
	byte 0, byte 16r08,	# RSA_EXPORT_WITH_DES40_CBC_SHA
	byte 0, byte 16r09,	# RSA_WITH_DES_CBC_SHA
	byte 0, byte 16r0A,	# RSA_WITH_3DES_EDE_CBC_SHA
	
	byte 0, byte 16r0B,	# DH_DSS_EXPORT_WITH_DES40_CBC_SHA
	byte 0, byte 16r0C,	# DH_DSS_WITH_DES_CBC_SHA
	byte 0, byte 16r0D,	# DH_DSS_WITH_3DES_EDE_CBC_SHA
	byte 0, byte 16r0E,	# DH_RSA_EXPORT_WITH_DES40_CBC_SHA
	byte 0, byte 16r0F,	# DH_RSA_WITH_DES_CBC_SHA
	byte 0, byte 16r10,	# DH_RSA_WITH_3DES_EDE_CBC_SHA
	byte 0, byte 16r11,	# DHE_DSS_EXPORT_WITH_DES40_CBC_SHA
	byte 0, byte 16r12,	# DHE_DSS_WITH_DES_CBC_SHA
	byte 0, byte 16r13,	# DHE_DSS_WITH_3DES_EDE_CBC_SHA
	byte 0, byte 16r14,	# DHE_RSA_EXPORT_WITH_DES40_CBC_SHA
	byte 0, byte 16r15,	# DHE_RSA_WITH_DES_CBC_SHA
	byte 0, byte 16r16,	# DHE_RSA_WITH_3DES_EDE_CBC_SHA
	
	byte 0, byte 16r17,	# DH_anon_EXPORT_WITH_RC4_40_MD5
	byte 0, byte 16r18,	# DH_anon_WITH_RC4_128_MD5
	byte 0, byte 16r19,	# DH_anon_EXPORT_WITH_DES40_CBC_SHA
	byte 0, byte 16r1A,	# DH_anon_WITH_DES_CBC_SHA
	byte 0, byte 16r1B,	# DH_anon_WITH_3DES_EDE_CBC_SHA
	
	byte 0, byte 16r1C,	# FORTEZZA_KEA_WITH_NULL_SHA
	byte 0, byte 16r1D,	# FORTEZZA_KEA_WITH_FORTEZZA_CBC_SHA
	byte 0, byte 16r1E,	# FORTEZZA_KEA_WITH_RC4_128_SHA
};
ssl_comprs := array [] of {byte 0};

FD, Connection: import sys;
Iobuf : import bufio;

ibuf, obuf : ref Bufio->Iobuf;
conn : int = 0;
inited : int = 0;
 
rpid : int = -1;
cread : chan of (int, string);

DEBUG : con 0;
usessl:= 0;
sslx : ref Context;


open(user, password, server : string, usesslarg: int): (int, string)
{
	s : string;
 	usessl = usesslarg;
	if (!inited) {
		sys = load Sys Sys->PATH;
		bufio = load Bufio Bufio->PATH;
		timers = load Timers Timers->PATH;
		timers->init(100);
		inited = 1;
	}
	if (conn)
		return (-1, "connection is already open");
	if (server == nil) {
		server = defaultserver();
		if (server == nil)
			return (-1, "no default mail server");
	}
	addr: string;
	if(usessl)
		addr = "tcp!" + server + "!995";
	else
		addr = "tcp!" + server + "!110";
	(ok, c) := sys->dial (addr, nil);
	if (ok < 0)
		return (-1, "dialup failed");
	if(usessl){
		# read server greeting, send STLS, initiate TLS, continue as normal
#		buf := array[512] of byte;
#		nb := sys->read(c.dfd, buf, len buf);
#		if(DEBUG)
#			sys->print("%s\n", string buf[:nb]);
#		stls := "STLS\r\n";
#		b := array of byte stls;
#		sys->write(c.dfd, b, len b);
#		nb = sys->read(c.dfd, buf, len buf);
#		if(DEBUG)
#			sys->print("%s\n", string buf[:nb]);
		ssl3 = load SSL3 SSL3->PATH;
		ssl3->init();
		sslx = ssl3->Context.new();
#		sslx.use_devssl();
		vers := 3;
		e: string;
		info := ref SSL3->Authinfo(ssl_suites, ssl_comprs, nil, 0, nil, nil, nil);
		(e, vers) = sslx.client(c.dfd, addr, vers, info);
		if(e != "") {
			return (-1, s);
		}
		if(DEBUG)
			sys->print("SSL HANDSHAKE completed\n");
		cread = chan of (int, string);
		spawn tlsreader(cread);
		(rpid, nil) = <- cread;
	}else{
		ibuf = bufio->fopen(c.dfd, Bufio->OREAD);
		obuf = bufio->fopen(c.dfd, Bufio->OWRITE);
		if (ibuf == nil || obuf == nil)
			return (-1, "failed to open bufio");
		cread = chan of (int, string);
		spawn mreader(cread);
		(rpid, nil) = <- cread;
	}
 	(ok, s) = mread();
	if (ok < 0)
		return (-1, s);
	(ok, s) = mcmd("USER " + user);
	if (ok < 0)
		return (-1, s);
	(ok, s) = mcmd("PASS " + password);
	if (ok < 0)
		return (-1, s);
	conn = 1;
	return (1, nil);
}

stat() : (int, string, int, int)
{
	if (!conn)
		return (-1, "not connected", 0, 0);
	(ok, s) := mcmd("STAT");
	if (ok < 0)
		return (-1, s, 0, 0);
	(n, ls) := sys->tokenize(s, " ");
	if (n == 3)
		return (1, nil, int hd tl ls, int hd tl tl ls);
	return (-1, "stat failed", 0, 0);
}

uidl(m: int) : (int, string)
{
	if (!conn)
		return (-1, "not connected");
	(ok, s) := mcmd(sys->sprint("UIDL %d", m));
	if (ok < 0)
		return (-1, s);
	(n, ls) := sys->tokenize(s, " ");
	if (n == 3)
		return (1, hd tl tl ls);
	return (-1, s);
}

	
msglist() : (int, string, list of (int, int))
{
	ls : list of (int, int);

	if (!conn)
		return (-1, "not connected", nil);
	(ok, s) := mcmd("LIST");
	if (ok < 0)
		return (-1, s, nil);
	for (;;) {
		(ok, s) = mread();
		if (ok < 0)
			return (-1, s, nil);
		if (len s < 3) {
			if (len s > 0 && s[0] == '.')
				return (1, nil, rev2(ls));
			else
				return (-1, s, nil);
		}
		else {
			(n, sl) := sys->tokenize(s, " ");
			if (n == 2)
				ls = (int hd sl, int hd tl sl) :: ls;
			else
				return (-1, "bad list format", nil);
		}
	}
}

uidllist() : (int, string, list of (int, string))
{
	ls : list of (int, string);

	if (!conn)
		return (-1, "not connected", nil);
	(ok, s) := mcmd("UIDL");
	if (ok < 0)
		return (-1, s, nil);
	for (;;) {
		(ok, s) = mread();
		if (ok < 0)
			return (-1, s, nil);
		if (len s < 3) {
			if (len s > 0 && s[0] == '.')
				return (1, nil, ls);
			else
				return (-1, s, nil);
		}
		else {
			(n, sl) := sys->tokenize(s, " ");
			if (n == 2)
				ls = (int hd sl, hd tl sl) :: ls;
			else
				return (-1, "bad list format", nil);
		}
	}
}

msgnolist() : (int, string, list of int)
{
	ls : list of int;

	if (!conn)
		return (-1, "not connected", nil);
	(ok, s) := mcmd("LIST");
	if (ok < 0)
		return (-1, s, nil);
	for (;;) {
		(ok, s) = mread();
		if (ok < 0)
			return (-1, s, nil);
		if (len s < 3) {
			if (len s > 0 && s[0] == '.' && ls != nil)
				return (1, nil, rev1(ls));
			else if(len s > 0 && s[0] == '.')
				return (1, nil, nil);
			else
				return (-1, s, nil);
		}
		else {
			(n, sl) := sys->tokenize(s, " ");
			if (n == 2)
				ls = int hd sl :: ls;
			else
				return (-1, "bad list format", nil);
		}
	}
}

top(m : int) : (int, string, string)
{
	if (!conn)
		return (-1, "not connected", nil);
	(ok, s) := mcmd("TOP " + string m + " 1");
	if (ok < 0)
		return (-1, s, nil);
	return getbdy();
}

get(m : int) : (int, string, string)
{
	if (!conn)
		return (-1, "not connected", nil);
	(ok, s) := mcmd("RETR " + string m);
	if (ok < 0)
		return (-1, s, nil);
	return getbdy();
}
	
getbdy() : (int, string, string)
{
	b : string;

	for (;;) {
		(ok, s) := mread();
		if (ok < 0)
			return (-1, s, nil);
		if (s == ".")
			break;
		if (len s > 1 && s[0] == '.' && s[1] == '.')
			s = s[1:];
		b = b + s + "\n";
	}
	return (1, nil, b);
}

fetch(dir: string, m: int): (int, string)
{
	if (!conn)
		return (-1, "not connected");
	f := dir + "/" + string m;
	(ok, s) := uidl(m);
	if(ok == 1)
		f = dir + "/" + s;
	
	(ok, s) = mcmd("RETR " + string m);
	if (ok < 0)
		return (-1, s);
	fd := sys->create(f, Sys->OWRITE, 0);
	if (fd == nil) 
		return (-1, sys->sprint("could not create '%s'", f));
	for (;;) {
		(ok, s) = mread();
		if (ok < 0)
			return (-1, s);
		if (s == ".")
			break;
		if (len s > 1 && s[0] == '.' && s[1] == '.')
			s = s[1:];
		if(sys->fprint(fd, "%s\n", s) < 0) {
			sys->remove(f);
			return (-1, sys->sprint("could not write '%s': %r", f));
		}
	}
	return (0, nil);
}
	
delete(m : int) : (int, string)
{
	if (!conn)
		return (-1, "not connected");
	return mcmd("DELE " + string m);
}
			
close(): (int, string)
{
	if (!conn)
		return (-1, "connection not open");
	ok := mwrite("QUIT");
	kill(rpid);
	if(!usessl){
		ibuf.close();
		obuf.close();
	}
	conn = 0;
	if (ok < 0)
		return (-1, "failed to close connection");
	return (1, nil);
}
 
SLPTIME : con 100;
MAXSLPTIME : con 10000;

mread() : (int, string)
{
	timer := Timer.start(MAXSLPTIME);
	alt {
		(ok, s) := <- cread =>
			timer.stop();
			return (ok, s);
		<-timer.timeout =>
			sys->print("pop3 timer fired\n");
	}
	kill(rpid);
	return (-1, "smtp timed out\n");	
}

mreader(c : chan of (int, string))
{
	c <- = (sys->pctl(0, nil), nil);
	for (;;) {
		line := ibuf.gets('\n');
		if (DEBUG)
			sys->print("mread : %s", line);
		if (line == nil) {
			c <- = (-1, "could not read response from server");
			continue;
		}
		l := len line;
		if (line[l-1] == '\n')
			l--;
		if (line[l-1] == '\r')
			l--;
		c <- = (1, line[0:l]);
	}
}
 
mwrite(s : string): int
{
	s += "\r\n";
	if (DEBUG)
		sys->print("mwrite : %s", s);
	b := array of byte s;
	l := len b;
	nb: int;
	if(!usessl){
		nb = obuf.write(b, l);
		obuf.flush();
	}else{
		nb = sslx.write(b,l);
	}
	if (nb != l)
		return -1;
	return 1;
}
 
mcmd(s : string) : (int, string)
{
	ok : int;
	r : string;

	ok = mwrite(s);
	if (ok < 0)
		return (-1, err(s) + " send failed");
	(ok, r) = mread();
	if (ok < 0)
		return (-1, err(s) + " receive failed (" + r + ")");
	if (len r > 1 && r[0] == '+')
		return (1, r);
	return (-1, r);
}

defaultserver() : string
{
	return "$pop3";
}

rev1(l1 : list of int) : list of int
{
	l2 : list of int;

	for ( ; l1 != nil; l1 = tl l1)
		l2 = hd l1 :: l2;
	return l2;
}

rev2(l1 : list of (int, int)) : list of (int, int)
{
	l2 : list of (int, int);

	for ( ; l1 != nil; l1 = tl l1)
		l2 = hd l1 :: l2;
	return l2;
}

err(s : string) : string
{
	for (i := 0; i < len s; i++)
		if (s[i] == ' ' || s[i] == ':')
			return s[0:i];
	return s;
}

kill(pid : int) : int
{
	if (pid < 0)
		return 0;
	fd := sys->open("#p/" + string pid + "/ctl", sys->OWRITE);
	if (fd == nil || sys->fprint(fd, "kill") < 0)
		return -1;
	return 0;
}

tlsreader(c : chan of (int, string))
{
	buf := array[1] of byte;
	lin := array[1024] of byte;
	c <- = (sys->pctl(0, nil), nil);
	k := 0;
	for (;;) {
		n := sslx.read(buf, len buf);
		if(n < 0){
			c <- = (-1, "could not read response from server");
			continue;
		}
		lin[k++] = buf[0];
		if(int buf[0] == '\n'){
			line := string lin[0:k];
			if (DEBUG)
				sys->print("tlsreader : %s", line);
			l := len line - 1;
			if (line[l-1] == '\r')
				l--;
			c <- = (1, line[0:l]);
			k = 0;
		}
	}
}
