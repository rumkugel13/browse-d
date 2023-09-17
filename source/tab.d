module tab;

import std.file : readText;
import std.algorithm : sort;
import std.range : array;
import std.stdio : writeln;
import dlangui : DrawBuf, Rect;
import cssparser;
import url;
import htmlparser;
import node;
import layout;
import displaycommand;
import globals;

class Tab
{
    URL url;
    Rule[] defaultStyleSheet;
    DocumentLayout document;
    DisplayList displayList;
    int scroll;

    this()
    {
        defaultStyleSheet = new CSSParser(readText("browser.css")).parse();
    }

    void load(URL url)
    {
        this.url = url;
        this.scroll = 0;
        HttpResponse response = url.request();
        auto parser = new HTMLParser(response.htmlBody);
        // auto test = "<a href=\"http://test/0\">Click me</a>";
        // auto parser = new HTMLParser(test);
        auto tree = parser.parse();
        // parser.printTree(tree, 0);

        auto rules = defaultStyleSheet.dup;

        string[] links;
        Node[] list;
        foreach(node; treeToList(tree, list))
        {
            auto element = cast(Element)node;
            if (element !is null && element.tag == "link" && "href" in element.attributes 
                && "rel" in element.attributes && element.attributes["rel"] == "stylesheet")
            {
                links ~= element.attributes["href"];
            }
        }

        foreach (link; links)
        {
            HttpResponse r;
            try
            {
                r = url.resolve(link).request();
            }
            catch (Exception _) 
            {
                continue;
            }
            rules ~= new CSSParser(r.htmlBody).parse();
        }
        
        cssparser.style(tree, rules.sort.array);

        // auto cssTest = "a {p :v} ";
        // auto rules = new CSSParser(cssTest).parse();
        // writeln(rules);
        // if (rules.length > 0)
        //     return;

        document = new DocumentLayout(tree);
        document.layout();
        // document.printTree();

        this.displayList.length = 0;
        document.paint(this.displayList);

        // foreach(command; this.displayList)
        // {
        //     writeln(command);
        // }
    }

    void draw(DrawBuf buf, Rect rect)
    {
        foreach (command; displayList)
        {
            if (command.top > scroll + HEIGHT)
                continue;
            if (command.bottom < scroll)
                continue;
            command.execute(scroll, buf);
        }
    }

    void click(int x, int y)
    {
        y += scroll;

        BlockLayout[] list, objs;
        foreach(node; treeToList(document, list))
        {
            if (node.x <= x && x < node.x + node.width &&
                node.y <= y && y < node.y + node.height)
            {
                objs ~= node;
            }
        }

        if (objs.length == 0) return;
        auto elt = objs[$-1].node;

        while (elt)
        {
            // writeln(elt);
            auto text = cast(Text)elt;
            auto element = cast(Element)elt;
            if (text !is null) 
            {
                
            }
            else if (element.tag == "a" && "href" in element.attributes)
            {
                auto url = this.url.resolve(element.attributes["href"]);
                load(url);
                return;
            }
            elt = elt.parent;
        }
    }

    void scrollDown()
    {
        import std.algorithm : max, min;
        auto maxY = max(document.height - HEIGHT, 0);
        scroll = min(scroll + SCROLL_STEP, maxY);
    }

    void scrollUp()
    {
        import std.algorithm : max, min;
        scroll = max(scroll - SCROLL_STEP, 0);
    }
}