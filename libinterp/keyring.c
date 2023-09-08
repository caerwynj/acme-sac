#include "lib9.h"
#include "kernel.h"
#include <isa.h>
#include "interp.h"
#include <mp.h>
#include <libsec.h>
#include "pool.h"
#include "raise.h"

/* arguably limbo -t should qualify type name */
#define	DigestState_copy Keyring_DigestState_copy
#define	IPint_random Keyring_IPint_random
#include "keyringif.h"
#include "keyring.h"

#include "ipint.h"
#include "../libkeyring/keys.h"

static Type*	TDigestState;
static Type*	TAESstate;
static Type*	TDESstate;
static Type*	TIDEAstate;
static Type*	TBFstate;
static Type*	TRC4state;

static Type*	TSigAlg;
static Type*	TCertificate;
static Type*	TSK;
static Type*	TPK;
static Type*	TAuthinfo;

static Type*	TDSAsk;
static Type*	TDSApk;
static Type*	TDSAsig;
static Type*	TEGsk;
static Type*	TEGpk;
static Type*	TEGsig;
static Type*	TRSAsk;
static Type*	TRSApk;
static Type*	TRSAsig;

enum {
	Maxmsg=	4096
};

static uchar DigestStatemap[] = Keyring_DigestState_map;
static uchar AESstatemap[] = Keyring_AESstate_map;
static uchar DESstatemap[] = Keyring_DESstate_map;
static uchar IDEAstatemap[] = Keyring_IDEAstate_map;
static uchar BFstatemap[] = Keyring_BFstate_map;
static uchar RC4statemap[] = Keyring_RC4state_map;

static uchar SigAlgmap[] = Keyring_SigAlg_map;
static uchar SKmap[] = Keyring_SK_map;
static uchar PKmap[] = Keyring_PK_map;
static uchar Certificatemap[] = Keyring_Certificate_map;
static uchar Authinfomap[] = Keyring_Authinfo_map;
static uchar DSAskmap[] = Keyring_DSAsk_map;
static uchar DSApkmap[] = Keyring_DSApk_map;
static uchar DSAsigmap[] = Keyring_DSAsig_map;
static uchar EGskmap[] = Keyring_EGsk_map;
static uchar EGpkmap[] = Keyring_EGpk_map;
static uchar EGsigmap[] = Keyring_EGsig_map;
static uchar RSAskmap[] = Keyring_RSAsk_map;
static uchar RSApkmap[] = Keyring_RSApk_map;
static uchar RSAsigmap[] = Keyring_RSAsig_map;

static	PK*	checkPK(Keyring_PK *k);

extern void		setid(char*, int);
extern vlong		osusectime(void);
extern void		freeIPint(Heap*, int);

static char exBadSA[]	= "bad signature algorithm";
static char exBadSK[]	= "bad secret key";
static char exBadPK[]	= "bad public key";
static char exBadCert[]	= "bad certificate";
static char exBadBsize[]	= "data not multiple of block size";
static char exBadKey[]	= "bad encryption key";
static char exBadDigest[]	= "bad digest value";
static char exBadIvec[]	= "bad ivec";
static char exBadState[] = "bad encryption state";

typedef struct XBFstate XBFstate;

/* BF state */
struct XBFstate
{
	Keyring_BFstate	x;
	BFstate	state;
};

/* convert a Big to base64 ascii */
int
bigtobase64(mpint* b, char *buf, int len)
{
	uchar *p;
	int n, rv, o;

	n = (b->top+1)*Dbytes;
	p = malloc(n+1);
	if(p == nil)
		goto Err;
	n = mptobe(b, p+1, n, nil);
	if(n < 0)
		goto Err;
	p[0] = 0;
	if(n != 0 && (p[1]&0x80)){
		/* force leading 0 byte for compatibility with older representation */
		/* TO DO: if b->sign < 0, complement bits and add one */
		o = 0;
		n++;
	}else
		o = 1;
	rv = enc64(buf, len, p+o, n);
	free(p);
	return rv;

Err:
	free(p);
	if(len > 0){
		*buf = '*';
		return 1;
	}
	return 0;
}

/* convert a Big to base64 ascii for %U */
int
big64conv(Fmt *f)
{
	mpint *b;
	char *buf;
	int n;

	b = va_arg(f->args, mpint*);
	n = (b->top+1)*Dbytes + 1;
	n = ((n+3)/3)*4 + 1;
	buf = malloc(n);
	bigtobase64(b, buf, n);
	n = fmtstrcpy(f, buf);
	free(buf);
	return  n;
}

static void*
newthing(Type *t, int add)
{
	Heap *h;

	h = heap(t);
	if(add)
		ptradd(h);
	return H2D(void*, h);
}

static Keyring_IPint*
ipcopymp(mpint* b)
{
	if(b == nil)
		return H;
	return newIPint(mpcopy(b));
}

/* convert a base64 string to a big */
mpint*
base64tobig(char *str, char **strp)
{
	int n;
	char *p;
	mpint *b;
	uchar hex[(MaxBigBytes*6 + 7)/8];

	for(p = str; *p && *p != '\n'; p++)
		;
	if(p == str)
		return nil;
	n = dec64(hex, sizeof(hex), str, p - str);
	b = betomp(hex, n, nil);
	if(strp){
		if(*p)
			p++;
		*strp = p;
	}
	return b;
}

/*
 *  signature algorithms
 */
enum
{
	Maxalg = 8
};
static SigAlgVec	*algs[Maxalg];
static int		nalg;

static SigAlg*
newSigAlg(SigAlgVec *vec)
{
	Heap *h;
	SigAlg *sa;

	h = heap(TSigAlg);
	sa = H2D(SigAlg*, h);
	retstr(vec->name, &sa->x.name);
	sa->vec = vec;
	return sa;
}

static void
freeSigAlg(Heap *h, int swept)
{
	if(!swept)
		freeheap(h, 0);
}

SigAlgVec*
findsigalg(char *name)
{
	SigAlgVec **sap;

	for(sap = algs; sap < &algs[nalg]; sap++)
		if(strcmp(name, (*sap)->name) == 0)
			return *sap;
	return nil;
}

SigAlg*
strtoalg(char *str, char **strp)
{
	int n;
	char *p, name[20];
	SigAlgVec *sa;


	p = strchr(str, '\n');
	if(p == 0){
		p = str + strlen(str);
		if(strp)
			*strp = p;
	} else {
		if(strp)
			*strp = p+1;
	}

	n = p - str;
	if(n < sizeof(name)){
		strncpy(name, str, n);
		name[n] = 0;
		sa = findsigalg(name);
		if(sa != nil)
			return newSigAlg(sa);
	}
	return nil;
}

static SigAlg*
checkSigAlg(Keyring_SigAlg *ksa)
{
	SigAlgVec **sap;
	SigAlg *sa;

	sa = (SigAlg*)ksa;

	for(sap = algs; sap < &algs[Maxalg]; sap++)
		if(sa->vec == *sap)
			return sa;
	errorf("%s: %s", exType, exBadSA);
	return nil;
}

/*
 *  parse next new line terminated string into a String
 */
String*
strtostring(char *str, char **strp)
{
	char *p;
	String *s;

	p = strchr(str, '\n');
	if(p == 0)
		p = str + strlen(str);
	s = H;
	retnstr(str, p - str, &s);

	if(strp){
		if(*p)
			p++;
		*strp = p;
	}

	return s;
}

/*
 *  private part of a key
 */
static SK*
newSK(SigAlg *sa, String *owner, int increfsa)
{
	Heap *h;
	SK *k;

	h = heap(TSK);
	k = H2D(SK*, h);
	k->x.sa = (Keyring_SigAlg*)sa;
	if(increfsa) {
		h = D2H(sa);
		h->ref++;
		Setmark(h);
	}
	k->x.owner = owner;
	k->key = 0;
	return k;
}

static void
freeSK(Heap *h, int swept)
{
	SK *k;
	SigAlg *sa;

	k = H2D(SK*, h);
	sa = checkSigAlg(k->x.sa);
	if(k->key)
		(*sa->vec->skfree)(k->key);
	freeheap(h, swept);
}

static SK*
checkSK(Keyring_SK *k)
{
	SK *sk;

	sk = (SK*)k;
	if(sk == H || sk == nil || sk->key == 0 || D2H(sk)->t != TSK){
		errorf("%s: %s", exType, exBadSK);
		return nil;
	}
	return sk;
}

void
Keyring_genSK(void *fp)
{
	F_Keyring_genSK *f;
	SK *sk;
	SigAlg *sa;
	void *v;

	f = fp;
	v = *f->ret;
	*f->ret = H;
	destroy(v);

	sa = strtoalg(string2c(f->algname), 0);
	if(sa == nil)
		return;

	sk = newSK(sa, stringdup(f->owner), 0);
	*f->ret = (Keyring_SK*)sk;
	release();
	sk->key = (*sa->vec->gensk)(f->length);
	acquire();
}

void
Keyring_genSKfromPK(void *fp)
{
	F_Keyring_genSKfromPK *f;
	SigAlg *sa;
	PK *pk;
	SK *sk;
	void *v;

	f = fp;
	v = *f->ret;
	*f->ret = H;
	destroy(v);

	pk = checkPK(f->pk);
	sa = checkSigAlg(pk->x.sa);
	sk = newSK(sa, stringdup(f->owner), 1);
	*f->ret = (Keyring_SK*)sk;
	release();
	sk->key = (*sa->vec->genskfrompk)(pk->key);
	acquire();
}

/* converts a sequence of newline-separated base64-encoded mpints to attr=hexval ... in f */
static char*
bigs2attr(Fmt *f, char *bigs, char **names)
{
	int i, n, nd;
	char *b16, *vals[20];
	uchar data[(MaxBigBytes*6 + 7)/8];

	b16 = malloc(2*MaxBigBytes+1);
	if(b16 == nil)
		return nil;
	n = getfields(bigs, vals, nelem(vals), 0, "\n");
	for(i = 0; i < n-1; i++){
		if(names == nil || names[i] == nil)
			break;	/* shouldn't happen */
		nd = dec64(data, sizeof(data), vals[i], strlen(vals[i]));
		if(nd < 0)
			break;
		enc16(b16, 2*MaxBigBytes+1, data, nd);
		fmtprint(f, " %s=%s", names[i], b16);
	}
	free(b16);
	return fmtstrflush(f);
}

void
Keyring_sktoattr(void *fp)
{
	F_Keyring_sktoattr *f;
	char *val, *buf, *owner;
	SigAlg *sa;
	Fmt o;
	SK *sk;

	f = fp;
	sk = checkSK(f->sk);
	sa = checkSigAlg(sk->x.sa);
	buf = malloc(Maxbuf);
	if(buf == nil){
		retstr(nil, f->ret);
		return;
	}
	(*sa->vec->sk2str)(sk->key, buf, Maxbuf);
	fmtstrinit(&o);
	fmtprint(&o, "alg=%q", string2c(sa->x.name));
	owner = string2c(sk->x.owner);
	if(*owner)
		fmtprint(&o, " owner=%q", owner);
	val = bigs2attr(&o, buf, sa->vec->skattr);
	free(buf);
	retstr(val, f->ret);
	free(val);
}

static int
sktostr(SK *sk, char *buf, int len)
{
	int n;
	SigAlg *sa;

	sa = checkSigAlg(sk->x.sa);
	n = snprint(buf, len, "%s\n%s\n", string2c(sa->x.name),
			string2c(sk->x.owner));
	return n + (*sa->vec->sk2str)(sk->key, buf+n, len - n);
}

void
Keyring_sktostr(void *fp)
{
	F_Keyring_sktostr *f;
	char *buf;

	f = fp;
	buf = malloc(Maxbuf);

	if(buf)
		sktostr(checkSK(f->sk), buf, Maxbuf);
	retstr(buf, f->ret);

	free(buf);
}

static SK*
strtosk(char *buf)
{
	SK *sk;
	char *p;
	SigAlg *sa;
	String *owner;
	void *key;

	sa = strtoalg(buf, &p);
	if(sa == nil)
		return H;
	owner = strtostring(p, &p);
	if(owner == H){
		destroy(sa);
		return H;
	}

	key = (*sa->vec->str2sk)(p, &p);
	if(key == nil){
		destroy(sa);
		destroy(owner);
		return H;
	}
	sk = newSK(sa, owner, 0);
	sk->key = key;

	return sk;
}

void
Keyring_strtosk(void *fp)
{
	F_Keyring_strtosk *f;
	void *v;

	f = fp;
	v = *f->ret;
	*f->ret = H;
	destroy(v);
	*f->ret = (Keyring_SK*)strtosk(string2c(f->s));
}

/*
 *  public part of a key
 */
PK*
newPK(SigAlg *sa, String *owner, int increfsa)
{
	Heap *h;
	PK *k;

	h = heap(TPK);
	k = H2D(PK*, h);
	k->x.sa = (Keyring_SigAlg*)sa;
	if(increfsa) {
		h = D2H(sa);
		h->ref++;
		Setmark(h);
	}
	k->x.owner = owner;
	k->key = 0;
	return k;
}

void
pkimmutable(PK *k)
{
	poolimmutable(D2H(k));
	poolimmutable(D2H(k->x.sa));
	poolimmutable(D2H(k->x.sa->name));
	poolimmutable(D2H(k->x.owner));
}

void
pkmutable(PK *k)
{
	poolmutable(D2H(k));
	poolmutable(D2H(k->x.sa));
	poolmutable(D2H(k->x.sa->name));
	poolmutable(D2H(k->x.owner));
}

void
freePK(Heap *h, int swept)
{
	PK *k;
	SigAlg *sa;

	k = H2D(PK*, h);
	sa = checkSigAlg(k->x.sa);
	if(k->key)
		(*sa->vec->pkfree)(k->key);
	freeheap(h, swept);
}

static PK*
checkPK(Keyring_PK *k)
{
	PK *pk;

	pk = (PK*)k;
	if(pk == H || pk == nil || pk->key == 0 || D2H(pk)->t != TPK){
		errorf("%s: %s", exType, exBadPK);
		return nil;
	}
	return pk;
}

void
Keyring_sktopk(void *fp)
{
	F_Keyring_sktopk *f;
	PK *pk;
	SigAlg *sa;
	SK *sk;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	sk = checkSK(f->sk);
	sa = checkSigAlg(sk->x.sa);
	pk = newPK(sa, stringdup(sk->x.owner), 1);
	pk->key = (*sa->vec->sk2pk)(sk->key);
	*f->ret = (Keyring_PK*)pk;
}

static int
pktostr(PK *pk, char *buf, int len)
{
	int n;
	SigAlg *sa;

	sa = checkSigAlg(pk->x.sa);
	n = snprint(buf, len, "%s\n%s\n", string2c(sa->x.name), string2c(pk->x.owner));
	return n + (*sa->vec->pk2str)(pk->key, buf+n, len - n);
}

void
Keyring_pktostr(void *fp)
{
	F_Keyring_pktostr *f;
	char *buf;

	f = fp;
	buf = malloc(Maxbuf);

	if(buf)
		pktostr(checkPK(f->pk), buf, Maxbuf);
	retstr(buf, f->ret);

	free(buf);
}

void
Keyring_pktoattr(void *fp)
{
	F_Keyring_pktoattr *f;
	char *val, *buf, *owner;
	SigAlg *sa;
	Fmt o;
	PK *pk;

	f = fp;
	pk = checkPK(f->pk);
	sa = checkSigAlg(pk->x.sa);
	buf = malloc(Maxbuf);
	if(buf == nil){
		retstr(nil, f->ret);
		return;
	}
	(*sa->vec->pk2str)(pk->key, buf, Maxbuf);
	fmtstrinit(&o);
	fmtprint(&o, "alg=%q", string2c(sa->x.name));
	owner = string2c(pk->x.owner);
	if(*owner)
		fmtprint(&o, " owner=%q", owner);
	val = bigs2attr(&o, buf, sa->vec->pkattr);
	free(buf);
	retstr(val, f->ret);
	free(val);
}

static PK*
strtopk(char *buf)
{
	PK *pk;
	char *p;
	SigAlg *sa;
	String *owner;
	void *key;

	sa = strtoalg(buf, &p);
	if(sa == nil)
		return H;
	owner = strtostring(p, &p);
	if(owner == H){
		destroy(sa);
		return H;
	}

	key = (*sa->vec->str2pk)(p, &p);
	if(key == nil){
		destroy(sa);
		destroy(owner);
		return H;
	}
	pk = newPK(sa, owner, 0);
	pk->key = key;

	return pk;
}

void
Keyring_strtopk(void *fp)
{
	F_Keyring_strtopk *f;
	void *v;

	f = fp;
	v = *f->ret;
	*f->ret = H;
	destroy(v);
	*f->ret = (Keyring_PK*)strtopk(string2c(f->s));
}

/*
 *  Certificates/signatures
 */

void
certimmutable(Certificate *c)
{
	poolimmutable(D2H(c));
	poolimmutable(D2H(c->x.signer));
	poolimmutable(D2H(c->x.ha));
	poolimmutable(D2H(c->x.sa));
	poolimmutable(D2H(c->x.sa->name));
}

void
certmutable(Certificate *c)
{
	poolmutable(D2H(c));
	poolmutable(D2H(c->x.signer));
	poolmutable(D2H(c->x.ha));
	Setmark(D2H(c->x.sa));
	poolmutable(D2H(c->x.sa));
	Setmark(D2H(c->x.sa->name));
	poolmutable(D2H(c->x.sa->name));
}

Certificate*
newCertificate(SigAlg *sa, String *ha, String *signer, long exp, int increfsa)
{
	Heap *h;
	Certificate *c;

	h = heap(TCertificate);
	c = H2D(Certificate*, h);
	c->x.sa = (Keyring_SigAlg*)sa;
	if(increfsa) {
		h = D2H(sa);
		h->ref++;
		Setmark(h);
	}
	c->x.signer = signer;
	c->x.ha = ha;
	c->x.exp = exp;
	c->signa = 0;

	return c;
}

void
freeCertificate(Heap *h, int swept)
{
	Certificate *c;
	SigAlg *sa;

	c = H2D(Certificate*, h);
	sa = checkSigAlg(c->x.sa);
	if(c->signa)
		(*sa->vec->sigfree)(c->signa);
	freeheap(h, swept);
}

Certificate*
checkCertificate(Keyring_Certificate *c)
{
	Certificate *cert;

	cert = (Certificate*)c;
	if(cert == H || cert == nil || cert->signa == 0 || D2H(cert)->t != TCertificate){
		errorf("%s: %s", exType, exBadCert);
		return nil;
	}
	return cert;
}

static int
certtostr(Certificate *c, char *buf, int len)
{
	SigAlg *sa;
	int n;

	sa = checkSigAlg(c->x.sa);
	n = snprint(buf, len, "%s\n%s\n%s\n%d\n", string2c(sa->x.name),
		string2c(c->x.ha), string2c(c->x.signer), c->x.exp);
	return n + (*sa->vec->sig2str)(c->signa, buf+n, len - n);
}

void
Keyring_certtostr(void *fp)
{
	F_Keyring_certtostr *f;
	char *buf;

	f = fp;
	buf = malloc(Maxbuf);

	if(buf)
		certtostr(checkCertificate(f->c), buf, Maxbuf);
	retstr(buf, f->ret);

	free(buf);
}

void
Keyring_certtoattr(void *fp)
{
	F_Keyring_certtoattr *f;
	char *val, *buf, *ha;
	SigAlg *sa;
	Fmt o;
	Certificate *c;

	f = fp;
	c = checkCertificate(f->c);
	sa = checkSigAlg(c->x.sa);
	buf = malloc(Maxbuf);
	if(buf == nil){
		retstr(nil, f->ret);
		return;
	}
	(*sa->vec->sig2str)(c->signa, buf, Maxbuf);
	ha = string2c(c->x.ha);
	if(strcmp(ha, "sha") == 0)
		ha = "sha1";	/* normalise */
	fmtstrinit(&o);
	fmtprint(&o, "sigalg=%q-%q signer=%q expires=%ud", string2c(sa->x.name), ha,
		string2c(c->x.signer), c->x.exp);
	val = bigs2attr(&o, buf, sa->vec->sigattr);
	free(buf);
	retstr(val, f->ret);
	free(val);
}

static Certificate*
strtocert(char *buf)
{
	Certificate *c;
	char *p;
	SigAlg *sa;
	String *signer, *ha;
	long exp;
	void *signa;

	sa = strtoalg(buf, &p);
	if(sa == 0)
		return H;

	ha = strtostring(p, &p);
	if(ha == H){
		destroy(sa);
		return H;
	}

	signer = strtostring(p, &p);
	if(signer == H){
		destroy(sa);
		destroy(ha);
		return H;
	}

	exp = strtoul(p, &p, 10);
	if(*p)
		p++;
	signa = (*sa->vec->str2sig)(p, &p);
	if(signa == nil){
		destroy(sa);
		destroy(ha);
		destroy(signer);
		return H;
	}

	c = newCertificate(sa, ha, signer, exp, 0);
	c->signa = signa;

	return c;
}

void
Keyring_strtocert(void *fp)
{
	F_Keyring_strtocert *f;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);
	*f->ret = (Keyring_Certificate*)strtocert(string2c(f->s));
}

static Certificate*
sign(SK *sk, char *ha, ulong exp, uchar *a, int len)
{
	Certificate *c;
	mpint *b;
	int n;
	SigAlg *sa;
	DigestState *ds;
	uchar digest[SHA1dlen];
	char *buf;
	String *hastr;

	hastr = H;
	sa = checkSigAlg(sk->x.sa);
	buf = malloc(Maxbuf);
	if(buf == nil)
		return nil;

	/* add signer name and expiration time to hash */
	n = snprint(buf, Maxbuf, "%s %lud", string2c(sk->x.owner), exp);
	if(strcmp(ha, "sha") == 0 || strcmp(ha, "sha1") == 0){
		ds = sha1(a, len, 0, 0);
		sha1((uchar*)buf, n, digest, ds);
		n = Keyring_SHA1dlen;
	} else if(strcmp(ha, "md5") == 0){
		ds = md5(a, len, 0, 0);
		md5((uchar*)buf, n, digest, ds);
		n = Keyring_MD5dlen;
	} else if(strcmp(ha, "md4") == 0){
		ds = md4(a, len, 0, 0);
		md4((uchar*)buf, n, digest, ds);
		n = Keyring_MD5dlen;
	} else {
		free(buf);
		return nil;
	}
	free(buf);

	/* turn message into a big integer */
	b = betomp(digest, n, nil);
	if(b == nil)
		return nil;

	/* sign */
	retstr(ha, &hastr);
	c = newCertificate(sa, hastr, stringdup(sk->x.owner), exp, 1);
	certimmutable(c);		/* hide from the garbage collector */
	release();
	c->signa = (*sa->vec->sign)(b, sk->key);
	acquire();
	mpfree(b);

	return c;
}

void
Keyring_sign(void *fp)
{
	F_Keyring_sign *f;
	Certificate *c;
	mpint *b;
	int n;
	SigAlg *sa;
	SK *sk;
	XDigestState *ds;
	uchar digest[SHA1dlen];
	char *buf;
	void *v;

	f = fp;
	v = *f->ret;
	*f->ret = H;
	destroy(v);

	sk = checkSK(f->sk);
	sa = checkSigAlg(sk->x.sa);

	/* add signer name and expiration time to hash */
	if(f->state == H)
		return;
	buf = malloc(Maxbuf);
	if(buf == nil)
		return;
	ds = (XDigestState*)f->state;
	n = snprint(buf, Maxbuf, "%s %d", string2c(sk->x.owner), f->exp);
	if(strcmp(string2c(f->ha), "sha") == 0 || strcmp(string2c(f->ha), "sha1") == 0){
		sha1((uchar*)buf, n, digest, &ds->state);
		n = Keyring_SHA1dlen;
	} else if(strcmp(string2c(f->ha), "md5") == 0){
		md5((uchar*)buf, n, digest, &ds->state);
		n = Keyring_MD5dlen;
	} else if(strcmp(string2c(f->ha), "md4") == 0){
		md4((uchar*)buf, n, digest, &ds->state);
		n = Keyring_MD5dlen;
	} else {
		free(buf);
		return;
	}
	free(buf);

	/* turn message into a big integer */
	b = betomp(digest, n, nil);
	if(b == nil)
		return;

	/* sign */
	c = newCertificate(sa, stringdup(f->ha), stringdup(sk->x.owner), f->exp, 1);
	*f->ret = (Keyring_Certificate*)c;
	release();
	c->signa = (*sa->vec->sign)(b, sk->key);
	acquire();
	mpfree(b);
}

void
Keyring_signm(void *fp)
{
	F_Keyring_signm *f;
	Certificate *c;
	mpint *b;
	SigAlg *sa;
	SK *sk;
	void *v;

	f = fp;
	v = *f->ret;
	*f->ret = H;
	destroy(v);

	sk = checkSK(f->sk);
	sa = checkSigAlg(sk->x.sa);

	if(f->m == H)
		return;
	b = checkIPint(f->m);

	/* sign */
	c = newCertificate(sa, stringdup(f->ha), stringdup(sk->x.owner), 0, 1);
	*f->ret = (Keyring_Certificate*)c;
	release();
	c->signa = (*sa->vec->sign)(b, sk->key);
	acquire();
}

static int
verify(PK *pk, Certificate *c, char *a, int len)
{
	mpint *b;
	int n;
	SigAlg *sa, *pksa;
	DigestState *ds;
	uchar digest[SHA1dlen];
	char *buf;

	sa = checkSigAlg(c->x.sa);
	pksa = checkSigAlg(pk->x.sa);
	if(sa->vec != pksa->vec)
		return 0;

	/* add signer name and expiration time to hash */
	buf = malloc(Maxbuf);
	if(buf == nil)
		return 0;
	n = snprint(buf, Maxbuf, "%s %d", string2c(c->x.signer), c->x.exp);
	if(strcmp(string2c(c->x.ha), "sha") == 0 || strcmp(string2c(c->x.ha), "sha1") == 0){
		ds = sha1((uchar*)a, len, 0, 0);
		sha1((uchar*)buf, n, digest, ds);
		n = Keyring_SHA1dlen;
	} else if(strcmp(string2c(c->x.ha), "md5") == 0){
		ds = md5((uchar*)a, len, 0, 0);
		md5((uchar*)buf, n, digest, ds);
		n = Keyring_MD5dlen;
	} else if(strcmp(string2c(c->x.ha), "md4") == 0){
		ds = md4((uchar*)a, len, 0, 0);
		md4((uchar*)buf, n, digest, ds);
		n = Keyring_MD5dlen;
	} else {
		free(buf);
		return 0;
	}
	free(buf);

	/* turn message into a big integer */
	b = betomp(digest, n, nil);
	if(b == nil)
		return 0;
	/* verify */
	release();
	n = (*sa->vec->verify)(b, c->signa, pk->key);
	acquire();

	mpfree(b);
	return n;
}

void
Keyring_verify(void *fp)
{
	F_Keyring_verify *f;
	Certificate *c;
	mpint *b;
	int n;
	SigAlg *sa, *pksa;
	PK *pk;
	XDigestState *ds;
	uchar digest[SHA1dlen];
	char *buf;

	f = fp;
	*f->ret = 0;

	c = checkCertificate(f->cert);
	sa = checkSigAlg(c->x.sa);
	pk = checkPK(f->pk);
	pksa = checkSigAlg(pk->x.sa);
	if(sa->vec != pksa->vec)
		return;

	/* add signer name and expiration time to hash */
	if(f->state == H)
		return;
	buf = malloc(Maxbuf);
	if(buf == nil)
		return;
	n = snprint(buf, Maxbuf, "%s %d", string2c(c->x.signer), c->x.exp);
	ds = (XDigestState*)f->state;

	if(strcmp(string2c(c->x.ha), "sha") == 0 || strcmp(string2c(c->x.ha), "sha1") == 0){
		sha1((uchar*)buf, n, digest, &ds->state);
		n = Keyring_SHA1dlen;
	} else if(strcmp(string2c(c->x.ha), "md5") == 0){
		md5((uchar*)buf, n, digest, &ds->state);
		n = Keyring_MD5dlen;
	} else if(strcmp(string2c(c->x.ha), "md4") == 0){
		md4((uchar*)buf, n, digest, &ds->state);
		n = Keyring_MD5dlen;
	} else {
		free(buf);
		return;
	}
	free(buf);

	/* turn message into a big integer */
	b = betomp(digest, n, nil);
	if(b == nil)
		return;

	/* verify */
	release();
	*f->ret = (*sa->vec->verify)(b, c->signa, pk->key);
	acquire();

	mpfree(b);
}

void
Keyring_verifym(void *fp)
{
	F_Keyring_verifym *f;
	Certificate *c;
	SigAlg *sa, *pksa;
	PK *pk;

	f = fp;
	*f->ret = 0;

	c = checkCertificate(f->cert);
	sa = checkSigAlg(c->x.sa);
	pk = checkPK(f->pk);
	pksa = checkSigAlg(pk->x.sa);
	if(sa->vec != pksa->vec)
		return;

	if(f->m == H)
		return;

	release();
	*f->ret = (*sa->vec->verify)(checkIPint(f->m), c->signa, pk->key);
	acquire();
}

/*
 *  digests
 */
void
Keyring_DigestState_copy(void *fp)
{
	F_DigestState_copy *f;
	Heap *h;
	XDigestState *ds, *ods;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	if(f->d != H){
		ods = checktype(f->d, TDigestState, "DigestState", 0);
		h = heap(TDigestState);
		ds = H2D(XDigestState*, h); 	
		memmove(&ds->state, &ods->state, sizeof(ds->state)); 
		*f->ret = (Keyring_DigestState*)ds;
	}
}

static Keyring_DigestState*
keyring_digest_x(Array *buf, int n, Array *digest, int dlen, Keyring_DigestState *state, DigestState* (*fn)(uchar*, ulong, uchar*, DigestState*))
{
	Heap *h;
	XDigestState *ds;
	uchar *cbuf, *cdigest;

	if(buf != H){
		if(n > buf->len)
			n = buf->len;
		cbuf = buf->data;
	}else{
		if(n != 0)
			error(exInval);
		cbuf = nil;
	}

	if(digest != H){
		if(digest->len < dlen)
			error(exBadDigest);
		cdigest = digest->data;
	} else
		cdigest = nil;

	if(state == H){
		h = heap(TDigestState);
		ds = H2D(XDigestState*, h);
		memset(&ds->state, 0, sizeof(ds->state));
	} else
		ds = checktype(state, TDigestState, "DigestState", 1);

	(*fn)(cbuf, n, cdigest, &ds->state);

	return (Keyring_DigestState*)ds;
}

void
Keyring_sha1(void *fp)
{
	F_Keyring_sha1 *f;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	*f->ret = keyring_digest_x(f->buf, f->n, f->digest, SHA1dlen, f->state, sha1);
}

void
Keyring_sha224(void *fp)
{
	F_Keyring_sha224 *f;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	*f->ret = keyring_digest_x(f->buf, f->n, f->digest, SHA224dlen, f->state, sha224);
}

void
Keyring_sha256(void *fp)
{
	F_Keyring_sha256 *f;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	*f->ret = keyring_digest_x(f->buf, f->n, f->digest, SHA256dlen, f->state, sha256);
}

void
Keyring_sha384(void *fp)
{
	F_Keyring_sha384 *f;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	*f->ret = keyring_digest_x(f->buf, f->n, f->digest, SHA384dlen, f->state, sha384);
}

void
Keyring_sha512(void *fp)
{
	F_Keyring_sha512 *f;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	*f->ret = keyring_digest_x(f->buf, f->n, f->digest, SHA512dlen, f->state, sha512);
}

void
Keyring_md5(void *fp)
{
	F_Keyring_md5 *f;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	*f->ret = keyring_digest_x(f->buf, f->n, f->digest, MD5dlen, f->state, md5);
}

void
Keyring_md4(void *fp)
{
	F_Keyring_md4 *f;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	*f->ret = keyring_digest_x(f->buf, f->n, f->digest, MD4dlen, f->state, md4);
}

static Keyring_DigestState*
keyring_hmac_x(Array *data, int n, Array *key, Array *digest, int dlen, Keyring_DigestState *state, DigestState* (*fn)(uchar*, ulong, uchar*, ulong, uchar*, DigestState*))
{
	Heap *h;
	XDigestState *ds;
	uchar *cdata, *cdigest;

	if(data != H){
		if(n > data->len)
			n = data->len;
		cdata = data->data;
	}else{
		if(n != 0)
			error(exInval);
		cdata = nil;
	}

	if(key == H || key->len > 64)
		error(exBadKey);

	if(digest != H){
		if(digest->len < dlen)
			error(exBadDigest);
		cdigest = digest->data;
	} else
		cdigest = nil;

	if(state == H){
		h = heap(TDigestState);
		ds = H2D(XDigestState*, h);
		memset(&ds->state, 0, sizeof(ds->state));
	} else
		ds = checktype(state, TDigestState, "DigestState", 1);

	(*fn)(cdata, n, key->data, key->len, cdigest, &ds->state);

	return (Keyring_DigestState*)ds;
}

void
Keyring_hmac_sha1(void *fp)
{
	F_Keyring_hmac_sha1 *f;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);
	*f->ret = keyring_hmac_x(f->data, f->n, f->key, f->digest, SHA1dlen, f->state, hmac_sha1);
}

void
Keyring_hmac_md5(void *fp)
{
	F_Keyring_hmac_md5 *f;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);
	*f->ret = keyring_hmac_x(f->data, f->n, f->key, f->digest, MD5dlen, f->state, hmac_md5);
}

void
Keyring_dhparams(void *fp)
{
	F_Keyring_dhparams *f;
	mpint *p, *alpha;
	void *v;

	f = fp;
	v = f->ret->t0;
	f->ret->t0 = H;
	destroy(v);
	v = f->ret->t1;
	f->ret->t1 = H;
	destroy(v);

	p = mpnew(0);
	alpha = mpnew(0);
	release();
	if(f->nbits == 1024)
		DSAprimes(alpha, p, nil);
	else
		gensafeprime(p, alpha, f->nbits, 0);
	acquire();
	f->ret->t0 = newIPint(alpha);
	f->ret->t1 = newIPint(p);
}

static int
sendmsg(int fd, void *buf, int n)
{
	char num[10];

	release();
	snprint(num, sizeof(num), "%4.4d\n", n);
	if(kwrite(fd, num, 5) != 5){
		acquire();
		return -1;
	}
	n = kwrite(fd, buf, n);
	acquire();
	return n;
}

void
Keyring_sendmsg(void *fp)
{
	F_Keyring_sendmsg *f;
	int n;

	f = fp;
	*f->ret = -1;
	if(f->fd == H || f->buf == H || f->n < 0)
		return;
	n = f->n;
	if(n < 0 || n > f->buf->len)
		error(exBounds);
	*f->ret = sendmsg(f->fd->fd, f->buf->data, n);
}

static int
senderr(int fd, char *err, int addrmt)
{
	char num[10];
	int n, m;

	release();
	n = strlen(err);
	m = 0;
	if(addrmt)
		m = strlen("remote: ");
	snprint(num, sizeof(num), "!%3.3d\n", n+m);
	if(kwrite(fd, num, 5) != 5){
		acquire();
		return -1;
	}
	if(addrmt)
		kwrite(fd, "remote: ", m);
	n = kwrite(fd, err, n);
	acquire();
	return n;
}

void
Keyring_senderrmsg(void *fp)
{
	F_Keyring_senderrmsg *f;
	char *s;

	f = fp;
	*f->ret = -1;
	if(f->fd == H)
		return;
	s = string2c(f->s);
	if(senderr(f->fd->fd, s, 0) > 0)
		*f->ret = 0;
}

static int
nreadn(int fd, void *av, int n)
{

	char *a;
	long m, t;

	a = av;
	t = 0;
	while(t < n){
		m = kread(fd, a+t, n-t);
		if(m <= 0){
			if(t == 0)
				return m;
			break;
		}
		t += m;
	}
	return t;
}

#define MSG "input or format error"

static void
getmsgerr(char *buf, int n, int r)
{
	char *e;
	int l;

	e = r>0? MSG: "hungup";
	l = strlen(e)+1;
	if(n > l)
		n = l;
	memmove(buf, e, n-1);
	buf[n-1] = 0;
}

static int
getmsg(int fd, char *buf, int n)
{
	char num[6];
	int len, r;

	release();
	if((r = nreadn(fd, num, 5)) != 5){
		getmsgerr(buf, n, r);
		acquire();
		return -1;
	}
	num[5] = 0;

	if(num[0] == '!')
		len = strtoul(num+1, 0, 10);
	else
		len = strtoul(num, 0, 10);

	r = -1;
	if(len < 0 || len >= n || (r = nreadn(fd, buf, len)) != len){
		getmsgerr(buf, n, r);
		acquire();
		return -1;
	}

	buf[len] = 0;
	acquire();
	if(num[0] == '!')
		return -len;

	return len;
}

void
Keyring_getmsg(void *fp)
{
	F_Keyring_getmsg *f;
	char *buf;
	int n;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);
	if(f->fd == H){
		kwerrstr("nil fd");
		return;
	}

	buf = malloc(Maxmsg);
	if(buf == nil){
		kwerrstr(exNomem);
		return;
	}

	n = getmsg(f->fd->fd, buf, Maxmsg);
	if(n < 0){
		kwerrstr("%s", buf);
		free(buf);
		return;
	}

	*f->ret = mem2array(buf, n);
	free(buf);
}

void
Keyring_auth(void *fp)
{
	F_Keyring_auth *f;
	mpint *r0, *r1, *p, *alpha, *alphar0, *alphar1, *alphar0r1;
	SK *mysk;
	PK *mypk, *spk, *hispk;
	Certificate *cert, *hiscert, *alphacert;
	char *buf, *err;
	uchar *cvb;
	int n, fd, version;
	long now;

	hispk = H;
	hiscert = H;
	alphacert = H;
	err = nil;

	/* null out the return values */
	f = fp;
	destroy(f->ret->t0);
	f->ret->t0 = H;
	destroy(f->ret->t1);
	f->ret->t1 = H;
	r0 = r1 = alphar0 = alphar1 = alphar0r1 = nil;

	/* check args */
	if(f->fd == H || f->fd->fd < 0){
		retstr("bad fd", &f->ret->t0);
		return;
	}
	fd = f->fd->fd;

	buf = malloc(Maxbuf);
	if(buf == nil){
		retstr(exNomem, &f->ret->t0);
		return;
	}

	/* send auth protocol version number */
	if(sendmsg(fd, "1", 1) <= 0){
		err = MSG;
		goto out;
	}

	/* get auth protocol version number */
	n = getmsg(fd, buf, Maxbuf-1);
	if(n < 0){
		err = buf;
		goto out;
	}
	buf[n] = 0;
	version = atoi(buf);
	if(version != 1 || n > 4){
		err = "incompatible authentication protocol";
		goto out;
	}

	if(f->info == H){
		err = "no authentication information";
		goto out;
	}
	if(f->info->p == H){
		err = "missing diffie hellman mod";
		goto out;
	}
	if(f->info->alpha == H){
		err = "missing diffie hellman base";
		goto out;
	}
	mysk = checkSK(f->info->mysk);
	if(mysk == H){
		err = "bad sk arg";
		goto out;
	}
	mypk = checkPK(f->info->mypk);
	if(mypk == H){
		err = "bad pk arg";
		goto out;
	}
	cert = checkCertificate(f->info->cert);
	if(cert == H){
		err = "bad certificate arg";
		goto out;
	}
	spk = checkPK(f->info->spk);
	if(spk == H){
		err = "bad signer key arg";
		goto out;
	}

	/* get alpha and p */
	p = checkIPint(f->info->p);
	alpha = checkIPint(f->info->alpha);

	if(p->sign == -1) {
		err = "-ve modulus";
		goto out;
	}

	r0 = mpnew(0);
	r1 = mpnew(0);
	alphar0 = mpnew(0);
	alphar0r1 = mpnew(0);

	/* generate alpha**r0 */
if(0)print("X");
	release();
	mprand(mpsignif(p), genrandom, r0);
	mpexp(alpha, r0, p, alphar0);
	acquire();
if(0)print("Y");

	/* send alpha**r0 mod p, mycert, and mypk */
	n = bigtobase64(alphar0, buf, Maxbuf);
	if(sendmsg(fd, buf, n) <= 0){
		err = MSG;
		goto out;
	}

	n = certtostr(cert, buf, Maxbuf);
	if(sendmsg(fd, buf, n) <= 0){
		err = MSG;
		goto out;
	}

	n = pktostr(mypk, buf, Maxbuf);
	if(sendmsg(fd, buf, n) <= 0){
		err = MSG;
		goto out;
	}

	/* get alpha**r1 mod p, hiscert, hispk */
	n = getmsg(fd, buf, Maxbuf-1);
	if(n < 0){
		err = buf;
		goto out;
	}
	buf[n] = 0;
	alphar1 = strtomp(buf, nil, 64, nil);

	/* trying a fast one */
	if(mpcmp(p, alphar1) <= 0){
		err = "implausible parameter value";
		goto out;
	}

	/* if alpha**r1 == alpha**r0, someone may be trying a replay */
	if(mpcmp(alphar0, alphar1) == 0){
		err = "possible replay attack";
		goto out;
	}

	n = getmsg(fd, buf, Maxbuf-1);
	if(n < 0){
		err = buf;
		goto out;
	}
	buf[n] = 0;
	hiscert = strtocert(buf);
	if(hiscert == H){
		err = "bad certificate syntax";
		goto out;
	}
	certimmutable(hiscert);		/* hide from the garbage collector */

	n = getmsg(fd, buf, Maxbuf-1);
	if(n < 0){
		err = buf;
		goto out;
	}
	buf[n] = 0;
	hispk = strtopk(buf);
	if(hispk == H){
		err = "bad public key";
		goto out;
	}
	pkimmutable(hispk);		/* hide from the garbage collector */

	/* verify his public key */
	if(verify(spk, hiscert, buf, n) == 0){
		err = "pk doesn't match certificate";
		goto out;
	}

	/* check expiration date - in seconds of epoch */

	now = osusectime()/1000000;
	if(hiscert->x.exp != 0 && hiscert->x.exp <= now){
		err = "certificate expired";
		goto out;
	}

	/* sign alpha**r0 and alpha**r1 and send */
	n = bigtobase64(alphar0, buf, Maxbuf);
	n += bigtobase64(alphar1, buf+n, Maxbuf-n);
	alphacert = sign(mysk, "sha1", 0, (uchar*)buf, n);
	n = certtostr(alphacert, buf, Maxbuf);
	if(sendmsg(fd, buf, n) <= 0){
		err = MSG;
		goto out;
	}
	certmutable(alphacert);
	destroy(alphacert);
	alphacert = H;

	/* get signature of alpha**r1 and alpha**r0 and verify */
	n = getmsg(fd, buf, Maxbuf-1);
	if(n < 0){
		err = buf;
		goto out;
	}
	buf[n] = 0;
	alphacert = strtocert(buf);
	if(alphacert == H){
		err = "alpha**r1 doesn't match certificate";
		goto out;
	}
	certimmutable(alphacert);		/* hide from the garbage collector */
	n = bigtobase64(alphar1, buf, Maxbuf);
	n += bigtobase64(alphar0, buf+n, Maxbuf-n);
	if(verify(hispk, alphacert, buf, n) == 0){
		err = "bad certificate";
		goto out;
	}

	/* we are now authenticated and have a common secret, alpha**(r0*r1) */
	f->ret->t0 = stringdup(hispk->x.owner);
	mpexp(alphar1, r0, p, alphar0r1);
	n = mptobe(alphar0r1, nil, Maxbuf, &cvb);
	if(n < 0){
		err = "bad conversion";
		goto out;
	}
	f->ret->t1 = mem2array(cvb, n);
	free(cvb);

out:
	/* return status */
	if(f->ret->t0 == H){
		if(err == buf)
			senderr(fd, "missing your authentication data", 1);
		else
			senderr(fd, err, 1);
	}else
		sendmsg(fd, "OK", 2);

	/* read responses */
	if(err != buf){
		for(;;){
			n = getmsg(fd, buf, Maxbuf-1);
			if(n < 0){
				destroy(f->ret->t0);
				f->ret->t0 = H;
				destroy(f->ret->t1);
				f->ret->t1 = H;
				if(err == nil){
					if(n < -1)
						err = buf;
					else
						err = MSG;
				}
				break;
			}
			if(n == 2 && buf[0] == 'O' && buf[1] == 'K')
				break;
		}
	}

	/* set error and id to nobody */
	if(f->ret->t0 == H){
		if(err == nil)
			err = MSG;
		retstr(err, &f->ret->t0);
		if(f->setid)
			setid("nobody", 1);
	} else {
		/* change user id */
		if(f->setid)
			setid(string2c(f->ret->t0), 1);
	}
	
	/* free resources */
	if(hispk != H){
		pkmutable(hispk);
		destroy(hispk);
	}
	if(hiscert != H){
		certmutable(hiscert);
		destroy(hiscert);
	}
	if(alphacert != H){
		certmutable(alphacert);
		destroy(alphacert);
	}
	free(buf);
	if(r0 != nil){
		mpfree(r0);
		mpfree(r1);
		mpfree(alphar0);
		mpfree(alphar1);
		mpfree(alphar0r1);
	}
}

static Keyring_Authinfo*
newAuthinfo(void)
{
	return H2D(Keyring_Authinfo*, heap(TAuthinfo));
}

void
Keyring_writeauthinfo(void *fp)
{
	F_Keyring_writeauthinfo *f;
	int n, fd;
	char *buf;
	PK *spk;
	SK *mysk;
	Certificate *c;
	mpint *p, *alpha;

	f = fp;
	*f->ret = -1;

	if(f->filename == H)
		error(exNilref);
	if(f->info == H)
		error(exNilref);
	alpha = checkIPint(f->info->alpha);
	p = checkIPint(f->info->p);
	spk = checkPK(f->info->spk);
	mysk = checkSK(f->info->mysk);
	c = checkCertificate(f->info->cert);

	buf = malloc(Maxbuf);
	if(buf == nil)
		return;

	/*
	 *  The file may already exist or be a file2chan file so first
	 *  try opening with truncation since create will change the
	 *  permissions of the file and create doesn't work with a
	 *  file2chan.
	 */
	release();
	fd = kopen(string2c(f->filename), OTRUNC|OWRITE);
	if(fd < 0)
		fd = kcreate(string2c(f->filename), OWRITE, 0600);
	if(fd < 0)
		fd = kopen(string2c(f->filename), OWRITE);
	acquire();
	if(fd < 0)
		goto out;

	/* signer's public key */
	n = pktostr(spk, buf, Maxmsg);
	if(sendmsg(fd, buf, n) <= 0)
		goto out;

	/* certificate for my public key */
	n = certtostr(c, buf, Maxmsg);
	if(sendmsg(fd, buf, n) <= 0)
		goto out;

	/* my secret/public key */
	n = sktostr(mysk, buf, Maxmsg);
	if(sendmsg(fd, buf, n) <= 0)
		goto out;

	/* diffie hellman base */
	n = bigtobase64(alpha, buf, Maxbuf);
	if(sendmsg(fd, buf, n) <= 0)
		goto out;

	/* diffie hellman modulus */
	n = bigtobase64(p, buf, Maxbuf);
	if(sendmsg(fd, buf, n) <= 0)
		goto out;

	*f->ret = 0;
out:
	free(buf);
	if(fd >= 0){
		release();
		kclose(fd);
		acquire();
	}
}

void
Keyring_readauthinfo(void *fp)
{
	F_Keyring_readauthinfo *f;
	int fd;
	char *buf;
	int n, ok;
	PK *mypk;
	SK *mysk;
	SigAlg *sa;
	Keyring_Authinfo *ai;
	mpint *b;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	ok = 0;

	if(f->filename == H)
		return;

	buf = malloc(Maxbuf);
	if(buf == nil)
		return;

	ai = newAuthinfo();
	*f->ret = ai;

	release();
	fd = kopen(string2c(f->filename), OREAD);
	acquire();
	if(fd < 0)
		goto out;

	/* signer's public key */
	n = getmsg(fd, buf, Maxmsg);
	if(n < 0)
		goto out;

	ai->spk = (Keyring_PK*)strtopk(buf);
	if(ai->spk == H)
		goto out;

	/* certificate for my public key */
	n = getmsg(fd, buf, Maxmsg);
	if(n < 0)
		goto out;
	ai->cert = (Keyring_Certificate*)strtocert(buf);
	if(ai->cert == H)
		goto out;

	/* my secret/public key */
	n = getmsg(fd, buf, Maxmsg);
	if(n < 0)
		goto out;
	mysk = strtosk(buf);
	ai->mysk = (Keyring_SK*)mysk;
	if(mysk == H)
		goto out;
	sa = checkSigAlg(mysk->x.sa);
	mypk = newPK(sa, stringdup(mysk->x.owner), 1);
	mypk->key = (*sa->vec->sk2pk)(mysk->key);
	ai->mypk = (Keyring_PK*)mypk;

	/* diffie hellman base */
	n = getmsg(fd, buf, Maxmsg);
	if(n < 0)
		goto out;
	b = strtomp(buf, nil, 64, nil);
	ai->alpha = newIPint(b);

	/* diffie hellman modulus */
	n = getmsg(fd, buf, Maxmsg);
	if(n < 0)
		goto out;
	b = strtomp(buf, nil, 64, nil);
	ai->p = newIPint(b);
	ok = 1;
out:
	if(!ok){
		r = *f->ret;
		*f->ret = H;
		destroy(r);
	}
	free(buf);
	if(fd >= 0){
		release();
		kclose(fd);
		acquire();
		kwerrstr("%q: %s", string2c(f->filename), MSG);
	}
}

void
keyringmodinit(void)
{
	SigAlgVec *sav;
	extern SigAlgVec* elgamalinit(void);
	extern SigAlgVec* rsainit(void);
	extern SigAlgVec* dsainit(void);

	ipintsmodinit();	/* in case only Keyring is configured */
	TSigAlg = dtype(freeSigAlg, sizeof(SigAlg), SigAlgmap, sizeof(SigAlgmap));
	TSK = dtype(freeSK, sizeof(SK), SKmap, sizeof(SKmap));
	TPK = dtype(freePK, sizeof(PK), PKmap, sizeof(PKmap));
	TCertificate = dtype(freeCertificate, sizeof(Certificate), Certificatemap,
		sizeof(Certificatemap));
	TDigestState = dtype(freeheap, sizeof(XDigestState), DigestStatemap,
		sizeof(DigestStatemap));
	TAESstate = dtype(freeheap, sizeof(XAESstate), AESstatemap,
		sizeof(AESstatemap));
	TDESstate = dtype(freeheap, sizeof(XDESstate), DESstatemap,
		sizeof(DESstatemap));
	TIDEAstate = dtype(freeheap, sizeof(XIDEAstate), IDEAstatemap,
		sizeof(IDEAstatemap));
	TBFstate = dtype(freeheap, sizeof(XBFstate), BFstatemap,
		sizeof(BFstatemap));
	TRC4state = dtype(freeheap, sizeof(XRC4state), RC4statemap,
		sizeof(RC4statemap));
	TAuthinfo = dtype(freeheap, sizeof(Keyring_Authinfo), Authinfomap, sizeof(Authinfomap));
	TDSAsk = dtype(freeheap, sizeof(Keyring_DSAsk), DSAskmap, sizeof(DSAskmap));
	TDSApk = dtype(freeheap, sizeof(Keyring_DSApk), DSApkmap, sizeof(DSApkmap));
	TDSAsig = dtype(freeheap, sizeof(Keyring_DSAsig), DSAsigmap, sizeof(DSAsigmap));
	TEGsk = dtype(freeheap, sizeof(Keyring_EGsk), EGskmap, sizeof(EGskmap));
	TEGpk = dtype(freeheap, sizeof(Keyring_EGpk), EGpkmap, sizeof(EGpkmap));
	TEGsig = dtype(freeheap, sizeof(Keyring_EGsig), EGsigmap, sizeof(EGsigmap));
	TRSAsk = dtype(freeheap, sizeof(Keyring_RSAsk), RSAskmap, sizeof(RSAskmap));
	TRSApk = dtype(freeheap, sizeof(Keyring_RSApk), RSApkmap, sizeof(RSApkmap));
	TRSAsig = dtype(freeheap, sizeof(Keyring_RSAsig), RSAsigmap, sizeof(RSAsigmap));

	if((sav = elgamalinit()) != nil)
		algs[nalg++] = sav;
	if((sav = rsainit()) != nil)
		algs[nalg++] = sav;
	if((sav = dsainit()) != nil)
		algs[nalg++] = sav;

	fmtinstall('U', big64conv);
	builtinmod("$Keyring", Keyringmodtab, Keyringmodlen);
}

/*
 *  IO on a delimited channel.  A message starting with 0x00 is a normal
 *  message.  One starting with 0xff is an error string.
 *
 *  return negative number for error messages (including hangup)
 */
static int
getbuf(int fd, uchar *buf, int n, char *err, int nerr)
{
	int len;

	release();
	len = kread(fd, buf, n);
	acquire();
	if(len <= 0){
		strncpy(err, "hungup", nerr);
		buf[nerr-1] = 0;
		return -1;
	}
	if(buf[0] == 0)
		return len-1;
	if(buf[0] != 0xff){
		/*
		 * this happens when the client's password is wrong: both sides use a digest of the
		 * password as a crypt key for devssl. When they don't match decryption garbles
		 * messages
		 */
		strncpy(err, "failure", nerr);
		err[nerr-1] = 0;
		return -1;
	}

	/* error string */
	len--;
	if(len < 1){
		strncpy(err, "unknown", nerr);
		err[nerr-1] = 0;
	} else {
		if(len >= nerr)
			len = nerr-1;
		memmove(err, buf+1, len);
		err[len] = 0;
	}
	return -1;
}

void
Keyring_getstring(void *fp)
{
	F_Keyring_getstring *f;
	uchar *buf;
	char err[64];
	int n;

	f = fp;
	destroy(f->ret->t0);
	f->ret->t0 = H;
	destroy(f->ret->t1);
	f->ret->t1 = H;

	if(f->fd == H)
		return;

	buf = malloc(Maxmsg);
	if(buf == nil)
		return;

	n = getbuf(f->fd->fd, buf, Maxmsg, err, sizeof(err));
	if(n < 0)
		retnstr(err, strlen(err), &f->ret->t1);
	else
		retnstr(((char*)buf)+1, n, &f->ret->t0);

	free(buf);
}

void
Keyring_getbytearray(void *fp)
{
	F_Keyring_getbytearray *f;
	uchar *buf;
	char err[64];
	int n;

	f = fp;
	destroy(f->ret->t0);
	f->ret->t0 = H;
	destroy(f->ret->t1);
	f->ret->t1 = H;

	if(f->fd == H)
		return;

	buf = malloc(Maxmsg);
	if(buf == nil)
		return;

	n = getbuf(f->fd->fd, buf, Maxmsg, err, sizeof(err));
	if(n < 0)
		retnstr(err, strlen(err), &f->ret->t1);
	else
		f->ret->t0 = mem2array(buf+1, n);

	free(buf);
}

static int
putbuf(int fd, void *p, int n)
{
	char *buf;

	buf = malloc(Maxmsg);
	if(buf == nil)
		return -1;

	release();
	buf[0] = 0;
	if(n < 0){
		buf[0] = 0xff;
		n = -n;
	}
	if(n >= Maxmsg)
		n = Maxmsg - 1;
	memmove(buf+1, p, n);
	n = kwrite(fd, buf, n+1);
	acquire();

	free(buf);
	return n;
}

void
Keyring_putstring(void *fp)
{
	F_Keyring_putstring *f;

	f = fp;
	*f->ret = -1;
	if(f->fd == H || f->s == H)
		return;
	*f->ret = putbuf(f->fd->fd, string2c(f->s), strlen(string2c(f->s)));
}

void
Keyring_puterror(void *fp)
{
	F_Keyring_puterror *f;

	f = fp;
	*f->ret = -1;
	if(f->fd == H || f->s == H)
		return;
	*f->ret = putbuf(f->fd->fd, string2c(f->s), -strlen(string2c(f->s)));
}

void
Keyring_putbytearray(void *fp)
{
	F_Keyring_putbytearray *f;
	int n;

	f = fp;
	*f->ret = -1;
	if(f->fd == H || f->a == H)
		return;
	n = f->n;
	if(n < 0 || n > f->a->len)
		error(exBounds);
	*f->ret = putbuf(f->fd->fd, f->a->data, n);
}

void
Keyring_dessetup(void *fp)
{
	F_Keyring_dessetup *f;
	Heap *h;
	XDESstate *ds;
	uchar *ivec;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	if(f->key == H || f->key->len < 8)
		error(exBadKey);
	if(f->ivec != H){
		if(f->ivec->len < 8)
			error(exBadIvec);
		ivec = f->ivec->data;
	}else
		ivec = nil;

	h = heap(TDESstate);
	ds = H2D(XDESstate*, h);
	setupDESstate(&ds->state, f->key->data, ivec);

	*f->ret = (Keyring_DESstate*)ds;
}

void
Keyring_desecb(void *fp)
{
	F_Keyring_desecb *f;
	XDESstate *ds;
	int i;
	uchar *p;

	f = fp;

	if(f->buf == H)
		return;
	if(f->n < 0 || f->n > f->buf->len)
		error(exBounds);
	if(f->n & 7)
		error(exBadBsize);

	ds = checktype(f->state, TDESstate, exBadState, 0);
	p = f->buf->data;

	for(i = 8; i <= f->n; i += 8, p += 8)
		block_cipher(ds->state.expanded, p, f->direction);
}

void
Keyring_descbc(void *fp)
{
	F_Keyring_descbc *f;
	XDESstate *ds;
	uchar *p, *ep, *ip, *p2, *eip;
	uchar tmp[8];

	f = fp;

	if(f->buf == H)
		return;
	if(f->n < 0 || f->n > f->buf->len)
		error(exBounds);
	if(f->n & 7)
		error(exBadBsize);

	ds = checktype(f->state, TDESstate, exBadState, 0);
	p = f->buf->data;

	if(f->direction == 0){
		for(ep = p + f->n; p < ep; p += 8){
			p2 = p;
			ip = ds->state.ivec;
			for(eip = ip+8; ip < eip; )
				*p2++ ^= *ip++;
			block_cipher(ds->state.expanded, p, 0);
			memmove(ds->state.ivec, p, 8);
		}
	} else {
		for(ep = p + f->n; p < ep; ){
			memmove(tmp, p, 8);
			block_cipher(ds->state.expanded, p, 1);
			p2 = tmp;
			ip = ds->state.ivec;
			for(eip = ip+8; ip < eip; ){
				*p++ ^= *ip;
				*ip++ = *p2++;
			}
		}
	}
}

void
Keyring_ideasetup(void *fp)
{
	F_Keyring_ideasetup *f;
	Heap *h;
	XIDEAstate *is;
	uchar *ivec;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	if(f->key == H || f->key->len < 16)
		error(exBadKey);
	if(f->ivec != H){
		if(f->ivec->len < 8)
			error(exBadIvec);
		ivec = f->ivec->data;
	}else
		ivec = nil;

	h = heap(TIDEAstate);
	is = H2D(XIDEAstate*, h);

	setupIDEAstate(&is->state, f->key->data, ivec);

	*f->ret = (Keyring_IDEAstate*)is;
}

void
Keyring_ideaecb(void *fp)
{
	F_Keyring_ideaecb *f;
	XIDEAstate *is;
	int i;
	uchar *p;

	f = fp;

	if(f->buf == H)
		return;
	if(f->n < 0 || f->n > f->buf->len)
		error(exBounds);
	if(f->n & 7)
		error(exBadBsize);

	is = checktype(f->state, TIDEAstate, exBadState, 0);
	p = f->buf->data;

	for(i = 8; i <= f->n; i += 8, p += 8)
		idea_cipher(is->state.edkey, p, f->direction);
}

void
Keyring_ideacbc(void *fp)
{
	F_Keyring_ideacbc *f;
	XIDEAstate *is;
	uchar *p, *ep, *ip, *p2, *eip;
	uchar tmp[8];

	f = fp;

	if(f->buf == H)
		return;
	if(f->n < 0 || f->n > f->buf->len)
		error(exBounds);
	if(f->n & 7)
		error(exBadBsize);

	is = checktype(f->state, TIDEAstate, exBadState, 0);
	p = f->buf->data;

	if(f->direction == 0){
		for(ep = p + f->n; p < ep; p += 8){
			p2 = p;
			ip = is->state.ivec;
			for(eip = ip+8; ip < eip; )
				*p2++ ^= *ip++;
			idea_cipher(is->state.edkey, p, 0);
			memmove(is->state.ivec, p, 8);
		}
	} else {
		for(ep = p + f->n; p < ep; ){
			memmove(tmp, p, 8);
			idea_cipher(is->state.edkey, p, 1);
			p2 = tmp;
			ip = is->state.ivec;
			for(eip = ip+8; ip < eip; ){
				*p++ ^= *ip;
				*ip++ = *p2++;
			}
		}
	}
}

void
Keyring_aessetup(void *fp)
{
	F_Keyring_aessetup *f;
	Heap *h;
	XAESstate *is;
	uchar *ivec;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	if(f->key == H ||
	   f->key->len != 16 && f->key->len != 24 && f->key->len != 32)
		error(exBadKey);
	if(f->ivec != H){
		if(f->ivec->len < AESbsize)
			error(exBadIvec);
		ivec = f->ivec->data;
	}else
		ivec = nil;

	h = heap(TAESstate);
	is = H2D(XAESstate*, h);

	setupAESstate(&is->state, f->key->data, f->key->len, ivec);

	*f->ret = (Keyring_AESstate*)is;
}

void
Keyring_aescbc(void *fp)
{
	F_Keyring_aescbc *f;
	XAESstate *is;
	uchar *p;

	f = fp;

	if(f->buf == H)
		return;
	if(f->n < 0 || f->n > f->buf->len)
		error(exBounds);

	is = checktype(f->state, TAESstate, exBadState, 0);
	p = f->buf->data;

	if(f->direction == 0)
		aesCBCencrypt(p, f->n, &is->state);
	else
		aesCBCdecrypt(p, f->n, &is->state);
}

void
Keyring_blowfishsetup(void *fp)
{
	F_Keyring_blowfishsetup *f;
	Heap *h;
	XBFstate *is;
	uchar *ivec;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	if(f->key == H || f->key->len <= 0)
		error(exBadKey);
	if(f->ivec != H){
		if(f->ivec->len != BFbsize)
			error(exBadIvec);
		ivec = f->ivec->data;
	}else
		ivec = nil;

	h = heap(TBFstate);
	is = H2D(XBFstate*, h);

	setupBFstate(&is->state, f->key->data, f->key->len, ivec);

	*f->ret = (Keyring_BFstate*)is;
}

void
Keyring_blowfishcbc(void *fp)
{
	F_Keyring_blowfishcbc *f;
	XBFstate *is;
	uchar *p;

	f = fp;

	if(f->buf == H)
		return;
	if(f->n < 0 || f->n > f->buf->len)
		error(exBounds);
	if(f->n & 7)
		error(exBadBsize);

	is = checktype(f->state, TBFstate, exBadState, 0);
	p = f->buf->data;

	if(f->direction == 0)
		bfCBCencrypt(p, f->n, &is->state);
	else
		bfCBCdecrypt(p, f->n, &is->state);
}

void
Keyring_rc4setup(void *fp)
{
	F_Keyring_rc4setup *f;
	Heap *h;
	XRC4state *is;
	void *r;

	f = fp;
	r = *f->ret;
	*f->ret = H;
	destroy(r);

	if(f->seed == H)
		return;

	h = heap(TRC4state);
	is = H2D(XRC4state*, h);

	setupRC4state(&is->state, f->seed->data, f->seed->len);

	*f->ret = (Keyring_RC4state*)is;
}

void
Keyring_rc4(void *fp)
{
	F_Keyring_rc4 *f;
	XRC4state *is;
	uchar *p;

	f = fp;
	if(f->buf == H)
		return;
	if(f->n < 0 || f->n > f->buf->len)
		error(exBounds);
	is = checktype(f->state, TRC4state, exBadState, 0);
	p = f->buf->data;
	rc4(&is->state, p, f->n);
}

void
Keyring_rc4skip(void *fp)
{
	F_Keyring_rc4skip *f;
	XRC4state *is;

	f = fp;
	is = checktype(f->state, TRC4state, exBadState, 0);
	rc4skip(&is->state, f->n);
}

void
Keyring_rc4back(void *fp)
{
	F_Keyring_rc4back *f;
	XRC4state *is;

	f = fp;
	is = checktype(f->state, TRC4state, exBadState, 0);
	rc4back(&is->state, f->n);
}

/*
 *  public/secret keys, signing and verifying
 */

static void
dsapk2pub(DSApub* p, Keyring_DSApk* pk)
{
	if(pk == H)
		error(exNilref);
	p->p = checkIPint(pk->p);
	p->q = checkIPint(pk->q);
	p->alpha = checkIPint(pk->alpha);
	p->key = checkIPint(pk->key);
}

static void
dsask2priv(DSApriv* p, Keyring_DSAsk* sk)
{
	if(sk == H || sk->pk == H)
		error(exNilref);
	dsapk2pub(&p->pub, sk->pk);
	p->secret = checkIPint(sk->secret);
}

static void
dsapriv2sk(Keyring_DSAsk* sk, DSApriv* p)
{
	Keyring_DSApk* pk;

	pk = sk->pk;
	pk->p = ipcopymp(p->pub.p);
	pk->q = ipcopymp(p->pub.q);
	pk->alpha = ipcopymp(p->pub.alpha);
	pk->key = ipcopymp(p->pub.key);
	sk->secret = ipcopymp(p->secret);
}

void
DSAsk_gen(void *fp)
{
	F_DSAsk_gen *f;
	Keyring_DSAsk *sk;
	DSApriv *p;
	DSApub pub, *oldpk;
	void *v;

	f = fp;
	v = *f->ret;
	sk = newthing(TDSAsk, 0);
	sk->pk = newthing(TDSApk, 0);
	*f->ret = sk;
	destroy(v);
	oldpk = nil;
	if(f->oldpk != H){
		dsapk2pub(&pub, f->oldpk);
		oldpk = &pub;
	}
	release();
	p = dsagen(oldpk);
	acquire();
	dsapriv2sk(sk, p);
	dsaprivfree(p);
}

void
DSAsk_sign(void *fp)
{
	F_DSAsk_sign *f;
	Keyring_DSAsig *sig;
	DSApriv p;
	mpint *m;
	DSAsig *s;
	void *v;

	f = fp;
	v = *f->ret;
	sig = newthing(TDSAsig, 0);
	*f->ret = sig;
	destroy(v);

	dsask2priv(&p, f->k);
	m = checkIPint(f->m);
	release();
	s = dsasign(&p, m);
	acquire();
	sig->r = ipcopymp(s->r);
	sig->s = ipcopymp(s->s);
	dsasigfree(s);
}

void
DSApk_verify(void *fp)
{
	F_DSApk_verify *f;
	DSApub p;
	DSAsig sig;
	mpint *m;

	f = fp;
	*f->ret = 0;
	if(f->m == H || f->sig == H)
		return;
	dsapk2pub(&p, f->k);
	sig.r = checkIPint(f->sig->r);
	sig.s = checkIPint(f->sig->s);
	m = checkIPint(f->m);
	release();
	*f->ret = dsaverify(&p, &sig, m) == 0;
	acquire();
}

static void
egpk2pub(EGpub* p, Keyring_EGpk* pk)
{
	if(pk == H)
		error(exNilref);
	p->p = checkIPint(pk->p);
	p->alpha = checkIPint(pk->alpha);
	p->key = checkIPint(pk->key);
}

static void
egsk2priv(EGpriv* p, Keyring_EGsk* sk)
{
	if(sk == H || sk->pk == H)
		error(exNilref);
	egpk2pub(&p->pub, sk->pk);
	p->secret = checkIPint(sk->secret);
}

static void
egpriv2sk(Keyring_EGsk* sk, EGpriv* p)
{
	Keyring_EGpk* pk;

	pk = sk->pk;
	pk->p = ipcopymp(p->pub.p);
	pk->alpha = ipcopymp(p->pub.alpha);
	pk->key = ipcopymp(p->pub.key);
	sk->secret = ipcopymp(p->secret);
}

void
EGsk_gen(void *fp)
{
	F_EGsk_gen *f;
	Keyring_EGsk *sk;
	EGpriv *p;
	void *v;

	f = fp;
	v = *f->ret;
	sk = newthing(TEGsk, 0);
	sk->pk = newthing(TEGpk, 0);
	*f->ret = sk;
	destroy(v);
	release();
	for(;;){
		p = eggen(f->nlen, f->nrep);
		if(mpsignif(p->pub.p) == f->nlen)
			break;
		egprivfree(p);
	}
	acquire();
	egpriv2sk(sk, p);
	egprivfree(p);
}

void
EGsk_sign(void *fp)
{
	F_EGsk_sign *f;
	Keyring_EGsig *sig;
	EGpriv p;
	mpint *m;
	EGsig *s;
	void *v;

	f = fp;
	v = *f->ret;
	sig = newthing(TEGsig, 0);
	*f->ret = sig;
	destroy(v);

	egsk2priv(&p, f->k);
	m = checkIPint(f->m);
	release();
	s = egsign(&p, m);
	acquire();
	sig->r = ipcopymp(s->r);
	sig->s = ipcopymp(s->s);
	egsigfree(s);
}

void
EGpk_verify(void *fp)
{
	F_EGpk_verify *f;
	EGpub p;
	EGsig sig;
	mpint *m;

	f = fp;
	*f->ret = 0;
	if(f->m == H || f->sig == H)
		return;
	egpk2pub(&p, f->k);
	sig.r = checkIPint(f->sig->r);
	sig.s = checkIPint(f->sig->s);
	m = checkIPint(f->m);
	release();
	*f->ret = egverify(&p, &sig, m) == 0;
	acquire();
}

static void
rsapk2pub(RSApub* p, Keyring_RSApk* pk)
{
	if(pk == H)
		error(exNilref);
	memset(p, 0, sizeof(*p));
	p->n = checkIPint(pk->n);
	p->ek = checkIPint(pk->ek);
}

static void
rsask2priv(RSApriv* p, Keyring_RSAsk* sk)
{
	if(sk == H || sk->pk == H)
		error(exNilref);
	rsapk2pub(&p->pub, sk->pk);
	p->dk = checkIPint(sk->dk);
	p->p = checkIPint(sk->p);
	p->q = checkIPint(sk->q);
	p->kp = checkIPint(sk->kp);
	p->kq = checkIPint(sk->kq);
	p->c2 = checkIPint(sk->c2);
}

static void
rsapriv2sk(Keyring_RSAsk* sk, RSApriv* p)
{
	Keyring_RSApk* pk;

	pk = sk->pk;
	pk->n = ipcopymp(p->pub.n);
	pk->ek = ipcopymp(p->pub.ek);
	sk->dk = ipcopymp(p->dk);
	sk->p = ipcopymp(p->p);
	sk->q = ipcopymp(p->q);
	sk->kp = ipcopymp(p->kp);
	sk->kq = ipcopymp(p->kq);
	sk->c2 = ipcopymp(p->c2);
}

void
RSApk_encrypt(void *fp)
{
	F_RSApk_encrypt *f;
	RSApub p;
	mpint *m, *o;
	void *v;

	f = fp;
	v = *f->ret;
	*f->ret = H;
	destroy(v);

	rsapk2pub(&p, f->k);
	m = checkIPint(f->m);
	release();
	o = rsaencrypt(&p, m, nil);
	acquire();
	*f->ret = newIPint(o);
}

void
RSAsk_gen(void *fp)
{
	F_RSAsk_gen *f;
	Keyring_RSAsk *sk;
	RSApriv *p;
	void *v;

	f = fp;
	v = *f->ret;
	sk = newthing(TRSAsk, 0);
	sk->pk = newthing(TRSApk, 0);
	*f->ret = sk;
	destroy(v);
	release();
	for(;;){
		p = rsagen(f->nlen, f->elen, f->nrep);
		if(mpsignif(p->pub.n) == f->nlen)
			break;
		rsaprivfree(p);
	}
	acquire();
	rsapriv2sk(sk, p);
	rsaprivfree(p);
}

void
RSAsk_fill(void *fp)
{
	F_RSAsk_fill *f;
	Keyring_RSAsk *sk;
	RSApriv *p;
	void *v;

	f = fp;
	v = *f->ret;
	sk = newthing(TRSAsk, 0);
	sk->pk = newthing(TRSApk, 0);
	*f->ret = sk;
	destroy(v);
	release();
	p = rsafill(checkIPint(f->n), checkIPint(f->e), checkIPint(f->d),
			checkIPint(f->p), checkIPint(f->q));
	acquire();
	if(p == nil) {
		*f->ret = H;
		destroy(sk);
	}else{
		rsapriv2sk(sk, p);
		rsaprivfree(p);
	}
}

void
RSAsk_decrypt(void *fp)
{
	F_RSAsk_decrypt *f;
	RSApriv p;
	mpint *m, *o;
	void *v;

	f = fp;
	v = *f->ret;
	*f->ret = H;
	destroy(v);

	rsask2priv(&p, f->k);
	m = checkIPint(f->m);
	release();
	o = rsadecrypt(&p, m, nil);
	acquire();
	*f->ret = newIPint(o);
}

void
RSAsk_sign(void *fp)
{
	F_RSAsk_sign *f;
	Keyring_RSAsig *sig;
	RSApriv p;
	mpint *m, *s;
	void *v;

	f = fp;
	v = *f->ret;
	sig = newthing(TRSAsig, 0);
	*f->ret = sig;
	destroy(v);

	rsask2priv(&p, f->k);
	m = checkIPint(f->m);
	release();
	s = rsadecrypt(&p, m, nil);
	acquire();
	sig->n = newIPint(s);
}

void
RSApk_verify(void *fp)
{
	F_RSApk_verify *f;
	RSApub p;
	mpint *sig, *m, *t;

	f = fp;
	*f->ret = 0;
	if(f->m == H || f->sig == H)
		return;
	rsapk2pub(&p, f->k);
	sig = checkIPint(f->sig->n);
	m = checkIPint(f->m);
	release();
	t = rsaencrypt(&p, sig, nil);
	*f->ret = mpcmp(t, m) == 0;
	mpfree(t);
	acquire();
}

void
Keyring_IPint_random(void *fp)
{
	F_IPint_random *f;
	mpint *b;
	void *v;

	f = fp;
	v = *f->ret;
	*f->ret = H;
	destroy(v);

	release();
	b = mprand(f->maxbits, genrandom, nil);
	acquire();
	*f->ret = newIPint(b);
}
