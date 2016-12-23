# Translated to Limbo by Eric Grosse <ehg@netlib.bell-labs.com> 3/96
# Translated to Java by Reed Wade  (wade@cs.utk.edu) 2/96
# Translated to C by Bonnie Toy 5/88
# Will Menninger, 10/93
# Jack Dongarra, linpack, 3/11/78.
# Cleve Moler, linpack, 08/14/78

implement linbench;

include "sys.m";
	sys: Sys;
	print: import sys;
include "math.m";
	math: Math;
	dot, fabs, gemm, iamax: import math;
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "linalg.m";
	linalg: LinAlg;
	dgefa, dgesl, printmat: import linalg;

linbench: module
{
	init:   fn(nil: ref Draw->Context, argv: list of string);
};

init(nil: ref Draw->Context, argv: list of string)
{
	sys    = load Sys  Sys->PATH;
	math   = load Math Math->PATH;
	linalg = load LinAlg LinAlg->PATH;
		if(linalg==nil) print("couldn't load LinAlg\n");
	sys->pctl(Sys->NEWPGRP, nil);
	argv = tl argv;
	if(argv == nil){
		sys->fprint(sys->fildes(2), "usage: linbench n\n");
		exit;
	}
	n := int hd argv;
	(mflops,secs) := benchmark(n);
	sys->print("%8.2f Mflops %8.1f secs\n",mflops,secs);
}

benchmark(n: int): (real,real)
{
	math = load Math Math->PATH;

	time := array [2] of real;
	lda := 201;
	if(n>lda) lda = n;
	a := array [lda*n] of real;
	b := array [n] of real;
	x := array [n] of real;
	ipvt := array [n] of int;
	ops := (2*n*n*n)/3 + 2*n*n;

	norma := matgen(a,lda,n,b);
	printmat("a",a,lda,n,n);
	printmat("b",b,lda,n,1);
	t1 := second();
	info := dgefa(a,lda,n,ipvt);
	time[0] = second() - t1;
	printmat("a",a,lda,n,n);
	t1 = second();
	dgesl(a,lda,n,ipvt,b,0);
	time[1] = second() - t1;
	total := time[0] + time[1];

	for(i := 0; i < n; i++) {
		x[i] = b[i];
	}
	printmat("x",x,lda,n,1);
	norma = matgen(a,lda,n,b);
	for(i = 0; i < n; i++) {
		b[i] = -b[i];
	}
	dmxpy(b,x,a,lda);
	resid := 0.;
	normx := 0.;
	for(i = 0; i < n; i++){
		if(resid<fabs(b[i])) resid = fabs(b[i]);
		if(normx<fabs(x[i])) normx = fabs(x[i]);
	}

	eps_result := math->MachEps;
	residn_result := (real n)*norma*normx*eps_result;
	if(residn_result!=0.)
		residn_result = resid/residn_result;
	else
		print("can't scale residual.");
	if(residn_result>math->sqrt(real n))
		print("resid/MachEps=%.3g\n",residn_result);
	time_result := total;
	mflops_result := 0.;
	if(total!=0.)
		mflops_result = real ops/(1e6*total);
	else
		print("can't measure time\n");
	return (mflops_result,time_result);
}


# multiply matrix m times vector x and add the r_result to vector y.
dmxpy(y, x, m:array of real, ldm: int)
{
	n1 := len y;
	n2 := len x;
	gemm('N','N',n1,1,n2,1.,m,ldm,x,n2,1.,y,n1);
}

second(): real
{
	return(real sys->millisec()/1000.);
}


# generate a (fixed) random matrix and right hand side
# a[i][j] => a[lda*i+j]
matgen(a: array of real, lda, n: int, b: array of real): real
{
	seed := 1325;
	norma := 0.;
	for(j := 0; j < n; j++)
		for(i := 0; i < n; i++){
			seed = 3125*seed % 65536;
			a[lda*j+i] = (real seed - 32768.0)/16384.0;
			if(norma < a[lda*j+i]) norma = a[lda*j+i];
		}
	for (i = 0; i < n; i++)
		b[i] = 0.;
	for (j = 0; j < n; j++)
		for (i = 0; i < n; i++)
			b[i] += a[lda*j+i];
	return norma;
}
