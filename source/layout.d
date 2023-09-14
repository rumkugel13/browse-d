module layout;

import browser, url;
import dlangui;
import std.sumtype:match;
import std.string;

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

    this(url.Token[] tokens)
    {
        foreach (token; tokens)
        {
            this.token(token);
        }
        flush(); // @suppress(dscanner.vcall_ctor)
    }

    void token(url.Token token)
    {
        token.match!(
            (ref Text t) {
            foreach (word; t.text.split())
            {
                this.word(word);
            }
        },
            (ref Tag t) {
                switch (t.tag)
                {
                    case "i": italic = true; break;
                    case "/i": italic = false; break;
                    case "b": weight = FontWeight.Bold; break;
                    case "/b": weight = FontWeight.Normal; break;
                    case "small": size -= 2; break;
                    case "/small": size += 2; break;
                    case "big": size += 4; break;
                    case "/big": size -= 4; break;
                    case "br": flush(); break;
                    case "/p": { flush(); cursor_y += VSTEP; } break;
                    default: break;
                }
            }
        );
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
        cursor_y = baseline + maxDescent * 5 / 4;
    }
}