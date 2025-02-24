module cssparser;

import std.ascii : isWhite, isAlphaNum;
import std.algorithm : canFind, startsWith, endsWith;
import std.string : toLower, indexOf;
import std.typecons : tuple, Tuple;
import std.conv : to;
import node;
import selector;

alias KeyValuePair = Tuple!(string, "key", string, "value");
alias Body = string[string];

struct Rule
{
    string media;
    Selector selector;
    Body body;

    int opCmp(ref const Rule r) const 
    {  
        return (selector.priority > r.selector.priority) - (selector.priority < r.selector.priority);
    }
}

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
            throw new Exception("Parsing error, expected a word, got " ~ ((pos < text.length) ? text[pos].to!string
                    : "EOF"));

        return text[start..pos];
    }

    void literal(char lit)
    {
        if (!(pos < text.length && text[pos] == lit))
            throw new Exception("Parsing error, expected a literal " ~ lit ~ " got " ~ (
                    (pos < text.length) ? text[pos].to!string : "EOF"));
        pos++;
    }

    string untilChar(char[] chars)
    {
        auto start = this.pos;
        while(pos < text.length && !chars.canFind(text[pos]))
            pos++;
        return text[start..pos];
    }

    KeyValuePair pair(char[] until)
    {
        auto prop = word();
        whitespace();
        literal(':');
        whitespace();
        auto val = untilChar(until);
        return KeyValuePair(prop.toLower, val);
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

    Body styleBody()
    {
        Body pairs;
        while (pos < text.length && text[pos] != '}')
        {
            try
            {
                auto propVal = pair([';','}']);
                pairs[propVal.key.toLower] = propVal.value;
                whitespace();
                literal(';');
                whitespace();
            }
            catch (Exception e)
            {
                import std.stdio;
                writeln("CSSParser: " ~ e.msg);
                auto why = ignoreUntil([';', '}']);
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

    Selector simpleSelector()
    {
        auto tag = word().toLower;
        if (tag[1..$].canFind("."))
        {
            Selector[] sequence;
            auto idx = tag.indexOf(".", 1);
            auto first = tag[0..idx];
            sequence ~= first.startsWith(".") ? new ClassSelector(first) : new TagSelector(first);
            while (idx != -1)
            {
                auto baseIdx = idx;
                idx = tag.indexOf(".", idx + 1);
                auto next = string.init;
                if (idx != -1)
                    next = tag[baseIdx..idx];
                else
                    next = tag[baseIdx..$];
                sequence ~= new ClassSelector(next);
            }
            return new SelectorSequence(sequence);
        }
        return tag.startsWith(".") ? new ClassSelector(tag) : new TagSelector(tag);
    }

    Selector[] selectorList()
    {
        Selector[] list;
        Selector selector = simpleSelector();
        whitespace();
        while (pos < text.length && text[pos] != '{')
        {
            if (text[pos] == ',')
            {
                list ~= selector;
                literal(',');
                whitespace();
                selector = simpleSelector();
                whitespace();
            }
            else
            {
                auto descendant = simpleSelector();
                selector = new DescendantSelector(selector, descendant);
                whitespace();
            }
        }
        list ~= selector;
        return list;
    }

    KeyValuePair mediaQuery()
    {
        literal('@');
        auto word = word();
        if (word != "media")
            throw new Exception("Unsupported media query: " ~ word);
        // assert(word() == "media");
        whitespace();
        literal('(');
        auto pair = pair();
        whitespace();
        literal(')');
        return pair;
    }

    Rule[] parse()
    {
        Rule[] rules;
        auto media = string.init;
        whitespace();
        while (pos < text.length)
        {
            try
            {
                if (text[pos] == '@' && media == string.init)
                {
                    auto propVal = mediaQuery();
                    if (propVal.key == "prefers-color-scheme" && ["dark", "light"].canFind(propVal.value))
                    {
                        media = propVal.value;
                    }
                    whitespace();
                    literal('{');
                    whitespace();
                }
                else if(text[pos] == '}' && media != string.init)
                {
                    literal('}');
                    media = string.init;
                    whitespace();
                }
                else
                {
                    auto selectorList = selectorList();
                    literal('{');
                    whitespace();
                    auto b = styleBody();
                    literal('}');
                    whitespace();
                    foreach (selector; selectorList)
                    {
                        rules ~= Rule(media, selector, b);
                    }
                }
            }
            catch (Exception e)
            {
                import std.stdio;
                writeln("CSSParser: " ~ e.msg);
                auto why = ignoreUntil(['}']);
                if (why == '}')
                {
                    literal('}');
                    whitespace();
                }
                else
                    break;
            }
        }
        return rules;
    }
}

string[string] INHERITED_PROPERTIES;
shared static this() 
{
    INHERITED_PROPERTIES = [
    "font-size": "16px",
    "font-style": "normal",
    "font-weight": "normal",
    "font-family": "sans-serif",
    "color": "black",
    "text-align": "left"
    ];
}

void style(Node node, Rule[] rules, bool darkMode = false)
{
    node.style.clear;

    foreach (property, defaultValue; INHERITED_PROPERTIES)
    {
        if (node.parent && property in node.parent.style)
        {
            node.style[property] = node.parent.style[property];
        }
        else
        {
            node.style[property] = defaultValue;
        }
    }

    foreach (rule; rules)
    {
        if (rule.media != string.init)
        {
            if ((rule.media == "dark") != darkMode)
                continue;
        }
        if (!rule.selector.matches(node))
            continue;
        foreach (prop, b; rule.body)
        {
            node.style[prop] = b;
        }
    }

    auto element = cast(Element)node;
    if (element !is null && "style" in element.attributes)
    {
        auto pairs = new CSSParser(element.attributes["style"]).styleBody();
        foreach (property, value; pairs)
        {
            element.style[property] = value;
        }
    }

    if (node.style["font-size"].endsWith("%"))
    {
        string parentFontSize;
        if (node.parent && "font-size" in node.parent.style)
        {
            parentFontSize = node.parent.style["font-size"];
        }
        else {
            parentFontSize = INHERITED_PROPERTIES["font-size"];
        }
        auto nodePct = node.style["font-size"][0..$-1].to!float / 100f;
        auto parentPx = parentFontSize[0..$-2].to!float;
        node.style["font-size"] = (nodePct * parentPx).to!string ~ "px";
    }
    else if (!node.style["font-size"].endsWith("px"))
    {
        node.style["font-size"] = "16px";
    }

    foreach (child; node.children)
        style(child, rules);
}

int cascadePriority(Rule rule)
{
    return rule.selector.priority;
}