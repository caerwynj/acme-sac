int rootmaxq = 7;
Dirtab roottab[7] = {
	"",	{0, 0, QTDIR},	0,	0555,
	"dev",	{1, 0, QTDIR},	0,	0555,
	"fd",	{2, 0, QTDIR},	0,	0555,
	"prog",	{3, 0, QTDIR},	0,	0555,
	"net",	{4, 0, QTDIR},	0,	0555,
	"chan",	{5, 0, QTDIR},	0,	0555,
	"env",	{6, 0, QTDIR},	0,	0555,
};

Rootdata rootdata[7] = {
	0,	 &roottab[1],	6,	nil,
	0,	nil,	0,	nil,
	0,	nil,	0,	nil,
	0,	nil,	0,	nil,
	0,	nil,	0,	nil,
	0,	nil,	0,	nil,
	0,	nil,	0,	nil,
};
