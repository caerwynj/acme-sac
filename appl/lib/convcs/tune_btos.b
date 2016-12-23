implement Btos;

include "sys.m";
include "convcs.m";
include "tune.b";

MAXINT: con 16r7fffffff;

sys : Sys;

init(nil: string): string
{
	sys = load Sys Sys->PATH;
	return nil;
}

btos(nil: Convcs->State, b: array of byte, n: int): (Convcs->State, string, int)
{
	nc, nb, tr, i: int;
	str: string;

	nc = nb = 0;
	str = "";
	if(n == -1)
		n = MAXINT;
	while(nb<len b && nc<n-3){
		(c, l, nil) := sys->byte2char(b, nb);
		if(l == 0)
			break;
		nb += l;
		if(c>='' && c <= '' && (i = c%16) < len t2){
			if(c >= ''){
				str[nc++] = 'க';
				str[nc++] = '்';
				str[nc++] = 'ஷ';
			}else
				str[nc++] = findbytune(t3, c-i+1);
			if(i != 1)
				str[nc++] = t2[i];
		}else if((tr = findbytune(t1, c)) != BADCHAR)
			str[nc++] = tr;
		else case c{
			'' =>
				str[nc++] = 'ண'; str[nc++] = 'ா';
			'' =>
				str[nc++] = 'ற'; str[nc++] = 'ா';
			'' =>
				str[nc++] = 'ன'; str[nc++] = 'ா';
			'' =>
				str[nc++] = 'ண'; str[nc++] = 'ை';
			'' =>
				str[nc++] = 'ல'; str[nc++] = 'ை';
			'' =>
				str[nc++] = 'ள'; str[nc++] = 'ை';
			'' =>
				str[nc++] = 'ன'; str[nc++] = 'ை';
			'' =>
				str[nc++] = 'ஶ'; str[nc++] = '்'; str[nc++] = 'ர'; str[nc++] = 'ீ';
			* => 
				if(c >= '' && c <= '')
					c = BADCHAR;
				str[nc++] = c;
		}
	}
	return (nil, str, nb);
}
