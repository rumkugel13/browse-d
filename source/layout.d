module layout;

import globals, url;
import dlangui;
import std.sumtype : match;
import std.string;
import std.algorithm : map, sum, maxElement;
import std.array;
import std.conv : to;
import node;
import displaycommand;
import std.stdio : writeln;

auto BLOCK_ELEMENTS = [
    "html", "body", "article", "section", "nav", "aside",
    "h1", "h2", "h3", "h4", "h5", "h6", "hgroup", "header",
    "footer", "address", "p", "hr", "pre", "blockquote",
    "ol", "ul", "menu", "li", "dl", "dt", "dd", "figure",
    "figcaption", "main", "div", "table", "form", "fieldset",
    "legend", "details", "summary"
];

Font[FontKey] FONT_CACHE;

Font getCachedFont(int size, string weight, string slant, string family)
{
    auto key = FontKey(size, weight, slant, family);
    if (key !in FONT_CACHE)
    {
        FontFamily fontFamily;
        string fontFace;
        switch (family)
        {
            case "sans-serif":
                fontFamily = FontFamily.SansSerif;
                fontFace = "Arial";
                break;
            case "serif":
                fontFamily = FontFamily.Serif;
                fontFace = "Times New Roman";
                break;
            case "monospace":
                fontFamily = FontFamily.MonoSpace;
                fontFace = "Courier";
                break;
            default:
                fontFamily = FontFamily.Unspecified;
                fontFace = "Unspecified";
                break;
        }
        FontWeight fontWeight = weight == "bold" ? FontWeight.Bold : FontWeight.Normal;
        auto italic = slant == "italic";
        auto font = FontManager.instance.getFont(size, fontWeight, italic, fontFamily, fontFace);
        FONT_CACHE[key] = font;
    }
    return FONT_CACHE[key];
}

Font getFont(Node node)
{
    auto weight = "font-weight" in node.style ? node.style["font-weight"] : "normal";
    auto style = "font-style" in node.style ? node.style["font-style"] : "normal";
    auto size = "font-size" in node.style && node.style["font-size"].length > 2 ? node
        .style["font-size"][0 .. $ - 2].to!float
        .to!int : 16;
    auto family = "font-family" in node.style ? node.style["font-family"] : "sans-serif";
    return getCachedFont(size, weight, style, family);
}

int linespace(Font font)
{
    return font.height();
}

int wordWidth(Font font, string word)
{
    return font.textSize(word.to!dstring).x;
}

struct FontKey
{
    int size;
    string weight;
    string slant;
    string family;
}

enum LayoutMode
{
    Inline,
    Block
}

class BlockLayout
{
    int cursor_x = HSTEP;
    int x = 0, y = 0;
    int width = 0, height = 0;
    Node node;
    BlockLayout parent, previous;
    BlockLayout previousWord;
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
        BlockLayout prev = null;
        foreach (child; node.children)
        {
            auto next = new BlockLayout(child, this, prev);
            children ~= next;
            prev = next;
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
        else if (typeid(node) == typeid(Element))
        {
            auto element = cast(Element) node;
            if (element && element.tag == "input")
            {
                return LayoutMode.Inline;
            }
            else
                return LayoutMode.Block;
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
            else if (tag.tag == "input" || tag.tag == "button")
            {
                input(tag);
            }
            else
            foreach (child; tag.children)
            {
                recurse(child);
            }
        }
    }

    void input(Node node)
    {
        auto w = INPUT_WIDTH_PX;
        if (cursor_x + w > WIDTH)
            newLine();
        auto line = children[$-1];
        auto input = new InputLayout(node, line, previousWord);
        line.children ~= input;
        previousWord = input;
        auto font = getFont(node);
        cursor_x += w + font.wordWidth(" ");
    }

    void word(Node node, string word)
    {
        auto font = getFont(node);
        auto wordWidth = font.wordWidth(word);
        if (cursor_x + wordWidth > this.width)
        {
            newLine();
        }

        auto line = children[$-1];
        auto text = new TextLayout(node, word, line, previousWord);
        line.children ~= text;
        previousWord = text;

        cursor_x += wordWidth + font.wordWidth(" ");
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
        auto element = cast(Element) node;
        bool isAtomic = (element && (element.tag == "input" || element.tag == "button"));

        if (!isAtomic)
        if ("background-color" in node.style)
        {
            string color = node.style["background-color"];
            auto x2 = this.x + this.width;
            auto y2 = this.y + this.height;
            displayList ~= new DrawRect(this.x, this.y, x2, y2, color);
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

        auto el = cast(Element) node;
        if (el && "text-align" in el.style && el.style["text-align"] != "left")
        {
            auto childrenWidth = (children[$-1].x + children[$-1].width) - children[0].x;
            auto adjust = 0;
            if (el.style["text-align"] == "center")
                adjust = (this.width - childrenWidth) / 2;
            else if (el.style["text-align"] == "right")
                adjust = (this.width - childrenWidth);
            
            foreach(child;children)
            {
                child.x += adjust;
            }
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
        this.height = (maxAscent + maxDescent).to!int * 5 / 4;
    }

    override void paint(ref DisplayList displayList)
    {
        foreach (child; children)
            child.paint(displayList);
    }

    override string toString() const
    {
        import std.format;
        return format("LineLayout(x=%s, y=%s, w=%s, h=%s)", x, y, width, height);
    }
}

class TextLayout : BlockLayout
{
    string word;
    Font font;

    this(Node node, string word, BlockLayout parent, BlockLayout previous)
    {
        this.word = word;
        super(node, parent, previous);
    }

    override void layout()
    {
        this.font = getFont(node);

        this.width = font.wordWidth(word);
        if (previous)
        {
            auto space = (cast(TextLayout)previous).font.wordWidth(" ");
            this.x = previous.x + space + previous.width;
        }
        else 
        {
            this.x = parent.x;
        }

        this.height = linespace(this.font);
    }

    override void paint(ref DisplayList displayList)
    {
        auto color = "color" in node.style ? node.style["color"] : "black";
        displayList ~= new DrawText(this.x, this.y, this.word, this.font, color);
    }

    override string toString() const
    {
        import std.format;
        return format("TextLayout(x=%s, y=%s, w=%s, h=%s, word=%s)", x, y, width, height, word);
    }
}

auto INPUT_WIDTH_PX = 200;

class InputLayout : TextLayout
{
    this(Node node, BlockLayout parent, BlockLayout previous)
    {
        super(node, string.init, parent, previous);
    }

    override void layout()
    {
        this.font = getFont(node);

        this.width = INPUT_WIDTH_PX;
        if (previous)
        {
            auto space = (cast(TextLayout)previous).font.wordWidth(" ");
            this.x = previous.x + space + previous.width;
        }
        else 
        {
            this.x = parent.x;
        }

        this.height = linespace(this.font);
    }

    override void paint(ref DisplayList displayList)
    {
        if ("background-color" in node.style)
        {
            string color = node.style["background-color"];
            auto x2 = this.x + this.width;
            auto y2 = this.y + this.height;
            displayList ~= new DrawRect(this.x, this.y, x2, y2, color);
        }

        string text = "";
        auto element = cast(Element) node;
        if (element)
        {
            if (element.tag == "input" && "value" in element.attributes)
            {
                text = element.attributes["value"];
            }
            else 
            {
                if (element.children.length == 1)
                {
                    auto textNode = cast(Text)element.children[0];
                    if (textNode)
                    {
                        text = textNode.text;
                    }
                    else {
                        writeln("Layout: Ignoring HTML contents inside button");
                        text = "";
                    }
                }
                else 
                {
                    writeln("Layout: Ignoring HTML contents inside button");
                        text = "";
                }
            }
        }

        auto color = "color" in node.style ? node.style["color"] : "black";
        displayList ~= new DrawText(this.x, this.y, text, this.font, color);

        if (node.isFocused)
        {
            auto cx = x + font.wordWidth(text);
            displayList ~= new DrawLine(cx, y, cx, y + height, "black", 1);
        }
    }

    override string toString() const
    {
        import std.format;
        return format("InputLayout(x=%s, y=%s, w=%s, h=%s, node=%s)", x, y, width, height, node);
    }
}

BlockLayout[] treeToList(BlockLayout tree, ref BlockLayout[] list)
{
    list ~= tree;
    foreach(child; tree.children)
        auto _ = treeToList(child, list);
    return list;
}