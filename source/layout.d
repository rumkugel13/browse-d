module layout;

import browser, url;
import dlangui;
import std.sumtype:match;
import std.string;
import node, text, element;

struct WordPos
{
    int x;
    dstring s;
    Font f;
}

class Layout
{
    int cursor_x = HSTEP, cursor_y = VSTEP;
    auto weight = FontWeight.Normal;
    auto italic = false;
    auto size = 16;
    TextPos[] displayList;
    WordPos[] line;

    this(Node tree)
    {
        recurse(tree);
        flush(); // @suppress(dscanner.vcall_ctor)
    }

    void recurse(Node tree)
    {
        if (typeid(tree) == typeid(text.Text))
        {
            foreach (word; (cast(text.Text)tree).text.split())
            {
                this.word(word);
            }
        }
        else 
        {
            auto tag = cast(Element)tree;
            openTag(tag.tag);
            foreach (child; tag.children)
            {
                recurse(child);
            }
            closeTag(tag.tag);
        }
    }

    void openTag(string tag)
    {
        switch (tag)
        {
            case "i": italic = true; break;
            case "b": weight = FontWeight.Bold; break;
            case "small": size -= 2; break;
            case "big": size += 4; break;
            case "br": flush(); break; // bug: somehow causes text to overlap?
            default: break;
        }
    }

    void closeTag(string tag)
    {
        switch (tag)
        {
            case "i": italic = false; break;
            case "b": weight = FontWeight.Normal; break;
            case "small": size += 2; break;
            case "big": size -= 4; break;
            case "p": { flush(); cursor_y += VSTEP; } break;
            default: break;
        }
    }

    void word(string word)
    {
        auto font = FontManager.instance.getFont(size, weight, italic, FontFamily.Unspecified, "Times");
        auto wordWidth = font.textSize(word.to!dstring).x;
        if (cursor_x + wordWidth > WIDTH - HSTEP)
        {
            flush();
        }

        line ~= WordPos(cursor_x, word.to!dstring, font);
        cursor_x += wordWidth + font.textSize(" ").x;
    }

    void flush()
    {
        if (line.empty) return;

        import std.algorithm : map;
        import std.array;
        auto heights = line.map!((w) => w.f.height()).array;
        auto baselines = line.map!((w) => w.f.baseline()).array;

        auto descents = heights;
        heights[] -= baselines[];
        auto ascents = heights;
        ascents[] -= descents[];

        import std.algorithm : maxElement;
        auto maxAscent = ascents.maxElement;
        auto baseline = cursor_y + maxAscent * 5 / 4;

        foreach(wordpos; line)
        {
            auto y = baseline - (wordpos.f.height() - (wordpos.f.height() - wordpos.f.baseline()));
            displayList ~= TextPos(wordpos.x, y, wordpos.s, wordpos.f);
        }

        cursor_x = HSTEP;
        line.length = 0;

        auto maxDescent = descents.maxElement;
        cursor_y += baseline + maxDescent * 5 / 4;
    }
}