module displaycommands;

import dlangui : Font, DrawBuf, Color, Rect;

abstract class DisplayCommand
{
    int top, left, bottom, right;

    void execute(int scroll, DrawBuf buf);
    override string toString() const { return ""; }
}

class DrawText : DisplayCommand
{
    dstring text;
    Font font;

    this(int x1, int y1, dstring text, Font font)
    {
        top = y1;
        left = x1;
        this.text = text;
        this.font = font;
        bottom = y1 + font.size() * 3 / 2;
    }

    override void execute(int scroll, DrawBuf buf)
    {
        font.drawText(buf, left, top - scroll, text, Color.black);
    }

    override string toString() const
    {
        import std.format;
        return format("DrawText(t=%s, l=%s, b=%s, r=%s, text=%s)", top, left, bottom, right, text);
    }
}

class DrawRect : DisplayCommand
{
    uint color;

    this(int x1, int y1, int x2, int y2, uint color)
    {
        top = y1;
        left = x1;
        bottom = y2;
        right = x2;
        this.color = color;
    }

    override void execute(int scroll, DrawBuf buf)
    {
        // note: make sure order of args in Rect is correct
        buf.fillRect(Rect(left, top, right, bottom), color);
    }

    override string toString() const
    {
        import std.format;
        return format("DrawRect(t=%s, l=%s, b=%s, r=%s, c=%s)", top, left, bottom, right, color);
    }
}