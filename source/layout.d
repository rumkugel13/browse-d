module layout;

import browser, url;
import dlangui;
import std.sumtype : match;
import std.string;
import node;
import displaycommands;

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
    Node tree;
    TextPos[] displayList;
    WordPos[] line;
    BlockLayout parent, previous;
    BlockLayout[] children;

    this(Node tree, BlockLayout parent, BlockLayout previous)
    {
        this.tree = tree;
        this.parent = parent;
        this.previous = previous;
    }

    protected this(Node tree)
    {
        this.tree = tree;
    }

    void layout()
    {
        this.x = parent.x;
        if (previous !is null && typeid(previous) != typeid(NoLayout))
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
            cursor_x = cursor_y = 0;

            line = WordPos[].init;
            recurse(tree);
            flush();
        }
        foreach (child; children)
        {
            child.layout();
        }
        if (mode == LayoutMode.Block)
        {
            import std.algorithm : map, sum;
            this.height = children.map!((child) => child.height).sum();     
        }
        else 
        {
            this.height = cursor_y;
        }
    }

    void layoutIntermediate()
    {
        BlockLayout previous = new NoLayout();
        foreach (child; tree.children)
        {
            auto next = new BlockLayout(child, this, previous);
            children ~= next;
            previous = next;
        }
    }

    LayoutMode layoutMode() inout
    {
        if (typeid(tree) == typeid(node.Text))
            return LayoutMode.Inline;
        else if (tree.children.length > 0)
        {
            import std.algorithm : canFind;
            foreach (child; tree.children)
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

    void recurse(Node tree)
    {
        if (typeid(tree) == typeid(node.Text))
        {
            foreach (word; (cast(node.Text) tree).text.split())
            {
                this.word(tree, word);
            }
        }
        else
        {
            auto tag = cast(Element) tree;
            if (tag.tag == "br")
            {
                flush();
            }

            foreach (child; tag.children)
            {
                recurse(child);
            }
        }
    }

    void word(Node node, string word)
    {
        auto color = "color" in node.style ? node.style["color"] : "black";
        auto font = getFont(node);
        auto wordWidth = font.textSize(word.to!dstring).x;
        if (cursor_x + wordWidth > this.width)
        {
            flush();
        }

        line ~= WordPos(cursor_x, word.to!dstring, font, color);
        cursor_x += wordWidth + font.textSize(" ").x;
    }

    Font getFont(Node node)
    {
        auto weight = "font-weight" in  node.style && node.style["font-weight"] == "bold" ? FontWeight.Bold : FontWeight.Normal;
        auto style = "font-style" in node.style && node.style["font-style"] == "italic" ? FONT_STYLE_ITALIC.to!bool : FONT_STYLE_NORMAL.to!bool;
        auto size = "font-size" in node.style ? (node.style["font-size"][0..$-2].to!float * 0.75f).to!int : 16;
        return FontManager.instance.getFont(size, weight, style, FontFamily.SansSerif, "Arial");
    }

    void flush()
    {
        if (line.empty)
            return;

        import std.algorithm : map;
        import std.array;

        auto heights = line.map!((w) => w.f.height()).array;
        auto baselines = line.map!((w) => w.f.baseline()).array;

        auto descents = heights;
        descents[] -= baselines[];
        auto ascents = baselines;

        import std.algorithm : maxElement;

        auto maxAscent = ascents.maxElement;
        auto totalBaseline = cursor_y + maxAscent * 5 / 4;

        foreach (wordpos; line)
        {
            auto x = this.x + wordpos.x;
            auto y = this.y + totalBaseline - wordpos.f.baseline();
            displayList ~= TextPos(x, y, wordpos.s, wordpos.f, wordpos.color);
        }

        cursor_x = 0;
        line.length = 0;

        auto maxDescent = descents.maxElement;
        cursor_y = totalBaseline + maxDescent * 5 / 4;
    }

    void paint(ref DisplayList displayList)
    {
        if ("background-color" in tree.style)
        {
            string color = tree.style["background-color"];
            auto x2 = this.x + this.width;
            auto y2 = this.y + this.height;
            auto rect = new DrawRect(this.x, this.y, x2, y2, color);
            displayList ~= rect;
        }

        // if (layoutMode() == LayoutMode.Inline)
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
        return format("BlockLayout[%s](x=%s, y=%s, w=%s, h=%s, node=%s)", layoutMode, x, y, width, height, tree);
    }
}

class DocumentLayout : BlockLayout
{
    this(Node tree)
    {
        super(tree);
    }

    override void layout()
    {
        this.width = WIDTH - 2 * HSTEP;
        this.x = HSTEP;
        this.y = VSTEP;
        
        auto child = new BlockLayout(tree, this, new NoLayout());
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
        return format("DocumentLayout(x=%s, y=%s, w=%s, h=%s)", x, y, width, height);
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

class NoLayout : BlockLayout
{
    this()
    {
        super(new None());
    }

    override void layout()
    {
    }

    override void paint(ref DisplayList displayList)
    {
        
    }
}
