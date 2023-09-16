module node;

abstract class Node
{
    Node[] children;
    Node parent;
    string[string] style;

    override string toString() const pure @safe
    {
        return "";
    }
}

class Text : Node
{
    string text;

    this(string text, Node parent)
    {
        this.text = text;
        this.parent = parent;
    }

    override string toString() const pure @safe
    {
        return text;
    }
}

alias Attributes = string[string];

class Element : Node
{
    string tag;
    Attributes attributes;

    this(string tag, Attributes attributes, Node parent)
    {
        this.tag = tag;
        this.attributes = attributes;
        this.parent = parent;
    }

    override string toString() const pure @safe
    {
        import std.conv : to;
        return "<" ~ tag ~ " " ~ attributes.to!string ~ ">";
    }
}

class None : Node
{
}

Node[] treeToList(Node tree, ref Node[] list)
{
    list ~= tree;
    foreach(child; tree.children)
        auto _ = treeToList(child, list);
    return list;
}