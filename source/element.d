module element;

import node;

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