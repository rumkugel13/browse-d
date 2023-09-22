module selector;

import node;
import std.string : split;
import std.algorithm : any;

abstract class Selector
{
    int priority;

    bool matches(Node node)
    {
        return false;
    }

    override string toString() const pure @safe
    {
        return "";
    }
}

class TagSelector : Selector
{
    string tag;

    this(string tag)
    {
        this.tag = tag;
        this.priority = 1;
    }

    override bool matches(Node node)
    {
        auto element = cast(Element)node;
        return element !is null && this.tag == element.tag;
    }

    override string toString() const pure @safe
    {
        return "TagSelector(tag="~tag~")";
    }
}

class ClassSelector : Selector
{
    string classTag;

    this(string classTag)
    {
        this.classTag = classTag[1..$];
        this.priority = 10;
    }

    override bool matches(Node node)
    {
        auto element = cast(Element)node;
        if (element && "class" in element.attributes && element.attributes["class"].split().any!(a => a == classTag))
        {
            return true;
        }
        return false;
    }

    override string toString() const pure @safe
    {
        return "ClassSelector(tag="~classTag~")";
    }
}

class DescendantSelector : Selector 
{
    Selector ancestor, descendant;

    this(Selector ancestor, Selector descendant)
    {
        this.ancestor = ancestor;
        this.descendant = descendant;
        this.priority = ancestor.priority + descendant.priority;
    }

    override bool matches(Node node)
    {
        if (!descendant.matches(node)) return false;
        while (node.parent)
        {
            if (ancestor.matches(node.parent)) return true;
            node = node.parent;
        }
        return false;
    }

    override string toString() const pure @safe
    {
        return "DescendantSelector(ancestor=" ~ancestor.toString~", descendant="~descendant.toString~")";
    }
}