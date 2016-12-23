implement Rng;

#line	2	"rng.y"
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
Rng: module {

	PATH: con "y.tab.dis";
	init:   fn(ctxt: ref Draw->Context, args: list of string);
	setdot: fn(s: string): int;
	series: fn(beg, end, per: big);
	range: fn(s: string): list of rng;
	rng: adt {
		addr1:big;
		addr2:big;
	};
NUM: con	57346;

};
YYEOFCODE: con 1;
YYERRCODE: con 2;
YYMAXDEPTH: con 200;

#line	117	"rng.y"


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
yyexca := array[] of {-1, 1,
	1, -1,
	-2, 14,
};
YYNPROD: con 26;
YYPRIVATE: con 57344;
yytoknames: array of string;
yystates: array of string;
yydebug: con 0;
YYLAST:	con 34;
yyact := array[] of {
   3,   7,   8,  13,  14,  15,  17,  12,  19,  32,
  16,   9,  10,  11,   2,  34,  29,  28,  27,  26,
  23,  22,  33,  20,  21,  30,  31,  25,  24,   1,
   4,  18,   5,   6,
};
yypact := array[] of {
   3,  -3,-1000,  -8,  -1,   0,  19,  11,  10,-1000,
-1000,-1000,-1000,-1000,-1000,-1000,-1000,   9,-1000,   8,
   7,   6,-1000,-1000,  -3,  -3,  -2,  13,-1000,-1000,
-1000,-1000,-1000,   5,-1000,
};
yypgo := array[] of {
   0,   0,  33,  32,  31,  30,  29,  28,  27,
};
yyr1 := array[] of {
   0,   6,   6,   6,   6,   6,   7,   5,   8,   5,
   1,   1,   4,   4,   3,   3,   3,   3,   3,   3,
   3,   3,   2,   2,   2,   2,
};
yyr2 := array[] of {
   0,   0,   1,   3,   3,   5,   0,   4,   0,   4,
   1,   2,   2,   4,   0,   1,   2,   2,   2,   2,
   3,   3,   1,   1,   1,   1,
};
yychk := array[] of {
-1000,  -6,  11,  -1,  -5,  -3,  -2,   4,   5,  14,
  15,  16,  10,  11,  12,  13,  11,   7,  -4,   8,
   4,   5,  10,  10,  -7,  -8,  10,  10,  10,  10,
  -1,  -1,  11,   9,  10,
};
yydef := array[] of {
   1,  -2,   2,   0,   0,  10,  15,   0,   0,  22,
  23,  24,  25,   3,   6,   8,   4,   0,  11,   0,
  18,  19,  16,  17,  14,  14,   0,  12,  20,  21,
   7,   9,   5,   0,  13,
};
yytok1 := array[] of {
   1,   3,   3,   3,   3,   3,   3,   3,   3,   3,
  11,   3,   3,   3,   3,   3,   3,   3,   3,   3,
   3,   3,   3,   3,   3,   3,   3,   3,   3,   3,
   3,   3,   3,   3,   3,   3,  15,   3,   3,   3,
   3,   3,   6,   4,  12,   5,  16,   7,   3,   3,
   3,   3,   3,   3,   3,   3,   3,   3,   9,  13,
   3,   3,   3,   3,   8,   3,   3,   3,   3,   3,
   3,   3,   3,   3,   3,   3,   3,   3,   3,   3,
   3,   3,   3,   3,   3,   3,   3,   3,   3,   3,
   3,   3,   3,   3,  14,
};
yytok2 := array[] of {
   2,   3,  10,
};
yytok3 := array[] of {
   0
};

YYSys: module
{
	FD: adt
	{
		fd:	int;
	};
	fildes:		fn(fd: int): ref FD;
	fprint:		fn(fd: ref FD, s: string, *): int;
};

yysys: YYSys;
yystderr: ref YYSys->FD;

YYFLAG: con -1000;

# parser for yacc output

yytokname(yyc: int): string
{
	if(yyc > 0 && yyc <= len yytoknames && yytoknames[yyc-1] != nil)
		return yytoknames[yyc-1];
	return "<"+string yyc+">";
}

yystatname(yys: int): string
{
	if(yys >= 0 && yys < len yystates && yystates[yys] != nil)
		return yystates[yys];
	return "<"+string yys+">\n";
}

yylex1(yylex: ref YYLEX): int
{
	c : int;
	yychar := yylex.lex();
	if(yychar <= 0)
		c = yytok1[0];
	else if(yychar < len yytok1)
		c = yytok1[yychar];
	else if(yychar >= YYPRIVATE && yychar < YYPRIVATE+len yytok2)
		c = yytok2[yychar-YYPRIVATE];
	else{
		n := len yytok3;
		c = 0;
		for(i := 0; i < n; i+=2) {
			if(yytok3[i+0] == yychar) {
				c = yytok3[i+1];
				break;
			}
		}
		if(c == 0)
			c = yytok2[1];	# unknown char
	}
	if(yydebug >= 3)
		yysys->fprint(yystderr, "lex %.4ux %s\n", yychar, yytokname(c));
	return c;
}

YYS: adt
{
	yyv: YYSTYPE;
	yys: int;
};

yyparse(yylex: ref YYLEX): int
{
	if(yydebug >= 1 && yysys == nil) {
		yysys = load YYSys "$Sys";
		yystderr = yysys->fildes(2);
	}

	yys := array[YYMAXDEPTH] of YYS;

	yyval: YYSTYPE;
	yystate := 0;
	yychar := -1;
	yynerrs := 0;		# number of errors
	yyerrflag := 0;		# error recovery flag
	yyp := -1;
	yyn := 0;

yystack:
	for(;;){
		# put a state and value onto the stack
		if(yydebug >= 4)
			yysys->fprint(yystderr, "char %s in %s", yytokname(yychar), yystatname(yystate));

		yyp++;
		if(yyp >= len yys)
			yys = (array[len yys * 2] of YYS)[0:] = yys;
		yys[yyp].yys = yystate;
		yys[yyp].yyv = yyval;

		for(;;){
			yyn = yypact[yystate];
			if(yyn > YYFLAG) {	# simple state
				if(yychar < 0)
					yychar = yylex1(yylex);
				yyn += yychar;
				if(yyn >= 0 && yyn < YYLAST) {
					yyn = yyact[yyn];
					if(yychk[yyn] == yychar) { # valid shift
						yychar = -1;
						yyp++;
						if(yyp >= len yys)
							yys = (array[len yys * 2] of YYS)[0:] = yys;
						yystate = yyn;
						yys[yyp].yys = yystate;
						yys[yyp].yyv = yylex.lval;
						if(yyerrflag > 0)
							yyerrflag--;
						if(yydebug >= 4)
							yysys->fprint(yystderr, "char %s in %s", yytokname(yychar), yystatname(yystate));
						continue;
					}
				}
			}
		
			# default state action
			yyn = yydef[yystate];
			if(yyn == -2) {
				if(yychar < 0)
					yychar = yylex1(yylex);
		
				# look through exception table
				for(yyxi:=0;; yyxi+=2)
					if(yyexca[yyxi] == -1 && yyexca[yyxi+1] == yystate)
						break;
				for(yyxi += 2;; yyxi += 2) {
					yyn = yyexca[yyxi];
					if(yyn < 0 || yyn == yychar)
						break;
				}
				yyn = yyexca[yyxi+1];
				if(yyn < 0){
					yyn = 0;
					break yystack;
				}
			}

			if(yyn != 0)
				break;

			# error ... attempt to resume parsing
			if(yyerrflag == 0) { # brand new error
				yylex.error("syntax error");
				yynerrs++;
				if(yydebug >= 1) {
					yysys->fprint(yystderr, "%s", yystatname(yystate));
					yysys->fprint(yystderr, "saw %s\n", yytokname(yychar));
				}
			}

			if(yyerrflag != 3) { # incompletely recovered error ... try again
				yyerrflag = 3;
	
				# find a state where "error" is a legal shift action
				while(yyp >= 0) {
					yyn = yypact[yys[yyp].yys] + YYERRCODE;
					if(yyn >= 0 && yyn < YYLAST) {
						yystate = yyact[yyn];  # simulate a shift of "error"
						if(yychk[yystate] == YYERRCODE)
							continue yystack;
					}
	
					# the current yyp has no shift onn "error", pop stack
					if(yydebug >= 2)
						yysys->fprint(yystderr, "error recovery pops state %d, uncovers %d\n",
							yys[yyp].yys, yys[yyp-1].yys );
					yyp--;
				}
				# there is no state on the stack with an error shift ... abort
				yyn = 1;
				break yystack;
			}

			# no shift yet; clobber input char
			if(yydebug >= 2)
				yysys->fprint(yystderr, "error recovery discards %s\n", yytokname(yychar));
			if(yychar == YYEOFCODE) {
				yyn = 1;
				break yystack;
			}
			yychar = -1;
			# try again in the same state
		}
	
		# reduction by production yyn
		if(yydebug >= 2)
			yysys->fprint(yystderr, "reduce %d in:\n\t%s", yyn, yystatname(yystate));
	
		yypt := yyp;
		yyp -= yyr2[yyn];
#		yyval = yys[yyp+1].yyv;
		yym := yyn;
	
		# consult goto table to find next state
		yyn = yyr1[yyn];
		yyg := yypgo[yyn];
		yyj := yyg + yys[yyp].yys + 1;
	
		if(yyj >= YYLAST || yychk[yystate=yyact[yyj]] != -yyn)
			yystate = yyact[yyg];
		case yym {
			
2=>
#line	62	"rng.y"
{
		out(big setdot(""), big setdot("") + DAY);
	}
3=>
#line	66	"rng.y"
{
		out( yys[yypt-1].yyv.v,  daysend);
	}
4=>
#line	70	"rng.y"
{
		out( yys[yypt-1].yyv.r.addr1,  yys[yypt-1].yyv.r.addr2);
	}
5=>
#line	74	"rng.y"
{
		series(yys[yypt-3].yyv.r.addr1, yys[yypt-3].yyv.r.addr2, big yys[yypt-1].yyv.s);
	}
6=>
#line	79	"rng.y"
{dflt = END;}
7=>
#line	80	"rng.y"
{
		yyval.r.addr1 = yys[yypt-3].yyv.v; 
		yyval.r.addr2 = yys[yypt-0].yyv.v;
		dflt = START;
	}
8=>
#line	85	"rng.y"
{yyval.r.addr1 = now = yys[yypt-1].yyv.v; dflt = END;}
9=>
#line	86	"rng.y"
{
		yyval.r.addr2 = yys[yypt-0].yyv.v;
		now = big daytime->now();
		dflt = START;
	}
10=>
#line	93	"rng.y"
{yyval.v = yys[yypt-0].yyv.v; daysend = yys[yypt-0].yyv.v +  big DAY;}
11=>
#line	94	"rng.y"
{yyval.v = yys[yypt-1].yyv.v + yys[yypt-0].yyv.v; daysend = yys[yypt-1].yyv.v +  big DAY;}
12=>
#line	97	"rng.y"
{yyval.v =  big (60 * 60) * big yys[yypt-0].yyv.s;}
13=>
#line	98	"rng.y"
{yyval.v =  (big (60 * 60) * big yys[yypt-2].yyv.s) + (big 60 * big yys[yypt-0].yyv.s);}
14=>
#line	101	"rng.y"
{yyval.v = dflt;}
15=>
yyval.v = yys[yyp+1].yyv.v;
16=>
#line	103	"rng.y"
{yyval.v = big setdot("") + (big yys[yypt-0].yyv.s * big DAY);}
17=>
#line	104	"rng.y"
{yyval.v = big setdot("") - (big yys[yypt-0].yyv.s * big DAY);}
18=>
#line	105	"rng.y"
{yyval.v = yys[yypt-1].yyv.v + big DAY;}
19=>
#line	106	"rng.y"
{yyval.v = yys[yypt-1].yyv.v - big DAY;}
20=>
#line	107	"rng.y"
{yyval.v = yys[yypt-2].yyv.v + (big yys[yypt-0].yyv.s * big DAY);}
21=>
#line	108	"rng.y"
{yyval.v = yys[yypt-2].yyv.v - (big yys[yypt-0].yyv.s * big DAY);}
22=>
#line	111	"rng.y"
{yyval.v = big 0;}
23=>
#line	112	"rng.y"
{yyval.v = END;}
24=>
#line	113	"rng.y"
{yyval.v = big setdot("");}
25=>
#line	114	"rng.y"
{yyval.v= big setdot(yys[yypt-0].yyv.s);}
		}
	}

	return yyn;
}
