typedef struct Sys_Qid Sys_Qid;
typedef struct Sys_Dir Sys_Dir;
typedef struct Sys_FD Sys_FD;
typedef struct Sys_Connection Sys_Connection;
typedef struct Sys_FileIO Sys_FileIO;
typedef struct Draw_Chans Draw_Chans;
typedef struct Draw_Point Draw_Point;
typedef struct Draw_Rect Draw_Rect;
typedef struct Draw_Image Draw_Image;
typedef struct Draw_Display Draw_Display;
typedef struct Draw_Font Draw_Font;
typedef struct Draw_Screen Draw_Screen;
typedef struct Draw_Pointer Draw_Pointer;
typedef struct Draw_Context Draw_Context;
typedef struct Draw_Wmcontext Draw_Wmcontext;
typedef struct IPints_IPint IPints_IPint;
typedef struct Crypt_DigestState Crypt_DigestState;
typedef struct Crypt_AESstate Crypt_AESstate;
typedef struct Crypt_DESstate Crypt_DESstate;
typedef struct Crypt_IDEAstate Crypt_IDEAstate;
typedef struct Crypt_RC4state Crypt_RC4state;
typedef struct Crypt_BFstate Crypt_BFstate;
typedef struct Crypt_PK Crypt_PK;
typedef struct Crypt_SK Crypt_SK;
typedef struct Crypt_PKsig Crypt_PKsig;
typedef struct Loader_Inst Loader_Inst;
typedef struct Loader_Typedesc Loader_Typedesc;
typedef struct Loader_Link Loader_Link;
typedef struct Loader_Niladt Loader_Niladt;
struct Sys_Qid
{
	LONG	path;
	WORD	vers;
	WORD	qtype;
};
#define Sys_Qid_size 16
#define Sys_Qid_map {0}
struct Sys_Dir
{
	String*	name;
	String*	uid;
	String*	gid;
	String*	muid;
	Sys_Qid	qid;
	WORD	mode;
	WORD	atime;
	WORD	mtime;
	uchar	_pad44[4];
	LONG	length;
	WORD	dtype;
	WORD	dev;
};
#define Sys_Dir_size 64
#define Sys_Dir_map {0xf0,}
struct Sys_FD
{
	WORD	fd;
};
#define Sys_FD_size 4
#define Sys_FD_map {0}
struct Sys_Connection
{
	Sys_FD*	dfd;
	Sys_FD*	cfd;
	String*	dir;
};
#define Sys_Connection_size 12
#define Sys_Connection_map {0xe0,}
typedef struct{ Array* t0; String* t1; } Sys_Rread;
#define Sys_Rread_size 8
#define Sys_Rread_map {0xc0,}
typedef struct{ WORD t0; String* t1; } Sys_Rwrite;
#define Sys_Rwrite_size 8
#define Sys_Rwrite_map {0x40,}
struct Sys_FileIO
{
	Channel*	read;
	Channel*	write;
};
typedef struct{ WORD t0; WORD t1; WORD t2; Channel* t3; } Sys_FileIO_read;
#define Sys_FileIO_read_size 16
#define Sys_FileIO_read_map {0x10,}
typedef struct{ WORD t0; Array* t1; WORD t2; Channel* t3; } Sys_FileIO_write;
#define Sys_FileIO_write_size 16
#define Sys_FileIO_write_map {0x50,}
#define Sys_FileIO_size 8
#define Sys_FileIO_map {0xc0,}
struct Draw_Chans
{
	WORD	desc;
};
#define Draw_Chans_size 4
#define Draw_Chans_map {0}
struct Draw_Point
{
	WORD	x;
	WORD	y;
};
#define Draw_Point_size 8
#define Draw_Point_map {0}
struct Draw_Rect
{
	Draw_Point	min;
	Draw_Point	max;
};
#define Draw_Rect_size 16
#define Draw_Rect_map {0}
struct Draw_Image
{
	Draw_Rect	r;
	Draw_Rect	clipr;
	WORD	depth;
	Draw_Chans	chans;
	WORD	repl;
	Draw_Display*	display;
	Draw_Screen*	screen;
	String*	iname;
};
#define Draw_Image_size 56
#define Draw_Image_map {0x0,0x1c,}
struct Draw_Display
{
	Draw_Image*	image;
	Draw_Image*	white;
	Draw_Image*	black;
	Draw_Image*	opaque;
	Draw_Image*	transparent;
};
#define Draw_Display_size 20
#define Draw_Display_map {0xf8,}
struct Draw_Font
{
	String*	name;
	WORD	height;
	WORD	ascent;
	Draw_Display*	display;
};
#define Draw_Font_size 16
#define Draw_Font_map {0x90,}
struct Draw_Screen
{
	WORD	id;
	Draw_Image*	image;
	Draw_Image*	fill;
	Draw_Display*	display;
};
#define Draw_Screen_size 16
#define Draw_Screen_map {0x70,}
struct Draw_Pointer
{
	WORD	buttons;
	Draw_Point	xy;
	WORD	msec;
};
#define Draw_Pointer_size 16
#define Draw_Pointer_map {0}
struct Draw_Context
{
	Draw_Display*	display;
	Draw_Screen*	screen;
	Channel*	wm;
};
typedef struct{ String* t0; Channel* t1; } Draw_Context_wm;
#define Draw_Context_wm_size 8
#define Draw_Context_wm_map {0xc0,}
#define Draw_Context_size 12
#define Draw_Context_map {0xe0,}
struct Draw_Wmcontext
{
	Channel*	kbd;
	Channel*	ptr;
	Channel*	ctl;
	Channel*	wctl;
	Channel*	images;
	Sys_FD*	connfd;
	Draw_Context*	ctxt;
};
typedef WORD Draw_Wmcontext_kbd;
#define Draw_Wmcontext_kbd_size 4
#define Draw_Wmcontext_kbd_map {0}
typedef Draw_Pointer* Draw_Wmcontext_ptr;
#define Draw_Wmcontext_ptr_size 4
#define Draw_Wmcontext_ptr_map {0x80,}
typedef String* Draw_Wmcontext_ctl;
#define Draw_Wmcontext_ctl_size 4
#define Draw_Wmcontext_ctl_map {0x80,}
typedef String* Draw_Wmcontext_wctl;
#define Draw_Wmcontext_wctl_size 4
#define Draw_Wmcontext_wctl_map {0x80,}
typedef Draw_Image* Draw_Wmcontext_images;
#define Draw_Wmcontext_images_size 4
#define Draw_Wmcontext_images_map {0x80,}
#define Draw_Wmcontext_size 28
#define Draw_Wmcontext_map {0xfe,}
struct IPints_IPint
{
	WORD	x;
};
#define IPints_IPint_size 4
#define IPints_IPint_map {0}
struct Crypt_DigestState
{
	WORD	x;
};
#define Crypt_DigestState_size 4
#define Crypt_DigestState_map {0}
struct Crypt_AESstate
{
	WORD	x;
};
#define Crypt_AESstate_size 4
#define Crypt_AESstate_map {0}
struct Crypt_DESstate
{
	WORD	x;
};
#define Crypt_DESstate_size 4
#define Crypt_DESstate_map {0}
struct Crypt_IDEAstate
{
	WORD	x;
};
#define Crypt_IDEAstate_size 4
#define Crypt_IDEAstate_map {0}
struct Crypt_RC4state
{
	WORD	x;
};
#define Crypt_RC4state_size 4
#define Crypt_RC4state_map {0}
struct Crypt_BFstate
{
	WORD	x;
};
#define Crypt_BFstate_size 4
#define Crypt_BFstate_map {0}
#define Crypt_PK_RSA 0
#define Crypt_PK_Elgamal 1
#define Crypt_PK_DSA 2
struct Crypt_PK
{
	int	pick;
	union{
		struct{
			IPints_IPint*	n;
			IPints_IPint*	ek;
		} RSA;
		struct{
			IPints_IPint*	p;
			IPints_IPint*	alpha;
			IPints_IPint*	key;
		} Elgamal;
		struct{
			IPints_IPint*	p;
			IPints_IPint*	q;
			IPints_IPint*	alpha;
			IPints_IPint*	key;
		} DSA;
	} u;
};
#define Crypt_PK_RSA_size 12
#define Crypt_PK_RSA_map {0x60,}
#define Crypt_PK_Elgamal_size 16
#define Crypt_PK_Elgamal_map {0x70,}
#define Crypt_PK_DSA_size 20
#define Crypt_PK_DSA_map {0x78,}
#define Crypt_SK_RSA 0
#define Crypt_SK_Elgamal 1
#define Crypt_SK_DSA 2
struct Crypt_SK
{
	int	pick;
	union{
		struct{
			Crypt_PK*	pk;
			IPints_IPint*	dk;
			IPints_IPint*	p;
			IPints_IPint*	q;
			IPints_IPint*	kp;
			IPints_IPint*	kq;
			IPints_IPint*	c2;
		} RSA;
		struct{
			Crypt_PK*	pk;
			IPints_IPint*	secret;
		} Elgamal;
		struct{
			Crypt_PK*	pk;
			IPints_IPint*	secret;
		} DSA;
	} u;
};
#define Crypt_SK_RSA_size 32
#define Crypt_SK_RSA_map {0x7f,}
#define Crypt_SK_Elgamal_size 12
#define Crypt_SK_Elgamal_map {0x60,}
#define Crypt_SK_DSA_size 12
#define Crypt_SK_DSA_map {0x60,}
#define Crypt_PKsig_RSA 0
#define Crypt_PKsig_Elgamal 1
#define Crypt_PKsig_DSA 2
struct Crypt_PKsig
{
	int	pick;
	union{
		struct{
			IPints_IPint*	n;
		} RSA;
		struct{
			IPints_IPint*	r;
			IPints_IPint*	s;
		} Elgamal;
		struct{
			IPints_IPint*	r;
			IPints_IPint*	s;
		} DSA;
	} u;
};
#define Crypt_PKsig_RSA_size 8
#define Crypt_PKsig_RSA_map {0x40,}
#define Crypt_PKsig_Elgamal_size 12
#define Crypt_PKsig_Elgamal_map {0x60,}
#define Crypt_PKsig_DSA_size 12
#define Crypt_PKsig_DSA_map {0x60,}
struct Loader_Inst
{
	BYTE	op;
	BYTE	addr;
	uchar	_pad2[2];
	WORD	src;
	WORD	mid;
	WORD	dst;
};
#define Loader_Inst_size 16
#define Loader_Inst_map {0}
struct Loader_Typedesc
{
	WORD	size;
	Array*	map;
};
#define Loader_Typedesc_size 8
#define Loader_Typedesc_map {0x40,}
struct Loader_Link
{
	String*	name;
	WORD	sig;
	WORD	pc;
	WORD	tdesc;
};
#define Loader_Link_size 16
#define Loader_Link_map {0x80,}
struct Loader_Niladt
{
	char	dummy[1];
	uchar	_pad1[3];
};
#define Loader_Niladt_size 4
#define Loader_Niladt_map {0}
void Sys_announce(void*);
typedef struct F_Sys_announce F_Sys_announce;
struct F_Sys_announce
{
	WORD	regs[NREG-1];
	struct{ WORD t0; Sys_Connection t1; }*	ret;
	uchar	temps[12];
	String*	addr;
};
void Sys_aprint(void*);
typedef struct F_Sys_aprint F_Sys_aprint;
struct F_Sys_aprint
{
	WORD	regs[NREG-1];
	Array**	ret;
	uchar	temps[12];
	String*	s;
	WORD	vargs;
};
void Sys_bind(void*);
typedef struct F_Sys_bind F_Sys_bind;
struct F_Sys_bind
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	String*	s;
	String*	on;
	WORD	flags;
};
void Sys_byte2char(void*);
typedef struct F_Sys_byte2char F_Sys_byte2char;
struct F_Sys_byte2char
{
	WORD	regs[NREG-1];
	struct{ WORD t0; WORD t1; WORD t2; }*	ret;
	uchar	temps[12];
	Array*	buf;
	WORD	n;
};
void Sys_char2byte(void*);
typedef struct F_Sys_char2byte F_Sys_char2byte;
struct F_Sys_char2byte
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	WORD	c;
	Array*	buf;
	WORD	n;
};
void Sys_chdir(void*);
typedef struct F_Sys_chdir F_Sys_chdir;
struct F_Sys_chdir
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	String*	path;
};
void Sys_create(void*);
typedef struct F_Sys_create F_Sys_create;
struct F_Sys_create
{
	WORD	regs[NREG-1];
	Sys_FD**	ret;
	uchar	temps[12];
	String*	s;
	WORD	mode;
	WORD	perm;
};
void Sys_dial(void*);
typedef struct F_Sys_dial F_Sys_dial;
struct F_Sys_dial
{
	WORD	regs[NREG-1];
	struct{ WORD t0; Sys_Connection t1; }*	ret;
	uchar	temps[12];
	String*	addr;
	String*	local;
};
void Sys_dirread(void*);
typedef struct F_Sys_dirread F_Sys_dirread;
struct F_Sys_dirread
{
	WORD	regs[NREG-1];
	struct{ WORD t0; Array* t1; }*	ret;
	uchar	temps[12];
	Sys_FD*	fd;
};
void Sys_dup(void*);
typedef struct F_Sys_dup F_Sys_dup;
struct F_Sys_dup
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	WORD	old;
	WORD	new;
};
void Sys_export(void*);
typedef struct F_Sys_export F_Sys_export;
struct F_Sys_export
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Sys_FD*	c;
	String*	dir;
	WORD	flag;
};
void Sys_fauth(void*);
typedef struct F_Sys_fauth F_Sys_fauth;
struct F_Sys_fauth
{
	WORD	regs[NREG-1];
	Sys_FD**	ret;
	uchar	temps[12];
	Sys_FD*	fd;
	String*	aname;
};
void Sys_fd2path(void*);
typedef struct F_Sys_fd2path F_Sys_fd2path;
struct F_Sys_fd2path
{
	WORD	regs[NREG-1];
	String**	ret;
	uchar	temps[12];
	Sys_FD*	fd;
};
void Sys_fildes(void*);
typedef struct F_Sys_fildes F_Sys_fildes;
struct F_Sys_fildes
{
	WORD	regs[NREG-1];
	Sys_FD**	ret;
	uchar	temps[12];
	WORD	fd;
};
void Sys_file2chan(void*);
typedef struct F_Sys_file2chan F_Sys_file2chan;
struct F_Sys_file2chan
{
	WORD	regs[NREG-1];
	Sys_FileIO**	ret;
	uchar	temps[12];
	String*	dir;
	String*	file;
};
void Sys_fprint(void*);
typedef struct F_Sys_fprint F_Sys_fprint;
struct F_Sys_fprint
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Sys_FD*	fd;
	String*	s;
	WORD	vargs;
};
void Sys_fstat(void*);
typedef struct F_Sys_fstat F_Sys_fstat;
struct F_Sys_fstat
{
	WORD	regs[NREG-1];
	struct{ WORD t0; uchar	_pad4[4]; Sys_Dir t1; }*	ret;
	uchar	temps[12];
	Sys_FD*	fd;
};
void Sys_fversion(void*);
typedef struct F_Sys_fversion F_Sys_fversion;
struct F_Sys_fversion
{
	WORD	regs[NREG-1];
	struct{ WORD t0; String* t1; }*	ret;
	uchar	temps[12];
	Sys_FD*	fd;
	WORD	msize;
	String*	version;
};
void Sys_fwstat(void*);
typedef struct F_Sys_fwstat F_Sys_fwstat;
struct F_Sys_fwstat
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Sys_FD*	fd;
	uchar	_pad36[4];
	Sys_Dir	d;
};
void Sys_iounit(void*);
typedef struct F_Sys_iounit F_Sys_iounit;
struct F_Sys_iounit
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Sys_FD*	fd;
};
void Sys_listen(void*);
typedef struct F_Sys_listen F_Sys_listen;
struct F_Sys_listen
{
	WORD	regs[NREG-1];
	struct{ WORD t0; Sys_Connection t1; }*	ret;
	uchar	temps[12];
	Sys_Connection	c;
};
void Sys_millisec(void*);
typedef struct F_Sys_millisec F_Sys_millisec;
struct F_Sys_millisec
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
};
void Sys_mount(void*);
typedef struct F_Sys_mount F_Sys_mount;
struct F_Sys_mount
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Sys_FD*	fd;
	Sys_FD*	afd;
	String*	on;
	WORD	flags;
	String*	spec;
};
void Sys_open(void*);
typedef struct F_Sys_open F_Sys_open;
struct F_Sys_open
{
	WORD	regs[NREG-1];
	Sys_FD**	ret;
	uchar	temps[12];
	String*	s;
	WORD	mode;
};
void Sys_pctl(void*);
typedef struct F_Sys_pctl F_Sys_pctl;
struct F_Sys_pctl
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	WORD	flags;
	List*	movefd;
};
void Sys_pipe(void*);
typedef struct F_Sys_pipe F_Sys_pipe;
struct F_Sys_pipe
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Array*	fds;
};
void Sys_pread(void*);
typedef struct F_Sys_pread F_Sys_pread;
struct F_Sys_pread
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Sys_FD*	fd;
	Array*	buf;
	WORD	n;
	uchar	_pad44[4];
	LONG	off;
};
void Sys_print(void*);
typedef struct F_Sys_print F_Sys_print;
struct F_Sys_print
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	String*	s;
	WORD	vargs;
};
void Sys_pwrite(void*);
typedef struct F_Sys_pwrite F_Sys_pwrite;
struct F_Sys_pwrite
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Sys_FD*	fd;
	Array*	buf;
	WORD	n;
	uchar	_pad44[4];
	LONG	off;
};
void Sys_read(void*);
typedef struct F_Sys_read F_Sys_read;
struct F_Sys_read
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Sys_FD*	fd;
	Array*	buf;
	WORD	n;
};
void Sys_readn(void*);
typedef struct F_Sys_readn F_Sys_readn;
struct F_Sys_readn
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Sys_FD*	fd;
	Array*	buf;
	WORD	n;
};
void Sys_remove(void*);
typedef struct F_Sys_remove F_Sys_remove;
struct F_Sys_remove
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	String*	s;
};
void Sys_seek(void*);
typedef struct F_Sys_seek F_Sys_seek;
struct F_Sys_seek
{
	WORD	regs[NREG-1];
	LONG*	ret;
	uchar	temps[12];
	Sys_FD*	fd;
	uchar	_pad36[4];
	LONG	off;
	WORD	start;
};
void Sys_sleep(void*);
typedef struct F_Sys_sleep F_Sys_sleep;
struct F_Sys_sleep
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	WORD	period;
};
void Sys_sprint(void*);
typedef struct F_Sys_sprint F_Sys_sprint;
struct F_Sys_sprint
{
	WORD	regs[NREG-1];
	String**	ret;
	uchar	temps[12];
	String*	s;
	WORD	vargs;
};
void Sys_stat(void*);
typedef struct F_Sys_stat F_Sys_stat;
struct F_Sys_stat
{
	WORD	regs[NREG-1];
	struct{ WORD t0; uchar	_pad4[4]; Sys_Dir t1; }*	ret;
	uchar	temps[12];
	String*	s;
};
void Sys_stream(void*);
typedef struct F_Sys_stream F_Sys_stream;
struct F_Sys_stream
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Sys_FD*	src;
	Sys_FD*	dst;
	WORD	bufsiz;
};
void Sys_tokenize(void*);
typedef struct F_Sys_tokenize F_Sys_tokenize;
struct F_Sys_tokenize
{
	WORD	regs[NREG-1];
	struct{ WORD t0; List* t1; }*	ret;
	uchar	temps[12];
	String*	s;
	String*	delim;
};
void Sys_unmount(void*);
typedef struct F_Sys_unmount F_Sys_unmount;
struct F_Sys_unmount
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	String*	s1;
	String*	s2;
};
void Sys_utfbytes(void*);
typedef struct F_Sys_utfbytes F_Sys_utfbytes;
struct F_Sys_utfbytes
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Array*	buf;
	WORD	n;
};
void Sys_werrstr(void*);
typedef struct F_Sys_werrstr F_Sys_werrstr;
struct F_Sys_werrstr
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	String*	s;
};
void Sys_write(void*);
typedef struct F_Sys_write F_Sys_write;
struct F_Sys_write
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Sys_FD*	fd;
	Array*	buf;
	WORD	n;
};
void Sys_wstat(void*);
typedef struct F_Sys_wstat F_Sys_wstat;
struct F_Sys_wstat
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	String*	s;
	uchar	_pad36[4];
	Sys_Dir	d;
};
#define Sys_PATH "$Sys"
#define Sys_Maxint 2147483647
#define Sys_QTDIR 128
#define Sys_QTAPPEND 64
#define Sys_QTEXCL 32
#define Sys_QTAUTH 8
#define Sys_QTTMP 4
#define Sys_QTFILE 0
#define Sys_ATOMICIO 8192
#define Sys_SEEKSTART 0
#define Sys_SEEKRELA 1
#define Sys_SEEKEND 2
#define Sys_NAMEMAX 256
#define Sys_ERRMAX 128
#define Sys_WAITLEN 192
#define Sys_OREAD 0
#define Sys_OWRITE 1
#define Sys_ORDWR 2
#define Sys_OTRUNC 16
#define Sys_ORCLOSE 64
#define Sys_OEXCL 4096
#define Sys_DMDIR -2147483648
#define Sys_DMAPPEND 1073741824
#define Sys_DMEXCL 536870912
#define Sys_DMAUTH 134217728
#define Sys_DMTMP 67108864
#define Sys_MREPL 0
#define Sys_MBEFORE 1
#define Sys_MAFTER 2
#define Sys_MCREATE 4
#define Sys_MCACHE 16
#define Sys_NEWFD 1
#define Sys_FORKFD 2
#define Sys_NEWNS 4
#define Sys_FORKNS 8
#define Sys_NEWPGRP 16
#define Sys_NODEVS 32
#define Sys_NEWENV 64
#define Sys_FORKENV 128
#define Sys_EXPWAIT 0
#define Sys_EXPASYNC 1
#define Sys_UTFmax 3
#define Sys_UTFerror 128
void Rect_Xrect(void*);
typedef struct F_Rect_Xrect F_Rect_Xrect;
struct F_Rect_Xrect
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Rect	r;
	Draw_Rect	s;
};
void Point_add(void*);
typedef struct F_Point_add F_Point_add;
struct F_Point_add
{
	WORD	regs[NREG-1];
	Draw_Point*	ret;
	uchar	temps[12];
	Draw_Point	p;
	Draw_Point	q;
};
void Rect_addpt(void*);
typedef struct F_Rect_addpt F_Rect_addpt;
struct F_Rect_addpt
{
	WORD	regs[NREG-1];
	Draw_Rect*	ret;
	uchar	temps[12];
	Draw_Rect	r;
	Draw_Point	p;
};
void Display_allocate(void*);
typedef struct F_Display_allocate F_Display_allocate;
struct F_Display_allocate
{
	WORD	regs[NREG-1];
	Draw_Display**	ret;
	uchar	temps[12];
	String*	dev;
};
void Screen_allocate(void*);
typedef struct F_Screen_allocate F_Screen_allocate;
struct F_Screen_allocate
{
	WORD	regs[NREG-1];
	Draw_Screen**	ret;
	uchar	temps[12];
	Draw_Image*	image;
	Draw_Image*	fill;
	WORD	public;
};
void Image_arc(void*);
typedef struct F_Image_arc F_Image_arc;
struct F_Image_arc
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	c;
	WORD	a;
	WORD	b;
	WORD	thick;
	Draw_Image*	src;
	Draw_Point	sp;
	WORD	alpha;
	WORD	phi;
};
void Image_arcop(void*);
typedef struct F_Image_arcop F_Image_arcop;
struct F_Image_arcop
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	c;
	WORD	a;
	WORD	b;
	WORD	thick;
	Draw_Image*	src;
	Draw_Point	sp;
	WORD	alpha;
	WORD	phi;
	WORD	op;
};
void Image_arrow(void*);
typedef struct F_Image_arrow F_Image_arrow;
struct F_Image_arrow
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	WORD	a;
	WORD	b;
	WORD	c;
};
void Font_bbox(void*);
typedef struct F_Font_bbox F_Font_bbox;
struct F_Font_bbox
{
	WORD	regs[NREG-1];
	Draw_Rect*	ret;
	uchar	temps[12];
	Draw_Font*	f;
	String*	str;
};
void Image_bezier(void*);
typedef struct F_Image_bezier F_Image_bezier;
struct F_Image_bezier
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	a;
	Draw_Point	b;
	Draw_Point	c;
	Draw_Point	d;
	WORD	end0;
	WORD	end1;
	WORD	radius;
	Draw_Image*	src;
	Draw_Point	sp;
};
void Image_bezierop(void*);
typedef struct F_Image_bezierop F_Image_bezierop;
struct F_Image_bezierop
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	a;
	Draw_Point	b;
	Draw_Point	c;
	Draw_Point	d;
	WORD	end0;
	WORD	end1;
	WORD	radius;
	Draw_Image*	src;
	Draw_Point	sp;
	WORD	op;
};
void Image_bezspline(void*);
typedef struct F_Image_bezspline F_Image_bezspline;
struct F_Image_bezspline
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Array*	p;
	WORD	end0;
	WORD	end1;
	WORD	radius;
	Draw_Image*	src;
	Draw_Point	sp;
};
void Image_bezsplineop(void*);
typedef struct F_Image_bezsplineop F_Image_bezsplineop;
struct F_Image_bezsplineop
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Array*	p;
	WORD	end0;
	WORD	end1;
	WORD	radius;
	Draw_Image*	src;
	Draw_Point	sp;
	WORD	op;
};
void Image_border(void*);
typedef struct F_Image_border F_Image_border;
struct F_Image_border
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Rect	r;
	WORD	i;
	Draw_Image*	src;
	Draw_Point	sp;
};
void Image_bottom(void*);
typedef struct F_Image_bottom F_Image_bottom;
struct F_Image_bottom
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	win;
};
void Screen_bottom(void*);
typedef struct F_Screen_bottom F_Screen_bottom;
struct F_Screen_bottom
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Screen*	screen;
	Array*	wins;
};
void Font_build(void*);
typedef struct F_Font_build F_Font_build;
struct F_Font_build
{
	WORD	regs[NREG-1];
	Draw_Font**	ret;
	uchar	temps[12];
	Draw_Display*	d;
	String*	name;
	String*	desc;
};
void Draw_bytesperline(void*);
typedef struct F_Draw_bytesperline F_Draw_bytesperline;
struct F_Draw_bytesperline
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Rect	r;
	WORD	d;
};
void Rect_canon(void*);
typedef struct F_Rect_canon F_Rect_canon;
struct F_Rect_canon
{
	WORD	regs[NREG-1];
	Draw_Rect*	ret;
	uchar	temps[12];
	Draw_Rect	r;
};
void Rect_clip(void*);
typedef struct F_Rect_clip F_Rect_clip;
struct F_Rect_clip
{
	WORD	regs[NREG-1];
	struct{ Draw_Rect t0; WORD t1; }*	ret;
	uchar	temps[12];
	Draw_Rect	r;
	Draw_Rect	s;
};
void Display_cmap2rgb(void*);
typedef struct F_Display_cmap2rgb F_Display_cmap2rgb;
struct F_Display_cmap2rgb
{
	WORD	regs[NREG-1];
	struct{ WORD t0; WORD t1; WORD t2; }*	ret;
	uchar	temps[12];
	Draw_Display*	d;
	WORD	c;
};
void Display_cmap2rgba(void*);
typedef struct F_Display_cmap2rgba F_Display_cmap2rgba;
struct F_Display_cmap2rgba
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Display*	d;
	WORD	c;
};
void Display_color(void*);
typedef struct F_Display_color F_Display_color;
struct F_Display_color
{
	WORD	regs[NREG-1];
	Draw_Image**	ret;
	uchar	temps[12];
	Draw_Display*	d;
	WORD	color;
};
void Display_colormix(void*);
typedef struct F_Display_colormix F_Display_colormix;
struct F_Display_colormix
{
	WORD	regs[NREG-1];
	Draw_Image**	ret;
	uchar	temps[12];
	Draw_Display*	d;
	WORD	c1;
	WORD	c2;
};
void Rect_combine(void*);
typedef struct F_Rect_combine F_Rect_combine;
struct F_Rect_combine
{
	WORD	regs[NREG-1];
	Draw_Rect*	ret;
	uchar	temps[12];
	Draw_Rect	r;
	Draw_Rect	s;
};
void Rect_contains(void*);
typedef struct F_Rect_contains F_Rect_contains;
struct F_Rect_contains
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Rect	r;
	Draw_Point	p;
};
void Chans_depth(void*);
typedef struct F_Chans_depth F_Chans_depth;
struct F_Chans_depth
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Chans	c;
};
void Point_div(void*);
typedef struct F_Point_div F_Point_div;
struct F_Point_div
{
	WORD	regs[NREG-1];
	Draw_Point*	ret;
	uchar	temps[12];
	Draw_Point	p;
	WORD	i;
};
void Image_draw(void*);
typedef struct F_Image_draw F_Image_draw;
struct F_Image_draw
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Rect	r;
	Draw_Image*	src;
	Draw_Image*	matte;
	Draw_Point	p;
};
void Image_drawop(void*);
typedef struct F_Image_drawop F_Image_drawop;
struct F_Image_drawop
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Rect	r;
	Draw_Image*	src;
	Draw_Image*	matte;
	Draw_Point	p;
	WORD	op;
};
void Rect_dx(void*);
typedef struct F_Rect_dx F_Rect_dx;
struct F_Rect_dx
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Rect	r;
};
void Rect_dy(void*);
typedef struct F_Rect_dy F_Rect_dy;
struct F_Rect_dy
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Rect	r;
};
void Image_ellipse(void*);
typedef struct F_Image_ellipse F_Image_ellipse;
struct F_Image_ellipse
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	c;
	WORD	a;
	WORD	b;
	WORD	thick;
	Draw_Image*	src;
	Draw_Point	sp;
};
void Image_ellipseop(void*);
typedef struct F_Image_ellipseop F_Image_ellipseop;
struct F_Image_ellipseop
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	c;
	WORD	a;
	WORD	b;
	WORD	thick;
	Draw_Image*	src;
	Draw_Point	sp;
	WORD	op;
};
void Chans_eq(void*);
typedef struct F_Chans_eq F_Chans_eq;
struct F_Chans_eq
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Chans	c;
	Draw_Chans	d;
};
void Point_eq(void*);
typedef struct F_Point_eq F_Point_eq;
struct F_Point_eq
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Point	p;
	Draw_Point	q;
};
void Rect_eq(void*);
typedef struct F_Rect_eq F_Rect_eq;
struct F_Rect_eq
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Rect	r;
	Draw_Rect	s;
};
void Image_fillarc(void*);
typedef struct F_Image_fillarc F_Image_fillarc;
struct F_Image_fillarc
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	c;
	WORD	a;
	WORD	b;
	Draw_Image*	src;
	Draw_Point	sp;
	WORD	alpha;
	WORD	phi;
};
void Image_fillarcop(void*);
typedef struct F_Image_fillarcop F_Image_fillarcop;
struct F_Image_fillarcop
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	c;
	WORD	a;
	WORD	b;
	Draw_Image*	src;
	Draw_Point	sp;
	WORD	alpha;
	WORD	phi;
	WORD	op;
};
void Image_fillbezier(void*);
typedef struct F_Image_fillbezier F_Image_fillbezier;
struct F_Image_fillbezier
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	a;
	Draw_Point	b;
	Draw_Point	c;
	Draw_Point	d;
	WORD	wind;
	Draw_Image*	src;
	Draw_Point	sp;
};
void Image_fillbezierop(void*);
typedef struct F_Image_fillbezierop F_Image_fillbezierop;
struct F_Image_fillbezierop
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	a;
	Draw_Point	b;
	Draw_Point	c;
	Draw_Point	d;
	WORD	wind;
	Draw_Image*	src;
	Draw_Point	sp;
	WORD	op;
};
void Image_fillbezspline(void*);
typedef struct F_Image_fillbezspline F_Image_fillbezspline;
struct F_Image_fillbezspline
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Array*	p;
	WORD	wind;
	Draw_Image*	src;
	Draw_Point	sp;
};
void Image_fillbezsplineop(void*);
typedef struct F_Image_fillbezsplineop F_Image_fillbezsplineop;
struct F_Image_fillbezsplineop
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Array*	p;
	WORD	wind;
	Draw_Image*	src;
	Draw_Point	sp;
	WORD	op;
};
void Image_fillellipse(void*);
typedef struct F_Image_fillellipse F_Image_fillellipse;
struct F_Image_fillellipse
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	c;
	WORD	a;
	WORD	b;
	Draw_Image*	src;
	Draw_Point	sp;
};
void Image_fillellipseop(void*);
typedef struct F_Image_fillellipseop F_Image_fillellipseop;
struct F_Image_fillellipseop
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	c;
	WORD	a;
	WORD	b;
	Draw_Image*	src;
	Draw_Point	sp;
	WORD	op;
};
void Image_fillpoly(void*);
typedef struct F_Image_fillpoly F_Image_fillpoly;
struct F_Image_fillpoly
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Array*	p;
	WORD	wind;
	Draw_Image*	src;
	Draw_Point	sp;
};
void Image_fillpolyop(void*);
typedef struct F_Image_fillpolyop F_Image_fillpolyop;
struct F_Image_fillpolyop
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Array*	p;
	WORD	wind;
	Draw_Image*	src;
	Draw_Point	sp;
	WORD	op;
};
void Image_flush(void*);
typedef struct F_Image_flush F_Image_flush;
struct F_Image_flush
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	win;
	WORD	func;
};
void Image_gendraw(void*);
typedef struct F_Image_gendraw F_Image_gendraw;
struct F_Image_gendraw
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Rect	r;
	Draw_Image*	src;
	Draw_Point	p0;
	Draw_Image*	matte;
	Draw_Point	p1;
};
void Image_gendrawop(void*);
typedef struct F_Image_gendrawop F_Image_gendrawop;
struct F_Image_gendrawop
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Rect	r;
	Draw_Image*	src;
	Draw_Point	p0;
	Draw_Image*	matte;
	Draw_Point	p1;
	WORD	op;
};
void Display_getwindow(void*);
typedef struct F_Display_getwindow F_Display_getwindow;
struct F_Display_getwindow
{
	WORD	regs[NREG-1];
	struct{ Draw_Screen* t0; Draw_Image* t1; }*	ret;
	uchar	temps[12];
	Draw_Display*	d;
	String*	winname;
	Draw_Screen*	screen;
	Draw_Image*	image;
	WORD	backup;
};
void Draw_icossin(void*);
typedef struct F_Draw_icossin F_Draw_icossin;
struct F_Draw_icossin
{
	WORD	regs[NREG-1];
	struct{ WORD t0; WORD t1; }*	ret;
	uchar	temps[12];
	WORD	deg;
};
void Draw_icossin2(void*);
typedef struct F_Draw_icossin2 F_Draw_icossin2;
struct F_Draw_icossin2
{
	WORD	regs[NREG-1];
	struct{ WORD t0; WORD t1; }*	ret;
	uchar	temps[12];
	Draw_Point	p;
};
void Point_in(void*);
typedef struct F_Point_in F_Point_in;
struct F_Point_in
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Point	p;
	Draw_Rect	r;
};
void Rect_inrect(void*);
typedef struct F_Rect_inrect F_Rect_inrect;
struct F_Rect_inrect
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Rect	r;
	Draw_Rect	s;
};
void Rect_inset(void*);
typedef struct F_Rect_inset F_Rect_inset;
struct F_Rect_inset
{
	WORD	regs[NREG-1];
	Draw_Rect*	ret;
	uchar	temps[12];
	Draw_Rect	r;
	WORD	n;
};
void Image_line(void*);
typedef struct F_Image_line F_Image_line;
struct F_Image_line
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	p0;
	Draw_Point	p1;
	WORD	end0;
	WORD	end1;
	WORD	radius;
	Draw_Image*	src;
	Draw_Point	sp;
};
void Image_lineop(void*);
typedef struct F_Image_lineop F_Image_lineop;
struct F_Image_lineop
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	p0;
	Draw_Point	p1;
	WORD	end0;
	WORD	end1;
	WORD	radius;
	Draw_Image*	src;
	Draw_Point	sp;
	WORD	op;
};
void Chans_mk(void*);
typedef struct F_Chans_mk F_Chans_mk;
struct F_Chans_mk
{
	WORD	regs[NREG-1];
	Draw_Chans*	ret;
	uchar	temps[12];
	String*	s;
};
void Point_mul(void*);
typedef struct F_Point_mul F_Point_mul;
struct F_Point_mul
{
	WORD	regs[NREG-1];
	Draw_Point*	ret;
	uchar	temps[12];
	Draw_Point	p;
	WORD	i;
};
void Image_name(void*);
typedef struct F_Image_name F_Image_name;
struct F_Image_name
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Image*	src;
	String*	name;
	WORD	in;
};
void Display_namedimage(void*);
typedef struct F_Display_namedimage F_Display_namedimage;
struct F_Display_namedimage
{
	WORD	regs[NREG-1];
	Draw_Image**	ret;
	uchar	temps[12];
	Draw_Display*	d;
	String*	name;
};
void Display_newimage(void*);
typedef struct F_Display_newimage F_Display_newimage;
struct F_Display_newimage
{
	WORD	regs[NREG-1];
	Draw_Image**	ret;
	uchar	temps[12];
	Draw_Display*	d;
	Draw_Rect	r;
	Draw_Chans	chans;
	WORD	repl;
	WORD	color;
};
void Screen_newwindow(void*);
typedef struct F_Screen_newwindow F_Screen_newwindow;
struct F_Screen_newwindow
{
	WORD	regs[NREG-1];
	Draw_Image**	ret;
	uchar	temps[12];
	Draw_Screen*	screen;
	Draw_Rect	r;
	WORD	backing;
	WORD	color;
};
void Display_open(void*);
typedef struct F_Display_open F_Display_open;
struct F_Display_open
{
	WORD	regs[NREG-1];
	Draw_Image**	ret;
	uchar	temps[12];
	Draw_Display*	d;
	String*	name;
};
void Font_open(void*);
typedef struct F_Font_open F_Font_open;
struct F_Font_open
{
	WORD	regs[NREG-1];
	Draw_Font**	ret;
	uchar	temps[12];
	Draw_Display*	d;
	String*	name;
};
void Image_origin(void*);
typedef struct F_Image_origin F_Image_origin;
struct F_Image_origin
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Image*	win;
	Draw_Point	log;
	Draw_Point	scr;
};
void Image_poly(void*);
typedef struct F_Image_poly F_Image_poly;
struct F_Image_poly
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Array*	p;
	WORD	end0;
	WORD	end1;
	WORD	radius;
	Draw_Image*	src;
	Draw_Point	sp;
};
void Image_polyop(void*);
typedef struct F_Image_polyop F_Image_polyop;
struct F_Image_polyop
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	dst;
	Array*	p;
	WORD	end0;
	WORD	end1;
	WORD	radius;
	Draw_Image*	src;
	Draw_Point	sp;
	WORD	op;
};
void Display_publicscreen(void*);
typedef struct F_Display_publicscreen F_Display_publicscreen;
struct F_Display_publicscreen
{
	WORD	regs[NREG-1];
	Draw_Screen**	ret;
	uchar	temps[12];
	Draw_Display*	d;
	WORD	id;
};
void Display_readimage(void*);
typedef struct F_Display_readimage F_Display_readimage;
struct F_Display_readimage
{
	WORD	regs[NREG-1];
	Draw_Image**	ret;
	uchar	temps[12];
	Draw_Display*	d;
	Sys_FD*	fd;
};
void Image_readpixels(void*);
typedef struct F_Image_readpixels F_Image_readpixels;
struct F_Image_readpixels
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Image*	src;
	Draw_Rect	r;
	Array*	data;
};
void Display_rgb(void*);
typedef struct F_Display_rgb F_Display_rgb;
struct F_Display_rgb
{
	WORD	regs[NREG-1];
	Draw_Image**	ret;
	uchar	temps[12];
	Draw_Display*	d;
	WORD	r;
	WORD	g;
	WORD	b;
};
void Display_rgb2cmap(void*);
typedef struct F_Display_rgb2cmap F_Display_rgb2cmap;
struct F_Display_rgb2cmap
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Display*	d;
	WORD	r;
	WORD	g;
	WORD	b;
};
void Draw_setalpha(void*);
typedef struct F_Draw_setalpha F_Draw_setalpha;
struct F_Draw_setalpha
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	WORD	c;
	WORD	a;
};
void Rect_size(void*);
typedef struct F_Rect_size F_Rect_size;
struct F_Rect_size
{
	WORD	regs[NREG-1];
	Draw_Point*	ret;
	uchar	temps[12];
	Draw_Rect	r;
};
void Display_startrefresh(void*);
typedef struct F_Display_startrefresh F_Display_startrefresh;
struct F_Display_startrefresh
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Display*	d;
};
void Point_sub(void*);
typedef struct F_Point_sub F_Point_sub;
struct F_Point_sub
{
	WORD	regs[NREG-1];
	Draw_Point*	ret;
	uchar	temps[12];
	Draw_Point	p;
	Draw_Point	q;
};
void Rect_subpt(void*);
typedef struct F_Rect_subpt F_Rect_subpt;
struct F_Rect_subpt
{
	WORD	regs[NREG-1];
	Draw_Rect*	ret;
	uchar	temps[12];
	Draw_Rect	r;
	Draw_Point	p;
};
void Chans_text(void*);
typedef struct F_Chans_text F_Chans_text;
struct F_Chans_text
{
	WORD	regs[NREG-1];
	String**	ret;
	uchar	temps[12];
	Draw_Chans	c;
};
void Image_text(void*);
typedef struct F_Image_text F_Image_text;
struct F_Image_text
{
	WORD	regs[NREG-1];
	Draw_Point*	ret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	p;
	Draw_Image*	src;
	Draw_Point	sp;
	Draw_Font*	font;
	String*	str;
};
void Image_textbg(void*);
typedef struct F_Image_textbg F_Image_textbg;
struct F_Image_textbg
{
	WORD	regs[NREG-1];
	Draw_Point*	ret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	p;
	Draw_Image*	src;
	Draw_Point	sp;
	Draw_Font*	font;
	String*	str;
	Draw_Image*	bg;
	Draw_Point	bgp;
};
void Image_textbgop(void*);
typedef struct F_Image_textbgop F_Image_textbgop;
struct F_Image_textbgop
{
	WORD	regs[NREG-1];
	Draw_Point*	ret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	p;
	Draw_Image*	src;
	Draw_Point	sp;
	Draw_Font*	font;
	String*	str;
	Draw_Image*	bg;
	Draw_Point	bgp;
	WORD	op;
};
void Image_textop(void*);
typedef struct F_Image_textop F_Image_textop;
struct F_Image_textop
{
	WORD	regs[NREG-1];
	Draw_Point*	ret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Point	p;
	Draw_Image*	src;
	Draw_Point	sp;
	Draw_Font*	font;
	String*	str;
	WORD	op;
};
void Image_top(void*);
typedef struct F_Image_top F_Image_top;
struct F_Image_top
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Image*	win;
};
void Screen_top(void*);
typedef struct F_Screen_top F_Screen_top;
struct F_Screen_top
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Draw_Screen*	screen;
	Array*	wins;
};
void Font_width(void*);
typedef struct F_Font_width F_Font_width;
struct F_Font_width
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Font*	f;
	String*	str;
};
void Display_writeimage(void*);
typedef struct F_Display_writeimage F_Display_writeimage;
struct F_Display_writeimage
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Display*	d;
	Sys_FD*	fd;
	Draw_Image*	i;
};
void Image_writepixels(void*);
typedef struct F_Image_writepixels F_Image_writepixels;
struct F_Image_writepixels
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Draw_Image*	dst;
	Draw_Rect	r;
	Array*	data;
};
#define Draw_PATH "$Draw"
#define Draw_Opaque -1
#define Draw_Transparent 0
#define Draw_Black 255
#define Draw_White -1
#define Draw_Red -16776961
#define Draw_Green 16711935
#define Draw_Blue 65535
#define Draw_Cyan 16777215
#define Draw_Magenta -16711681
#define Draw_Yellow -65281
#define Draw_Grey -286331137
#define Draw_Paleyellow -21761
#define Draw_Darkyellow -286351617
#define Draw_Darkgreen 1149781247
#define Draw_Palegreen -1426085121
#define Draw_Medgreen -1999861505
#define Draw_Darkblue 22015
#define Draw_Palebluegreen -1426063361
#define Draw_Paleblue 48127
#define Draw_Bluegreen 8947967
#define Draw_Greygreen 1437248255
#define Draw_Palegreygreen -1628508417
#define Draw_Yellowgreen -1718006529
#define Draw_Medblue 39423
#define Draw_Greyblue 6142975
#define Draw_Palegreyblue 1234427391
#define Draw_Purpleblue -2004300545
#define Draw_Notacolor -256
#define Draw_Nofill -256
#define Draw_Endsquare 0
#define Draw_Enddisc 1
#define Draw_Endarrow 2
#define Draw_Flushoff 0
#define Draw_Flushon 1
#define Draw_Flushnow 2
#define Draw_Refbackup 0
#define Draw_Refnone 1
#define Draw_SinD 8
#define Draw_DinS 4
#define Draw_SoutD 2
#define Draw_DoutS 1
#define Draw_S 10
#define Draw_SoverD 11
#define Draw_SatopD 9
#define Draw_SxorD 3
#define Draw_D 5
#define Draw_DoverS 7
#define Draw_DatopS 6
#define Draw_DxorS 3
#define Draw_Clear 0
#define Draw_CRed 0
#define Draw_CGreen 1
#define Draw_CBlue 2
#define Draw_CGrey 3
#define Draw_CAlpha 4
#define Draw_CMap 5
#define Draw_CIgnore 6
void Math_FPcontrol(void*);
typedef struct F_Math_FPcontrol F_Math_FPcontrol;
struct F_Math_FPcontrol
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	WORD	r;
	WORD	mask;
};
void Math_FPstatus(void*);
typedef struct F_Math_FPstatus F_Math_FPstatus;
struct F_Math_FPstatus
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	WORD	r;
	WORD	mask;
};
void Math_acos(void*);
typedef struct F_Math_acos F_Math_acos;
struct F_Math_acos
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_acosh(void*);
typedef struct F_Math_acosh F_Math_acosh;
struct F_Math_acosh
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_asin(void*);
typedef struct F_Math_asin F_Math_asin;
struct F_Math_asin
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_asinh(void*);
typedef struct F_Math_asinh F_Math_asinh;
struct F_Math_asinh
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_atan(void*);
typedef struct F_Math_atan F_Math_atan;
struct F_Math_atan
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_atan2(void*);
typedef struct F_Math_atan2 F_Math_atan2;
struct F_Math_atan2
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	y;
	REAL	x;
};
void Math_atanh(void*);
typedef struct F_Math_atanh F_Math_atanh;
struct F_Math_atanh
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_bits32real(void*);
typedef struct F_Math_bits32real F_Math_bits32real;
struct F_Math_bits32real
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	WORD	b;
};
void Math_bits64real(void*);
typedef struct F_Math_bits64real F_Math_bits64real;
struct F_Math_bits64real
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	LONG	b;
};
void Math_cbrt(void*);
typedef struct F_Math_cbrt F_Math_cbrt;
struct F_Math_cbrt
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_ceil(void*);
typedef struct F_Math_ceil F_Math_ceil;
struct F_Math_ceil
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_copysign(void*);
typedef struct F_Math_copysign F_Math_copysign;
struct F_Math_copysign
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
	REAL	s;
};
void Math_cos(void*);
typedef struct F_Math_cos F_Math_cos;
struct F_Math_cos
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_cosh(void*);
typedef struct F_Math_cosh F_Math_cosh;
struct F_Math_cosh
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_dot(void*);
typedef struct F_Math_dot F_Math_dot;
struct F_Math_dot
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	Array*	x;
	Array*	y;
};
void Math_erf(void*);
typedef struct F_Math_erf F_Math_erf;
struct F_Math_erf
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_erfc(void*);
typedef struct F_Math_erfc F_Math_erfc;
struct F_Math_erfc
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_exp(void*);
typedef struct F_Math_exp F_Math_exp;
struct F_Math_exp
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_expm1(void*);
typedef struct F_Math_expm1 F_Math_expm1;
struct F_Math_expm1
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_export_int(void*);
typedef struct F_Math_export_int F_Math_export_int;
struct F_Math_export_int
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Array*	b;
	Array*	x;
};
void Math_export_real(void*);
typedef struct F_Math_export_real F_Math_export_real;
struct F_Math_export_real
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Array*	b;
	Array*	x;
};
void Math_export_real32(void*);
typedef struct F_Math_export_real32 F_Math_export_real32;
struct F_Math_export_real32
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Array*	b;
	Array*	x;
};
void Math_fabs(void*);
typedef struct F_Math_fabs F_Math_fabs;
struct F_Math_fabs
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_fdim(void*);
typedef struct F_Math_fdim F_Math_fdim;
struct F_Math_fdim
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
	REAL	y;
};
void Math_finite(void*);
typedef struct F_Math_finite F_Math_finite;
struct F_Math_finite
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_floor(void*);
typedef struct F_Math_floor F_Math_floor;
struct F_Math_floor
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_fmax(void*);
typedef struct F_Math_fmax F_Math_fmax;
struct F_Math_fmax
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
	REAL	y;
};
void Math_fmin(void*);
typedef struct F_Math_fmin F_Math_fmin;
struct F_Math_fmin
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
	REAL	y;
};
void Math_fmod(void*);
typedef struct F_Math_fmod F_Math_fmod;
struct F_Math_fmod
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
	REAL	y;
};
void Math_gemm(void*);
typedef struct F_Math_gemm F_Math_gemm;
struct F_Math_gemm
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	WORD	transa;
	WORD	transb;
	WORD	m;
	WORD	n;
	WORD	k;
	uchar	_pad52[4];
	REAL	alpha;
	Array*	a;
	WORD	lda;
	Array*	b;
	WORD	ldb;
	REAL	beta;
	Array*	c;
	WORD	ldc;
};
void Math_getFPcontrol(void*);
typedef struct F_Math_getFPcontrol F_Math_getFPcontrol;
struct F_Math_getFPcontrol
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
};
void Math_getFPstatus(void*);
typedef struct F_Math_getFPstatus F_Math_getFPstatus;
struct F_Math_getFPstatus
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
};
void Math_hypot(void*);
typedef struct F_Math_hypot F_Math_hypot;
struct F_Math_hypot
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
	REAL	y;
};
void Math_iamax(void*);
typedef struct F_Math_iamax F_Math_iamax;
struct F_Math_iamax
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Array*	x;
};
void Math_ilogb(void*);
typedef struct F_Math_ilogb F_Math_ilogb;
struct F_Math_ilogb
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_import_int(void*);
typedef struct F_Math_import_int F_Math_import_int;
struct F_Math_import_int
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Array*	b;
	Array*	x;
};
void Math_import_real(void*);
typedef struct F_Math_import_real F_Math_import_real;
struct F_Math_import_real
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Array*	b;
	Array*	x;
};
void Math_import_real32(void*);
typedef struct F_Math_import_real32 F_Math_import_real32;
struct F_Math_import_real32
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Array*	b;
	Array*	x;
};
void Math_isnan(void*);
typedef struct F_Math_isnan F_Math_isnan;
struct F_Math_isnan
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_j0(void*);
typedef struct F_Math_j0 F_Math_j0;
struct F_Math_j0
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_j1(void*);
typedef struct F_Math_j1 F_Math_j1;
struct F_Math_j1
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_jn(void*);
typedef struct F_Math_jn F_Math_jn;
struct F_Math_jn
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	WORD	n;
	uchar	_pad36[4];
	REAL	x;
};
void Math_lgamma(void*);
typedef struct F_Math_lgamma F_Math_lgamma;
struct F_Math_lgamma
{
	WORD	regs[NREG-1];
	struct{ WORD t0; uchar	_pad4[4]; REAL t1; }*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_log(void*);
typedef struct F_Math_log F_Math_log;
struct F_Math_log
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_log10(void*);
typedef struct F_Math_log10 F_Math_log10;
struct F_Math_log10
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_log1p(void*);
typedef struct F_Math_log1p F_Math_log1p;
struct F_Math_log1p
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_modf(void*);
typedef struct F_Math_modf F_Math_modf;
struct F_Math_modf
{
	WORD	regs[NREG-1];
	struct{ WORD t0; uchar	_pad4[4]; REAL t1; }*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_nextafter(void*);
typedef struct F_Math_nextafter F_Math_nextafter;
struct F_Math_nextafter
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
	REAL	y;
};
void Math_norm1(void*);
typedef struct F_Math_norm1 F_Math_norm1;
struct F_Math_norm1
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	Array*	x;
};
void Math_norm2(void*);
typedef struct F_Math_norm2 F_Math_norm2;
struct F_Math_norm2
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	Array*	x;
};
void Math_pow(void*);
typedef struct F_Math_pow F_Math_pow;
struct F_Math_pow
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
	REAL	y;
};
void Math_pow10(void*);
typedef struct F_Math_pow10 F_Math_pow10;
struct F_Math_pow10
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	WORD	p;
};
void Math_realbits32(void*);
typedef struct F_Math_realbits32 F_Math_realbits32;
struct F_Math_realbits32
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_realbits64(void*);
typedef struct F_Math_realbits64 F_Math_realbits64;
struct F_Math_realbits64
{
	WORD	regs[NREG-1];
	LONG*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_remainder(void*);
typedef struct F_Math_remainder F_Math_remainder;
struct F_Math_remainder
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
	REAL	p;
};
void Math_rint(void*);
typedef struct F_Math_rint F_Math_rint;
struct F_Math_rint
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_scalbn(void*);
typedef struct F_Math_scalbn F_Math_scalbn;
struct F_Math_scalbn
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
	WORD	n;
};
void Math_sin(void*);
typedef struct F_Math_sin F_Math_sin;
struct F_Math_sin
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_sinh(void*);
typedef struct F_Math_sinh F_Math_sinh;
struct F_Math_sinh
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_sort(void*);
typedef struct F_Math_sort F_Math_sort;
struct F_Math_sort
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Array*	x;
	Array*	pi;
};
void Math_sqrt(void*);
typedef struct F_Math_sqrt F_Math_sqrt;
struct F_Math_sqrt
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_tan(void*);
typedef struct F_Math_tan F_Math_tan;
struct F_Math_tan
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_tanh(void*);
typedef struct F_Math_tanh F_Math_tanh;
struct F_Math_tanh
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_y0(void*);
typedef struct F_Math_y0 F_Math_y0;
struct F_Math_y0
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_y1(void*);
typedef struct F_Math_y1 F_Math_y1;
struct F_Math_y1
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	REAL	x;
};
void Math_yn(void*);
typedef struct F_Math_yn F_Math_yn;
struct F_Math_yn
{
	WORD	regs[NREG-1];
	REAL*	ret;
	uchar	temps[12];
	WORD	n;
	uchar	_pad36[4];
	REAL	x;
};
#define Math_PATH "$Math"
#define Math_Infinity Infinity
#define Math_NaN NaN
#define Math_MachEps 2.220446049250313e-16
#define Math_Pi 3.141592653589793
#define Math_Degree .017453292519943295
#define Math_INVAL 1
#define Math_ZDIV 2
#define Math_OVFL 4
#define Math_UNFL 8
#define Math_INEX 16
#define Math_RND_NR 0
#define Math_RND_NINF 256
#define Math_RND_PINF 512
#define Math_RND_Z 768
#define Math_RND_MASK 768
void IPints_DSAprimes(void*);
typedef struct F_IPints_DSAprimes F_IPints_DSAprimes;
struct F_IPints_DSAprimes
{
	WORD	regs[NREG-1];
	struct{ IPints_IPint* t0; IPints_IPint* t1; Array* t2; }*	ret;
	uchar	temps[12];
};
void IPint_add(void*);
typedef struct F_IPint_add F_IPint_add;
struct F_IPint_add
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	i1;
	IPints_IPint*	i2;
};
void IPint_and(void*);
typedef struct F_IPint_and F_IPint_and;
struct F_IPint_and
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	i1;
	IPints_IPint*	i2;
};
void IPint_b64toip(void*);
typedef struct F_IPint_b64toip F_IPint_b64toip;
struct F_IPint_b64toip
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	String*	str;
};
void IPint_bebytestoip(void*);
typedef struct F_IPint_bebytestoip F_IPint_bebytestoip;
struct F_IPint_bebytestoip
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	Array*	mag;
};
void IPint_bits(void*);
typedef struct F_IPint_bits F_IPint_bits;
struct F_IPint_bits
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	IPints_IPint*	i;
};
void IPint_bytestoip(void*);
typedef struct F_IPint_bytestoip F_IPint_bytestoip;
struct F_IPint_bytestoip
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	Array*	buf;
};
void IPint_cmp(void*);
typedef struct F_IPint_cmp F_IPint_cmp;
struct F_IPint_cmp
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	IPints_IPint*	i1;
	IPints_IPint*	i2;
};
void IPint_copy(void*);
typedef struct F_IPint_copy F_IPint_copy;
struct F_IPint_copy
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	i;
};
void IPint_div(void*);
typedef struct F_IPint_div F_IPint_div;
struct F_IPint_div
{
	WORD	regs[NREG-1];
	struct{ IPints_IPint* t0; IPints_IPint* t1; }*	ret;
	uchar	temps[12];
	IPints_IPint*	i1;
	IPints_IPint*	i2;
};
void IPint_eq(void*);
typedef struct F_IPint_eq F_IPint_eq;
struct F_IPint_eq
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	IPints_IPint*	i1;
	IPints_IPint*	i2;
};
void IPint_expmod(void*);
typedef struct F_IPint_expmod F_IPint_expmod;
struct F_IPint_expmod
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	base;
	IPints_IPint*	exp;
	IPints_IPint*	mod;
};
void IPints_genprime(void*);
typedef struct F_IPints_genprime F_IPints_genprime;
struct F_IPints_genprime
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	WORD	nbits;
	WORD	nrep;
};
void IPints_gensafeprime(void*);
typedef struct F_IPints_gensafeprime F_IPints_gensafeprime;
struct F_IPints_gensafeprime
{
	WORD	regs[NREG-1];
	struct{ IPints_IPint* t0; IPints_IPint* t1; }*	ret;
	uchar	temps[12];
	WORD	nbits;
	WORD	nrep;
};
void IPints_genstrongprime(void*);
typedef struct F_IPints_genstrongprime F_IPints_genstrongprime;
struct F_IPints_genstrongprime
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	WORD	nbits;
	WORD	nrep;
};
void IPint_inttoip(void*);
typedef struct F_IPint_inttoip F_IPint_inttoip;
struct F_IPint_inttoip
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	WORD	i;
};
void IPint_invert(void*);
typedef struct F_IPint_invert F_IPint_invert;
struct F_IPint_invert
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	base;
	IPints_IPint*	mod;
};
void IPint_iptob64(void*);
typedef struct F_IPint_iptob64 F_IPint_iptob64;
struct F_IPint_iptob64
{
	WORD	regs[NREG-1];
	String**	ret;
	uchar	temps[12];
	IPints_IPint*	i;
};
void IPint_iptob64z(void*);
typedef struct F_IPint_iptob64z F_IPint_iptob64z;
struct F_IPint_iptob64z
{
	WORD	regs[NREG-1];
	String**	ret;
	uchar	temps[12];
	IPints_IPint*	i;
};
void IPint_iptobebytes(void*);
typedef struct F_IPint_iptobebytes F_IPint_iptobebytes;
struct F_IPint_iptobebytes
{
	WORD	regs[NREG-1];
	Array**	ret;
	uchar	temps[12];
	IPints_IPint*	i;
};
void IPint_iptobytes(void*);
typedef struct F_IPint_iptobytes F_IPint_iptobytes;
struct F_IPint_iptobytes
{
	WORD	regs[NREG-1];
	Array**	ret;
	uchar	temps[12];
	IPints_IPint*	i;
};
void IPint_iptoint(void*);
typedef struct F_IPint_iptoint F_IPint_iptoint;
struct F_IPint_iptoint
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	IPints_IPint*	i;
};
void IPint_iptostr(void*);
typedef struct F_IPint_iptostr F_IPint_iptostr;
struct F_IPint_iptostr
{
	WORD	regs[NREG-1];
	String**	ret;
	uchar	temps[12];
	IPints_IPint*	i;
	WORD	base;
};
void IPint_mod(void*);
typedef struct F_IPint_mod F_IPint_mod;
struct F_IPint_mod
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	i1;
	IPints_IPint*	i2;
};
void IPint_mul(void*);
typedef struct F_IPint_mul F_IPint_mul;
struct F_IPint_mul
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	i1;
	IPints_IPint*	i2;
};
void IPint_neg(void*);
typedef struct F_IPint_neg F_IPint_neg;
struct F_IPint_neg
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	i;
};
void IPint_not(void*);
typedef struct F_IPint_not F_IPint_not;
struct F_IPint_not
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	i1;
};
void IPint_ori(void*);
typedef struct F_IPint_ori F_IPint_ori;
struct F_IPint_ori
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	i1;
	IPints_IPint*	i2;
};
void IPints_probably_prime(void*);
typedef struct F_IPints_probably_prime F_IPints_probably_prime;
struct F_IPints_probably_prime
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	IPints_IPint*	n;
	WORD	nrep;
};
void IPint_random(void*);
typedef struct F_IPint_random F_IPint_random;
struct F_IPint_random
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	WORD	nbits;
};
void IPint_shl(void*);
typedef struct F_IPint_shl F_IPint_shl;
struct F_IPint_shl
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	i;
	WORD	n;
};
void IPint_shr(void*);
typedef struct F_IPint_shr F_IPint_shr;
struct F_IPint_shr
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	i;
	WORD	n;
};
void IPint_strtoip(void*);
typedef struct F_IPint_strtoip F_IPint_strtoip;
struct F_IPint_strtoip
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	String*	str;
	WORD	base;
};
void IPint_sub(void*);
typedef struct F_IPint_sub F_IPint_sub;
struct F_IPint_sub
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	i1;
	IPints_IPint*	i2;
};
void IPint_xor(void*);
typedef struct F_IPint_xor F_IPint_xor;
struct F_IPint_xor
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	IPints_IPint*	i1;
	IPints_IPint*	i2;
};
#define IPints_PATH "$IPints"
void Crypt_aescbc(void*);
typedef struct F_Crypt_aescbc F_Crypt_aescbc;
struct F_Crypt_aescbc
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Crypt_AESstate*	state;
	Array*	buf;
	WORD	n;
	WORD	direction;
};
void Crypt_aessetup(void*);
typedef struct F_Crypt_aessetup F_Crypt_aessetup;
struct F_Crypt_aessetup
{
	WORD	regs[NREG-1];
	Crypt_AESstate**	ret;
	uchar	temps[12];
	Array*	key;
	Array*	ivec;
};
void Crypt_blowfishcbc(void*);
typedef struct F_Crypt_blowfishcbc F_Crypt_blowfishcbc;
struct F_Crypt_blowfishcbc
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Crypt_BFstate*	state;
	Array*	buf;
	WORD	n;
	WORD	direction;
};
void Crypt_blowfishsetup(void*);
typedef struct F_Crypt_blowfishsetup F_Crypt_blowfishsetup;
struct F_Crypt_blowfishsetup
{
	WORD	regs[NREG-1];
	Crypt_BFstate**	ret;
	uchar	temps[12];
	Array*	key;
	Array*	ivec;
};
void DigestState_copy(void*);
typedef struct F_DigestState_copy F_DigestState_copy;
struct F_DigestState_copy
{
	WORD	regs[NREG-1];
	Crypt_DigestState**	ret;
	uchar	temps[12];
	Crypt_DigestState*	d;
};
void Crypt_descbc(void*);
typedef struct F_Crypt_descbc F_Crypt_descbc;
struct F_Crypt_descbc
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Crypt_DESstate*	state;
	Array*	buf;
	WORD	n;
	WORD	direction;
};
void Crypt_desecb(void*);
typedef struct F_Crypt_desecb F_Crypt_desecb;
struct F_Crypt_desecb
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Crypt_DESstate*	state;
	Array*	buf;
	WORD	n;
	WORD	direction;
};
void Crypt_dessetup(void*);
typedef struct F_Crypt_dessetup F_Crypt_dessetup;
struct F_Crypt_dessetup
{
	WORD	regs[NREG-1];
	Crypt_DESstate**	ret;
	uchar	temps[12];
	Array*	key;
	Array*	ivec;
};
void Crypt_dhparams(void*);
typedef struct F_Crypt_dhparams F_Crypt_dhparams;
struct F_Crypt_dhparams
{
	WORD	regs[NREG-1];
	struct{ IPints_IPint* t0; IPints_IPint* t1; }*	ret;
	uchar	temps[12];
	WORD	nbits;
};
void Crypt_dsagen(void*);
typedef struct F_Crypt_dsagen F_Crypt_dsagen;
struct F_Crypt_dsagen
{
	WORD	regs[NREG-1];
	Crypt_SK**	ret;
	uchar	temps[12];
	Crypt_PK*	oldpk;
};
void Crypt_eggen(void*);
typedef struct F_Crypt_eggen F_Crypt_eggen;
struct F_Crypt_eggen
{
	WORD	regs[NREG-1];
	Crypt_SK**	ret;
	uchar	temps[12];
	WORD	nlen;
	WORD	nrep;
};
void Crypt_genSK(void*);
typedef struct F_Crypt_genSK F_Crypt_genSK;
struct F_Crypt_genSK
{
	WORD	regs[NREG-1];
	Crypt_SK**	ret;
	uchar	temps[12];
	String*	algname;
	WORD	length;
};
void Crypt_genSKfromPK(void*);
typedef struct F_Crypt_genSKfromPK F_Crypt_genSKfromPK;
struct F_Crypt_genSKfromPK
{
	WORD	regs[NREG-1];
	Crypt_SK**	ret;
	uchar	temps[12];
	Crypt_PK*	pk;
};
void Crypt_hmac_md5(void*);
typedef struct F_Crypt_hmac_md5 F_Crypt_hmac_md5;
struct F_Crypt_hmac_md5
{
	WORD	regs[NREG-1];
	Crypt_DigestState**	ret;
	uchar	temps[12];
	Array*	data;
	WORD	n;
	Array*	key;
	Array*	digest;
	Crypt_DigestState*	state;
};
void Crypt_hmac_sha1(void*);
typedef struct F_Crypt_hmac_sha1 F_Crypt_hmac_sha1;
struct F_Crypt_hmac_sha1
{
	WORD	regs[NREG-1];
	Crypt_DigestState**	ret;
	uchar	temps[12];
	Array*	data;
	WORD	n;
	Array*	key;
	Array*	digest;
	Crypt_DigestState*	state;
};
void Crypt_ideacbc(void*);
typedef struct F_Crypt_ideacbc F_Crypt_ideacbc;
struct F_Crypt_ideacbc
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Crypt_IDEAstate*	state;
	Array*	buf;
	WORD	n;
	WORD	direction;
};
void Crypt_ideaecb(void*);
typedef struct F_Crypt_ideaecb F_Crypt_ideaecb;
struct F_Crypt_ideaecb
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Crypt_IDEAstate*	state;
	Array*	buf;
	WORD	n;
	WORD	direction;
};
void Crypt_ideasetup(void*);
typedef struct F_Crypt_ideasetup F_Crypt_ideasetup;
struct F_Crypt_ideasetup
{
	WORD	regs[NREG-1];
	Crypt_IDEAstate**	ret;
	uchar	temps[12];
	Array*	key;
	Array*	ivec;
};
void Crypt_md4(void*);
typedef struct F_Crypt_md4 F_Crypt_md4;
struct F_Crypt_md4
{
	WORD	regs[NREG-1];
	Crypt_DigestState**	ret;
	uchar	temps[12];
	Array*	buf;
	WORD	n;
	Array*	digest;
	Crypt_DigestState*	state;
};
void Crypt_md5(void*);
typedef struct F_Crypt_md5 F_Crypt_md5;
struct F_Crypt_md5
{
	WORD	regs[NREG-1];
	Crypt_DigestState**	ret;
	uchar	temps[12];
	Array*	buf;
	WORD	n;
	Array*	digest;
	Crypt_DigestState*	state;
};
void Crypt_rc4(void*);
typedef struct F_Crypt_rc4 F_Crypt_rc4;
struct F_Crypt_rc4
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Crypt_RC4state*	state;
	Array*	buf;
	WORD	n;
};
void Crypt_rc4back(void*);
typedef struct F_Crypt_rc4back F_Crypt_rc4back;
struct F_Crypt_rc4back
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Crypt_RC4state*	state;
	WORD	n;
};
void Crypt_rc4setup(void*);
typedef struct F_Crypt_rc4setup F_Crypt_rc4setup;
struct F_Crypt_rc4setup
{
	WORD	regs[NREG-1];
	Crypt_RC4state**	ret;
	uchar	temps[12];
	Array*	seed;
};
void Crypt_rc4skip(void*);
typedef struct F_Crypt_rc4skip F_Crypt_rc4skip;
struct F_Crypt_rc4skip
{
	WORD	regs[NREG-1];
	WORD	noret;
	uchar	temps[12];
	Crypt_RC4state*	state;
	WORD	n;
};
void Crypt_rsadecrypt(void*);
typedef struct F_Crypt_rsadecrypt F_Crypt_rsadecrypt;
struct F_Crypt_rsadecrypt
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	Crypt_SK*	k;
	IPints_IPint*	m;
};
void Crypt_rsaencrypt(void*);
typedef struct F_Crypt_rsaencrypt F_Crypt_rsaencrypt;
struct F_Crypt_rsaencrypt
{
	WORD	regs[NREG-1];
	IPints_IPint**	ret;
	uchar	temps[12];
	Crypt_PK*	k;
	IPints_IPint*	m;
};
void Crypt_rsafill(void*);
typedef struct F_Crypt_rsafill F_Crypt_rsafill;
struct F_Crypt_rsafill
{
	WORD	regs[NREG-1];
	Crypt_SK**	ret;
	uchar	temps[12];
	IPints_IPint*	n;
	IPints_IPint*	ek;
	IPints_IPint*	dk;
	IPints_IPint*	p;
	IPints_IPint*	q;
};
void Crypt_rsagen(void*);
typedef struct F_Crypt_rsagen F_Crypt_rsagen;
struct F_Crypt_rsagen
{
	WORD	regs[NREG-1];
	Crypt_SK**	ret;
	uchar	temps[12];
	WORD	nlen;
	WORD	elen;
	WORD	nrep;
};
void Crypt_sha1(void*);
typedef struct F_Crypt_sha1 F_Crypt_sha1;
struct F_Crypt_sha1
{
	WORD	regs[NREG-1];
	Crypt_DigestState**	ret;
	uchar	temps[12];
	Array*	buf;
	WORD	n;
	Array*	digest;
	Crypt_DigestState*	state;
};
void Crypt_sha224(void*);
typedef struct F_Crypt_sha224 F_Crypt_sha224;
struct F_Crypt_sha224
{
	WORD	regs[NREG-1];
	Crypt_DigestState**	ret;
	uchar	temps[12];
	Array*	buf;
	WORD	n;
	Array*	digest;
	Crypt_DigestState*	state;
};
void Crypt_sha256(void*);
typedef struct F_Crypt_sha256 F_Crypt_sha256;
struct F_Crypt_sha256
{
	WORD	regs[NREG-1];
	Crypt_DigestState**	ret;
	uchar	temps[12];
	Array*	buf;
	WORD	n;
	Array*	digest;
	Crypt_DigestState*	state;
};
void Crypt_sha384(void*);
typedef struct F_Crypt_sha384 F_Crypt_sha384;
struct F_Crypt_sha384
{
	WORD	regs[NREG-1];
	Crypt_DigestState**	ret;
	uchar	temps[12];
	Array*	buf;
	WORD	n;
	Array*	digest;
	Crypt_DigestState*	state;
};
void Crypt_sha512(void*);
typedef struct F_Crypt_sha512 F_Crypt_sha512;
struct F_Crypt_sha512
{
	WORD	regs[NREG-1];
	Crypt_DigestState**	ret;
	uchar	temps[12];
	Array*	buf;
	WORD	n;
	Array*	digest;
	Crypt_DigestState*	state;
};
void Crypt_sign(void*);
typedef struct F_Crypt_sign F_Crypt_sign;
struct F_Crypt_sign
{
	WORD	regs[NREG-1];
	Crypt_PKsig**	ret;
	uchar	temps[12];
	Crypt_SK*	sk;
	IPints_IPint*	m;
};
void Crypt_sktopk(void*);
typedef struct F_Crypt_sktopk F_Crypt_sktopk;
struct F_Crypt_sktopk
{
	WORD	regs[NREG-1];
	Crypt_PK**	ret;
	uchar	temps[12];
	Crypt_SK*	sk;
};
void Crypt_verify(void*);
typedef struct F_Crypt_verify F_Crypt_verify;
struct F_Crypt_verify
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Crypt_PK*	pk;
	Crypt_PKsig*	sig;
	IPints_IPint*	m;
};
#define Crypt_PATH "$Crypt"
#define Crypt_SHA1dlen 20
#define Crypt_SHA224dlen 28
#define Crypt_SHA256dlen 32
#define Crypt_SHA384dlen 48
#define Crypt_SHA512dlen 64
#define Crypt_MD5dlen 16
#define Crypt_MD4dlen 16
#define Crypt_Encrypt 0
#define Crypt_Decrypt 1
#define Crypt_AESbsize 16
#define Crypt_DESbsize 8
#define Crypt_IDEAbsize 8
#define Crypt_BFbsize 8
void Loader_compile(void*);
typedef struct F_Loader_compile F_Loader_compile;
struct F_Loader_compile
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Modlink*	mp;
	WORD	flag;
};
void Loader_dnew(void*);
typedef struct F_Loader_dnew F_Loader_dnew;
struct F_Loader_dnew
{
	WORD	regs[NREG-1];
	Loader_Niladt**	ret;
	uchar	temps[12];
	WORD	size;
	Array*	map;
};
void Loader_ext(void*);
typedef struct F_Loader_ext F_Loader_ext;
struct F_Loader_ext
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Modlink*	mp;
	WORD	idx;
	WORD	pc;
	WORD	tdesc;
};
void Loader_ifetch(void*);
typedef struct F_Loader_ifetch F_Loader_ifetch;
struct F_Loader_ifetch
{
	WORD	regs[NREG-1];
	Array**	ret;
	uchar	temps[12];
	Modlink*	mp;
};
void Loader_link(void*);
typedef struct F_Loader_link F_Loader_link;
struct F_Loader_link
{
	WORD	regs[NREG-1];
	Array**	ret;
	uchar	temps[12];
	Modlink*	mp;
};
void Loader_newmod(void*);
typedef struct F_Loader_newmod F_Loader_newmod;
struct F_Loader_newmod
{
	WORD	regs[NREG-1];
	Modlink**	ret;
	uchar	temps[12];
	String*	name;
	WORD	ss;
	WORD	nlink;
	Array*	inst;
	Loader_Niladt*	data;
};
void Loader_tdesc(void*);
typedef struct F_Loader_tdesc F_Loader_tdesc;
struct F_Loader_tdesc
{
	WORD	regs[NREG-1];
	Array**	ret;
	uchar	temps[12];
	Modlink*	mp;
};
void Loader_tnew(void*);
typedef struct F_Loader_tnew F_Loader_tnew;
struct F_Loader_tnew
{
	WORD	regs[NREG-1];
	WORD*	ret;
	uchar	temps[12];
	Modlink*	mp;
	WORD	size;
	Array*	map;
};
#define Loader_PATH "$Loader"
