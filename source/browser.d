module browser;

import dlangui;
import url;
import std.range : split;
import std.conv : to;
import std.sumtype : match;
import std.stdio : writeln;
import layout;
import htmlparser, cssparser;
import displaycommands;
import std.file : readText;
import node;

const auto WIDTH = 800, HEIGHT = 600;
const auto HSTEP = 13, VSTEP = 18;
auto SCROLL_STEP = 100;

alias DisplayList = DisplayCommand[];

final class Browser
{
    Window window;
    CanvasWidget canvas;
    DocumentLayout document;
    DisplayList displayList;
    Rule[] defaultStyleSheet;
    int scroll = 0;

    this()
    {
        // create window
        window = Platform.instance.createWindow("Drowsey", null, WindowFlag.Resizable, WIDTH, HEIGHT);

        // create some widget to show in window
        canvas = new CanvasWidget();
        
        canvas.onDrawListener = delegate(CanvasWidget canvas, DrawBuf buf, Rect rc) => doDraw(canvas, buf, rc);
        canvas.keyEvent = delegate(Widget source, KeyEvent event) => onKey(source, event);
        canvas.mouseEvent = delegate(Widget source, MouseEvent event) => onMouse(source, event);

        window.mainWidget = canvas;

        defaultStyleSheet = new CSSParser(readText("browser.css")).parse();

        // show window
        window.show();
    }

    void load(URL url)
    {
        auto parser = new HTMLParser(url.request().htmlBody);
        // auto test = "<div></div><div>text</div><div><div></div>text</div><span></span><span>text</span>";
        // test = "<pre>pre text</pre>";
        // auto parser = new HTMLParser(test);
        auto tree = parser.parse();
        parser.printTree(tree, 0);

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
            HttpResponse response;
            try
            {
                response = url.resolve(link).request();
            }
            catch (Exception _) 
            {
                continue;
            }
            rules ~= new CSSParser(response.htmlBody).parse();
        }

        import std.algorithm : sort;
        import std.range : array;
        
        cssparser.style(tree, rules.sort.array);

        // auto cssTest = "a {p :v} ";
        // auto rules = new CSSParser(cssTest).parse();
        // writeln(rules);
        // if (rules.length > 0)
        //     return;

        document = new DocumentLayout(tree);
        document.layout();
        document.printTree();

        this.displayList.length = 0;
        document.paint(this.displayList);

        foreach(command; this.displayList)
        {
            writeln(command);
        }
    }

    void doDraw(CanvasWidget canvas, DrawBuf buf, Rect rc)
    {
        // buf.fill(Color.white); //background
        buf.clear();

        foreach (command; displayList)
        {
            if (command.top > scroll + window.height())
                continue;
            if (command.bottom < scroll)
                continue;
            command.execute(scroll, buf);
        }
    }

    bool onKey(Widget source, KeyEvent event)
    {
        if (event.action == KeyAction.KeyDown)
        {
            switch (event.keyCode)
            {
            case KeyCode.DOWN:
                {
                    scrollDown();
                    return true;
                }
            case KeyCode.UP:
                {
                    scrollUp();
                    return true;
                }
            default:
                return false;
            }
        }

        return false;
    }

    bool onMouse(Widget source, MouseEvent event)
    {
        if (event.action == MouseAction.Wheel)
        {
            if (event.wheelDelta < 0)
            {
                scrollDown();
            }
            else
            {
                scrollUp();
            }
            return true;
        }

        return false;
    }

    void scrollDown()
    {
        import std.algorithm : max, min;
        auto maxY = max(document.height - HEIGHT, 0);
        scroll = min(scroll + SCROLL_STEP, maxY);
        canvas.invalidate(); // mark to redraw
    }

    void scrollUp()
    {
        import std.algorithm : max, min;
        scroll = max(scroll - SCROLL_STEP, 0);
        canvas.invalidate(); // mark to redraw
    }
}
