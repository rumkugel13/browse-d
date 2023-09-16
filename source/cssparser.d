module cssparser;

import std.ascii : isWhite, isAlphaNum;
import std.algorithm : canFind;
import std.string : toLower;
import std.typecons : tuple, Tuple;
import node;

alias KeyValuePair = Tuple!(string, "key", string, "value");

class CSSParser
{
    string text;
    int pos;

    this(string text)
    {
        this.text = text;
        pos = 0;
    }

    void whitespace()
    {
        while (pos < text.length && text[pos].isWhite)
            pos++;
    }

    string word()
    {
        int start = pos;
        while (pos < text.length)
        {
            if (text[pos].isAlphaNum || "#-.%".canFind(text[pos]))
            {
                pos++;
            }
            else
            {
                break;
            }
        }

        if (!(pos > start))
            throw new Exception("Parsing error, expected a word");

        return text[start..pos];
    }

    void literal(char lit)
    {
        if (!(pos < text.length && text[pos] == lit))
            throw new Exception("Parsing error, expected a literal");
        pos++;
    }

    KeyValuePair pair()
    {
        auto prop = word();
        whitespace();
        literal(':');
        whitespace();
        auto val = word();
        return KeyValuePair(prop.toLower, val);
    }

    string[string] styleBody()
    {
        string[string] pairs;
        while (pos < text.length)
        {
            try
            {
                auto propVal = pair();
                pairs[propVal.key.toLower] = propVal.value;
                whitespace();
                literal(';');
                whitespace();
            }
            catch (Exception _)
            {
                auto why = ignoreUntil([';']);
                if (why == ';')
                {
                    literal(';');
                    whitespace();
                }
                else
                    break;
            }
        }
        return pairs;
    }

    char ignoreUntil(char[] chars)
    {
        while (pos < text.length)
        {
            if (chars.canFind(text[pos]))
                return text[pos];
            else
                pos++;
        }

        return '\0';
    }
}

void style(Node node)
{
    node.style.clear;

    auto element = cast(Element)node;
    if (element !is null && "style" in element.attributes)
    {
        auto pairs = new CSSParser(element.attributes["style"]).styleBody();
        foreach (property, value; pairs)
        {
            element.style[property] = value;
        }
    }

    foreach (child; node.children)
        style(child);
}