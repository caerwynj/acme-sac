typedef struct{char *name; long sig; void (*fn)(void*); int size; int np; uchar map[16];} Runtab;
Runtab Srvmodtab[]={
	"init",0x9cd71c5e,Srv_init,32,0,{0},
	"ipa2h",0xaf4c19dd,Srv_ipa2h,40,2,{0x0,0x80,},
	"iph2a",0xaf4c19dd,Srv_iph2a,40,2,{0x0,0x80,},
	"ipn2p",0xea1a6969,Srv_ipn2p,40,2,{0x0,0xc0,},
	0
};
#define Srvmodlen	4
