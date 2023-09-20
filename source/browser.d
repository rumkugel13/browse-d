module browser;

import dlangui;
import globals;
import url;
import tab;
import displaycommand;
import std.conv : to;
import std.algorithm : max;

final class Browser
{
    Window window;
    CanvasWidget canvas;
    Tab[] tabs;
    ulong activeTab;
    string focus;
    string addressBar;

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
        newTab.load(url, string.init);
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
            displayList ~= new DrawText(x1 + 10, 10, name, tabFont, "black");

            if (i == activeTab)
            {
                displayList ~= new DrawLine(0, 40, x1, 40, "black", 1);
                displayList ~= new DrawLine(x2, 40, WIDTH, 40, "black", 1);
            }
        }

        auto buttonFont = FontManager.instance.getFont(30, FontWeight.Normal, false, FontFamily.SansSerif, "Arial");
        displayList ~= new DrawOutline(10, 10, 30, 30, "black", 1);
        displayList ~= new DrawText(11, 0, "+", buttonFont, "black");


        displayList ~= new DrawOutline(40, 50, WIDTH - 10, 90, "black", 1);
        if (focus == "address bar")
        {
            displayList ~= new DrawText(55, 55, addressBar.to!dstring, buttonFont, "black");
            auto w = buttonFont.textSize(addressBar.to!dstring).x;
            displayList ~= new DrawLine(55 + w, 55, 55 + w, 85, "black", 1);
        }
        else 
        {  
            auto url = tabs[activeTab].url.toString().to!dstring;
            displayList ~= new DrawText(55, 55, url, buttonFont, "black");
        }

        displayList ~= new DrawOutline(10, 50, 35, 90, "black", 1);
        displayList ~= new DrawText(15, 50, "<", buttonFont, "black");

        

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
            case KeyCode.RETURN:
                {
                    if (focus == "address bar")
                    {
                        tabs[activeTab].load(new URL(addressBar), string.init);
                        focus = "";
                    }
                    return true;
                }
            default:
                break;
            }
        }

        if (event.keyCode == KeyCode.BACK && (event.action == KeyAction.KeyDown || event.action == KeyAction.Repeat))
        {
            if (focus == "address bar" && addressBar.length > 0)
            {
                addressBar.length--;
            }
            else if (focus == "content")
            {
                tabs[activeTab].backspace();
            }
            return true;
        }

        if (event.action == KeyAction.Text || event.action == KeyAction.Repeat)
        {
            if (event.text.length == 0) return false;
            if (!(0x20 <= event.text[0] && event.text[0] < 0x7f)) return false;

            if (focus == "address bar")
            {
                addressBar ~= event.text.to!string;
            }
            else if (focus == "content")
            {
                tabs[activeTab].keyPress(event.text.to!string);
            }

            return true;
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
            focus = "";
            if (event.y < CHROME_PX)
            {
                if (40 <= event.x && event.x < 40 + 80 * tabs.length && 0 <= event.y && event.y < 40)
                    activeTab = (event.x - 40) / 80;
                else if (10 <= event.x && event.x < 30 && 10 <= event.y && event.y < 30)
                    load(new URL("https://browser.engineering/"));
                else if (10 <= event.x && event.x < 35 && 50 <= event.y && event.y < 90)
                    tabs[activeTab].goBack();
                else if (50 <= event.x && event.x < WIDTH - 10 && 50 <= event.y && event.y < 90)
                {
                    focus = "address bar";
                    addressBar = "";
                }
            }
            else
            {
                focus = "content";
                tabs[activeTab].click(event.x, event.y - CHROME_PX);
            }
            return true;
        }

        return false;
    }
}
