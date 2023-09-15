module browser;

import dlangui;
import url;
import std.range : split;
import std.conv : to;
import std.sumtype : match;
import layout;
import htmlparser;

const auto WIDTH = 800, HEIGHT = 600;
const auto HSTEP = 13, VSTEP = 18;
auto SCROLL_STEP = 100;

struct TextPos
{
    int x, y;
    dstring s;
    Font f;
}

class Browser
{
    Window window;
    CanvasWidget canvas;
    Layout document;
    TextPos[] displayList;
    int scroll = 0;

    this()
    {
        // create window
        window = Platform.instance.createWindow("Drowsey", null, WindowFlag.Resizable, WIDTH, HEIGHT);

        // create some widget to show in window
        canvas = new CanvasWidget();
        window.mainWidget = canvas;

        // show window
        window.show();
    }

    void load(URL url)
    {
        canvas.onDrawListener = delegate(CanvasWidget canvas, DrawBuf buf, Rect rc) => doDraw(canvas, buf, rc);
        canvas.keyEvent = delegate(Widget source, KeyEvent event) => onKey(source, event);
        canvas.mouseEvent = delegate(Widget source, MouseEvent event) => onMouse(source, event);

        auto parser = new HTMLParser(url.request().htmlBody);
        auto tree = parser.parse();
        parser.printTree(tree, 0);

        document = new DocumentLayout(tree);
        document.layout();
        displayList = document.displayList;
    }

    void doDraw(CanvasWidget canvas, DrawBuf buf, Rect rc)
    {
        buf.fill(0xFFFFFF); //background
        int x = rc.left;
        int y = rc.top;

        foreach (charPos; displayList)
        {
            if (charPos.y > scroll + window.height())
                continue;
            if (charPos.y + VSTEP < scroll)
                continue;
            charPos.f.drawText(buf, x + charPos.x, y + charPos.y - scroll, charPos.s, 0x0A0A0A);
        }

        // buf.fillRect(Rect(x + 20, y + 20, x + 150, y + 200), 0x80FF80);
        // buf.fillRect(Rect(x + 90, y + 80, x + 250, y + 250), 0x80FF80FF);
        // canvas.font.drawText(buf, x + 40, y + 50, "fillRect()"d, 0xC080C0);
        // buf.drawFrame(Rect(x + 400, y + 30, x + 550, y + 150), 0x204060, Rect(2, 3, 4, 5), 0x80704020);
        // canvas.font.drawText(buf, x + 400, y + 5, "drawFrame()"d, 0x208020);
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
        scroll += SCROLL_STEP;
        canvas.invalidate(); // mark to redraw
    }

    void scrollUp()
    {
        scroll -= SCROLL_STEP;
        scroll = scroll < 0 ? 0 : scroll; //stop scrolling up
        canvas.invalidate(); // mark to redraw
    }
}
