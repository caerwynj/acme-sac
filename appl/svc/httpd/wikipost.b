implement Wikipost;

include "sys.m";
	sys: Sys;
stderr: ref Sys->FD;
include "bufio.m";

include "draw.m";
draw : Draw;

include "cache.m";
include "contents.m";
include "httpd.m";
	Private_info: import Httpd;
include "daytime.m";
	daytime: Daytime;

include "cgiparse.m";
cgiparse: CgiParse;

Wikipost: module
{
    init: fn(g: ref Private_info, req: Httpd->Request);
};

init(g: ref Private_info, req: Httpd->Request) 
{	
	sys = load Sys Sys->PATH;
	daytime = load Daytime Daytime->PATH;
	stderr = sys->fildes(2);	
	cgiparse = load CgiParse CgiParse->PATH;
	if( cgiparse == nil ) {
		sys->fprint( stderr, "echo: cannot load %s: %r\n", CgiParse->PATH);
		return;
	}

	send(g, cgiparse->cgiparse(g, req));
}

send(g: ref Private_info, cgidata: ref CgiData ) 
{	
	bufio := g.bufio;
	Iobuf: import bufio;
	if( cgidata == nil ){
		g.bout.flush();
		return;
	}
	
#	g.bout.puts( cgidata.httphd );
	
	title, text, service, comment, author, base: string;
	version := 0;
	if (cgidata.form != nil){
		while(cgidata.form != nil){
			(tag, val) := hd cgidata.form;
			case tag {
			"title" =>
				title = val;
			"version" =>
				version = int val;
			"text" =>
				text = val;
			"service" =>
				service = val;
			"comment" =>
				comment = val;
			"author" =>
				author = val;
			"base" =>
				base = val;
			}
			cgidata.form = tl cgidata.form;
		}	
	}
	uri := dowiki(title,author,comment,base,text,version);
	g.bout.puts(sys->sprint("%s 301 Moved Permanently\r\n", g.version));
	g.bout.puts(sys->sprint("Date: %s\r\n", daytime->time()));
	g.bout.puts("Server: Charon\r\n");
	g.bout.puts("MIME-version: 1.0\r\n");
	g.bout.puts("Content-type: text/html\r\n");
	g.bout.puts(sys->sprint("URI: <%s>\r\n",uri));
	g.bout.puts(sys->sprint("Location: %s\r\n",uri));
	g.bout.puts("\r\n");
	g.bout.puts("<head><title>Object Moved</title></head>\r\n");
	g.bout.puts("<body><h1>Object Moved</h1>\r\n");
	g.bout.puts(sys->sprint(
		"Your selection moved to <a href=\"%s\"> here</a>.<p></body>\r\n",
					 uri));
	g.bout.flush();
}

dowiki(title,author,comment,base,text: string, version: int): string
{
	fd := sys->open("/mnt/wiki/new", Sys->ORDWR);
	if(fd == nil)
		return nil;
	sys->fprint(fd, "%s\nD%ud\nA%s\n", title, version, author);
	if(comment != nil)
		sys->fprint(fd, "C%s\n", comment);
	sys->fprint(fd, "\n");
	sys->fprint(fd, "%s", text);

	buf := array[8192] of byte;
	n := sys->write(fd, buf, 0);
	if(n < 0)
		sys->fprint(sys->fildes(2), "dowiki: %r\n");
	sys->seek(fd, big 0, Sys->SEEKSTART);
	n = sys->read(fd, buf, len buf);
	if(n < 0)
		return sys->sprint("%s/1/index.html", base);
	name := string buf[0:n];
	
	s := sys->sprint("%s/%s/%s.html", base, name, "index");
	return s;
}
