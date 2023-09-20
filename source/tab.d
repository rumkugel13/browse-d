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
import std.datetime.stopwatch : StopWatch, AutoStart;

class Tab
{
    URL url;
    Rule[] defaultStyleSheet;
    DocumentLayout document;
    DisplayList displayList;
    int scroll;
    URL[] history;
    StopWatch sw;

    this()
    {
        defaultStyleSheet = new CSSParser(readText("browser.css")).parse();
    }

    void load(URL url)
    {
        this.history ~= url;
        this.url = url;
        this.scroll = 0;
        sw = StopWatch(AutoStart.yes);
        HttpResponse response = url.request();
        handleResponse(response);
    }

    void handleResponse(HttpResponse response)
    {
        writeln("Request took " ~ sw.peek().toString);
        sw.reset();
        auto parser = new HTMLParser(response.htmlBody);
//         auto test = "<pre class='sourceCode python'><code class='sourceCode python'><span id='cb6-1'><a href='#cb6-1' aria-hidden='true' tabindex='-1'></a><span class='kw'>class</span> URL:</span>
// <span id='cb6-2'><a href='#cb6-2' aria-hidden='true' tabindex='-1'></a>    <span class='kw'>def</span> <span class='fu'>__init__</span>(<span class='va'>self</span>, url):</span>
// <span id='cb6-3'><a href='#cb6-3' aria-hidden='true' tabindex='-1'></a>        <span class='va'>self</span>.scheme, url <span class='op'>=</span> url.split(<span class='st'>'://'</span>, <span class='dv'>1</span>)</span>
// <span id='cb6-4'><a href='#cb6-4' aria-hidden='true' tabindex='-1'></a>        <span class='cf'>assert</span> <span class='va'>self</span>.scheme <span class='op'>==</span> <span class='st'>'http'</span>, <span class='op'>\\</span></span>
// <span id='cb6-5'><a href='#cb6-5' aria-hidden='true' tabindex='-1'></a>            <span class='st'>'Unknown scheme </span><span class='sc'>{}</span><span class='st'>'</span>.<span class='bu'>format</span>(<span class='va'>self</span>.scheme)</span></code></pre>";
//         auto parser = new HTMLParser(test);
        auto tree = parser.parse();
        parser.printTree(tree, 0);
        writeln("Parsing took " ~ sw.peek().toString);
        sw.reset();
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
        writeln("Requests took " ~ sw.peek().toString);
        sw.reset();
        
        cssparser.style(tree, rules.sort.array);
        writeln("Styling took " ~ sw.peek().toString);
        sw.reset();

        // auto cssTest = "a {p :v} ";
        // auto rules = new CSSParser(cssTest).parse();
        foreach (rule; rules)
            writeln(rule);
        // if (rules.length > 0)
        //     return;

        document = new DocumentLayout(tree);
        document.layout();
        // document.printTree();
        writeln("Layout took " ~ sw.peek().toString);
        sw.reset();

        this.displayList.length = 0;
        document.paint(this.displayList);
        writeln("Painting took " ~ sw.peek().toString);
        sw.stop();

        // foreach(command; this.displayList)
        // {
        //     writeln(command);
        // }
    }

    void draw(DrawBuf buf, Rect rect)
    {
        foreach (command; displayList)
        {
            if (command.top > scroll + HEIGHT - CHROME_PX)
                continue;
            if (command.bottom < scroll)
                continue;
            command.execute(scroll - CHROME_PX, buf);
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
        auto maxY = max(document.height - (HEIGHT - CHROME_PX), 0);
        scroll = min(scroll + SCROLL_STEP, maxY);
    }

    void scrollUp()
    {
        import std.algorithm : max, min;
        scroll = max(scroll - SCROLL_STEP, 0);
    }

    void goBack()
    {
        if (history.length > 1)
        {
            history.length--;
            auto back = history[$-1];
            history.length--;
            load(back); // note: load adds the url back to history
        }
    }
}