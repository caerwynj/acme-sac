int rootmaxq = 9;
Dirtab roottab[9] = {
	"",	{0, 0, QTDIR},	 0,	0555,
	"dev",	{1, 0, QTDIR},	 0,	0555,
	"fd",	{2, 0, QTDIR},	 0,	0555,
	"prog",	{3, 0, QTDIR},	 0,	0555,
	"net",	{4, 0, QTDIR},	 0,	0555,
	"net.alt",	{5, 0, QTDIR},	 0,	0555,
	"chan",	{6, 0, QTDIR},	 0,	0555,
	"nvfs",	{7, 0, QTDIR},	 0,	0555,
	"env",	{8, 0, QTDIR},	 0,	0555,
};
Rootdata rootdata[9] = {
	0,	 &roottab[1],	 8,	nil,
	0,	 nil,	 0,	 nil,
	0,	 nil,	 0,	 nil,
	0,	 nil,	 0,	 nil,
	0,	 nil,	 0,	 nil,
	0,	 nil,	 0,	 nil,
	0,	 nil,	 0,	 nil,
	0,	 nil,	 0,	 nil,
	0,	 nil,	 0,	 nil,
};
