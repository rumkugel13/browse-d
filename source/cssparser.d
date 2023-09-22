module cssparser;

import std.ascii : isWhite, isAlphaNum;
import std.algorithm : canFind, startsWith, endsWith;
import std.string : toLower;
import std.typecons : tuple, Tuple;
import std.conv : to;
import node;
import selector;

alias KeyValuePair = Tuple!(string, "key", string, "value");
alias Body = string[string];
// alias Rule = Tuple!(Selector, "selector", Body, "body");

struct Rule
{
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
            throw new Exception("Parsing error, expected a word, got " ~ ((pos < text.length) ? text[pos].to!string : "EOF"));

        return text[start..pos];
    }

    void literal(char lit)
    {
        if (!(pos < text.length && text[pos] == lit))
            throw new Exception("Parsing error, expected a literal " ~ lit ~ " got " ~ ((pos < text.length) ? text[pos].to!string : "EOF"));
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

    Body styleBody()
    {
        Body pairs;
        while (pos < text.length && text[pos] != '}')
        {
            try
            {
                auto propVal = pair();
                pairs[propVal.key.toLower] = propVal.value;
                whitespace();
                literal(';');
                whitespace();
            }
            catch (Exception e)
            {
                import std.stdio;
                writeln(e.msg);
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

    Selector selector()
    {
        auto tag = word().toLower;
        Selector result = tag.startsWith(".") ? new ClassSelector(tag) : new TagSelector(tag);
        whitespace();
        while (pos < text.length && text[pos] != '{')
        {
            tag = word().toLower;
            auto descendant = tag.startsWith(".") ? new ClassSelector(tag) : new TagSelector(tag);
            result = new DescendantSelector(result, descendant);
            whitespace();
        }
        return result;
    }

    Rule[] parse()
    {
        Rule[] rules;
        while (pos < text.length)
        {
            try
            {
                whitespace();
                auto selector = selector();
                literal('{');
                whitespace();
                auto b = styleBody();
                literal('}');
                rules ~= Rule(selector, b);
            }
            catch (Exception e)
            {
                import std.stdio;
                writeln(e.msg);
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

immutable string[string] INHERITED_PROPERTIES;
shared static this() 
{
    INHERITED_PROPERTIES = [
    "font-size": "16px",
    "font-style": "normal",
    "font-weight": "normal",
    "color": "black",
    ];
}

void style(Node node, Rule[] rules)
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
        if (!rule.selector.matches(node)) continue;
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