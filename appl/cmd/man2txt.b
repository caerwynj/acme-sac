implement Man2txt;

include "sys.m";
	sys: Sys;
include "draw.m";
	draw : Draw;
	Font: import draw;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "env.m";
	env: Env;
	getenv: import env;
include "man.m";
include "arg.m";
	arg: Arg;

Man2txt: module {
	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

W: adt {
	textwidth: fn(w: self ref W, text: Parseman->Text): int;
};

R: adt {
	textwidth: fn(w: self ref R, text: Parseman->Text): int;
};

output: ref Iobuf;
ROMAN: con "/fonts/lucidasans/euro.8.font";
rfont : ref Font;
rflag := 0;

init(ctxt: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	env = load Env Env->PATH;
	bufio = load Bufio Bufio->PATH;
	arg = load Arg Arg->PATH;
	if (bufio == nil) {
		sys->print("cannot load Bufio module: %r\n");
		raise "fail:init";
	}

	stdout := sys->fildes(1);
	output = bufio->fopen(stdout, Sys->OWRITE);

	parser := load Parseman Parseman->PATH;
	parser->init();
	arg->init(argv);
	while((c := arg->opt()))
		case c {
		'r' =>
			rflag = 1;
		}
	
	
	argv = arg->argv();
	for (; argv != nil ; argv = tl argv) {
		fname := hd argv;
		fd := sys->open(fname, Sys->OREAD);
		if (fd == nil) {
			sys->print("cannot open %s: %r\n", fname);
			continue;
		}
		font := getenv("font");
		if(font == nil)
			font = ROMAN;
		m: Parseman->Metrics;
		datachan := chan of list of (int, Parseman->Text);
		if(ctxt != nil && !rflag){
			rfont = Font.open(ctxt.display, font);
			em := rfont.width("m");
			en := rfont.width("n");
			m = Parseman->Metrics(490, 80, em, en, 14, 40, 20);
			spawn parser->parseman(fd, m, 1, ref W, datachan);
		}else{
			m = Parseman->Metrics(72, 10, 1, 1, 1, 3, 3);   # RFC format
			spawn parser->parseman(fd, m, 1, ref R, datachan);
		}
		for (;;) {
			line := <- datachan;
			if (line == nil)
				break;
			if(ctxt!=nil && !rflag)
				setline(line);
			else
				osetline(line);
		}
		output.flush();
	}
	output.close();
}

W.textwidth(nil: self ref W, text: Parseman->Text): int
{
	return rfont.width(text.text);
}

R.textwidth(nil: self ref R, text: Parseman->Text): int
{
	return len text.text;
}

setline(line: list of (int, Parseman->Text))
{
#return;
	offset := 0;
	for (; line != nil; line = tl line) {
		(indent, txt) := hd line;
		# indent is in dots
		indent = indent / rfont.width(" ");
		while (offset < indent) {
			output.putc(' ');
			offset++;
		}
		output.puts(txt.text);
		offset += (rfont.width(txt.text) / rfont.width(" "));
	}
	output.putc('\n');
}

osetline(line: list of (int, Parseman->Text))
{
#return;
	offset := 0;
	for (; line != nil; line = tl line) {
		(indent, txt) := hd line;
		while (offset < indent) {
			output.putc(' ');
			offset++;
		}
		output.puts(txt.text);
		offset += len txt.text;
	}
	output.putc('\n');
}
