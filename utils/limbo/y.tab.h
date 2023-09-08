
typedef union 
{
	struct{
		Src	src;
		union{
			Sym	*idval;
			Long	ival;
			Real	rval;
		}v;
	}tok;
	Decl	*ids;
	Node	*node;
	Type	*type;
	Typelist *types;
}	YYSTYPE;
extern	YYSTYPE	yylval;
#define	Landeq	57346
#define	Loreq	57347
#define	Lxoreq	57348
#define	Llsheq	57349
#define	Lrsheq	57350
#define	Laddeq	57351
#define	Lsubeq	57352
#define	Lmuleq	57353
#define	Ldiveq	57354
#define	Lmodeq	57355
#define	Lexpeq	57356
#define	Ldeclas	57357
#define	Lload	57358
#define	Loror	57359
#define	Landand	57360
#define	Lcons	57361
#define	Leq	57362
#define	Lneq	57363
#define	Lleq	57364
#define	Lgeq	57365
#define	Llsh	57366
#define	Lrsh	57367
#define	Lexp	57368
#define	Lcomm	57369
#define	Linc	57370
#define	Ldec	57371
#define	Lof	57372
#define	Lref	57373
#define	Lif	57374
#define	Lelse	57375
#define	Lfn	57376
#define	Lexcept	57377
#define	Lraises	57378
#define	Lmdot	57379
#define	Lto	57380
#define	Lor	57381
#define	Lrconst	57382
#define	Lconst	57383
#define	Lid	57384
#define	Ltid	57385
#define	Lsconst	57386
#define	Llabs	57387
#define	Lnil	57388
#define	Llen	57389
#define	Lhd	57390
#define	Ltl	57391
#define	Ltagof	57392
#define	Limplement	57393
#define	Limport	57394
#define	Linclude	57395
#define	Lcon	57396
#define	Ltype	57397
#define	Lmodule	57398
#define	Lcyclic	57399
#define	Ladt	57400
#define	Larray	57401
#define	Llist	57402
#define	Lchan	57403
#define	Lself	57404
#define	Ldo	57405
#define	Lwhile	57406
#define	Lfor	57407
#define	Lbreak	57408
#define	Lalt	57409
#define	Lcase	57410
#define	Lpick	57411
#define	Lcont	57412
#define	Lreturn	57413
#define	Lexit	57414
#define	Lspawn	57415
#define	Lraise	57416
#define	Lfix	57417
#define	Ldynamic	57418
