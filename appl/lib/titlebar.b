implement Titlebar;
include "sys.m";
	sys: Sys;
include "draw.m";
	draw: Draw;
	Point, Rect: import draw;
include "tk.m";
	tk: Tk;
include "titlebar.m";

COLOR: con "#cccc88ff";

title_cfg := array[] of {
	"button .Wm_br -relief flat -fg "+COLOR+" -bg "+COLOR+" -activebackground "+COLOR+" -activeforeground "+COLOR+" -highlightcolor "+COLOR+" -width 1",
	"button .Wm_bl -relief flat -fg "+COLOR+" -bg "+COLOR+" -activebackground "+COLOR+" -activeforeground "+COLOR+" -highlightcolor "+COLOR+" -width 1",
	"button .Wm_bb -relief flat -fg "+COLOR+" -bg "+COLOR+" -activebackground "+COLOR+" -activeforeground "+COLOR+" -highlightcolor "+COLOR+" -height 1",
	"button .Wm_bt -relief flat -fg "+COLOR+" -bg "+COLOR+" -activebackground "+COLOR+" -activeforeground "+COLOR+" -highlightcolor "+COLOR+" -height 1",
	"pack .Wm_br -side right -fill y",
	"pack .Wm_bl -side left -fill y",
	"pack .Wm_bb -side bottom -fill x",
	"pack .Wm_bt -side top -fill x",
	"bind .Wm_br <Button-1> {send wm_title move %X %Y}",
	"bind .Wm_bl <Button-1> {send wm_title move %X %Y}",
	"bind .Wm_bt <Button-1> {send wm_title move %X %Y}",
	"bind .Wm_bb <Button-1> {send wm_title move %X %Y}",
	"bind .Wm_br <Button-2> {send wm_title size} -takefocus 0",
	"bind .Wm_bl <Button-2> {send wm_title size} -takefocus 0",
	"bind .Wm_bt <Button-2> {send wm_title size} -takefocus 0",
	"bind .Wm_bb <Button-2> {send wm_title size} -takefocus 0",
	"bind .Wm_br <Button-3> {send wm_title exit} ",
	"bind .Wm_bl <Button-3> {send wm_title exit} ",
	"bind .Wm_bt <Button-3> {send wm_title exit} ",
	"bind .Wm_bb <Button-3> {send wm_title exit} ",
	"bind .Wm_br <Double-Button-1> {send wm_title task}",
	"bind .Wm_bl <Double-Button-1> {send wm_title task}",
	"bind .Wm_bb <Double-Button-1> {send wm_title task}",
	"bind .Wm_bt <Double-Button-1> {send wm_title task}",
	"frame .Wm_t",
	"label .Wm_t.title -anchor w -bg #aaaaaa -fg white",
};

init()
{
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	tk = load Tk Tk->PATH;
}

new(top: ref Tk->Toplevel, buts: int): chan of string
{
	ctl := chan of string;
	tk->namechan(top, ctl, "wm_title");

	if(buts & Plain)
		return ctl;

	for(i := 0; i < len title_cfg; i++)
		cmd(top, title_cfg[i]);

	return ctl;
}

title(top: ref Tk->Toplevel): string
{
	if(tk->cmd(top, "winfo class .Wm_t.title")[0] != '!')
		return cmd(top, ".Wm_t.title cget -text");
	return nil;
}
	
settitle(top: ref Tk->Toplevel, t: string): string
{
	s := title(top);
	tk->cmd(top, ".Wm_t.title configure -text '" + t);
	return s;
}

setfocus(top: ref Tk->Toplevel, focus: int)
{
	color : string;
	but := array[] of {".Wm_br", ".Wm_bl", ".Wm_bt", ".Wm_bb"};
	if(focus)
		color = "#777700";
	else
		color = "#dddd93";
	for(i:=0; i < len but; i++)
		cmd(top, sys->sprint("%s configure  -fg %s -bg %s -activebackground %s -activeforeground %s -highlightcolor %s", but[i], color, color, color, color, color));
}

sendctl(top: ref Tk->Toplevel, c: string)
{
	cmd(top, "send wm_title " + c);
}

minsize(top: ref Tk->Toplevel): Point
{
	r := tk->rect(top, ".", Tk->Border);
	r.min.x = r.max.x;
	r.max.y = r.min.y;
	return r.size();
}

cmd(top: ref Tk->Toplevel, s: string): string
{
	e := tk->cmd(top, s);
	if (e != nil && e[0] == '!')
		sys->fprint(sys->fildes(2), "wmclient: tk error %s on '%s'\n", e, s);
	return e;
}
