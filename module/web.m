Web: module
{
	PATH: con "/dis/lib/web.dis";
	
	init0:	fn();
	readurl:	fn(url:string): array of byte;
	posturl:	fn(url: string, msg: string): array of byte;
};
