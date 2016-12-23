Httpd: module {

	Internal, TempFail, Unimp, UnkVers, BadCont, BadReq, Syntax, 
	BadSearch, NotFound, NoSearch , OnlySearch, Unauth, OK : con iota;	
	
	SVR_ROOT : con "/services/httpd/root/";
	HTTPLOG : con "/services/httpd/httpd.log";
	DEBUGLOG : con "/services/httpd/httpd.debug";
	HTTP_SUFF : con "/services/httpd/httpd.suff";
	REWRITE   : con "/services/httpd/httpd.rewrite";
	MAGICPATH : con "/dis/svc/httpd/"; # must end in /
	
	Entity: adt{
		 name : string;
		 value : int;
	};
	
	Etag: adt {
		etag: string;
		weak: int;
	};

	Range: adt {
		suffix: int;
		start: int;
		stop: int;
	};

	Private_info : adt{
		# used in parse and httpd
		bufio: Bufio;
		bin, bout : ref Bufio->Iobuf;
		logfile, dbg_log, accesslog: ref Sys->FD;
		cache : Cache;
		eof : int;
		getcerr : string;
		version : string;
		oklang, okencode, oktype, okchar : list of ref Contents->Content;
		host : string; # initialized to mydomain just before parsing header
		remotesys, referer : string;
		ifmodsince : int;
		ifunmodsince: int;
		ifrangedate: int;

		# used by /magic for reading body
		clength : int;
		ctype : string;

		#only used in parse
		wordval : string;
		tok, parse_eol, parse_eoh : int;
		mydomain, client : string;
		entity: array of Entity;

		# http 1.1
		meth: string;
		vermaj, vermin: int;
		requri, uri, urihost: string; #requested uri, resolved uri, host
		closeit: int;
		persist: int;
		authuser: string;
		authpass: string;
		ifmatch: list of Etag;
		ifnomatch: list of Etag;
		ifrangeetag: list of Etag;
		range: list of Range;
		transenc: list of (string, list of (string, string));
		expectother, expectcont: int;
		fresh_thresh, fresh_have: int;
	};

	Request: adt {
		method, version, uri, search: string;
	};

	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

Cgi: module{
	init: fn(g: ref Httpd->Private_info, req: Httpd->Request);
};
