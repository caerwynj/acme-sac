%{
# 1@10:30,2@12:00/1
# what happens when we do a timeseries and we cross summer time change

	include "sys.m";
	sys: Sys;

	include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;

	include "draw.m";
	include "daytime.m";
	daytime: Daytime;
	Tm: import Daytime;
	
	include "arg.m";
	arg: Arg;
	now: big;
	dflt: big;
	daysend: big;

	DAY: con big (60 * 60 * 24);
	END: con big 16rffffffff;
	START: con big 0;
	YYSTYPE: adt {
		v: big;
		r: rng;
		s: string;
	};
	YYLEX: adt {
		 lval:   YYSTYPE;
		 lex: fn(l: self ref YYLEX): int;
		 error: fn(l: self ref YYLEX, msg: string);
	};
%}

%module Rng{
	PATH: con "y.tab.dis";
	init:   fn(ctxt: ref Draw->Context, args: list of string);
	setdot: fn(s: string): int;
	series: fn(beg, end, per: big);
	range: fn(s: string): list of rng;
	rng: adt {
		addr1:big;
		addr2:big;
	};
}

%left   '+' '-'
%left   '*' '/'
%left   '@' ':'

%type   <v> saddr znum day time
%type   <r> caddr
%token  <s> NUM

%%

top:	
	| '\n'
	{
		out(big setdot(""), big setdot("") + DAY);
	}
	|	top saddr '\n'
	{
		out( $2,  daysend);
	}
	|	top caddr '\n'
	{
		out( $2.addr1,  $2.addr2);
	}
	|	top caddr '/' NUM '\n'
	{
		series($2.addr1, $2.addr2, big $4);
	}
	;

caddr:	saddr ',' {dflt = END;} saddr	
	{
		$$.addr1 = $1; 
		$$.addr2 = $4;
		dflt = START;
	}
	|	saddr ';' {$$.addr1 = now = $1; dflt = END;} saddr	
	{
		$$.addr2 = $4;
		now = big daytime->now();
		dflt = START;
	}
	;

saddr:	day {$$ = $1; daysend = $1 +  big DAY;}
	|	day time  {$$ = $1 + $2; daysend = $1 +  big DAY;}
	;

time:		'@' NUM 			{$$ =  big (60 * 60) * big $2;}
	|	'@' NUM ':' NUM 	{$$ =  (big (60 * 60) * big $2) + (big 60 * big $4);}
	;

day:		{$$ = dflt;}
	|	znum
	|	'+' NUM	{$$ = big setdot("") + (big $2 * big DAY);}
	|	'-' NUM	{$$ = big setdot("") - (big $2 * big DAY);}
	|	znum '+' 	{$$ = $1 + big DAY;}
	|	znum '-' 	{$$ = $1 - big DAY;}
	|	znum '+' NUM	{$$ = $1 + (big $3 * big DAY);}
	|	znum '-' NUM	{$$ = $1 - (big $3 * big DAY);}
	;

znum:	'^'	{$$ = big 0;}
	|	'$'	{$$ = END;}
	|	'.'	{$$ = big setdot("");}
	|	NUM	{$$= big setdot($1);}
	;

%%

in: ref Iobuf;
stderr: ref Sys->FD;
rngl: list of rng;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	daytime = load Daytime Daytime->PATH;
	args = tl args;
	stderr = sys->fildes(2);
	if(len args == 1)
		in = bufio->sopen(hd args + "\n");
	else
		in = bufio->fopen(sys->fildes(0), Bufio->OREAD);
	lex := ref YYLEX;
	now = big daytime->now();
	dflt = START;
	yyparse(lex);
	rngl = rev(rngl);
	for( ; rngl != nil; rngl = tl rngl){
		r := hd rngl;
		sys->print("%bd\t%bd\t%bd\n", big daytime->now(), r.addr1, r.addr2);
	}
}

rev(l: list of rng): list of rng
{
	nl : list of rng;
	for(; l != nil; l = tl l)
		nl = hd l :: nl;
	return nl;
}


range(s: string): list of rng
{
	if(sys == nil){
		sys = load Sys Sys->PATH;
		bufio = load Bufio Bufio->PATH;
		daytime = load Daytime Daytime->PATH;
	}
	rngl = nil;
	in = bufio->sopen(s);
	lex := ref YYLEX;
	now = big daytime->now();
	dflt = START;
	yyparse(lex);
	return rngl;
}

YYLEX.error(nil: self ref YYLEX, err: string)
{
	sys->fprint(stderr, "%s\n", err);
}

YYLEX.lex(lex: self ref YYLEX): int
{
	for(;;){
		c := in.getc();
		case c{
		' ' or '\t' =>
			;
		'-' or '+' or '*' or '/' or '(' or ')' or '.' or ',' or ';' or '^' or '$' or '\n' or '@' or ':'=>
			return c;
		'0' to '9'  =>
			s := "";
			i := 0;
			s[i++] = c;
			while((c = in.getc()) >= '0' && c <= '9')
				s[i++] = c;
			in.ungetc();
			lex.lval.s =  s;
			return NUM;
		* =>
			return -1;
		}
	}
}

setdot(s: string): int
{
	l := len s;
	t := daytime->local(int now);
	dot: ref Tm;

	case l{
	0 =>
		dot = ref Tm(0, 0, 0, t.mday, t.mon, t.year, 
					t.wday, t.yday, t.zone, t.tzoff);
	1 or 2=>
		dot = ref Tm(0, 0, 0, int s, t.mon, t.year, 
					t.wday, t.yday, t.zone, t.tzoff);
	4 =>
		dot = ref Tm(0, 0, 0, int s[2:4], (int s[0:2]) - 1, t.year, 
					t.wday, t.yday, t.zone, t.tzoff);
	6 =>
		dot = ref Tm(0, 0, 0, int s[4:6], (int s[2:4]) - 1, (int s[0:2]) + 100, 
					t.wday, t.yday, t.zone, t.tzoff);
	8 =>
		dot = ref Tm(0, 0, 0, int s[6:8], (int s[4:6]) - 1, (int s[0:4]) - 1900, 
					t.wday, t.yday, t.zone, t.tzoff);
	* =>
		dot = t;
	}
	return daytime->tm2epoch(dot);
}

series(beg, end, per: big)
{
	toggle := 0;
	pair := array[2] of big;

	pair[1] = beg;
	for(i := beg + per * DAY; i <= end; i += per * DAY) {
		pair[toggle] = i;
		out(pair[toggle^1], pair[toggle]);
		toggle ^= 1;
	}
}


out(t1, t2:  big)
{
	rngl = rng(t1, t2) :: rngl;
}
