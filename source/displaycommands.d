module displaycommands;

import dlangui : Font, DrawBuf, Color, Rect, COLOR_TRANSPARENT;

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
    string fontString;
    string color;

    this(int x1, int y1, dstring text, Font font, string color)
    {
        top = y1;
        left = x1;
        this.text = text;
        this.font = font;
        bottom = y1 + font.size() * 3 / 2;
        fontString = getFontDetails();
        this.color = color;
    }

    override void execute(int scroll, DrawBuf buf)
    {
        Color c;
        switch (color)
        {
            case "black": c = Color.black; break;
            case "blue": c = Color.blue; break;
            default: c = Color.black; break;
        }
        font.drawText(buf, left, top - scroll, text, c);
    }

    override string toString() const
    {
        import std.format;
        return format("DrawText(t=%s, l=%s, b=%s, r=%s, text=%s, font=%s)", top, left, bottom, right, text, fontString);
    }

    string getFontDetails()
    {
        import std.format;
        return format("Font(family=%s, size=%s, weight=%s, slant=%s, face=%s)", font.family, font.size, font.weight, font.italic, font.face);
    }
}

class DrawRect : DisplayCommand
{
    string color;

    this(int x1, int y1, int x2, int y2, string color)
    {
        top = y1;
        left = x1;
        bottom = y2;
        right = x2;
        this.color = color;
    }

    override void execute(int scroll, DrawBuf buf)
    {
        uint c;
        switch (color)
        {
            case "lightblue": c = Color.light_blue; break;
            case "gray": c = Color.gray; break;
            default: c = COLOR_TRANSPARENT; break;
        }

        // note: make sure order of args in Rect is correct
        buf.fillRect(Rect(left, top - scroll, right, bottom - scroll), c);
    }

    override string toString() const
    {
        import std.format;
        return format("DrawRect(t=%s, l=%s, b=%s, r=%s, c=%s)", top, left, bottom, right, color);
    }
}