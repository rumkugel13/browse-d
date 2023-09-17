module layout;

import globals, url;
import dlangui;
import std.sumtype : match;
import std.string;
import std.algorithm : map, sum;
import std.array;
import std.algorithm : maxElement;
import node;
import displaycommand;

auto BLOCK_ELEMENTS = [
    "html", "body", "article", "section", "nav", "aside",
    "h1", "h2", "h3", "h4", "h5", "h6", "hgroup", "header",
    "footer", "address", "p", "hr", "pre", "blockquote",
    "ol", "ul", "menu", "li", "dl", "dt", "dd", "figure",
    "figcaption", "main", "div", "table", "form", "fieldset",
    "legend", "details", "summary"
];

struct WordPos
{
    int x;
    dstring s;
    Font f;
    string color;
}

struct TextPos
{
    int x, y;
    dstring s;
    Font f;
    string color;
}

enum LayoutMode
{
    Inline,
    Block
}

class BlockLayout
{
    int cursor_x = HSTEP, cursor_y = VSTEP;
    int x = 0, y = 0;
    int width = 0, height = 0;
    Node node;
    TextPos[] displayList;
    BlockLayout parent, previous;
    TextLayout previousWord;
    BlockLayout[] children;

    this(Node node, BlockLayout parent, BlockLayout previous)
    {
        this.node = node;
        this.parent = parent;
        this.previous = previous;
    }

    protected this(Node node)
    {
        this.node = node;
    }

    void layout()
    {
        this.x = parent.x;
        if (previous)
            this.y = previous.y + previous.height;
        else
            this.y = parent.y;
        this.width = parent.width;
        
        auto mode = layoutMode();
        if (mode == LayoutMode.Block)
        {
            layoutIntermediate();
        }
        else
        {
            newLine();
            recurse(this.node);
        }
        foreach (child; children)
        {
            child.layout();
        }
        
        this.height = children.map!((child) => child.height).sum();
    }

    void layoutIntermediate()
    {
        BlockLayout previous = null;
        foreach (child; node.children)
        {
            auto next = new BlockLayout(child, this, previous);
            children ~= next;
            previous = next;
        }
    }

    LayoutMode layoutMode() inout
    {
        if (typeid(node) == typeid(Text))
            return LayoutMode.Inline;
        else if (node.children.length > 0)
        {
            import std.algorithm : canFind;
            foreach (child; node.children)
            {
                auto tag = cast(Element) child;
                if (tag !is null && BLOCK_ELEMENTS.canFind(tag.tag))
                    return LayoutMode.Block;
            }

            return LayoutMode.Inline;
        }
        else
            return LayoutMode.Block;
    }

    void recurse(Node node)
    {
        if (typeid(node) == typeid(Text))
        {
            foreach (word; (cast(Text) node).text.split())
            {
                this.word(node, word);
            }
        }
        else
        {
            auto tag = cast(Element) node;
            if (tag.tag == "br")
            {
                newLine();
            }

            foreach (child; tag.children)
            {
                recurse(child);
            }
        }
    }

    void word(Node node, string word)
    {
        auto font = getFont(node);
        auto wordWidth = font.textSize(word.to!dstring).x;
        if (cursor_x + wordWidth > this.width)
        {
            newLine();
        }

        auto line = children[$-1];
        auto text = new TextLayout(node, word, line, previousWord);
        line.children ~= text;
        previousWord = text;

        cursor_x += wordWidth + font.textSize(" ").x;
    }

    Font getFont(Node node)
    {
        auto weight = "font-weight" in  node.style && node.style["font-weight"] == "bold" ? FontWeight.Bold : FontWeight.Normal;
        auto style = "font-style" in node.style && node.style["font-style"] == "italic" ? FONT_STYLE_ITALIC.to!bool : FONT_STYLE_NORMAL.to!bool;
        auto size = "font-size" in node.style ? (node.style["font-size"][0..$-2].to!float).to!int : 16;
        return FontManager.instance.getFont(size, weight, style, FontFamily.SansSerif, "Arial");
    }

    void newLine()
    {
        previousWord = null;
        cursor_x = 0;
        auto lastLine = children.length > 0 ? children[$-1] : null;
        auto newLine = new LineLayout(node, this, lastLine);
        children ~= newLine;
    }

    void paint(ref DisplayList displayList)
    {
        if ("background-color" in node.style)
        {
            string color = node.style["background-color"];
            auto x2 = this.x + this.width;
            auto y2 = this.y + this.height;
            auto rect = new DrawRect(this.x, this.y, x2, y2, color);
            displayList ~= rect;
        }

        if (layoutMode() == LayoutMode.Inline)
        foreach (textPos; this.displayList)
        {
            displayList ~= new DrawText(textPos.x, textPos.y, textPos.s, textPos.f, textPos.color);
        }

        foreach (child; children)
        {
            child.paint(displayList);
        }
    }

    override string toString() const
    {
        import std.format;
        return format("BlockLayout[%s](x=%s, y=%s, w=%s, h=%s, node=%s)", layoutMode, x, y, width, height, node);
    }
}

class DocumentLayout : BlockLayout
{
    this(Node node)
    {
        super(node);
    }

    override void layout()
    {
        this.width = WIDTH - 2 * HSTEP;
        this.x = HSTEP;
        this.y = VSTEP;
        
        auto child = new BlockLayout(node, this, null);
        children ~= child;
        child.layout();

        this.height = child.height + 2 * VSTEP;
    }

    override void paint(ref DisplayList displayList)
    {
        children[0].paint(displayList);
    }

    override string toString() const
    {
        import std.format;
        return format("DocumentLayout(x=%s, y=%s, w=%s, h=%s, node=%s)", x, y, width, height, node);
    }

    void printTree()
    {
        import std.stdio : writeln;
        writeln(this);
        foreach (child; children)
        {
            printTree(child, 2);
        }
    }

    void printTree(BlockLayout layout, int indent = 0)
    {
        import std.stdio : writeln;
        import std.range : repeat;

        writeln(' '.repeat(indent), layout);
        foreach (child; layout.children)
        {
            printTree(child, indent + 2);
        }
    }
}

class LineLayout : BlockLayout
{
    this(Node node, BlockLayout parent, BlockLayout previous)
    {
        super(node, parent, previous);
    }

    override void layout()
    {
        width = parent.width;
        x = parent.x;

        if (previous)
            y = previous.y + previous.height;
        else
            y = parent.y;
        
        foreach (word; children)
        {
            word.layout();
        }

        if (!children)
        {
            this.height = 0;
            return;
        }

        auto heights = children.map!((w) => (cast(TextLayout)w).font.height()).array;
        auto baselines = children.map!((w) => (cast(TextLayout)w).font.baseline()).array;

        auto descents = heights;
        descents[] -= baselines[];
        auto ascents = baselines;

        auto maxAscent = ascents.maxElement;
        auto totalBaseline = this.y + maxAscent * 5 / 4;

        foreach (word; children)
        {
            word.y = totalBaseline - (cast(TextLayout)word).font.baseline();
        }

        auto maxDescent = descents.maxElement;
        this.height = (maxAscent + maxDescent) * 5 / 4;
    }

    override void paint(ref DisplayList displayList)
    {
        foreach (child; children)
            child.paint(displayList);
    }

    override string toString() const
    {
        import std.format;
        return format("LineLayout(x=%s, y=%s, w=%s, h=%s, node=%s)", x, y, width, height, node);
    }
}

class TextLayout : BlockLayout
{
    string word;
    Font font;

    this(Node node, string word, BlockLayout parent, TextLayout previous)
    {
        this.word = word;
        super(node, parent, previous);
    }

    override void layout()
    {
        this.font = getFont(node);

        this.width = font.textSize(word.to!dstring).x;
        if (previous)
        {
            auto space = (cast(TextLayout)previous).font.textSize(" ").x;
            this.x = previous.x + space + previous.width;
        }
        else 
        {
            this.x = parent.x;
        }

        this.height = this.font.height();
    }

    override void paint(ref DisplayList displayList)
    {
        auto color = "color" in node.style ? node.style["color"] : "black";
        displayList ~= new DrawText(this.x, this.y, this.word.to!dstring, this.font, color);
    }

    override string toString() const
    {
        import std.format;
        return format("TextLayout(x=%s, y=%s, w=%s, h=%s, word=%s, node=%s)", x, y, width, height, word, node);
    }
}

BlockLayout[] treeToList(BlockLayout tree, ref BlockLayout[] list)
{
    list ~= tree;
    foreach(child; tree.children)
        auto _ = treeToList(child, list);
    return list;
}