implement Wiki;

include "sys.m";
	sys: Sys;
	Qid, open, read, write, create, werrstr, fprint: import sys;
include "daytime.m";
	daytime: Daytime;
	now: import daytime;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "string.m";
	str: String;
include "wiki.m";
include "draw.m";
include "sh.m";

init(b: Bufio)
{
	sys = load Sys Sys->PATH;
	bufio = b;
	daytime = load Daytime Daytime->PATH;
	str = load String String->PATH;
	wikidir = ".";
}

# wdir

setwikidir(s: string)
{
	wikidir = s;
}

wname(s: string): string
{
	return  wikidir + "/" + s;
}

wopen(f: string, mode:int): ref Sys->FD
{
	f = wname(f);
	rv := sys->open(f, mode);
	return rv;
}

wcreate(f: string, mode, perm: int): ref Sys->FD
{
	f = wname(f);
	rv := sys->create(f, mode, perm);
	return rv;
}

wBopen(f: string, mode: int): ref Iobuf
{
	f = wname(f);
	rv := bufio->open(f, mode);
	return rv;
}

wdirstat(f: string): ref Sys->Dir
{
	f = wname(f);
	(n, d) := sys->stat(f);
	if(n < 0)
		return nil;
	else
		return ref d;
}

# cache 

Nhash: con 64;
Mcache: con 4;

Wcache: adt {
	n: int;
	use: int;
	tcurrent: int;
	thist: int;
	hist: ref Whist;
	current: ref Whist;
	qid: ref Qid;
	qidhist: ref Qid;
};

tab := array[Nhash] of list of ref Wcache;

findcache(n: int): ref Wcache
{
	for(wl :=tab[n%Nhash]; wl != nil; wl= tl wl){
		w := hd wl;
		if(w.n == n){
			w.use = now();
			return w;	
		}
	}
	return nil;
}

current(w: ref Wcache)
{
	lock := sys->sprint("d/L.%d", w.n);
	file := sys->sprint("d/%d", w.n);
	if(w != nil && w.tcurrent + Tcache >= now())
		return;
	if(((d := wdirstat(file)) == nil) || (d.qid.path == w.qid.path && d.qid.vers == w.qid.vers)){
		w.tcurrent = now();
		return;
	}
	if((wh := readwhist(file, lock, w.qid)) != nil){
		wh.n = w.n;
		w.tcurrent = now();
		w.current = wh;
	}
}

currenthist(w: ref Wcache)
{
	lock := sys->sprint("d/L.%d", w.n);
	file := sys->sprint("d/%d.hist", w.n);
	if(w != nil && w.thist + Tcache >= now())
		return;
	if(((d := wdirstat(file)) == nil) || (d.qid.path == w.qidhist.path && d.qid.vers == w.qidhist.vers)){
		w.thist = now();
		return;
	}
	if((wh := readwhist(file, lock, w.qidhist)) != nil){
		wh.n = w.n;
		w.thist = now();
		w.hist = wh;
	}
}

voidcache(n: int)
{
	if((c := findcache(n)) != nil){
		c.tcurrent = 0;
		c.thist = 0;
	}
}

# we want to avoid locking as much as possible because
# the flush message kills procs possibly leaving stray locks.
# use immutable types and just let last-one-in-wins for caches.
# (file locks are released when the file reference is garbage collected :)
getcache(n, hist: int): ref Whist
{
	wh: ref Whist;
	if((c := findcache(n)) != nil){
		current(c);
		if(hist)
			currenthist(c);
		if(hist)
			wh = c.hist;
		else
			wh = c.current;
		return wh;
	}
	h := n%Nhash;
	ol := tab[h];
	c = ref Wcache(0, 0, 0, 0, nil, nil, nil, nil);
	c.qid = ref Qid(big 0, 0, 0);
	c.qidhist = ref Qid(big 0, 0, 0);
	while(len ol >= Mcache){
		evict := -1;
		t := ~0;
		for(l := ol; l != nil; l = tl l){
			if((hd l).use < t){
				t = (hd l).use;
				evict = (hd l).n;
			}
		}
		l = nil;
		for(;ol != nil; ol = tl ol)
			if((hd ol).n != evict)
				l = hd ol :: l;
		ol = l;
	}
	c.n = n;

	# last in wins!
	tab[h] = c :: ol;
	current(c);
	if(hist)
		currenthist(c);
	if(hist)
		wh = c.hist;
	else
		wh = c.current;
	return wh;
}

getcurrent(n: int): ref Whist
{
	return getcache(n, 0);
}

getcurrentbyname(s: string): ref Whist
{
	if((n := nametonum(s)) < 0)
		return nil;
	return getcache(n, 0);
}

gethistory(n: int): ref Whist
{
	return getcache(n, 1);
}

# io

getlock(lock:string): ref Sys->FD
{
	SECS := 200;

	for(i:=0; i<SECS*10; i++){
		fd := wcreate(lock, Sys->ORDWR, Sys->DMEXCL|8r666);
		if(fd != nil)
			return fd;
		sys->fprint(sys->fildes(2), "wcreate error: %r\n");
		sys->sleep(1000/10);
	}
	werrstr("couldn't acquire lock");
	return nil;
}


readwhist(file: string, lock: string, qid: ref Qid): ref Whist
{
	lfd: ref Sys->FD;
	d: ref Sys->Dir;
	b: ref Iobuf;
	wh: ref Whist;

	if((lfd = getlock(lock)) == nil)
		return nil;

	if(qid != nil){
		if((d = wdirstat(file)) == nil){
			return nil;
		}
		*qid =  d.qid;
	}

	if((b = wBopen(file, Sys->OREAD)) == nil)
		return nil;
	wh = Brdwhist(b);
	lfd = nil;
	return wh;
}


Brdwline(b: ref Iobuf, nil: int): string
{
	p: string;

	if(b.getc() == '#'){
		p = b.gets('\n');
		return p;
	}else{
		b.ungetc();
		return nil;
	}
}

Srdwline(b: ref Iobuf, nil: int): string
{
	return b.gets('\n');
}

Brdwhist(b: ref Iobuf): ref Whist
{
	p, author, comment, title: string;
	current, conflict, c, n, t: int;
	w: array of ref Wdoc;
	h: ref Whist;

	if((p = b.gets('\n')) == nil){
		return nil;
	}

	title = strcondense(p);
	w = nil;
	n = 0;
	t = -1;
	author = nil;
	comment = nil;
	conflict = 0;
	current = 0;
	while((c = b.getc()) != Bufio->EOF){
		if(c != '#'){
			p = b.gets('\n');
			if(p == nil)
				break;
			case c {
			'D' =>
				t = int p;
			'A' =>
				author = p;
			'C' =>
				comment = p;
			'X' =>
				conflict = 1;
			};
		}else {
			b.ungetc();
			if(n%8 == 0)
				w = (array[n+8] of ref Wdoc)[0:] = w;
			w[n] = ref Wdoc;
			w[n].time = t;
			w[n].author = author;
			w[n].comment = comment;
			w[n].wtxt = Brdpage(b, Brdwline);
			w[n].conflict = conflict;
			if(w[n].wtxt == nil)
				raise "Error";
			if(!conflict)
				current = n;	
			n++;
			comment = nil;
			author = nil;
			conflict = 0;
			t = -1;
		}
	}
	h = ref Whist;
	h.title = title;
	h.doc = w;
	h.ndoc = n;
	h.current = current;
	return h;
}


strcondense(s: string): string
{
	ss: string;
	ss = "";
	(nil, flds) := sys->tokenize(s, " \n\t\r");
	for(; flds != nil; flds = tl flds)
		if(tl flds == nil)
			ss += hd flds;
		else
			ss += hd flds + " ";
	return ss;
}

Brdpage(b: ref Iobuf, rdwline: ref fn(b: ref Iobuf, sep: int): string): list of ref Wpage
{
	p: string;
	pw: list of ref Wpage;
	waspara: int;

	while((p = rdwline(b, '\n')) != nil){
		if(p[0] != '!')
			p = strcondense(p);
		if(len p == 0){
			if(waspara == 0){
				waspara=1;
				pw = ref Wpage(Wpara, nil, 0, nil) :: pw;
			}
			continue;
		}
		waspara = 0;
		case p[0] {
		'*' =>
			pw = ref Wpage(Wbullet, nil, 0, nil) :: pw;
			pw = ref Wpage(Wplain, p[1:], 0, nil) :: pw;
		'!' =>
			pw = ref Wpage(Wpre, p[1:], 0, nil) :: pw;
		* =>
			(nil, c) := str->splitl(p, "a-z");
			(nil, d) := str->splitl(p, "A-Z");
			if(len c == 0 && len d != 0){
				pw = ref Wpage(Wheading, p, 0, nil) :: pw;
				continue;
			}
			pw = ref Wpage(Wplain, p, 0, nil) :: pw;
		}
	}
	if(pw == nil)
		return nil;
	pw = reverse(pw);
	pw = wcondense(pw);	# reverses
	pw = wlink(pw);		# reverses again
	return pw;
}

wcondense(wtxt: list of ref Wpage): list of ref Wpage
{
	nw : list of ref Wpage;

	wl := wtxt;
	while(wl != nil){
		if((hd wl).typ != Wplain){
			nw = hd wl :: nw;
			wl = tl wl;
			continue;
		}
		txt := "";
		first := "";
		while(wl != nil && (hd wl).typ == Wplain ){
			w := hd wl;
			w.text = strcondense(w.text);
			txt = txt + first + w.text;
			first = " ";
			wl = tl wl;
		}
		nw = ref Wpage(Wplain, txt, 0, nil) :: nw;
		if(wl == nil)
			break;
	}
	return nw;		# the list is now in reverse order
}

mklink(s: string): ref Wpage
{	
	w : ref Wpage;
	for(i:=0; i < len s; i++)
		if(s[i] == '|')
			break;
	q := s[i:];
	if(len q == 0)
		w = ref Wpage(Wlink, strcondense(s), 0, nil);
	else
		w = ref Wpage(Wlink, strcondense(s[0:i]), 0, s[i+1:]);
	return w;
}

wlink(wtxt: list of ref Wpage): list of ref Wpage
{
	nw: list of ref Wpage;
	for(wl := wtxt; wl != nil; wl = tl wl){
		w := hd wl;
		if(w.typ != Wplain){
			nw = w :: nw;
			continue;
		}
		# TODO this is all wrong
		l : list of ref Wpage;
		l = nil;
		for(;;){
			(a, b) := str->splitl(w.text, "[");
			if(len a > 0){
				w.text = a;
				l = w :: l;
			}
			(c, d) := str->splitl(b, "]");
			if(len c > 1)
				l = mklink(c[1:]) :: l;
			if(len d > 1)
				w = ref Wpage(Wplain, d[1:], 0, nil);
			else{
				for(; l != nil; l = tl l)
					nw = hd l :: nw;
				break;
			}
		}
	}
	return nw;
}

ismanchar(c: int): int
{
	return ('a' <= c && c <= 'z')
		|| ('A' <= c && c <= 'Z')
		|| ('0' <= c && c <= '9')
		|| c=='_' || c=='-' || c=='.' || c=='/'
		|| (c < 0);	# UTF
}


# map

# this should be a proc that reads from a channel to force a refresh.
# maybe it's not even neccessary. last to complete wins.
# the map can't be corrupted.
currentmap(force: int)
{
	lfd: ref Sys->FD;
	d: ref Sys->Dir;
	fd: ref Iobuf;

	if(!force && map != nil && map.t+Tcache >= now())
		return;

	if((lfd = getlock("d/L.map")) == nil)
		return;
	if((d = wdirstat("d/map")) == nil)
		return;
	if(map != nil && d.qid.path == map.qid.path && d.qid.vers == map.qid.vers){
		map.t = now();
		return;
	}

	if(d.length > big Maxmap)
		return;
	if((fd = wBopen("d/map", Sys->OREAD)) == nil)
		return;

	nmap := ref Map;
	m := 0;
	while((s := fd.gets('\n')) != nil) {
		(n, rest) := str->toint(s, 10);
		el := ref Mapel(strcondense(rest), n);
		if(m%8 == 0)
			nmap.el = (array[m + 8] of ref Mapel)[0:] = nmap.el;
		nmap.el[m] = el;
		m++;
	}
	mergesort(nmap.el[:m], array[m] of ref Mapel, m);
	nmap.qid = d.qid;
	nmap.t = now();
	nmap.nel = m;
	map = nmap;
	lfd = nil;
}

mergesort(a, b: array of ref Mapel, r: int)
{
	if (r > 1) {
		m := (r-1)/2 + 1;
		mergesort(a[0:m], b[0:m], m);
		mergesort(a[m:r], b[m:r], r-m);
		b[0:] = a[0:r];
		for ((i, j, k) := (0, m, 0); i < m && j < r; k++) {
			if (b[i].s > b[j].s)
				a[k] = b[j++];
			else
				a[k] = b[i++];
		}
		if (i < m)
			a[k:] = b[i:m];
		else if (j < r)
			a[k:] = b[j:r];
	}
}

# once this function has a local reference to map it doesn't need a lock
# because currentmap() will create a new object, the referenced object doesn't change.
nametonum(s: string): int
{
	lo, hi, m, rv: int;
	p: ref Map;

	s = str->tolower(s);
	for(i:=0;i< len s; i++)
		if(s[i] == '_')
			s[i] = ' ';
	currentmap(0);
	p = map;
	lo = 0;
	hi = map.nel;
	while(hi-lo >1){
		m = (lo+hi)/2;
		if(s < p.el[m].s)
			hi = m;
		else
			lo = m;
	}
	if(hi-lo == 1 && s == p.el[lo].s)
		rv = p.el[lo].n;
	else
		rv = -1;
	return rv;
}

numtoname(n: int): string
{
	p: ref Map;
	currentmap(0);
	p = map;
	for(i:=0; i<p.nel;i++){
		if(p.el[i].n == n)
			break;
	}
	if(i == p.nel)
		return nil;
	return p.el[i].s;
}

allocnum(title: string, mustbenew:int): int
{
	if(title == "map" || title == "new"){
		werrstr("reserved title name");
		return -1;
	}
	(nil, b) := str->splitl(title, "/<>:");
	if(len b != 0){
		werrstr("invalid character in name");
		return -1;
	}
	if((n := nametonum(title)) >=0){
		if(mustbenew){
			werrstr("duplicate title");
			return -1;
		}
		return n;
	}

	title = strcondense(title);
	title = str->tolower(title);

	if((lfd := getlock("d/L.map")) == nil)
		return -1;
	if((fd := wBopen("d/map", Sys->ORDWR)) == nil){
		lfd = nil;
		return -1;
	}
	n = 0;
	rest: string;
	while((s := fd.gets('\n')) != nil){
		(n, rest) = str->toint(s, 10);
		n++;
		if(rest[1:] == title){
			if(mustbenew){
				werrstr("duplicate title");
				return -1;
			}
			else
				return n;
		}
	}
	fd.seek(big 0, Sys->SEEKEND);
	buf := sys->sprint("%d %s\n", n, title);
	fd.write(array of byte buf, len array of byte buf);
	fd.close();
	lfd = nil;
	currentmap(1);
	return n;
}

writepage(num: int, t: int, s: string, title: string): int
{
	err: string;
	tmp := sys->sprint("d/%d", num);
	tmplock := sys->sprint("d/L.%d", num);
	hist := sys->sprint("d/%d.hist", num);
	if((lfd := getlock(tmplock)) == nil)
		return -1;
	conflict := 0;
	if((b := wBopen(tmp, Sys->OREAD)) != nil){
		b.gets('\n');		# title
		p := b.gets('\n');		#version
		if(p == nil || p[0] != 'D'){
			err = sys->sprint("bad format in extant file");
			conflict = 1;
		}
	}else{
		if(t != 0){
			lfd = nil;
			werrstr("did not expect to create");
			return -1;
		}
	}

	if((fd := wopen(hist, Sys->OWRITE)) == nil){
		if((fd = wcreate(hist, Sys->OWRITE, 8r666)) == nil){
			lfd = nil;
			return -1;
		}else
			sys->fprint(fd, "%s\n", title);
	}
	if(sys->seek(fd, big 0, 2) < big 0
	|| (conflict && fprint(fd, "X\n") != 2)
	|| fprint(fd, "%s\n", s) < 0){
		lfd = nil;
		return -1;
	}

	if(conflict){
		lfd = nil;
		voidcache(num);
		werrstr(err);
		return -1;
	}

	if((fd = wcreate(tmp, Sys->OWRITE, 8r666)) == nil){
		lfd = nil;
		voidcache(num);
		return -1;
	}
	fprint(fd, "%s\n", title);
	fprint(fd, "%s\n", s);
	lfd = nil;
	voidcache(num);
	return 0;
}

# transform

endlin(s: string, dosharp: int): string
{
	if(dosharp){
		if(len s == 1 && s[0] == '#')
			return s;
		if(len s > 1 && s[len s - 2] == '\n' && s[len s - 1] == '#')
			return s;
		s += "\n#";
	}else{
		if(len s > 1 && s[len s - 1] == '\n')
			return s;
		s += "\n";
	}
	return s;
}

pagetext(page: list of ref Wpage, dosharp: int): string
{
	inlist, inpara: int;
	s, t, prefix, sharp: string;
	w: ref Wpage;

	inlist = 0;
	inpara = 0;
	prefix = "";
	if(dosharp)
		sharp = "#";
	else
		sharp = "";
	s = sharp;
	for(wl := page; wl != nil; wl = tl wl){
		w = hd wl;
		case w.typ{
		Wheading =>
			if(inlist){
				prefix = "";
				inlist = 0;
			}
			s = endlin(s, dosharp);
			if(!inpara){
				inpara = 1;
				s += "\n" + sharp;
			}
			s += w.text + "\n" + sharp + "\n" + sharp;
		Wpara =>
			s = endlin(s, dosharp);
			if(inlist){
				prefix = "";
				inlist = 0;
			}
			if(!inpara){
				inpara = 1;
				s += "\n" + sharp;
			}
		Wbullet =>
			s = endlin(s, dosharp);
			if(!inlist)
				inlist = 1;
			if(inpara)
				inpara = 0;
			s += " *\t";
			prefix = "\t";
		Wlink =>
			if(inpara)
				inpara = 0;
			t = "[" + w.text;
			if(w.url == nil)
				t += "]";
			else
				t += " | " + w.url + "]";
			s += t;
		Wpre =>
			if(inlist){
				prefix = "";
				inlist = 0;
			}
			if(inpara)
				inpara = 0;
			s = endlin(s, dosharp);
			s += "! " + w.text +  sharp;
		Wplain =>
			if(inpara)
				inpara = 0;
			s += w.text;
		}
	}
	s = endlin(s, dosharp);
	return s;
}

doctext(d: ref Wdoc): string
{
	s: string;
	s = sys->sprint("D%d", d.time);
	if(d.comment != nil)
		s += "\nC" + d.comment;
	if(d.author != nil)
		s += "\nA" + d.author;
	if(d.conflict)
		s += "\nX";
	s += "\n";
	s += pagetext(d.wtxt, 1);	
	return s;
}

reverse(wtxt: list of ref Wpage): list of ref Wpage
{
	nw: list of ref Wpage;
	for(; wtxt != nil; wtxt = tl wtxt)
		nw = hd wtxt :: nw;
	return nw;
}

printpage(wl: list of ref Wpage)
{
	for(; wl != nil; wl = tl wl){
		w := hd wl;
		case w.typ{
		Wpara =>
			sys->print("para\n");
		Wheading =>
			sys->print("heading '%s'\n", w.text);
		Wbullet =>
			sys->print("bullet\n");
		Wlink =>
			sys->print("link '%s' '%s'\n", w.text, w.url);
		Wman =>
			sys->print("man %d %s\n", w.section, w.text);
		Wplain =>
			sys->print("plain '%s'\n", w.text);
		Wpre =>
			sys->print("pre '%s'\n", w.text);
		}
	}
}

pagehtml(page: list of ref Wpage, ty: int): string
{
	inpre, inlist, inpara: int;
	s, p: string;
	w: ref Wpage;

	inlist = 0;
	inpara = 0;
	inpre = 0;

	for(wl := page; wl != nil; wl = tl wl){
		w = hd wl;
		case w.typ{
		Wheading =>
			if(!inpara){
				inpara = 1;
				s += "\n<p>\n";
			}
			s += "<b>" + w.text + "</b>\n<p>\n";
		Wpara =>
			if(inlist){
				inlist = 0;
				s += "\n</ul>\n";
			}
			if(inpre){
				inpre = 0;
				s += "</pre>\n";
			}
			if(!inpara){
				inpara = 1;
				s += "\n<p>\n";
			}
		Wbullet =>
			if(inpre){
				inpre = 0;
				s += "</pre>\n";
			}
			if(!inlist){
				inlist = 1;
				s += "\n<ul>\n";
			}
			if(inpara)
				inpara = 0;
			s += "\n<li>\n";
		Wlink =>
			if(inpara)
				inpara = 0;
			if(w.url == nil)
				p = mkurl(w.text, ty);
			else
				p = w.url;
			s += "<a href=\"" + p + "\">";
			s += escap(w.text, 0);
			s += "</a>";
		Wpre =>
			if(inpara)
				inpara = 0;
			if(inlist){
				inlist = 0;
				s += "\n</ul>\n";
			}
			if(!inpre){
				inpre = 1;
				s += "\n<pre>\n";
			}
			s += escap(w.text, 1);
		Wplain =>
			if(inpre){
				inpre = 0;
				s += "</pre>\n";
			}
			if(inpara)
				inpara = 0;
			s += escap(w.text, 0);
		}
	}
	if(inlist)
		s += "\n</ul>\n";
	if(inpre)
		s += "</pre>\n";
	if(!inpara)
		s += "\n<p>\n";
	return s;
}

mkurl(s: string, ty: int): string
{
	if((len s >= 4 && s[0:4] == "ftp:")
		|| (len s >= 5 && (s[0:5] == "http:" ||s[0:5] == "file:"))
		|| (len s >= 7 && (s[0:7] == "mailto:" || s[0:7] == "telnet:")))
		return s;
	if(ty == Toldpage)
		s = sys->sprint("../../%s", s);
	else
		s = sys->sprint("../%s", s);
	for(i := 0; i < len s; i++)
		if(s[i] == ' ')
			s[i] = '_';
	return s;
}

escap(s: string, pre: int):string
{
	ss := "";
	for(i := 0; i < len s; i++){
		if(str->in(s[i], "<>& ")){
			case s[i] {
			'<' =>
				ss += "&lt;";
			'>' =>
				ss += "&gt;";
			'&' =>
				ss += "&amp;";
			' ' =>
				if(pre)
					ss += " ";
				else
					ss += "\n";
			}
		} else
			ss[len ss] = s[i];
	}
	return ss;
}

tohtml(h: ref Whist, d: ref Wdoc, ty: int): string
{
	s: string;
	sub := array[3] of Sub;
	nsub: int;

	t := gettemplate(ty);
	(p, q) := str->splitstrl(t, "PAGE");
	if(q != nil)
		q = q[4:];
	nsub = 0;
	if(h != nil){
		sub[nsub] = Sub("TITLE", h.title);
		nsub++;
	}
	if(d != nil){
		ver := sys->sprint("%ud", d.time);
		sub[nsub] = Sub("VERSION", ver);
		nsub++;
		atime := daytime->text(daytime->local(d.time));
		sub[nsub] = Sub("DATE", atime);
		nsub++;
	}
	s = appendsub(p, sub[0:nsub]);
	case ty{
	Tpage or Toldpage =>
		s += pagehtml(d.wtxt, ty);
	Tedit =>
		s += pagetext(d.wtxt, 0);
	Tdiff =>
		s += diffhtml(h);
	Thistory =>
		s += historyhtml(h);
	Tnew or Twerror =>
		;
	}
	if(q != nil)
		s += appendsub(q, sub[0:nsub]);
	return s;
}

name := array[] of {
	"page.html",
	"edit.html",
	"diff.html",
	"history.html",
	"new.html",
	"oldpage.html",
	"werror.html",
	"page.txt",
	"diff.txt",
	"history.txt",
	"oldpage.txt",
	"werror.txt"
};

Template: adt {
	s: string;
	t: int;
	qid: Sys->Qid;
};

cache := array[2*Ntemplate] of ref Template;

gettemplate(typ: int): string
{
	if(typ >= Ntemplate)
		return nil;

	c := cache[typ];
	if(c != nil && c.t + Tcache >= now())
		return c.s;
	d := wdirstat(name[typ]);
	if(d == nil && c != nil)
		return c.s;
	if(c != nil && d.qid.vers == c.qid.vers && d.qid.path == c.qid.path){
		nt := ref Template(c.s, now(), d.qid);
		cache[typ] = nt;
		return nt.s;
	}
	b := wBopen(name[typ], Sys->OREAD);
	if(b == nil)
		return nil;
	ss: string;
	while((s := b.gets('\n')) != nil)
		ss += s;
	t := ref Template(ss, now(), d.qid);
	cache[typ] = t;
	return ss;
}

appendsub(p: string, sub: array of Sub): string
{
	r, q, s: string;
	
	while(len p > 0){
		m := -1;
		r = p;
		for(i:=0;i<len sub;i++){
			(r, q) = str->splitstrl(r, sub[i].match);
			if(q != nil){
				m = i;
			}
		}
		s += r;
		p = p[len r:];
		if(m >= 0){
			s += sub[m].sub;
			p = p[len sub[m].match:];
		}
	}
	return s;
}

historyhtml(h: ref Whist): string
{
	s, tmp, atime: string;

	s = "<ul>\n";
	for(i:=h.ndoc-1;i>=0;i--){
		if(i==h.current)
			tmp="index.html";
		else
			tmp=sys->sprint("%ud", h.doc[i].time);
		atime = daytime->text(daytime->local(h.doc[i].time));
		s += "<li><a href=\"" + tmp + "\">" + atime + "</a>";
		if(h.doc[i].author != nil)
			s += ", " + h.doc[i].author;
		if(h.doc[i].conflict)
			s += ", conflicting write";
		s += "\n";
		if(h.doc[i].comment != nil)
			s += "<br><i>" + h.doc[i].comment + "</i>\n";
	}
	s += "</ul>";
	return s;
}

stringfromint(i: int): string
{
	s: string;
	s[0] = i;
	return s;
}

mktemp(as: string): string
{
	pid: int;
	s: string;

	s = nil;
	pid = sys->pctl(0, nil);
	for (x := len as - 1; x >= 0; x--)
		if (as[x] == 'X') {
			s = stringfromint('0' + pid % 10) + s;
			pid /= 10;
		}
		else
			s = stringfromint(as[x]) + s;
	s[len s] = 'a';
	for (;;) {
		(rv, nil) := sys->stat(s);
		if (rv < 0)
			break;
		if (s[len s - 1] == 'z')
			return "/";
		s[len s - 1]++;
	}
	return s;
}

exec(sync: chan of int, cmd : string, argl : list of string, out: array of ref Sys->FD)
{
	file := cmd;
	if(len file<4 || file[len file-4:]!=".dis")
		file += ".dis";

	sys->pctl(Sys->FORKFD, nil);
	sys->dup(out[1].fd, 1);
	out[0] = nil;
	out[1] = nil;
	sync <-= sys->pctl(Sys->NEWFD, 0 :: 1 :: 2 :: nil);
	c := load Command file;
	if(c == nil) {
		err := sys->sprint("%r");
		if(file[0]!='/' && file[0:2]!="./"){
			c = load Command "/dis/"+file;
			if(c == nil)
				err = sys->sprint("%r");
		}
		if(c == nil){
			# debug(sys->sprint("file %s not found\n", file));
			sys->fprint(sys->fildes(2), "%s: %s\n", cmd, err);
			return;
		}
	}
	c->init(nil, argl);
}

dodiff(f1, f2: string): ref Sys->FD
{
	p := array[2] of ref Sys->FD;

	if(sys->pipe(p) < 0)
		return nil;
	sync := chan of int;
	spawn exec(sync, "/dis/diff.dis", "diff" :: f1 :: f2 :: nil, (array[2] of ref Sys->FD)[0:] = p);
	<-sync;
	p[1] = nil;
	return p[0];
}

GREY :con "<font color=#777777>";
UNGREY  :con  "</font>";

copythru(s, new: string, line, end: int): (string, string, int)
{
	while(line < end){
		(r, q) := str->splitl(new, "\n");
		if(q != nil){
			s += r + "\n";
			new = q[1:];
		}else{
			s += r;
			new = nil;
			break;
		}
		line++;
	}
	if(line < end)
		line = end;
	return (s, new, line);
}

sdiff(h: ref Whist, i, j: int): string
{
	s : string;

	if(j < 0)
		return pagehtml(h.doc[i].wtxt, Tpage);
	fn1 := mktemp("/tmp/wiki.XXXXXX");
	if((fd1 := sys->create(fn1, Sys->ORDWR|Sys->ORCLOSE, 8r666)) == nil)
		return "\nopentemp failed; sorry\n";
	fn2 := mktemp("/tmp/wiki.XXXXXX");
	if((fd2 := sys->create(fn2, Sys->ORDWR|Sys->ORCLOSE, 8r666)) == nil)
		return "\nopentemp failed; sorry\n";

	new := pagehtml(h.doc[i].wtxt, Tpage);
	old := pagehtml(h.doc[j].wtxt, Tpage);
	sys->fprint(fd1, "%s", new);
	sys->fprint(fd2, "%s", old);
	
	fdiff := dodiff(fn2, fn1);
	if(fdiff == nil)
		s += "\ndiff failed; sorry\n";
	else{
		nline := 0;
		b := bufio->fopen(fdiff, Sys->OREAD);
		while((p := b.gets('\n')) != nil){
			if(p[0]=='<' || p[0]=='>' || p[0]=='-')
				continue;
			(nil, r) := str->splitl(p, "acd");
			if(r == nil)
				continue;
			case r[0] {
			'a' or 'c' =>
				(n1, nil) := str->toint(r[1:], 10);
				(nil,v) := str->splitl(r, ",");
				if(v != nil)
					(n2, nil) := str->toint(v[1:], 10);
				else
					n2 = n1;
				s += GREY;
				(s, new, nline) = copythru(s, new, nline, n1-1);	
				s += UNGREY;
				(s, new, nline) = copythru(s, new, nline, n2);
			}
		}
		s += GREY;
		s += new;
		s += UNGREY;
	}
	return s;
}

diffhtml(h: ref Whist): string
{
	s, tmp, atime: string;

	for(i:=h.ndoc-1;i>=0;i--){
		s += "<hr>\n";
		if(i==h.current)
			tmp = "index.html";
		else
			tmp = sys->sprint("%ud", h.doc[i].time);
		atime = daytime->text(daytime->local(h.doc[i].time));
		s += "<li><a href=\"" + tmp + "\">" + atime + "</a>";
		if(h.doc[i].author != nil)
			s += ", " + h.doc[i].author;
		if(h.doc[i].conflict)
			s += ", conflicting write";
		s += "\n";
		if(h.doc[i].comment != nil)
			s += "<br><i>" + h.doc[i].comment + "</i>\n";
		s += "<br><hr>";
		s += sdiff(h, i, i-1);
	}
	s += "<hr>";
	return s;
}

historytext(h: ref Whist): string
{
	s, tmp, atime: string;

	for(i:=h.ndoc-1;i>=0;i--){
		if(i==h.current)
			tmp = "[current]";
		else
			tmp = sys->sprint("[%ud/]", h.doc[i].time);
		atime = daytime->text(daytime->local(h.doc[i].time));
		s += " * " + tmp + " " + atime;
		if(h.doc[i].author != nil)
			s += ", " + h.doc[i].author;
		if(h.doc[i].conflict)
			s += ", conflicting write";
		s += "\n";
		if(h.doc[i].comment != nil)
			s += "<i>" + h.doc[i].comment + "</i>\n";
	}	
	return s;
}

totext(h: ref Whist, d: ref Wdoc, ty: int): string
{
	s: string;
	sub := array[3] of Sub;
	nsub: int;

	t := gettemplate(Ntemplate+ty);
	(p, q) := str->splitstrl(t, "PAGE");
	if(q != nil)
		q = q[4:];
	nsub = 0;
	if(h != nil){
		sub[nsub] = Sub("TITLE", h.title);
		nsub++;
	}
	if(d != nil){
		ver := sys->sprint("%ud", d.time);
		sub[nsub] = Sub("VERSION", ver);
		nsub++;
		atime := daytime->text(daytime->local(d.time));
		sub[nsub] = Sub("DATE", atime);
		nsub++;
	}
	s = appendsub(p, sub[0:nsub]);

	case ty{
	Tpage or Toldpage =>
		s += pagetext(d.wtxt, 0);
	Thistory =>
		s += historytext(h);
	Tnew or Twerror =>
		;
	}
	if(q != nil)
		s += appendsub(q, sub[0:nsub]);
	return s;
}
