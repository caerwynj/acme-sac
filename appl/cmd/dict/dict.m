Dictm: module
{
#  Runes for special purposes (0xe800-0xfdff is Private Use Area) 
NONE	#  Emit nothing 
, TAGS	#  Start of tag 
, TAGE	#  End of tag 
, SPCS	#  Start of special character name 
, PAR	#  Newline, indent 
, LIGS: con 59392+iota;	#  Start of ligature codes 
LACU	#  Acute () ligatures 
, LGRV	#  Grave () ligatures 
, LUML	#  Umlaut () ligatures 
, LCED	#  Cedilla () ligatures 
, LTIL	#  Tilde () ligatures 
, LBRV	#  Breve () ligatures 
, LRNG	#  Ring () ligatures 
, LDOT	#  Dot () ligatures 
, LDTB	#  Dot below (.) ligatures 
, LFRN	#  Frown (") ligatures 
, LFRB	#  Frown below (/) ligatures 
, LOGO	#  Ogonek () ligatures 
, LMAC	#  Macron () ligatures 
, LHCK	#  Hacek () ligatures 
, LASP	#  Asper () ligatures 
, LLEN	#  Lenis () ligatures 
, LBRB	#  Breve below (.) ligatures 
, LIGE	#  End of ligature codes 
, MULTI: con 59397+iota;	#  Start of multi-rune codes 
MAAS	#   
, MALN	#   
, MAND	#  and 
, MAOQ	#  a/q 
, MBRA	#  <| 
, MDD	#  .. 
, MDDD	#  ... 
, MEAS	#   
, MELN	#   
, MEMM	#   
, MHAS	#   
, MHLN	#   
, MIAS	#   
, MILN	#   
, MLCT	#  ct 
, MLFF	#  ff 
, MLFFI	#  ffi 
, MLFFL	#  ffl 
, MLFL	#  fl 
, MLFI	#  fi 
, MLLS	#  ll with swing 
, MLST	#  st 
, MOAS	#   
, MOLN	#   
, MOR	#  or 
, MRAS	#   
, MRLN	#   
, MTT	#  ~~ 
, MUAS	#   
, MULN	#   
, MWAS	#   
, MWLN	#   
, MOE	#  oe 
, MES	#  em space 
, MULTIE: con 59415+iota;	#  End of multi-rune codes 
Nligs: con LIGE-LIGS;
Nmulti: con MULTIE-MULTI;

	Entry: adt{
		start: array of byte;	#  entry starts at start 
		end: array of byte;	#  and finishes just before end 
		doff: big;	#  dictionary offset (for debugging) 
	};
	
	Assoc: adt{
		key: array of byte;
		val: int;
	};
	
	Nassoc: adt{
		key: int;
		val: int;
	};
	
	Dict: adt{
		name: array of byte;	#  dictionary name 
		desc: array of byte;	#  description 
		path: array of byte;	#  path to dictionary data 
		indexpath: array of byte;	#  path to index data 
	};
}
