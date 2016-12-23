implement Irc;

include "sys.m";
	sys: Sys;
	fprint, print, sprint, fildes, tokenize, Connection: import sys;

include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;

include "draw.m";

include "string.m";
	str: String;
	splitstrl : import str;

include "irc.m";

ircfd: ref Sys->FD;
ircaddr: string;
ichan: list of ref Ichan;
stderr: ref Sys->FD;

CHANBUF : con 10;

blankisub : Isub;
blankimsg : Imsg;
blankiwho: Iwho;
blankichan: Ichan;


init()
{
	sys = load Sys Sys->PATH;
	str = load String String->PATH;
	bufio = load Bufio Bufio->PATH;

	stderr = fildes(2);
	readchan = chan[CHANBUF] of ref Imsg;
	writechan = chan[CHANBUF] of string;
	subchan = chan[CHANBUF] of ref Isub;
	unsubchan = chan[CHANBUF] of ref Isub;
	spawn mux();
	spawn ping();
}

ircdial(addr: string): int
{
	(ok, net) := sys->dial(netmkaddr(addr, "tcp", "6667"), nil);
	if(ok < 0) {
		fprint(stderr, "irc: %r\n");
		return -1;
	}
	spawn ircread(net.dfd);
	spawn ircwrite(net.dfd);
	return 0;
}

netmkaddr(addr, net, svc: string): string
{
	if(net == nil)
		net = "net";
	(n, nil) := tokenize(addr, "!");
	if(n <= 1){
		if(svc== nil)
			return sprint("%s!%s", net, addr);
		return sprint("%s!%s!%s", net, addr, svc);
	}
	if(svc == nil || n > 2)
		return addr;
	return sprint("%s!%s", addr, svc);
}

irctokenize(s: string): list of string
{
	l : list of string;
	(p, q) := str->splitl(s, " ");
	l = p :: nil;
	while(q != nil){
		q = q[1:];
		if(len q > 0 && q[0] == ':'){
			l = q :: l;
			break;
		}
		(p, q) = str->splitl(q, " ");
		if(p == nil)
			break;
		else
			l = p :: l;
	}
	nl: list of string;
	for(; l != nil; l = tl l)
		nl = hd l :: nl;
	return nl;
}

irctolower(c: int): int
{
	if('A' <= c && c <= 'Z')
		return c+'a'-'A';
	if(c == '{')
		return '[';
	if(c == '}')
		return ']';
	if(c == '|')
		return '\\';
	if(c == '^')
		return '~';
	return c;
}


irccistrcmp(s, t: string): int
{
	a,b:int;
	j := 0;

	for(; j < len s && j < len t; j++){
		
		a = irctolower(s[j]);
		b = irctolower(t[j]);
		if(a < b)
			return -1;
		if(a > b)
			return 1;
	}
	if(len s == len t)
		return 0;
	else if (j == len s)
		return -1;
	else
		return 1;
}

imsgfmt(m: ref Imsg): string
{
	buf := sprint("pre=%q src=%q dst=%q cmd=%q",
		m.prefix, m.src, m.dst, m.cmd);
	for(l := m.arg; l != nil; l = tl l)
		buf += sprint(", %q", hd l);
	return buf;
}


ircread(fd: ref Sys->FD)
{
	b := bufio->fopen(fd, Bufio->OREAD);
	while((p := b.gets('\n')) != nil){
		p = p[:len p -1];
		if(p[len p -1] == '\r')
			p = p[:len p - 1];
		if(chatty)
			fprint(stderr, "<< %s\n", p);
		m := ref blankimsg;
		flds := irctokenize(p);
		if(len flds < 1){
			fprint(stderr, "irc: bad message (too few args):\n\t%s\n", p);
			continue;
		}
		if((hd flds)[0] == ':'){
			m.prefix = (hd flds)[1:];
			(r, q) := str->splitl(m.prefix, "!");
			if(q != nil)
				m.src = r;
			else {
				(r, q) = str->splitl(m.prefix, "@");
				if(q != nil)
					m.src = r;
				else
				m.src = m.prefix;
			}
			flds = tl flds;
		}
		m.cmd = hd flds;
		flds = tl flds;
		(m.cmdnum, nil) = str->toint(m.cmd, 10);
		if(m.prefix != nil){
			m.dst = hd flds;
			flds = tl flds;
		}
		m.arg = flds;
		readchan <-= m;
	}
	readchan <-= nil;
}

ircwrite(fd: ref Sys->FD)
{
	while((p :=<- writechan) != nil){
		if(chatty)
			fprint(stderr, ">> %s\n", p);
		fprint(fd, "%s\r\n", p);
	}
}

inputrelay(ic: ref Ichan)
{
	b := bufio->fopen(fildes(0), Bufio->OREAD);
	while((p := b.gets('\n')) != nil){
		if(ic != nil){
			buf := sprint("PRIVMSG %s :%s", ic.name, p);
			writechan <-= buf;
		}else
			writechan <-= p;
	}
}

login(fullname: string, nicks: list of string, passwd: string): int
{
	sub := ref blankisub;

	sub.snoop = 1;
	sub.ml = chan[10] of ref Imsg;
	subchan <-= sub;

	if(len nicks == 0)
		nicks = "inferno" :: nil;
	if(fullname == nil)
		fullname = "Acme User";

	buf := sprint("USER %s 0 * :%s", hd nicks, fullname);
	writechan <-= buf;
	accepted := 0;
	loop: for(l := nicks; l != nil; l = tl l){
		nick = hd nicks;
		writechan <-= "NICK " + nick;

		for(;;){
			m :=<- sub.ml;
			if(m.cmd == "001"){
				accepted = 1;
				break loop;
			}
			if(m.cmdnum == 451)
				continue;
			if(m.cmd[0] == '4')
				break;
		}
	}
	if(accepted == 0)
		return -1;
	if(passwd != nil){
		buf = sprint("PRIVMSG nickserv :IDENTIFY %s", passwd);
		writechan <-= buf;
		for(;;){
			m := <- sub.ml;
			if(irccistrcmp(m.src,"nickserv") == 0)
				break;
			if(irccistrcmp(m.cmd, "MODE") == 0) {
				if(len m.arg >= 2
				&& irccistrcmp(hd m.arg, nick) == 0
				&& (hd tl m.arg)[0] == '+'
				&& (splitstrl(hd tl m.arg, "er")).t1 != nil)	# XXX cf. irc.c
					break;
				if(len m.arg >= 1
				&& (hd m.arg)[0] == '+'
				&& (splitstrl(hd m.arg, "er")).t1 != nil)
					break;
			}
		}
	}
	unsubchan <-= sub;
	return 0;
}

printmopthread(s: string)
{
	sub := ref blankisub;
	if(s == "mop")
		sub.mop = 1;
	else if(s == "snoop")
		sub.snoop = 1;
	else
		return;
	sub.ml = chan[10] of ref Imsg;
	subchan <-= sub;
	
	for(;;){
		m :=<- sub.ml;
		print("mop: %s\n", imsgfmt(m));
	}
}

mux()
{
	sub : list of ref Isub;

	for(;;) alt {
	s :=<- subchan =>
		sub = s :: sub;
	us :=<- unsubchan =>
		nl : list of ref Isub;
		for(l := sub; l != nil; l = tl l)
			if((hd l) != us)
				nl = hd l :: nl;
		sub = nl;
	m :=<- readchan => 
		if(m == nil){
			fprint(stderr, "lost network connection\n");
			exit;
		}
		n := 0;
		for(l := sub; l != nil; l = tl l){
			t := hd l;
			nn := 0;
			if(t.snoop 
			|| (!t.mop && t.match != nil && (nn = t.match(t, m)))){
				t.ml <-= m;
				if(!t.snoop)
					n += nn;
			}
		}
		if(n == 0){
			for(l = sub; l != nil; l = tl l ){
				t := hd l;
				if(t.mop)
				if(t.match != nil && t.match(t, m)){
					t.ml <-= m;
					n++;
				}
			}
		}
		if(n == 0){
			for(l = sub; l != nil; l = tl l){
				t := hd l;
				if(t.mop && t.match == nil)
					t.ml <-= m;
			}
		}
	}
}

pingmatch(nil: ref Isub, m: ref Imsg): int
{
	return m.cmd == "PING";
}

ping()
{
	src : string;
	sub := ref blankisub;
	sub.match = pingmatch;
	sub.ml = chan[10] of ref Imsg;
	subchan <-= sub;

	for(;;){
		m :=<- sub.ml;
		if(len m.arg > 0)
			src = hd m.arg;
		else
			src = "you";
		buf := sprint("PONG :%s", src);
		writechan <-= buf;
	}
}

ichanmatch(s: ref Isub, m: ref Imsg): int
{

	name := s.name;

	if(m.dst != nil && m.dst[0] == ':')
		m.dst = m.dst[1:];
	if(irccistrcmp(m.dst, name) == 0)
		return 1;

	if(irccistrcmp(m.cmd, "PRIVMSG") == 0)
	if(irccistrcmp(m.dst, nick) == 0){
		(p, nil) := str->splitl(m.prefix, "!");
		if(irccistrcmp(p, name) == 0){
			return 1;
		}
	}
	
	if(irccistrcmp(m.cmd, "NICK") == 0
		|| irccistrcmp(m.cmd, "QUIT") == 0)
#	if(inchannel(m.src, ic))
		return 1;

	if(len m.arg > 0 && irccistrcmp(hd m.arg, name)  == 0)
		return 1;

	if(len m.arg > 1 && m.cmdnum == RPL_NAMREPLY
	&& irccistrcmp(hd tl m.arg, name) == 0)
		return 1;

	return 0;
}

addwho(ic: ref Ichan, m: ref Imsg)
{
	arg := m.arg;
	if(len arg < 5)
		return;
	arg = tl arg;
	wx  := ref blankiwho;
	wx.user = hd arg; arg = tl arg;
	wx.host = hd arg; arg = tl arg;
	wx.server = hd arg; arg = tl arg;
	wx.nick = hd arg; arg = tl arg;
	wx.fullname = "";
	wx.mode[0] = 0;
	n := 0;
	if((hd arg)[0] == 'H' || (hd arg)[0] == 'G')
	if((len (hd arg)) == 1){
		wx.mode[n++] = (hd arg)[0];
		arg = tl arg;
	}
	if(arg != nil && (hd arg)[0] == '*' && len (hd arg) == 1){
		wx.mode[n++] = '*';
		arg = tl arg;
	}
	if(arg != nil && ((hd arg)[0] == '@' ||  (hd arg)[0] == '+'))
	if((len (hd arg)) == 1){
		wx.mode[n] = (hd arg)[0];
		arg = tl arg;
	}
	if(len arg > 0){
		p: string;
		(wx.hops, p) = str->toint(hd arg, 10);
		wx.fullname = str->drop(p, " \t\r\n");
	}
	ic.who  = wx :: ic.who;
}


findnick(ic: ref Ichan, name: string): ref Iwho
{
	for(l := ic.who; l != nil; l = tl l)
		if(irccistrcmp((hd l).nick, name) == 0)
			return hd l;
	return nil;
}

addname(ic: ref Ichan, name: string)
{
	if(findnick(ic, name) != nil)
		return;
	w := ref blankiwho;
	w.nick = name;
	ic.who = w :: ic.who;
}

delname(ic: ref Ichan, name: string)
{
	nl : list of ref Iwho;

	for(l := ic.who; l != nil; l = tl l)
		if(irccistrcmp((hd l).nick, name) != 0)
			nl = hd l :: nl;
	ic.who = nl;
}

changename(ic: ref Ichan, old, name: string)
{
	i := findnick(ic, old);
	if(i == nil)
		addname(ic, name);
	else
		i.nick = name;
}

ichanthread(ic: ref Ichan)
{
	handled := 0;
	joined := 0;
	gotnames := 0;
	m : ref Imsg;

	subchan <-= ic.sub;

	if(ic.name[0] == '#')
		writechan <-= sprint("JOIN :%s", ic.name);
	else{
		if(!ic.sure)
			writechan <-= "WHOIS :" + ic.name;
		else
			joined = 1;
	}

	loop: while((m = <- ic.sub.ml) != nil) {
		handled = 0;
		if(!joined){
			if(m.cmdnum != 477)
			if(400 <= m.cmdnum && m.cmdnum <= 499){
				ic.err = m.cmd;
				break loop;
			}
			if(ic.name[0] != '#' && m.cmdnum == RPL_ENDOFWHOIS){
				handled = 1;
				joined = 1;
			}
		}
		if(ic.name[0] == '#'){
			if(irccistrcmp(m.cmd, "JOIN") == 0){
				if(irccistrcmp(m.src, nick) == 0){ # it's me
					if(!joined)
						joined = 1;
				}else {
					addname(ic, m.src);
				}
				handled = 0;
			}
			if(irccistrcmp(m.cmd, "PART") == 0){
				delname(ic, m.src);
				handled = 0;
			}
			if(irccistrcmp(m.cmd, "NICK") == 0){
				changename(ic, m.src, m.dst);
				handled = 0;
			}
			if(m.cmdnum == RPL_NOTOPIC){
				ic.topic = nil;
				handled = 1;
			}
			if(m.cmdnum == RPL_TOPIC && len m.arg == 1){
				ic.topic = hd m.arg;
				handled = 1;
			}
			if(m.cmdnum == RPL_OWNERTIME && len m.arg == 2){
				ic.owner = hd m.arg;
				(ic.time, nil) = str->toint(hd tl m.arg, 10);
				handled = 1;
			}
			if(m.cmdnum == RPL_NAMREPLY){
				if(gotnames){
					#ignore this, why?
				}else if(len m.arg != 3
				|| len hd m.arg != 1
				|| !str->in((hd m.arg)[0], "=*@")
				|| irccistrcmp(hd tl m.arg, ic.name) != 0)
					print("bad names line: %s\n", imsgfmt(m));
				else{
					(nil, flds) := tokenize(hd tl tl m.arg, " \t\n\r");
					for(; flds != nil; flds = tl flds)
						addname(ic, hd flds);
				}
				handled = 1;
			}
			if(m.cmdnum == RPL_ENDOFNAMES){
				gotnames = 1;
				handled = 1;
			}
			if(m.cmdnum == RPL_WHOREPLY){
				if(!ic._inwho){
					ic.who = nil;
					ic._inwho = 1;
				}
				# fprint(stderr, "who %s %d\n", hd tl tl m.arg, len ic.who);
				addwho(ic, m);  # XXX cf. irc.c
				handled = 1;
			}
			if(m.cmdnum == RPL_ENDOFWHO){
				ic._inwho = 0;
				# sortwho(ic);
				handled = 0;
			}
			
		}
		if(!handled)
			ic.chatter <-= m;
	}

	if(m == nil)
	if(ic.name[0] == '#')
		writechan <-= "PART :" + ic.name;

	unsubchan <-= ic.sub;
}


ircjoin(name: string, sure: int): (string, ref Ichan)
{
	if(name == nil || name[0] == '*' || len name > 128)
		return ("bad channel/nick name", nil);

	for(l:= ichan; l != nil; l = tl l){
		if(irccistrcmp((hd l).name, name) == 0){
			ic := hd l;
			ic.refn++;
			return (nil, ic);
		}
	}

	ic := ref blankichan;
	ic.sure = sure;
	ic.name = name;
	ic.sub = ref blankisub;
	ic.sub.name = name;
	ic.sub.match = ichanmatch;
	ic.sub.ml = chan[10] of ref Imsg;
	ic.chatter = chan[10] of ref Imsg;
	ichan = ic :: ichan;

	spawn ichanthread(ic);

	return (nil, ic);
}

ircleave(ic: ref Ichan)
{
	if(--ic.refn > 0)
		return;

	ic.sub.ml <-= nil; # this will kill the ichanthread
	unsubchan <-= ic.sub;
	nl : list of ref Ichan;
	for(l := ichan; l != nil; l = tl l)
		if(irccistrcmp((hd l).name, ic.name) != 0)
			nl = hd l :: nl;
	ichan = nl;
}
