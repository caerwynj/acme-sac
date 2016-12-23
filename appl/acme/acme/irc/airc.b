implement Airc;

include "sys.m";
	sys: Sys;
	open, print, sprint, fprint, dup, fildes, pread, pctl,
	OREAD, OWRITE: import sys;
include "draw.m";
include "irc.m";
	irc: Irc;
	ircdial, login, ircjoin, Ichan, Imsg, Isub, irctolower, irccistrcmp,
	ircleave, nick, chatty,
	readchan, writechan, subchan, unsubchan: import irc;
include "arg.m";
	arg: Arg;
include "bufio.m";
include "acmewin.m";
	win: Acmewin;
	Win, Event: import win;
include "string.m";
	str: String;

Airc: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

chattyacme: int;
debug := 0;
nicks : list of string;
ircaddr: string;
server: string;
redial: int;
servername: string;
fullname: string;
ircwin: ref Win;
passwd: string;
stderr: ref Sys->FD;
join: list of string;

usage()
{
	fprint(fildes(2), "usage: airc [-r] [-f fullname] [-n nick] server\n");
	exit;
}

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	pctl(Sys->NEWPGRP, nil);
	irc = load Irc Irc->PATH;
	irc->init();
	irccmd := "";
	stderr = fildes(2);
	win = load Acmewin Acmewin->PATH;
	win->init();

	str = load String String->PATH;
	arg = load Arg Arg->PATH;
	for(l := args; l != nil; l = tl l){
		irccmd += hd l;
		if(tl args != nil)
			irccmd += " ";
	}
	arg->init(args);
	while((c := arg->opt()) != 0)
	case c {
	'A'  => chattyacme = 1;
	'D' => debug = 1;
	'V' => chatty = 1;
	'f' => fullname = arg->earg();
	'n' => nicks = arg->earg() :: nicks;
	'r' => redial = 1;
	's' => servername = arg->earg();
	'p' => passwd = arg->earg();
	'j' => join = arg->earg() :: join;
	}
	args = arg->argv();
	if(len args != 1)
		usage();
	server = hd args;
	if(servername == nil)
		servername = server;
	ircwin = w := Win.wnew();
	w.wname("/irc/" + servername);
	w.wsetdump("/", irccmd);
	w.openbody(Sys->OWRITE);

#	if((fd := w.openfile("errors")) != nil){
#		dup(fd.fd, 1);
#		dup(fd.fd, 2);
#		fd = nil;
#	}
	pid := chan of int;
	spawn infothread(pid);
	spawn autowinthread(pid);
	<-pid;
	<-pid;
	if(ircdial(server) < 0){
		fprint(stderr, "dial %s: %r", ircaddr);
		postnote(1, pctl(0, nil), "kill");
		exit;
	}

	if(login(fullname, nicks, passwd) < 0){
		fprint(stderr, "login failed");
		postnote(1, pctl(0, nil), "kill");
		exit;
	}
	for (; join != nil; join = tl join)
		newchat(hd join, nil);
	mainwin(w);
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

Chat: adt {
	name: string;
	m: ref Imsg;
	w: ref Win;
	ic: ref Ichan;
};

clist: list of ref Chat;

doexec(w: ref Win, ic: ref Ichan, cmd: string): int
{
	cmd = skip(cmd, "");
	if(cmd != nil && cmd[0] == '!'){
		writechan <-= cmd[1:];
		return 1;
	}
	arg: string;
	(cmd, arg) = str->splitl(cmd, " \t\r\n");
	if(arg != nil)
		arg = skip(arg, "");
	(arg, nil) = str->splitl(arg, " \t\r\n");
	case cmd {
	"Chat" =>
		if(arg == nil){
			fprint(stderr, "invalid name %q\n", arg);
			return 1;
		}
		newchat(arg, nil);
	"Del" or "Delete" =>
		return -1;
	"List" =>
		if(arg == nil){
			fprint(stderr, "invalid name %q\n", arg);
			return 1;
		}
		writechan <-= "LIST :" + arg;
	"Whois" =>
		if(arg == nil){
			fprint(stderr, "invalid name %q\n", arg);
			return 1;
		}
		writechan <-= "WHOIS :" + arg;
	"Nick" =>
		writechan <-= "NICK " + arg;
	"Who" =>
		if(ic != nil)
			writechan <-= "WHO " + ic.name;
	"Scroll" =>
		w.ctlwrite("scroll\n");
	"Noscroll" =>
		w.ctlwrite("noscroll\n");
	* =>
		return 0;
	}
	return 1;
}

skip(s, cmd: string): string
{
	s = s[len cmd:];
	while(s != nil && (s[0] == ' ' || s[0] == '\t' || s[0] == '\n'))
		s = s[1:];
	return s;
}

mainwin(w: ref Win)
{
	c := chan of Event;
	na: int;
	ea: Event;
	s: string;

	w.wtagwrite("List Chat");
#	w.wclean();     does a flush which is race condition with infothread and bufio is not threadsafe
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
			n := doexec(w, nil, s);
			if(n == 0)
				w.wwriteevent(ref e);
			else if(n < 0)
				break loop;
		'l' or 'L' =>
			w.wwriteevent(ref e);
		}
	}
	postnote(1, pctl(0, nil), "kill");
	w.wdel(1);
	# XXX kill all
	exit;
}

fixhostpt(w: ref Win, hostpt: int): int
{
	dofix := 0;
	buf := "?";
	if(hostpt == 0){
		dofix = 1;
	}else if(hostpt == 1){
		buf = w.wread(hostpt -1, hostpt);
		if(len buf == 0 || buf[0] != '\n')
			dofix = 1;
	}else if (hostpt > 1){
		buf = w.wread(hostpt - 2, hostpt);
		if(len buf != 2 
		|| buf[0] != '\n'
		|| buf[1] != '\n')
			dofix = 1;
	}
	if(!dofix)
		return hostpt;
#	fprint(stderr, "new newline at %ud - %c\n", hostpt, buf[0]);
	w.wreplace(sprint("#%ud,#%ud", hostpt, hostpt), "\n");
	hostpt++;
	return hostpt;
}

getdot(w: ref Win): (int, int, int)
{
	buf := array[24] of byte;

	w.ctlwrite("addr=dot\n");
	if(pread(w.addr, buf, 24, big 0) != 24)
		return (-1, 0, 0);
	(n, nil) := str->toint(string buf[:12], 10);
	(m, nil) := str->toint(string buf[12:], 10);
	if(debug)
		sys->print("getdot: %d %d from %s \n", n, m, string buf);
	return (0, n, m);
}
	

doline(w: ref Win, name, line: string, q0, q1:int): int
{
	if(line != nil && line[len line - 1] == '\n')
		line=line[:len line - 1];
	if(len line > 0){
		writechan <-= "PRIVMSG " + name + " :" + line;
		w.wreplace(sprint("#%ud,#%ud", q0-1, q1), sprint("<%s> %s\n\n", nick, line));
		(nil, q0, q1) = readaddr(w);
		w.wselect("$");
	}
	return q1;
}

domsg(w: ref Win, name: string, hostpt: int): int
{
	hostpt = fixhostpt(w, hostpt);
	if(w.wsetaddr(sprint("#%ud", hostpt), 1) == 0){
		w.wsetaddr("$+#0", 1);
		(nil, q0, nil) := readaddr(w);
		return q0;
	}
	if(w.wsetaddr(sprint("#%ud", hostpt), 1) && w.wsetaddr("/\\n/", 1)){
		(nil, q0, q) := readaddr(w);
		if(q <= hostpt) { #wrapped
		#	fprint(stderr, "wrapped\n");
			return hostpt;
		}
		line := w.wread(hostpt, q0);
		hostpt = doline(w, name, line, hostpt, q);
	}else
		fprint(stderr, "bad hostpt in domsg\n");
	return hostpt;
}

readaddr(w: ref Win): (int, int, int)
{
	buf := array[24] of byte;
	if(pread(w.addr, buf, 24, big 0) <=0)
		return (-1, 0, 0);
	(n, nil) := str->toint(string buf[:12], 10);
	(m, nil) := str->toint(string buf[12:], 10);
	if(debug)
		sys->print("readaddr: %d %d from %s \n", n, m, string buf);
	return (0, n, m);
}

newchat(name: string, m: ref Imsg)
{
	for(l:=clist; l != nil; l = tl l){
		if(irccistrcmp((hd l).name, name) == 0){
			(hd l).w.wshow();
			return;
		}
	}
	w := Win.wnew();
	w.wname(sprint("/irc/%s/%s", servername, name));
	(e, ic) := ircjoin(name, m!=nil);
	if(e != nil) {
		w.wwritebody(sprint("join %s: %s\n", name, e));
		return;
	}
	ch := ref Chat(name, m, w, ic);
	clist = ch :: clist;
	spawn chatwin(ch);
}

lower(s: string): string
{
	t: string;
	for(i := 0; i< len s; i++)
		t[i] = irctolower(s[i]);
	return t;
}

dowho(ic: ref Ichan)
{
	ircwin.wwritebody(sprint("in %s:\n", ic.name));
	for(l := ic.who; l != nil; l = tl l){
		w := hd l;
		ircwin.wwritebody(sprint("\t%s\t%s <%s@%s>\n",
			w.nick, w.fullname, w.user, w.host));
	}
	if(len ic.who == 0)
		ircwin.wwritebody("\t(no one)\n");
}


chatwin(chat : ref Chat)
{
	hostpt := 1;
	ea: Event;
	lastc2: int;
	na: int;
	name := chat.name;
	ic := chat.ic;
	w := chat.w;
	w.wwritebody("\n");
	w.wtagwrite("Who");
	c := chan of Event;
	spawn w.wslave(c);
	loop: for(;;) alt {
	m := <- ic.chatter =>
		hostpt = fixhostpt(w, hostpt);
		addr := sprint("#%ud", hostpt -1);
		if(!w.wsetaddr(addr, 1)){
			fprint(stderr, "bad address from fihostpt %s\n", addr);
			addr = "$";
		}
		case m.cmdnum {
		Irc->RPL_NOTOPIC 
		or Irc->RPL_TOPIC 
		or Irc->RPL_OWNERTIME
		or Irc->RPL_LIST
		or Irc->ERR_NOCHANMODES =>
				;
		Irc->RPL_WHOISUSER 
		or Irc->RPL_WHOWASUSER =>
			w.wreplace(addr, sprint("<*> %s: %s@%s: %s\n",								hd m.arg, hd tl m.arg, hd tl tl m.arg, hd tl tl tl m.arg));
		Irc->RPL_WHOISSERVER =>
			w.wreplace(addr, sprint("<*> %s: %s %s\n",
				hd m.arg, hd tl m.arg, hd tl tl m.arg));
		Irc->RPL_WHOISOPERATOR 
		or Irc->RPL_WHOISCHANNELS
		or Irc->RPL_WHOISIDENTIFIED =>
			w.wreplace(addr, sprint("<*> %s: %s\n",
				hd m.arg, hd tl m.arg));
		Irc->RPL_WHOISIDLE =>
			w.wreplace(addr, sprint("<*> %s: %s seconds idle\n",
				hd m.arg, hd tl m.arg));
		Irc->RPL_ENDOFWHO =>
			dowho(ic);
		* =>
			case lower(m.cmd) {
			"join" =>
				w.wreplace(addr, sprint("<*> Who +%s\n", m.src));
			"part" =>
				w.wreplace(addr, sprint("<*> Who -%s\n", m.src));
			"quit" =>
				if(inchannel(m.src, ic))
					w.wreplace(addr, sprint("<*> Who -%s (%s)\n", 
					m.src, m.dst));
			"nick" =>
				if(inchannel(m.src, ic))
					w.wreplace(addr, sprint("<*> Who %s => %s\n",
					m.src, m.dst));
			"privmsg" =>
				w.wreplace(addr, sprint("<%s> %s\n", m.src, hd m.arg));
			"notice" =>
				w.wreplace(addr, sprint("[%s] %s\n", m.src, hd m.arg));
			"ping" =>
				;
			* =>
				w.wreplace(addr, sprint("unexpected msg: \n"));
			}
		}
		(nil, nil, hostpt) = readaddr(w);
		hostpt++;

	e := <-c =>
		if(chattyacme || debug)
			fprint(stderr, "event %c hostpt %ud\n", e.c1, hostpt);
		case e.c1 {
#		'F' =>
#			case e.c2 {
#			'I' =>
#				if(lastc2 == 'D')
#					hostpt = e.q1;
#				else {
#					hostpt = e.q1 + 1;
#					if(e.q1 == 0)
#						hostpt = 0;
#				}
#			}
		'M' or 'K'  =>
			case e.c2 {
			'I' =>
				if(e.q0 < hostpt)
					hostpt += e.q1-e.q0;
				else
					hostpt = domsg(w, name, hostpt);
			'D' =>
				if(e.q0 < hostpt){
					if(hostpt < e.q1)
						hostpt = e.q0;
					else
						hostpt -= e.q1 - e.q0;
				}
			'x' or 'X' =>
				s: string;
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
				#sys->print("chatwinexec: %s\n", s);
				n := doexec(w, ic, s);
				if(n == 0)
					w.wwriteevent(ref e);
				else if (n < 0)
					break loop;
			'l' or 'L' =>
				w.wwriteevent(ref e);
			}
		}
		lastc2 = e.c2;
	}
	# remove ourselves from chatlist
	nl : list of ref Chat;
	for(l:=clist; l != nil; l = tl l)
		if(irccistrcmp((hd l).name, chat.name) != 0)
			nl = hd l :: nl;
	clist = nl;
	ircleave(ic);
	w.wdel(1);
}

blankisub : Isub;

anyprivmsg(nil: ref Isub, m: ref Imsg): int
{
	if(m.src == nil || m.dst == nil)
		return 0;
	return irccistrcmp(m.cmd, "PRIVMSG") == 0 
		|| irccistrcmp(m.cmd, "NOTICE") == 0;
}


autowinthread(c: chan of int)
{
	c <-= pctl(0, nil);
	name: string;
	sub := ref blankisub;
	sub.match = anyprivmsg;
	sub.ml = chan[10] of ref Imsg;
	subchan <-= sub;

	for(;;){
		m :=<-sub.ml;
		if(m == nil)
			return;
		if(m.dst == nil || m.src == nil)
			continue;
		if(nick == nil || irccistrcmp(m.dst, nick) == 0)
			name = m.src;
		else
			name = m.dst;
		newchat(name, m);
	}
}


infomatch(nil: ref Isub, m: ref Imsg): int
{

	case m.cmdnum {
	Irc->RPL_TOPIC
	or Irc->RPL_OWNERTIME
	or Irc->RPL_NAMREPLY
	or Irc->RPL_ENDOFNAMES
	or Irc->RPL_WHOREPLY
	or Irc->RPL_ENDOFWHO =>
		return 0;
	* =>
		if(m.cmdnum > 0 && m.cmdnum < 400)
			return 1;
	}
	if(irccistrcmp(m.cmd, "NOTICE") == 0 && m.src == nil)
		return 1;
	if(irccistrcmp(m.cmd, "JOIN") == 0)
		return 1;
	if(irccistrcmp(m.cmd, "PART") == 0)
		return 1;
	if(irccistrcmp(m.cmd, "QUIT") == 0)
		return 1;
	if(irccistrcmp(m.cmd, "MODE") == 0)
		return 1;
	return 0;
}

infothread(c: chan of int)
{
	c <-= pctl(0, nil);
	sub := ref blankisub;
	sub.match = infomatch;
	sub.ml = chan[10] of ref Imsg;
	subchan <-= sub;

	while((m := <-sub.ml) != nil){
		buf := "";
		case m.cmdnum {
		* =>
			if(m.prefix != nil)
				buf = ":" + m.prefix + " ";
			buf += m.cmd + " ";
			if(m.dst != nil)
				buf += m.dst + " ";
		1 or 2 or 3 or 4 or 5 
		or 250 or 251 or 252 or 254 
		or 255 or 265 or 372 or 375 
		or 376 =>
			;
		}
		for(l := m.arg; l != nil; l = tl l)
			if(tl l == nil)
				buf += hd l;
			else
				buf += hd l + " ";
		buf += "\n";
		ircwin.wwritebody(buf);
	}
}

inchannel(who: string, ic: ref Ichan): int
{
	if(irccistrcmp(who, ic.name) == 0)
		return 1;
	for(l := ic.who; l != nil; l = tl l)
		if(irccistrcmp(who, (hd l).nick) == 0)
			return 1;
	return 0;
}
