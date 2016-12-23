
appendsub(p: string, n, sub: array of Sub, nsub:int): string
{
	r, q, s: string;
	
	while(len p > 0){
		m := -1;
		r = p;
		for(i:=0;i<nsub;i++){
			(r, q) = str->stringstrl(r, sub[i].match);
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
}

historyhtml(s: string, h: ref Whist): string
{
	s += "<ul>\n";
	for(i:=h.ndoc-1;i>=0;i--){
		if(i==h.current)
			tmp="index.html";
		else
			tmp=sys->sprint("%ud", h.doc[i].time);
		atime = daytime->text(daytime->local(h.doc[i].time));
		s += "<li><a href=\"" + tmp + "\">" + atime + "</a>";
		if(h.doc[i].author != nil)
			s += ", " + h.doc[i].author;
		if(h.doc[i].conflict != nil)
			s += ", conflicting write";
		s += "\n";
		if(h.doc[i].comment != nil)
			s += "<br><i>" + h.doc[i].comment + "</i>\n";
	}
	s += "</ul>";
	return s;
}
