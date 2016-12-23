BADCHAR: con 16rfffd;

t1 := array[] of {
	('அ', ''),
	('ஆ', ''),
	('இ', ''),
	('ஈ', ''),
	('உ', ''),
	('ஊ', ''),
	('எ', ''),
	('ஏ', ''),
	('ஐ', ''),
	('ஒ', ''),
	('ஓ', ''),
	('ஔ', ''),
	('ஃ', '')
};

t2 := array[] of {
	'்', 
	'்',	# filler
	'ா',
	'ி',
	'ீ',
	'ு',
	'ூ',
	'ெ',
	'ே',
	'ை',
	'ொ',
	'ோ',
	'ௌ'
};

t3 := array[] of {
	('க', ''),
	('ங', ''),
	('ச', ''),
	('ஜ', ''),
	('ஞ', ''),
	('ட', ''),
	('ண', ''),
	('த', ''),
	('ந', ''),
	('ன', ''),
	('ப', ''),
	('ம', ''),
	('ய', ''),
	('ர', ''),
	('ற', ''),
	('ல', ''),
	('ள', ''),
	('ழ', ''),
	('வ', ''),
 	('ஶ', ''),
	('ஷ', ''),
	('ஸ', ''),
	('ஹ', '')
};

findbytune(tab: array of (int, int), t: int): int
{
	for(i:=0; i<len tab; i++)
		if(tab[i].t1 == t)
			return tab[i].t0;
	return BADCHAR;
}

findbyuni(tab: array of (int, int), u: int): int
{
	for(i:=0; i<len tab; i++)
		if(tab[i].t0 == u)
			return tab[i].t1;
	return BADCHAR;
}

findindex(tab: array of int, c: int): int
{
	for(i:=0; i<len tab; i++)
		if(tab[i] == c)
			return i;
	return -1;
}
