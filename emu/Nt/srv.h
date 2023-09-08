void Srv_init(void*);
typedef struct F_Srv_init F_Srv_init;
struct F_Srv_init
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
};
void Srv_ipa2h(void*);
typedef struct F_Srv_ipa2h F_Srv_ipa2h;
struct F_Srv_ipa2h
{
	WORD	regs[NREG-1];
	List**	ret;
	uchar	temps[12];
	String*	addr;
};
void Srv_iph2a(void*);
typedef struct F_Srv_iph2a F_Srv_iph2a;
struct F_Srv_iph2a
{
	WORD	regs[NREG-1];
	List**	ret;
	uchar	temps[12];
	String*	host;
};
void Srv_ipn2p(void*);
typedef struct F_Srv_ipn2p F_Srv_ipn2p;
struct F_Srv_ipn2p
{
	WORD	regs[NREG-1];
	String**	ret;
	uchar	temps[12];
	String*	net;
	String*	service;
};
#define Srv_PATH "$Srv"
