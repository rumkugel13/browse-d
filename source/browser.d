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
    bool darkMode;

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
        auto newTab = new Tab(darkMode);
        newTab.load(url, string.init);
        activeTab = tabs.length;
        tabs ~= newTab;
    }

    void doDraw(CanvasWidget canvas, DrawBuf buf, Rect rc)
    {
        if (!darkMode)
            buf.fill(Color.white); //background
        else
            buf.fill(Color.black);

        if (tabs)
            tabs[activeTab].draw(buf, rc);

        foreach (cmd; paintChrome())
        {
            cmd.execute(0, buf);
        }

        canvas.invalidate(); // mark to redraw
    }

    DisplayList paintChrome()
    {
        string color = "black", backColor = "white";
        if (darkMode)
        {
            color = "white";
            backColor = "black";
        }

        DisplayList displayList;
        displayList ~= new DrawRect(0, 0, WIDTH, CHROME_PX, backColor);
        displayList ~= new DrawLine(0, CHROME_PX - 1, WIDTH, CHROME_PX - 1, color, 1);

        auto tabFont = FontManager.instance.getFont(20, FontWeight.Normal, false, FontFamily.SansSerif, "Arial");
        foreach (i, tab; tabs)
        {
            int tabNum = i.to!int;
            dstring name = "Tab " ~ tabNum.to!dstring;
            int x1 = 40 + 80 * tabNum;
            int x2 = 120 + 80 * tabNum;

            displayList ~= new DrawLine(x1, 0, x1, 40, color, 1);
            displayList ~= new DrawLine(x2, 0, x2, 40, color, 1);
            displayList ~= new DrawText(x1 + 10, 10, name, tabFont, color);

            if (i == activeTab)
            {
                displayList ~= new DrawLine(0, 40, x1, 40, color, 1);
                displayList ~= new DrawLine(x2, 40, WIDTH, 40, color, 1);
            }
        }

        auto buttonFont = FontManager.instance.getFont(30, FontWeight.Normal, false, FontFamily.SansSerif, "Arial");
        displayList ~= new DrawOutline(10, 10, 30, 30, color, 1);
        displayList ~= new DrawText(11, 0, "+", buttonFont, color);

        displayList ~= new DrawOutline(40, 50, WIDTH - 10, 90, color, 1);
        if (focus == "address bar")
        {
            displayList ~= new DrawText(55, 55, addressBar.to!dstring, buttonFont, color);
            auto w = buttonFont.textSize(addressBar.to!dstring).x;
            displayList ~= new DrawLine(55 + w, 55, 55 + w, 85, color, 1);
        }
        else if (tabs)
        {
            auto url = tabs[activeTab].url.toString().to!dstring;
            displayList ~= new DrawText(55, 55, url, buttonFont, color);
        }

        displayList ~= new DrawOutline(10, 50, 35, 90, color, 1);
        displayList ~= new DrawText(15, 50, "<", buttonFont, color);

        if (tabs && tabs[activeTab].document.height > HEIGHT)
        {
            auto height = ((1f * (HEIGHT - CHROME_PX) / tabs[activeTab].document.height) * (HEIGHT - CHROME_PX)).to!int;
            auto y = ((1f * tabs[activeTab].scroll / tabs[activeTab].document.height) * (HEIGHT - CHROME_PX)).to!int;
            displayList ~= new DrawRect(WIDTH - 20, CHROME_PX, WIDTH, HEIGHT, "lightblue");
            displayList ~= new DrawRect(WIDTH - 20, y + CHROME_PX, WIDTH, y + CHROME_PX + height, "blue");
        }

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
                    handleDown();
                    return true;
                }
            case KeyCode.UP:
                {
                    handleUp();
                    return true;
                }
            case KeyCode.HOME:
                {
                    handleHome();
                    return true;
                }
            case KeyCode.END:
                {
                    handleEnd();
                    return true;
                }
            case KeyCode.PAGEUP:
                {
                    handlePageUp();
                    return true;
                }
            case KeyCode.PAGEDOWN:
                {
                    handlePageDown();
                    return true;
                }
            case KeyCode.RETURN:
                {
                    handleEnter();
                    return true;
                }
            case KeyCode.F8:
                {
                    toggleDarkMode();
                    return true;
                }
            default:
                break;
            }
        }

        if (event.keyCode == KeyCode.BACK && (event.action == KeyAction.KeyDown || event.action == KeyAction
                .Repeat))
        {
            handleBack();
            return true;
        }

        if (event.action == KeyAction.Text || event.action == KeyAction.Repeat)
        {
            handleInput(event.text.to!string);
            return true;
        }

        return false;
    }

    bool onMouse(Widget source, MouseEvent event)
    {
        if (event.action == MouseAction.Wheel)
        {
            if (event.wheelDelta < 0)
                handleDown();
            else
                handleUp();

            return true;
        }
        else if (event.action == MouseAction.ButtonUp && event.button == MouseButton.Left)
        {
            handleLeftClick(event.x, event.y);
            return true;
        }

        return false;
    }

    void handleDown()
    {
        tabs[activeTab].scrollDown();
    }

    void handleUp()
    {
        tabs[activeTab].scrollUp();
    }

    void handlePageDown()
    {
        tabs[activeTab].pageDown();
    }

    void handlePageUp()
    {
        tabs[activeTab].pageUp();
    }

    void handleHome()
    {
        tabs[activeTab].jumpUp();
    }

    void handleEnd()
    {
        tabs[activeTab].jumpDown();
    }

    void handleEnter()
    {
        if (focus == "address bar")
        {
            tabs[activeTab].load(new URL(addressBar), string.init);
            focus = "";
        }
    }

    void handleInput(string text)
    {
        if (text.length == 0)
                return;
        if (!(0x20 <= text[0] && text[0] < 0x7f))
            return;

        if (focus == "address bar")
        {
            addressBar ~= text;
        }
        else if (focus == "content")
        {
            tabs[activeTab].keyPress(text.to!string);
        }
    }

    void handleBack()
    {
        if (focus == "address bar" && addressBar.length > 0)
        {
            addressBar.length--;
        }
        else if (focus == "content")
        {
            tabs[activeTab].backspace();
        }
    }

    void handleLeftClick(int x, int y)
    {
        focus = "";
        if (y < CHROME_PX)
        {
            if (40 <= x && x < 40 + 80 * tabs.length && 0 <= y && y < 40)
                activeTab = (x - 40) / 80;
            else if (10 <= x && x < 30 && 10 <= y && y < 30)
                load(new URL("https://browser.engineering/"));
            else if (10 <= x && x < 35 && 50 <= y && y < 90)
                tabs[activeTab].goBack();
            else if (50 <= x && x < WIDTH - 10 && 50 <= y && y < 90)
            {
                focus = "address bar";
                addressBar = "";
            }
        }
        else
        {
            focus = "content";
            tabs[activeTab].click(x, y - CHROME_PX);
        }
    }

    void toggleDarkMode()
    {
        darkMode = !darkMode;
        // tabs[activeTab].toggleDarkMode();
        foreach (tab; tabs)
            tab.toggleDarkMode();
    }
}
