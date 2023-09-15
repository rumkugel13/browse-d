module htmlparser;

import node;
import std.string : empty, startsWith, split, toLower;
import std.algorithm : canFind;

auto SELF_CLOSING_TAGS = [
    "area", "base", "br", "col", "embed", "hr", "img", "input",
    "link", "meta", "param", "source", "track", "wbr",
];

auto HEAD_TAGS = [
        "base", "basefont", "bgsound", "noscript",
        "link", "meta", "title", "style", "script",
    ];

struct TagAttribute
{
    string tag;
    string[string] attributes;
}

class HTMLParser 
{
    string htmlBody;
    Node[] unfinished;

    this(string htmlBody)
    {
        this.htmlBody = htmlBody;
    }

    Node parse()
    {
        bool inTag = false;
        string text = "";

        foreach(c; htmlBody)
        {
            if (c == '<')
            {
                inTag = true;
                if (!text.empty) 
                    addText(text);
                text = "";
            }
            else if (c == '>')
            {
                inTag = false;
                addTag(text);
                text = "";
            }
            else
            {
                text ~= c; // todo: replace with appender or index range
            }
        }
        if (!inTag && !text.empty) 
            addText(text);
        return finish();
    }

    void addText(string text)
    {
        import std.ascii : isWhite;
        if (text[0].isWhite()) 
            return;
        implicitTags("");
        auto parent = unfinished[$-1];
        auto node = new Text(text, parent);
        parent.children ~= node;
    }

    void addTag(string tag)
    {
        auto tagAttribute = getAttributes(tag);
        tag = tagAttribute.tag;
        if (tag.startsWith("!")) return;
        implicitTags(tag);
        if (tag.startsWith("/"))
        {
            if (unfinished.length == 1) return;
            auto node = unfinished[$-1];
            unfinished.length--;
            auto parent = unfinished[$-1];
            parent.children ~= node;
        }
        else if (SELF_CLOSING_TAGS.canFind(tag))
        {
            auto parent = unfinished[$-1];
            auto node = new Element(tag, tagAttribute.attributes, parent);
            parent.children ~= node;
        }
        else 
        {
            auto parent = unfinished.length > 0 ? unfinished[$-1] : new None();
            auto node = new Element(tag, tagAttribute.attributes, parent);
            unfinished ~= node;
        }
    }

    TagAttribute getAttributes(string text)
    {
        auto parts = text.split();  // todo: correctly parse attributes with whitespace in strings
        auto tag = parts[0].toLower();
        string[string] attributes;
        foreach (attrpair; parts[1..$])
        {
            if (attrpair.canFind("="))
            {
                auto pair = attrpair.split("=");
                auto value = pair[1];
                if (value.length > 2 && value.canFind("'", "\""))
                    value = value[1..$-1];
                attributes[pair[0].toLower()] = value;
            }
            else
            {
                attributes[attrpair.toLower()] = "";
            }
        }
        return TagAttribute(tag, attributes);
    }

    void implicitTags(string tag)
    {
        while(true)
        {
            string[] openTags;
            foreach (node; unfinished)
            {
                Element e = (cast(Element)node);
                if (e !is null)
                    openTags ~= e.tag;
            }
            if (openTags.empty && tag != "html")
            {
                addTag("html");
            }
            else if (openTags.length == 1 && openTags[0] == "html" && !["head", "body", "/html"].canFind(tag))
            {
                if (HEAD_TAGS.canFind(tag))
                    addTag("head");
                else 
                    addTag("body");
            }
            else if (openTags.length == 2 && openTags[0] == "html" && openTags[1] == "head" && !(["/head"] ~ HEAD_TAGS).canFind(tag))
            {
                addTag("/head");
            }
            else
                break;
        }
    }

    Node finish()
    {
        if (unfinished.length == 0)
            addTag("html");
        
        while (unfinished.length > 1)
        {
            auto node = unfinished[$-1];
            unfinished.length--;
            auto parent = unfinished[$-1];
            parent.children ~= node;
        }

        auto last = unfinished[$-1];
        unfinished.length--;
        return last;
    }

    void printTree(Node node, int indent = 0)
    {
        import std.stdio : writeln;
        import std.range : repeat;
        writeln(' '.repeat(indent), node);
        foreach (child; node.children)
        {
            printTree(child, indent + 2);
        }
    }
}