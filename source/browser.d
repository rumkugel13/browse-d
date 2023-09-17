module browser;

import dlangui;
import globals;
import url;
import tab;
import displaycommand;
import std.conv : to;

final class Browser
{
    Window window;
    CanvasWidget canvas;
    Tab[] tabs;
    ulong activeTab;

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

        // show window
        window.show();
    }

    void load(URL url)
    {
        auto newTab = new Tab();
        newTab.load(url);
        activeTab = tabs.length;
        tabs ~= newTab;
    }

    void doDraw(CanvasWidget canvas, DrawBuf buf, Rect rc)
    {
        // buf.fill(Color.white); //background
        buf.clear();

        tabs[activeTab].draw(buf, rc);

        foreach (cmd; paintChrome())
        {
            cmd.execute(0, buf);
        }

        canvas.invalidate(); // mark to redraw
    }

    DisplayList paintChrome()
    {
        DisplayList displayList;
        displayList ~= new DrawRect(0, 0, WIDTH, CHROME_PX, "white");
        displayList ~= new DrawLine(0, CHROME_PX - 1, WIDTH, CHROME_PX - 1, "black", 1);

        auto tabFont = FontManager.instance.getFont(20, FontWeight.Normal, false, FontFamily.SansSerif, "Arial");
        foreach (i, tab; tabs)
        {
            int tabNum = i.to!int;
            dstring name = "Tab " ~ tabNum.to!dstring;
            int x1 = 40 + 80 * tabNum;
            int x2 = 120 + 80 * tabNum;

            displayList ~= new DrawLine(x1, 0, x1, 40, "black", 1);
            displayList ~= new DrawLine(x2, 0, x2, 40, "black", 1);
            displayList ~= new DrawText(x1 + 10, 10, name, tabFont, "brown");   // test color

            if (i == activeTab)
            {
                displayList ~= new DrawLine(0, 40, x1, 40, "black", 1);
                displayList ~= new DrawLine(x2, 40, WIDTH, 40, "black", 1);
            }
        }

        auto buttonFont = FontManager.instance.getFont(30, FontWeight.Normal, false, FontFamily.SansSerif, "Arial");
        displayList ~= new DrawOutline(10, 10, 30, 30, "black", 1);
        displayList ~= new DrawText(11, 0, "+", buttonFont, "black");

        return displayList;
    }

    bool onKey(Widget source, KeyEvent event)
    {
        if (event.action == KeyAction.KeyDown)
        {
            switch (event.keyCode)
            {
            case KeyCode.DOWN:
                {
                    tabs[activeTab].scrollDown();
                    return true;
                }
            case KeyCode.UP:
                {
                    tabs[activeTab].scrollUp();
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
                tabs[activeTab].scrollDown();
            else
                tabs[activeTab].scrollUp();

            return true;
        }
        else if (event.action == MouseAction.ButtonUp && event.button == MouseButton.Left)
        {
            if (event.y < CHROME_PX)
            {
                if (40 <= event.x && event.x < 40 + 80 * tabs.length && 0 <= event.y && event.y < 40)
                    activeTab = (event.x - 40) / 80;
                else if (10 <= event.x && event.x < 30 && 10 <= event.y && event.y < 30)
                    load(new URL("https://browser.engineering/"));
            }
            else
                tabs[activeTab].click(event.x, event.y - CHROME_PX);
            return true;
        }

        return false;
    }
}
