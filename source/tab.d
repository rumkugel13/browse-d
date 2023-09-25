module tab;

import std.file : readText;
import std.algorithm : sort, max, min;
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
import urllibparse : quote;

class Tab
{
    URL url;
    Rule[] defaultStyleSheet, rules;
    DocumentLayout document;
    DisplayList displayList;
    Node tree;
    int scroll;
    URL[] history;
    StopWatch sw;
    Element focus;
    bool darkMode;

    this(bool darkMode = false)
    {
        defaultStyleSheet = new CSSParser(readText("browser.css")).parse();
        this.darkMode = darkMode;
    }

    void load(URL url, string body)
    {
        this.history ~= url;
        this.url = url;
        this.scroll = 0;
        sw = StopWatch(AutoStart.yes);
        HttpResponse response = url.request(body);
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
        tree = parser.parse();
        parser.printTree(tree, 0);
        writeln("Parsing took " ~ sw.peek().toString);
        sw.reset();
        rules = defaultStyleSheet.dup;

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

        render();
        writeln("Rendering took " ~ sw.peek().toString);
        sw.stop();
    }

    void render()
    {
        if (darkMode)
            INHERITED_PROPERTIES["color"] = "white";
        else
            INHERITED_PROPERTIES["color"] = "black";
        style(tree, rules.sort.array);
        foreach (rule; rules)
            writeln(rule);
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
            if (command.top > scroll + HEIGHT - CHROME_PX)
                continue;
            if (command.bottom < scroll)
                continue;
            command.execute(scroll - CHROME_PX, buf);
        }
    }

    void click(int x, int y)
    {
        focus = null;
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
                load(url, string.init);
                return;
            }
            else if (element.tag == "input")
            {
                element.attributes["value"] = "";
                if (focus)
                {
                    focus.isFocused = false;
                }
                focus = element;
                element.isFocused = true;
                render();
                return;
            }
            else if (element.tag == "button")
            {
                while (elt)
                {
                    auto tagElt = cast(Element)elt;
                    if (tagElt && tagElt.tag == "form" && "action" in tagElt.attributes)
                    {
                        submitForm(tagElt);
                        return;
                    }
                    elt = elt.parent;
                }
            }
            elt = elt.parent;
        }
    }

    void submitForm(Element elt)
    {
        Element[] inputs;
        Node[] list;
        foreach(node; treeToList(elt, list))
        {
            auto element = cast(Element)node;
            if (element !is null && element.tag == "input" && "name" in element.attributes)
            {
                inputs ~= element;
            }
        }

        string reqBody;
        foreach (input; inputs)
        {
            auto name = quote(input.attributes["name"]);
            auto value = quote("value" in input.attributes ? input.attributes["value"] : "");
            reqBody ~= "&" ~ name ~ "=" ~ value;
        }
        reqBody = reqBody[1..$];
        writeln(reqBody);

        auto url = url.resolve(elt.attributes["action"]);
        load(url, reqBody);
    }

    void backspace()
    {
        if (focus)
        {
            auto value = focus.attributes["value"];
            if (value.length > 0)
                value.length--;
            focus.attributes["value"] = value;
            render();
        }
    }

    void keyPress(string text)
    {
        if (focus)
        {
            focus.attributes["value"] ~= text;
            render();
        }
    }

    void scrollDown()
    {
        auto maxY = max(document.height - (HEIGHT - CHROME_PX), 0);
        scroll = min(scroll + SCROLL_STEP, maxY);
    }

    void scrollUp()
    {
        scroll = max(scroll - SCROLL_STEP, 0);
    }

    void jumpUp()
    {
        scroll = 0;
    }

    void jumpDown()
    {
        scroll = max(document.height - (HEIGHT - CHROME_PX), 0);
    }

    void pageUp()
    {
        scroll = max(scroll - PAGE_STEP, 0);
    }

    void pageDown()
    {
        auto maxY = max(document.height - (HEIGHT - CHROME_PX), 0);
        scroll = min(scroll + PAGE_STEP, maxY);
    }

    void goBack()
    {
        if (history.length > 1)
        {
            history.length--;
            auto back = history[$-1];
            history.length--;
            load(back, string.init); // note: load adds the url back to history
        }
    }

    void toggleDarkMode()
    {
        darkMode = !darkMode;
        render();
    }
}