implement Stob;

include "sys.m";
include "convcs.m";
include "tune.b";

sys: Sys;
lastc: int;
Startstate: import Convcs;

init(nil: string): string
{
	sys = load Sys Sys->PATH;
	return nil;
}

stob(s: Convcs->State, str: string): (Convcs->State, array of byte)
{
	c, i, n, nb: int;
	b: array of byte;

	b = array[(len str+2)*Sys->UTFmax] of byte;
	n = nb = 0;
	while(n<len str){
		case s{
		Startstate =>
			if((c=findbyuni(t3, str[n])) != BADCHAR){
				lastc = c;
				s = "1";
			}else if(str[n] == 'ஒ'){
				lastc = '';
				s = "3";
			}else if((c=findbyuni(t1, str[n])) != BADCHAR)
				nb += sys->char2byte(c, b, nb);
			else
				nb += sys->char2byte(str[n], b, nb);
		"1" =>
			if((i=findindex(t2, str[n])) != -1){
				if(lastc!=BADCHAR)
					lastc += i-1;
				if(str[n] == 'ெ')
					s = "5";
				else if(str[n] == 'ே')
					s = "4";
				else if(lastc == '')
					s = "2";
				else if(lastc == '')
					s = "6";
				else{
					nb += sys->char2byte(lastc, b, nb);
					s = Startstate;
				}
			}else if(lastc!=BADCHAR && (str[n]=='²' || str[n]=='³' || str[n]=='⁴')){
				lastc = BADCHAR;
			}else{
				nb += sys->char2byte(lastc, b, nb);
				s = Startstate;
				continue;
			}
		"2" =>
			if(str[n] == 'ஷ'){
				lastc = '';
				s = "1";
			}else{
				nb += sys->char2byte(lastc, b, nb);
				s = Startstate;
				continue;
			}
		"3" =>
			s = Startstate;
			if(str[n] == 'ௗ')
				nb += sys->char2byte('', b, nb);
			else{
				nb += sys->char2byte(lastc, b, nb);
				continue;
			}
		"4" =>
			s = Startstate;
			if(str[n] == 'ா'){
				if(lastc != BADCHAR)
					lastc += 3;
				nb += sys->char2byte(lastc, b, nb);
			}else{
				nb += sys->char2byte(lastc, b, nb);
				continue;
			}
		"5" =>
			s = Startstate;
			if(str[n] == 'ா' || str[n] == 'ௗ'){
				if(lastc != BADCHAR)
					if(str[n] == 'ா')
						lastc += 3;
					else
						lastc += 5;
				nb += sys->char2byte(lastc, b, nb);
			}else{
				nb += sys->char2byte(lastc, b, nb);
				continue;
			}
		"6" =>
			if(str[n] == 'ர')
				s = "7";
			else{
				nb += sys->char2byte(lastc, b, nb);
				s = Startstate;
				continue;
			}
		"7" =>
			if(str[n] == 'ீ'){
				nb += sys->char2byte('', b, nb);
				s = Startstate;
			}else{
				nb += sys->char2byte(lastc, b, nb);
				lastc = '';
				s = "1";
				continue;
			}
		}
		n++;
	}
	if(str == "" && s != Startstate){
		nb += sys->char2byte(lastc, b, nb);
		if(s == "7")
			nb += sys->char2byte('', b, nb);
		s = Startstate;
	}
	return (s, b[:nb]);
}
