module displaycommand;

import dlangui;
import std.string : startsWith, join;
import std.algorithm : map, each;
import std.conv : to;

alias DisplayList = DisplayCommand[];

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
        bottom = y1 + font.height();
        fontString = getFontDetails();
        this.color = color;
    }

    override void execute(int scroll, DrawBuf buf)
    {
        font.drawText(buf, left, top - scroll, text, getColor(color));
    }

    override string toString() const
    {
        import std.format;
        return format("DrawText(top=%s, left=%s, bottom=%s, right=%s, text=%s, color=%s, font=%s)", top, left, bottom, right, text, color, fontString);
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
        if (color == "lightblue") color = "light_blue";
        buf.fillRect(Rect(left, top - scroll, right, bottom - scroll), getColor(color));
    }

    override string toString() const
    {
        import std.format;
        return format("DrawRect(top=%s, left=%s, bottom=%s, right=%s, color=%s)", top, left, bottom, right, color);
    }
}

class DrawLine : DisplayCommand
{
    string color;
    int thickness;

    this(int x1, int y1, int x2, int y2, string color, int thickness)
    {
        top = y1;
        left = x1;
        bottom = y2;
        right = x2;
        this.color = color;
        this.thickness = thickness;
    }

    override void execute(int scroll, DrawBuf buf)
    {
        buf.drawLineF(PointF(left, top - scroll), PointF(right, bottom - scroll), thickness, getColor(color));
    }

    override string toString() const
    {
        import std.format;
        return format("DrawLine(top=%s, left=%s, bottom=%s, right=%s, color=%s, thickness=%s)", top, left, bottom, right, color, thickness);
    }
}

class DrawOutline : DisplayCommand
{
    string color;
    int thickness;

    this(int x1, int y1, int x2, int y2, string color, int thickness)
    {
        top = y1;
        left = x1;
        bottom = y2;
        right = x2;
        this.color = color;
    }

    override void execute(int scroll, DrawBuf buf)
    {
        buf.drawFrame(Rect(left, top - scroll, right, bottom - scroll), getColor(color), Rect(thickness, thickness, thickness, thickness), COLOR_TRANSPARENT);
    }

    override string toString() const
    {
        import std.format;
        return format("DrawOutline(top=%s, left=%s, bottom=%s, right=%s, color=%s, thickness=%s)", top, left, bottom, right, color, thickness);
    }
}

uint getColor(string color)
{
    if (color.startsWith("#"))
    {
        if (color.length == 4)
        {
            color = "#" ~ color[1..$].map!(a => [a,a]).join.to!string;
        }

        return decodeHexColor(color);
    }
    else 
    {
        return decodeCSSColor(color);
    }
}