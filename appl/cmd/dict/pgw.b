implement Dictm;

include "draw.m";
include "sys.m";
	sys: Sys;
	sprint: import sys;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "libc.m";
	libc: Libc;
include "utils.m";
	utils: Utils;
	outrune, outrunes, outnl, Assoc, changett, outinhibit,
	lookassoc,liglookup,debug,err: import utils;
include "dictm.m";

bdict, bout : ref Iobuf;

init(b: Bufio, u: Utils, bd, bo: ref Iobuf )
{
	sys = load Sys Sys->PATH;
	bufio = b;
	bdict = bd;
	bout = bo;
	utils = u;
	libc = load Libc Libc->PATH;
}

Buflen: con 1000;
Maxaux: con 5;

#  Possible tags 
B	#  Bold 
, Blockquote	#  Block quote 
, Br	#  Break line 
, Cd	#  ? coloquial data 
, Col	#  ? Coloquial 
, Def	#  Definition 
, Hw	#  Head Word 
, I	#  Italics 
, P	#  Paragraph 
, Pos	#  Part of Speach 
, Sn	#  Sense 
, U	#  ? Underlined cross reference
, Wf	#  ? word form 
#  end of tags 
, Ntag: con  iota;

NONE : con 16r800;
TAGS, TAGE, SPCS, PAR, LIGS : con iota + NONE;
LACU, LGRV, LUML, LCED, LTIL, LBRV, LRNG, LDOT, LDTB, LFRN, LFRB, LOGO, LMAC,
LHCK, LASP, LLEN, LBRB, LIGE, MULTI: con iota + LIGS;

MAAS, MALN, MAND, MAOQ, MBRA, MDD, MDDD, MEAS, MELN, MEMM, MHAS, MHLN,
MIAS, MILN, MLCT, MLFF, MLFFI, MLFFL, MLFL, MLFI, MLLS, MLST, MOAS, MOLN, MOR, 
MRAS, MRLN, MTT, MUAS, MULN, MWAS, MWLN, MOE, MES, MULTIE: con iota + MULTI;


#  Assoc tables must be sorted on first field 
tagtab := array[13] of {
	Assoc("b",	B),
	Assoc("blockquote",	Blockquote),
	Assoc("BR",	Br),
	Assoc("cd",	Cd),
	Assoc("col",	Col),
	Assoc("def",	Def),
	Assoc("hw",	Hw),
	Assoc("i",	I),
	Assoc("p",	P),
	Assoc("pos",	Pos),
	Assoc("sn",	Sn),
	Assoc("u",	U),
	Assoc("wf",	Wf),
};

#  Possible tag auxilliary info 
Cols	#  number of columns in a table 
, Num	#  letter or number, for a sense 
, St	#  status (e.g., obs) 
, Naux: con  iota;

auxtab := array[3] of {
	Assoc("cols",	Cols),
	Assoc("num",	Num),
	Assoc("st",	St),
};
spectab := array[598] of {
	Assoc("3on4",	'¾'),
	Assoc("AElig",		'Æ'),
	Assoc("Aacute",	'Á'),
	Assoc("Aang",	'Å'),
	Assoc("Abarab",	'Ā'),
	Assoc("Acirc",	'Â'),
	Assoc("Agrave",	'À'),
	Assoc("Alpha",	'Α'),
	Assoc("Amacr",	'Ā'),
	Assoc("Asg",		'Ʒ'),		# Unicyle. Cf "Sake" 
	Assoc("Auml",	'Ä'),
	Assoc("Beta",	'Β'),
	Assoc("Cced",	'Ç'),
	Assoc("Chacek",	'Č'),
	Assoc("Chi",		'Χ'),
	Assoc("Chirho",	'☧'),		# Chi Rho U+2627 
	Assoc("Csigma",	'Ϛ'),
	Assoc("Delta",	'Δ'),
	Assoc("Eacute",	'É'),
	Assoc("Ecirc",	'Ê'),
	Assoc("Edh",		'Ð'),
	Assoc("Epsilon",	'Ε'),
	Assoc("Eta",		'Η'),
	Assoc("Gamma",	'Γ'),
	Assoc("Iacute",	'Í'),
	Assoc("Icirc",	'Î'),
	Assoc("Imacr",	'Ī'),
	Assoc("Integ",	'∫'),
	Assoc("Iota",	'Ι'),
	Assoc("Kappa",	'Κ'),
	Assoc("Koppa",	'Ϟ'),
	Assoc("Lambda",	'Λ'),
	Assoc("Lbar",	'Ł'),
	Assoc("Mu",		'Μ'),
	Assoc("Naira",	'N'),		# should have bar through 
	Assoc("Nplus",	'N'),		# should have plus above 
	Assoc("Ntilde",	'Ñ'),
	Assoc("Nu",		'Ν'),
	Assoc("Oacute",	'Ó'),
	Assoc("Obar",	'Ø'),
	Assoc("Ocirc",	'Ô'),
	Assoc("Oe",		'Œ'),
	Assoc("Omega",	'Ω'),
	Assoc("Omicron",	'Ο'),
	Assoc("Ouml",	'Ö'),
	Assoc("Phi",		'Φ'),
	Assoc("Pi",		'Π'),
	Assoc("Psi",		'Ψ'),
	Assoc("Rho",		'Ρ'),
	Assoc("Sacute",	'Ś'),
	Assoc("Sigma",	'Σ'),
	Assoc("Summ",	'∑'),
	Assoc("Tau",		'Τ'),
	Assoc("Th",		'Þ'),
	Assoc("Theta",	'Θ'),
	Assoc("Tse",		'Ц'),
	Assoc("Uacute",	'Ú'),
	Assoc("Ucirc",	'Û'),
	Assoc("Upsilon",	'Υ'),
	Assoc("Uuml",	'Ü'),
	Assoc("Wyn",		'ƿ'),		# wynn U+01BF 
	Assoc("Xi",		'Ξ'),
	Assoc("Ygh",		'Ʒ'),		# Yogh	U+01B7 
	Assoc("Zeta",	'Ζ'),
	Assoc("Zh",		'Ʒ'),		# looks like Yogh. Cf "Sake" 
	Assoc("a",		'a'),		# ante 
	Assoc("aacute",	'á'),
	Assoc("aang",	'å'),
	Assoc("aasper",	MAAS),
	Assoc("abreve",	'ă'),
	Assoc("acirc",	'â'),
	Assoc("acute",		LACU),
	Assoc("aelig",		'æ'),
	Assoc("agrave",	'à'),
	Assoc("ahook",	'ą'),
	Assoc("alenis",	MALN),
	Assoc("alpha",	'α'),
	Assoc("amacr",	'ā'),
	Assoc("amp",		'&'),
	Assoc("and",		MAND),
	Assoc("ang",		LRNG),
	Assoc("angle",	'∠'),
	Assoc("ankh",	'☥'),		# ankh U+2625 
	Assoc("ante",	'a'),		# before Assoc(year) 
	Assoc("aonq",	MAOQ),
	Assoc("appreq",	'≃'),
	Assoc("aquar",	'♒'),
	Assoc("arDadfull",	'ض'),		# Dad U+0636 
	Assoc("arHa",	'ح'),		# haa U+062D 
	Assoc("arTa",	'ت'),		# taa U+062A 
	Assoc("arain",	'ع'),		# ain U+0639 
	Assoc("arainfull",	'ع'),		# ain U+0639 
	Assoc("aralif",	'ا'),		# alef U+0627 
	Assoc("arba",	'ب'),		# baa U+0628 
	Assoc("arha",	'ه'),		# ha U+0647 
	Assoc("aries",	'♈'),
	Assoc("arnun",	'ن'),		# noon U+0646 
	Assoc("arnunfull",	'ن'),		# noon U+0646 
	Assoc("arpa",	'ه'),		# ha U+0647 
	Assoc("arqoph",	'ق'),		# qaf U+0642 
	Assoc("arshinfull",	'ش'),		# sheen U+0634 
	Assoc("arta",	'ت'),		# taa U+062A 
	Assoc("artafull",	'ت'),		# taa U+062A 
	Assoc("artha",	'ث'),		# thaa U+062B 
	Assoc("arwaw",	'و'),		# waw U+0648 
	Assoc("arya",	'ي'),		# ya U+064A 
	Assoc("aryafull",	'ي'),		# ya U+064A 
	Assoc("arzero",	'٠'),		# indic zero U+0660 
	Assoc("asg",		'ʒ'),		# unicycle character. Cf "hallow" 
	Assoc("asper",	LASP),
	Assoc("assert",	'⊢'),
	Assoc("astm",	'⁂'),		# asterism: should be upside down 
	Assoc("at",		'@'),
	Assoc("atilde",	'ã'),
	Assoc("auml",	'ä'),
	Assoc("ayin",	'ع'),		# arabic ain U+0639 
	Assoc("b1",		'-'),		# single bond 
	Assoc("b2",		'='),		# double bond 
	Assoc("b3",		'≡'),		# triple bond 
	Assoc("bbar",	'ƀ'),		# b with bar U+0180 
	Assoc("beta",	'β'),
	Assoc("bigobl",	'/'),
	Assoc("blC",		'C'),		# should be black letter 
	Assoc("blJ",		'J'),		# should be black letter 
	Assoc("blU",		'U'),		# should be black letter 
	Assoc("blb",		'b'),		# should be black letter 
	Assoc("blozenge",	'◊'),		# U+25CA; should be black 
	Assoc("bly",		'y'),		# should be black letter 
	Assoc("bra",		MBRA),
	Assoc("brbl",	LBRB),
	Assoc("breve",	LBRV),
	Assoc("bslash",	'\\'),
	Assoc("bsquare",	'■'),		# black square U+25A0 
	Assoc("btril",	'◀'),		# U+25C0 
	Assoc("btrir",	'▶'),		# U+25B6 
	Assoc("c",		'c'),		# circa 
	Assoc("cab",		'〉'),
	Assoc("cacute",	'ć'),
	Assoc("canc",	'♋'),
	Assoc("capr",	'♑'),
	Assoc("caret",	'^'),
	Assoc("cb",		'}'),
	Assoc("cbigb",	'}'),
	Assoc("cbigpren",	')'),
	Assoc("cbigsb",	']'),
	Assoc("cced",	'ç'),
	Assoc("cdil",	LCED),
	Assoc("cdsb",	'〛'),		# ]] U+301b 
	Assoc("cent",	'¢'),
	Assoc("chacek",	'č'),
	Assoc("chi",		'χ'),
	Assoc("circ",	LRNG),
	Assoc("circa",	'c'),		# about Assoc(year) 
	Assoc("circbl",	'̥'),		# ring below accent U+0325 
	Assoc("circle",	'○'),		# U+25CB 
	Assoc("circledot",	'⊙'),
	Assoc("click",	'ʖ'),
	Assoc("club",	'♣'),
	Assoc("comtime",	'C'),
	Assoc("conj",	'☌'),
	Assoc("cprt",	'©'),
	Assoc("cq",		'\''),
	Assoc("cqq",		'”'),
	Assoc("cross",	'✠'),		# maltese cross U+2720 
	Assoc("crotchet",	'♩'),
	Assoc("csb",		']'),
	Assoc("ctilde",	'c'),		# +tilde 
	Assoc("ctlig",	MLCT),
	Assoc("cyra",	'а'),
	Assoc("cyre",	'е'),
	Assoc("cyrhard",	'ъ'),
	Assoc("cyrjat",	'ѣ'),
	Assoc("cyrm",	'м'),
	Assoc("cyrn",	'н'),
	Assoc("cyrr",	'р'),
	Assoc("cyrsoft",	'ь'),
	Assoc("cyrt",	'т'),
	Assoc("cyry",	'ы'),
	Assoc("dag",		'†'),
	Assoc("dbar",	'đ'),
	Assoc("dblar",	'⇋'),
	Assoc("dblgt",	'≫'),
	Assoc("dbllt",	'≪'),
	Assoc("dced",	'd'),		# +cedilla 
	Assoc("dd",		MDD),
	Assoc("ddag",	'‡'),
	Assoc("ddd",		MDDD),
	Assoc("decr",	'↓'),
	Assoc("deg",		'°'),
	Assoc("dele",	'd'),		# should be dele 
	Assoc("delta",	'δ'),
	Assoc("descnode",	'☋'),		# descending node U+260B 
	Assoc("diamond",	'♢'),
	Assoc("digamma",	'ϝ'),
	Assoc("div",		'÷'),
	Assoc("dlessi",	'ı'),
	Assoc("dlessj1",	'j'),		# should be dotless 
	Assoc("dlessj2",	'j'),		# should be dotless 
	Assoc("dlessj3",	'j'),		# should be dotless 
	Assoc("dollar",	'$'),
	Assoc("dotab",	LDOT),
	Assoc("dotbl",	LDTB),
	Assoc("drachm",	'ʒ'),
	Assoc("dubh",	'-'),
	Assoc("eacute",	'é'),
	Assoc("earth",	'♁'),
	Assoc("easper",	MEAS),
	Assoc("ebreve",	'ĕ'),
	Assoc("ecirc",	'ê'),
	Assoc("edh",		'ð'),
	Assoc("egrave",	'è'),
	Assoc("ehacek",	'ě'),
	Assoc("ehook",	'ę'),
	Assoc("elem",	'∊'),
	Assoc("elenis",	MELN),
	Assoc("em",		'—'),
	Assoc("emacr",	'ē'),
	Assoc("emem",	MEMM),
	Assoc("en",		'–'),
	Assoc("epsilon",	'ε'),
	Assoc("equil",	'⇋'),
	Assoc("ergo",	'∴'),
	Assoc("es",		MES),
	Assoc("eszett",	'ß'),
	Assoc("eta",		'η'),
	Assoc("eth",		'ð'),
	Assoc("euml",	'ë'),
	Assoc("expon",	'↑'),
	Assoc("fact",	'!'),
	Assoc("fata",	'ɑ'),
	Assoc("fatpara",	'¶'),		# should have fatter, filled in bowl 
	Assoc("female",	'♀'),
	Assoc("ffilig",	MLFFI),
	Assoc("fflig",	MLFF),
	Assoc("ffllig",	MLFFL),
	Assoc("filig",	MLFI),
	Assoc("flat",	'♭'),
	Assoc("fllig",	MLFL),
	Assoc("frE",		'E'),		# should be curly 
	Assoc("fr",		'L'),		# should be curly 
	Assoc("frR",		'R'),		# should be curly 
	Assoc("frakB",	'B'),		# should have fraktur style 
	Assoc("frakG",	'G'),
	Assoc("frakH",	'H'),
	Assoc("frakI",	'I'),
	Assoc("frakM",	'M'),
	Assoc("frakU",	'U'),
	Assoc("frakX",	'X'),
	Assoc("frakY",	'Y'),
	Assoc("frakh",	'h'),
	Assoc("frbl",	LFRB),
	Assoc("frown",	LFRN),
	Assoc("fs",		' '),
	Assoc("fsigma",	'ς'),
	Assoc("gAacute",	'Á'),		# should be Α+acute 
	Assoc("gaacute",	'α'),		# +acute 
	Assoc("gabreve",	'α'),		# +breve 
	Assoc("gafrown",	'α'),		# +frown 
	Assoc("gagrave",	'α'),		# +grave 
	Assoc("gamacr",	'α'),		# +macron 
	Assoc("gamma",	'γ'),
	Assoc("gauml",	'α'),		# +umlaut 
	Assoc("ge",		'≧'),
	Assoc("geacute",	'ε'),		# +acute 
	Assoc("gegrave",	'ε'),		# +grave 
	Assoc("ghacute",	'η'),		# +acute 
	Assoc("ghfrown",	'η'),		# +frown 
	Assoc("ghgrave",	'η'),		# +grave 
	Assoc("ghmacr",	'η'),		# +macron 
	Assoc("giacute",	'ι'),		# +acute 
	Assoc("gibreve",	'ι'),		# +breve 
	Assoc("gifrown",	'ι'),		# +frown 
	Assoc("gigrave",	'ι'),		# +grave 
	Assoc("gimacr",	'ι'),		# +macron 
	Assoc("giuml",	'ι'),		# +umlaut 
	Assoc("glagjat",	'ѧ'),
	Assoc("glots",	'ˀ'),
	Assoc("goacute",	'ο'),		# +acute 
	Assoc("gobreve",	'ο'),		# +breve 
	Assoc("grave",	LGRV),
	Assoc("gt",		'>'),
	Assoc("guacute",	'υ'),		# +acute 
	Assoc("gufrown",	'υ'),		# +frown 
	Assoc("gugrave",	'υ'),		# +grave 
	Assoc("gumacr",	'υ'),		# +macron 
	Assoc("guuml",	'υ'),		# +umlaut 
	Assoc("gwacute",	'ω'),		# +acute 
	Assoc("gwfrown",	'ω'),		# +frown 
	Assoc("gwgrave",	'ω'),		# +grave 
	Assoc("hacek",	LHCK),
	Assoc("halft",	'⌈'),
	Assoc("hash",	'#'),
	Assoc("hasper",	MHAS),
	Assoc("hatpath",	'ֲ'),		# hataf patah U+05B2 
	Assoc("hatqam",	'ֳ'),		# hataf qamats U+05B3 
	Assoc("hatseg",	'ֱ'),		# hataf segol U+05B1 
	Assoc("hbar",	'ħ'),
	Assoc("heart",	'♡'),
	Assoc("hebaleph",	'א'),		# aleph U+05D0 
	Assoc("hebayin",	'ע'),		# ayin U+05E2 
	Assoc("hebbet",	'ב'),		# bet U+05D1 
	Assoc("hebbeth",	'ב'),		# bet U+05D1 
	Assoc("hebcheth",	'ח'),		# bet U+05D7 
	Assoc("hebdaleth",	'ד'),		# dalet U+05D3 
	Assoc("hebgimel",	'ג'),		# gimel U+05D2 
	Assoc("hebhe",	'ה'),		# he U+05D4 
	Assoc("hebkaph",	'כ'),		# kaf U+05DB 
	Assoc("heblamed",	'ל'),		# lamed U+05DC 
	Assoc("hebmem",	'מ'),		# mem U+05DE 
	Assoc("hebnun",	'נ'),		# nun U+05E0 
	Assoc("hebnunfin",	'ן'),		# final nun U+05DF 
	Assoc("hebpe",	'פ'),		# pe U+05E4 
	Assoc("hebpedag",	'ף'),		# final pe? U+05E3 
	Assoc("hebqoph",	'ק'),		# qof U+05E7 
	Assoc("hebresh",	'ר'),		# resh U+05E8 
	Assoc("hebshin",	'ש'),		# shin U+05E9 
	Assoc("hebtav",	'ת'),		# tav U+05EA 
	Assoc("hebtsade",	'צ'),		# tsadi U+05E6 
	Assoc("hebwaw",	'ו'),		# vav? U+05D5 
	Assoc("hebyod",	'י'),		# yod U+05D9 
	Assoc("hebzayin",	'ז'),		# zayin U+05D6 
	Assoc("hgz",		'ʒ'),		# ??? Cf "alet" 
	Assoc("hireq",	'ִ'),		# U+05B4 
	Assoc("hlenis",	MHLN),
	Assoc("hook",	LOGO),
	Assoc("horizE",	'E'),		# should be on side 
	Assoc("horizP",	'P'),		# should be on side 
	Assoc("horizS",	'∽'),
	Assoc("horizT",	'⊣'),
	Assoc("horizb",	'{'),		# should be underbrace 
	Assoc("ia",		'α'),
	Assoc("iacute",	'í'),
	Assoc("iasper",	MIAS),
	Assoc("ib",		'β'),
	Assoc("ibar",	'ɨ'),
	Assoc("ibreve",	'ĭ'),
	Assoc("icirc",	'î'),
	Assoc("id",		'δ'),
	Assoc("ident",	'≡'),
	Assoc("ie",		'ε'),
	Assoc("ifilig",	MLFI),
	Assoc("ifflig",	MLFF),
	Assoc("ig",		'γ'),
	Assoc("igrave",	'ì'),
	Assoc("ih",		'η'),
	Assoc("ii",		'ι'),
	Assoc("ik",		'κ'),
	Assoc("ilenis",	MILN),
	Assoc("imacr",	'ī'),
	Assoc("implies",	'⇒'),
	Assoc("index",	'☞'),
	Assoc("infin",	'∞'),
	Assoc("integ",	'∫'),
	Assoc("intsec",	'∩'),
	Assoc("invpri",	'ˏ'),
	Assoc("iota",	'ι'),
	Assoc("iq",		'ψ'),
	Assoc("istlig",	MLST),
	Assoc("isub",	'ϵ'),		# iota below accent 
	Assoc("iuml",	'ï'),
	Assoc("iz",		'ζ'),
	Assoc("jup",		'♃'),
	Assoc("kappa",	'κ'),
	Assoc("koppa",	'ϟ'),
	Assoc("lambda",	'λ'),
	Assoc("lar",		'←'),
	Assoc("lbar",	'ł'),
	Assoc("le",		'≦'),
	Assoc("lenis",	LLEN),
	Assoc("leo",		'♌'),
	Assoc("lhalfbr",	'⌈'),
	Assoc("lhshoe",	'⊃'),
	Assoc("libra",	'♎'),
	Assoc("llswing",	MLLS),
	Assoc("lm",		'ː'),
	Assoc("logicand",	'∧'),
	Assoc("logicor",	'∨'),
	Assoc("longs",	'ʃ'),
	Assoc("lrar",	'↔'),
	Assoc("lt",		'<'),
	Assoc("ltappr",	'≾'),
	Assoc("ltflat",	'∠'),
	Assoc("lumlbl",	'l'),		# +umlaut below 
	Assoc("mac",		LMAC),
	Assoc("male",	'♂'),
	Assoc("mc",		'c'),		# should be raised 
	Assoc("merc",	'☿'),		# mercury U+263F 
	Assoc("min",		'−'),
	Assoc("moonfq",	'☽'),		# first quarter moon U+263D 
	Assoc("moonlq",	'☾'),		# last quarter moon U+263E 
	Assoc("msylab",	'm'),		# +sylab Assoc(ˌ) 
	Assoc("mu",		'μ'),
	Assoc("nacute",	'ń'),
	Assoc("natural",	'♮'),
	Assoc("neq",		'≠'),
	Assoc("nfacute",	'′'),
	Assoc("nfasper",	'ʽ'),
	Assoc("nfbreve",	'˘'),
	Assoc("nfced",	'¸'),
	Assoc("nfcirc",	'ˆ'),
	Assoc("nffrown",	'⌢'),
	Assoc("nfgra",	'ˋ'),
	Assoc("nfhacek",	'ˇ'),
	Assoc("nfmac",	'¯'),
	Assoc("nftilde",	'˜'),
	Assoc("nfuml",	'¨'),
	Assoc("ng",		'ŋ'),
	Assoc("not",		'¬'),
	Assoc("notelem",	'∉'),
	Assoc("ntilde",	'ñ'),
	Assoc("nu",		'ν'),
	Assoc("oab",		'〈'),
	Assoc("oacute",	'ó'),
	Assoc("oasper",	MOAS),
	Assoc("ob",		'{'),
	Assoc("obar",	'ø'),
	Assoc("obigb",	'{'),		# should be big 
	Assoc("obigpren",	'('),
	Assoc("obigsb",	'['),		# should be big 
	Assoc("obreve",	'ŏ'),
	Assoc("ocirc",	'ô'),
	Assoc("odsb",	'〚'),		# [[ U+301A 
	Assoc("oelig",		'œ'),
	Assoc("oeamp",	'&'),
	Assoc("ograve",	'ò'),
	Assoc("ohook",	'o'),		# +hook 
	Assoc("olenis",	MOLN),
	Assoc("omacr",	'ō'),
	Assoc("omega",	'ω'),
	Assoc("omicron",	'ο'),
	Assoc("ope",		'ɛ'),
	Assoc("opp",		'☍'),
	Assoc("oq",		'`'),
	Assoc("oqq",		'“'),
	Assoc("or",		MOR),
	Assoc("osb",		'['),
	Assoc("otilde",	'õ'),
	Assoc("ouml",	'ö'),
	Assoc("ounce",	'℥'),		# ounce U+2125 
	Assoc("ovparen",	'⌢'),		# should be sideways ( 
	Assoc("p",		'′'),
	Assoc("pa",		'∂'),
	Assoc("page",	'P'),
	Assoc("pall",	'ʎ'),
	Assoc("paln",	'ɲ'),
	Assoc("par",		PAR),
	Assoc("para",	'¶'),
	Assoc("pbar",	'p'),		# +bar 
	Assoc("per",		'℘'),		# per U+2118 
	Assoc("phi",		'φ'),
	Assoc("phi2",	'ϕ'),
	Assoc("pi",		'π'),
	Assoc("pisces",	'♓'),
	Assoc("planck",	'ħ'),
	Assoc("plantinJ",	'J'),		# should be script 
	Assoc("pm",		'±'),
	Assoc("pmil",	'‰'),
	Assoc("pp",		'″'),
	Assoc("ppp",		'‴'),
	Assoc("prop",	'∝'),
	Assoc("psi",		'ψ'),
	Assoc("pstlg",	'£'),
	Assoc("q",		'?'),		# should be raised 
	Assoc("qamets",	'ֳ'),		# U+05B3 
	Assoc("quaver",	'♪'),
	Assoc("rar",		'→'),
	Assoc("rasper",	MRAS),
	Assoc("rdot",	'·'),
	Assoc("recipe",	'℞'),		# U+211E 
	Assoc("reg",		'®'),
	Assoc("revC",	'Ɔ'),		# open O U+0186 
	Assoc("reva",	'ɒ'),
	Assoc("revc",	'ɔ'),
	Assoc("revope",	'ɜ'),
	Assoc("revr",	'ɹ'),
	Assoc("revsc",	'˒'),		# upside-down semicolon 
	Assoc("revv",	'ʌ'),
	Assoc("rfa",		'o'),		# +hook (Cf "goal") 
	Assoc("rhacek",	'ř'),
	Assoc("rhalfbr",	'⌉'),
	Assoc("rho",		'ρ'),
	Assoc("rhshoe",	'⊂'),
	Assoc("rlenis",	MRLN),
	Assoc("rsylab",	'r'),		# +sylab 
	Assoc("runash",	'F'),		# should be runic 'ash' 
	Assoc("rvow",	'˔'),
	Assoc("sacute",	'ś'),
	Assoc("sagit",	'♐'),
	Assoc("sampi",	'ϡ'),
	Assoc("saturn",	'♄'),
	Assoc("sced",	'ş'),
	Assoc("schwa",	'ə'),
	Assoc("scorpio",	'♏'),
	Assoc("scrA",	'A'),		# should be script 
	Assoc("scrC",	'C'),
	Assoc("scrE",	'E'),
	Assoc("scrF",	'F'),
	Assoc("scrI",	'I'),
	Assoc("scrJ",	'J'),
	Assoc("scrL",	'L'),
	Assoc("scrO",	'O'),
	Assoc("scrP",	'P'),
	Assoc("scrQ",	'Q'),
	Assoc("scrS",	'S'),
	Assoc("scrT",	'T'),
	Assoc("scrb",	'b'),
	Assoc("scrd",	'd'),
	Assoc("scrh",	'h'),
	Assoc("scrl",	'l'),
	Assoc("scruple",	'℈'),		# U+2108 
	Assoc("sdd",		'ː'),
	Assoc("sect",	'§'),
	Assoc("semE",	'∃'),
	Assoc("sh",		'ʃ'),
	Assoc("shacek",	'š'),
	Assoc("sharp",	'♯'),
	Assoc("sheva",	'ְ'),		# U+05B0 
	Assoc("shti",	'ɪ'),
	Assoc("shtsyll",	'∪'),
	Assoc("shtu",	'ʊ'),
	Assoc("sidetri",	'⊲'),
	Assoc("sigma",	'σ'),
	Assoc("since",	'∵'),
	Assoc("slge",	'≥'),		# should have slanted line under 
	Assoc("slle",	'≤'),		# should have slanted line under 
	Assoc("sm",		'ˈ'),
	Assoc("smm",		'ˌ'),
	Assoc("spade",	'♠'),
	Assoc("sqrt",	'√'),
	Assoc("square",	'□'),		# U+25A1 
	Assoc("ssChi",	'Χ'),		# should be sans serif 
	Assoc("ssIota",	'Ι'),
	Assoc("ssOmicron",	'Ο'),
	Assoc("ssPi",	'Π'),
	Assoc("ssRho",	'Ρ'),
	Assoc("ssSigma",	'Σ'),
	Assoc("ssTau",	'Τ'),
	Assoc("star",	'*'),
	Assoc("stlig",	MLST),
	Assoc("sup2",	'⁲'),
	Assoc("supgt",	'˃'),
	Assoc("suplt",	'˂'),
	Assoc("sur",		'ʳ'),
	Assoc("swing",	'∼'),
	Assoc("tau",		'τ'),
	Assoc("taur",	'♉'),
	Assoc("th",		'þ'),
	Assoc("thbar",	'þ'),		# +bar 
	Assoc("theta",	'θ'),
	Assoc("thinqm",	'?'),		# should be thinner 
	Assoc("tilde",	LTIL),
	Assoc("times",	'×'),
	Assoc("tri",		'∆'),
	Assoc("trli",	'‖'),
	Assoc("ts",		' '),
	Assoc("uacute",	'ú'),
	Assoc("uasper",	MUAS),
	Assoc("ubar",	'u'),		# +bar 
	Assoc("ubreve",	'ŭ'),
	Assoc("ucirc",	'û'),
	Assoc("udA",		'∀'),
	Assoc("udT",		'⊥'),
	Assoc("uda",		'ɐ'),
	Assoc("udh",		'ɥ'),
	Assoc("udqm",	'¿'),
	Assoc("udpsi",	'⋔'),
	Assoc("udtr",	'∇'),
	Assoc("ugrave",	'ù'),
	Assoc("ulenis",	MULN),
	Assoc("umacr",	'ū'),
	Assoc("uml",		LUML),
	Assoc("undl",	'ˍ'),		# underline accent 
	Assoc("union",	'∪'),
	Assoc("upsilon",	'υ'),
	Assoc("uuml",	'ü'),
	Assoc("vavpath",	'ו'),		# vav U+05D5 (+patah) 
	Assoc("vavsheva",	'ו'),		# vav U+05D5 (+sheva) 
	Assoc("vb",		'|'),
	Assoc("vddd",	'⋮'),
	Assoc("versicle2",	'℣'),		# U+2123 
	Assoc("vinc",	'¯'),
	Assoc("virgo",	'♍'),
	Assoc("vpal",	'ɟ'),
	Assoc("vvf",		'ɣ'),
	Assoc("wasper",	MWAS),
	Assoc("wavyeq",	'≈'),
	Assoc("wlenis",	MWLN),
	Assoc("wyn",		'ƿ'),		# wynn U+01BF 
	Assoc("xi",		'ξ'),
	Assoc("yacute",	'ý'),
	Assoc("ycirc",	'ŷ'),
	Assoc("ygh",		'ʒ'),
	Assoc("ymacr",	'y'),		# +macron 
	Assoc("yuml",	'ÿ'),
	Assoc("zced",	'z'),		# +cedilla 
	Assoc("zeta",	'ζ'),
	Assoc("zh",		'ʒ'),
	Assoc("zhacek",	'ž'),
};
# 
#    The following special characters don't have close enough
#    equivalents in Unicode, so aren't in the above table.
# 	22n		2^(2^n) Cf Fermat
# 	2on4		2/4
# 	3on8		3/8
# 	Bantuo		Bantu O. Cf Otshi-herero
# 	Car		C with circular arrow on top
# 	albrtime 	cut-time: C with vertical line
# 	ardal		Cf dental
# 	bantuo		Bantu o. Cf Otshi-herero
# 	bbc1		single chem bond below
# 	bbc2		double chem bond below
# 	bbl1		chem bond like /
# 	bbl2		chem bond like //
# 	bbr1		chem bond like \
# 	bbr2		chem bond \\
# 	bcop1		copper symbol. Cf copper
# 	bcop2		copper symbol. Cf copper
# 	benchm		Cf benchmark
# 	btc1		single chem bond above
# 	btc2		double chem bond above
# 	btl1		chem bond like \
# 	btl2		chem bond like \\
# 	btr1		chem bond like /
# 	btr2		chem bond line //
# 	burman		Cf Burman
# 	devph		sanskrit letter. Cf ph
# 	devrfls		sanskrit letter. Cf cerebral
# 	duplong[12]	musical note
# 	egchi		early form of chi
# 	eggamma[12]	early form of gamma
# 	egiota		early form of iota
# 	egkappa		early form of kappa
# 	eglambda	early form of lambda
# 	egmu[12]	early form of mu
# 	egnu[12]	early form of nu
# 	egpi[123]	early form of pi
# 	egrho[12]	early form of rho
# 	egsampi		early form of sampi
# 	egsan		early form of san
# 	egsigma[12]	early form of sigma
# 	egxi[123]	early form of xi
# 	elatS		early form of S
# 	elatc[12]	early form of C
# 	elatg[12]	early form of G
# 	glagjeri	Slavonic Glagolitic jeri
# 	glagjeru	Slavonic Glagolitic jeru
# 	hypolem		hypolemisk (line with underdot)
# 	lhrbr		lower half }
# 	longmord	long mordent
# 	mbwvow		backwards scretched C. Cf retract.
# 	mord		music symbol.  Cf mordent
# 	mostra		Cf direct
# 	ohgcirc		old form of circumflex
# 	oldbeta		old form of . Cf perturbate
# 	oldsemibr[12]	old forms of semibreve. Cf prolation
# 	ormg		old form of g. Cf G
# 	para[12345]	form of 
# 	pauseo		musical pause sign
# 	pauseu		musical pause sign
# 	pharyng		Cf pharyngal
# 	ragr		Black letter ragged r
# 	repetn		musical repeat. Cf retort
# 	segno		musical segno sign
# 	semain[12]	semitic ain
# 	semhe		semitic he
# 	semheth		semitic heth
# 	semkaph		semitic kaph
# 	semlamed[12]	semitic lamed
# 	semmem		semitic mem
# 	semnum		semitic nun
# 	sempe		semitic pe
# 	semqoph[123]	semitic qoph
# 	semresh		semitic resh
# 	semtav[1234]	semitic tav
# 	semyod		semitic yod
# 	semzayin[123]	semitic zayin
# 	shtlong[12]	U with underbar. Cf glyconic
# 	sigmatau	, combination
# 	squaver		sixteenth note
# 	sqbreve		square musical breve note
# 	swast		swastika
# 	uhrbr		upper half of big }
# 	versicle1		Cf versicle
#  
normtab := array[128] of {
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	' ',	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	' ',	'!',	'"',	'#',	'$',	'%',	SPCS,	'\'',
	'(',	')',	'*',	'+',	',',	'-',	'.',	'/',
	'0',	'1',	'2',	'3',	'4',	'5',	'6',	'7',
	'8',	'9',	':',	';',	TAGS,	'=',	TAGE,	'?',
	'@',	'A',	'B',	'C',	'D',	'E',	'F',	'G',
	'H',	'I',	'J',	'K',	'L',	'M',	'N',	'O',
	'P',	'Q',	'R',	'S',	'T',	'U',	'V',	'W',
	'X',	'Y',	'Z',	'[',	'\\',	']',	'^',	'_',
	'`',	'a',	'b',	'c',	'd',	'e',	'f',	'g',
	'h',	'i',	'j',	'k',	'l',	'm',	'n',	'o',
	'p',	'q',	'r',	's',	't',	'u',	'v',	'w',
	'x',	'y',	'z',	'{',	'|',	'}',	'~',	NONE,
};
phtab := array[128] of {
								
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	' ',	'!',	'ˈ',	'#',	'$',	'ˌ',	'æ',	'\'',
	'(',	')',	'*',	'+',	',',	'-',	'.',	'/',
  '0',	'1',	'2',	'ɜ',	'4',	'5',	'6',	'7',
	'8',	'ø',	'ː',	';',	TAGS,	'=',	TAGE,	'?',
  'ə',	'ɑ',	'B',	'C',	'ð',	'ɛ',	'F',	'G',
	'H',	'ɪ',	'J',	'K',	'L',	'M',	'ŋ',	'ɔ',
	'P',	'ɒ',	'R',	'ʃ',	'θ',	'ʊ',	'ʌ',	'W',
	'X',	'Y',	'ʒ',	'[',	'\\',	']',	'^',	'_',
	'`',	'a',	'b',	'c',	'd',	'e',	'f',	'g',
	'h',	'i',	'j',	'k',	'l',	'm',	'n',	'o',
	'p',	'q',	'r',	's',	't',	'u',	'v',	'w',
	'x',	'y',	'z',	'{',	'|',	'}',	'~',	NONE,
};
grtab := array[128] of {
								
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	' ',	'!',	'"',	'#',	'$',	'%',	SPCS,	'\'',
	'(',	')',	'*',	'+',	',',	'-',	'.',	'/',
  '0',	'1',	'2',	'3',	'4',	'5',	'6',	'7',
	'8',	'9',	':',	';',	TAGS,	'=',	TAGE,	'?',
  '@',	'Α',	'Β',	'Ξ',	'Δ',	'Ε',	'Φ',	'Γ',
	'Η',	'Ι',	'Ϛ',	'Κ',	'Λ',	'Μ',	'Ν',	'Ο',
	'Π',	'Θ',	'Ρ',	'Σ',	'Τ',	'Υ',	'V',	'Ω',
	'Χ',	'Ψ',	'Ζ',	'[',	'\\',	']',	'^',	'_',
	'`',	'α',	'β',	'ξ',	'δ',	'ε',	'φ',	'γ',
	'η',	'ι',	'ς',	'κ',	'λ',	'μ',	'ν',	'ο',
	'π',	'θ',	'ρ',	'σ',	'τ',	'υ',	'v',	'ω',
	'χ',	'ψ',	'ζ',	'{',	'|',	'}',	'~',	NONE,
};
subtab := array[128] of {
								
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	' ',	'!',	'"',	'#',	'$',	'%',	SPCS,	'\'',
	'₍',	'₎',	'*',	'₊',	',',	'₋',	'.',	'/',
  '₀',	'₁',	'₂',	'₃',	'₄',	'₅',	'₆',	'₇',
	'₈',	'₉',	':',	';',	TAGS,	'₌',	TAGE,	'?',
  '@',	'A',	'B',	'C',	'D',	'E',	'F',	'G',
	'H',	'I',	'J',	'K',	'L',	'M',	'N',	'O',
	'P',	'Q',	'R',	'S',	'T',	'U',	'V',	'W',
	'X',	'Y',	'Z',	'[',	'\\',	']',	'^',	'_',
	'`',	'a',	'b',	'c',	'd',	'e',	'f',	'g',
	'h',	'i',	'j',	'k',	'l',	'm',	'n',	'o',
	'p',	'q',	'r',	's',	't',	'u',	'v',	'w',
	'x',	'y',	'z',	'{',	'|',	'}',	'~',	NONE,
};
suptab := array[128] of {
								
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,	NONE,
	' ',	'!',	'"',	'#',	'$',	'%',	SPCS,	'\'',
	'⁽',	'⁾',	'*',	'⁺',	',',	'⁻',	'.',	'/',
  '⁰',	'ⁱ',	'⁲',	'⁳',	'⁴',	'⁵',	'⁶',	'⁷',
	'⁸',	'⁹',	':',	';',	TAGS,	'⁼',	TAGE,	'?',
  '@',	'A',	'B',	'C',	'D',	'E',	'F',	'G',
	'H',	'I',	'J',	'K',	'L',	'M',	'N',	'O',
	'P',	'Q',	'R',	'S',	'T',	'U',	'V',	'W',
	'X',	'Y',	'Z',	'[',	'\\',	']',	'^',	'_',
	'`',	'a',	'b',	'c',	'd',	'e',	'f',	'g',
	'h',	'i',	'j',	'k',	'l',	'm',	'n',	'o',
	'p',	'q',	'r',	's',	't',	'u',	'v',	'w',
	'x',	'y',	'z',	'{',	'|',	'}',	'~',	NONE,
};
multitab := array[] of {
	"ʽα",
	"ʼα",
	"and",
	"a/q",
	"<|",
	"..",
	"...",
	"ʽε",
	"ʼε",
	"——",
	"ʽη",
	"ʼη",
	"ʽι",
	"ʼι",
	"ct",
	"ff",
	"ffi",
	"ffl",
	"fl",
	"fi",
	"ɫɫ",
	"st",
	"ʽο",
	"ʼο",
	"or",
	"ʽρ",
	"ʼρ",
	"~~",
	"ʽυ",
	"ʼυ",
	"ʽω",
	"ʼω",
	"oe",
	"  ",
};

tagstarts: int;
tag : string;
spec : string;
auxstate := array[Naux] of array of byte;	#  vals for most recent tag 
curentry: Entry;

# 
#  * cmd is one of:
#  *    'p': normal print
#  *    'h': just print headwords
#  *    'P': print raw
#  
printentry(e: Entry, cmd: int)
{
	t: int;
	r, rprev, rlig: int;
	transtab: array of int;

	p := string e.start;
	transtab = normtab;
	rprev = NONE;
	changett(nil, nil, 0);
	curentry = e;
	if(cmd == 'h' || cmd == 'H')
		outinhibit = 1;
	while(len p > 0){
		if(cmd == 'r'){
			outrune(p[0]);
			p = p[1:];
			continue;
		}
		r = transtab[p[0]&16r7f];
		p = p[1:];
		if(r < NONE){
			#  Emit the rune, but buffer in case of ligature 
			if(rprev != NONE)
				outrune(rprev);
			rprev = r;
		}
		else if(r == SPCS){
			#  Start of special character name 
			(spec, p) = getspec(p);
			r = lookassoc(spectab, len spectab, spec);	
			if(r == -1){
				if(debug)
					err(sprint("spec %bd %d %s", e.doff, len curentry.start, spec));
				r = '�';
			}
			if(r >= LIGS && r < LIGE){
				#  handle possible ligature 
				rlig = liglookup(r, rprev);
				if(rlig != NONE)
					rprev = rlig;	#  overwrite rprev 
				else{
					#  could print accent, but let's not 
					if(rprev != NONE)
						outrune(rprev);
					rprev = NONE;
				}
			}else if(r >= MULTI && r < MULTIE){
				if(rprev != NONE){
					outrune(rprev);
					rprev = NONE;
				}
				outrunes(multitab[r-MULTI]);
			}else if(r == PAR){
				if(rprev != NONE){
					outrune(rprev);
					rprev = NONE;
				}
				outnl(1);
			}else{
				if(rprev != NONE)
					outrune(rprev);
				rprev = r;
			}
		}else if(r == TAGS){
			#  Start of tag name 
			if(rprev != NONE){
				outrune(rprev);
				rprev = NONE;
			}
			p = gettag(p);
			t = lookassoc(tagtab, len tagtab, tag);
			if(t == -1){
				if(debug)
					err(sprint("tag %bd %d %s", e.doff, len curentry.start, tag));
				continue;
			}
			case(t){
			Hw =>
				if(cmd == 'h' || cmd == 'H'){
					if(!tagstarts)
						outrune(' ');
					outinhibit = !tagstarts;
				}
			Sn =>
				if(tagstarts)
					outnl(2);
			P or Col or Br or Blockquote =>
				if(tagstarts)
					outnl(1);
			U =>
				outrune('/');
			}
		}
	}
	if(cmd == 'h' || cmd == 'H'){
		outinhibit = 0;
		outnl(0);
	}
}

# 
#  * Return offset into bdict where next webster entry after fromoff starts.
#  * Webster entries start with <p><hw>
#  
nextoff(fromoff: big): big
{
	a: big;
	n, c: int;

	a = bdict.seek(big fromoff, 0);
	if(a != fromoff)
		return big -1;
	n = 0;
	for(;;){
		c = bdict.getc();
		if(c < 0)
			break;
		if(c == '<' && bdict.getc() == 'p' && bdict.getc() == '>'){
			c = bdict.getc();
			if(c == '<'){
				if(bdict.getc() == 'h' && bdict.getc() == 'w' && bdict.getc() == '>')
					n = 7;
			} else if(c == '{')
				n = 4;
			if(n)
				break;
		}
	}
	return (bdict.offset()-big n);
}


#  TODO: find transcriptions of foreign consonents, S, , nasals 
printkey()
{
	bout.puts("No pronunciation key\n");
}

#  * f points just after a '&', fe points at end of entry.
#  * Accumulate the special name, starting after the &
#  * and continuing until the next ';', in spec[].
#  * Return pointer to char after ';'.

getspec(f: string): (string, string)
{
	for(i := 0; i < len f; i++){
		if(f[i] == ';')
			break;
	}
	return (f[:i], f[i+1:]);
}

#  * f points just after '<'; fe points at end of entry.
#  * Expect next characters from bin to match:
#  *  [/][^ >]+( [^>=]+=[^ >]+)*>
#  *      tag   auxname auxval
#  * Accumulate the tag and its auxilliary information in
#  * tag[], auxname[][] and auxval[][].
#  * Set tagstarts=1 if the tag is 'starting' (has no '/'), else 0.
#  * Set naux to the number of aux pairs found.
#  * Return pointer to after final '>'.

gettag(f: string): string
{
	tag = "";
	k := 0;
	if(f[0] == '/')
		tagstarts = 0;
	else {
		tagstarts = 1;
		tag[k++] = f[0];
	}
	for(i := 1; i < len f; i++){
		if(f[i] == '>'){
			i++;
			break;
		}
		tag[k++] = f[i];
	}
	return f[i:];
}

mkindex()
{
}
