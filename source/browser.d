module browser;

import dlangui;
import globals;
import url;
import tab;

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

        canvas.invalidate(); // mark to redraw
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
            tabs[activeTab].click(event.x, event.y);
            return true;
        }

        return false;
    }
}
