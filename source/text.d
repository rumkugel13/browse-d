module text;

import node;

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