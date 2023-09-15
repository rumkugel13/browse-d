import std.stdio;
import url, browser;
import dlangui;

mixin APP_ENTRY_POINT;

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args) // @suppress(dscanner.style.phobos_naming_convention)
{
    string test = "http://example.org";
    test = "http://httpforever.com/";
    // test = "http://localhost:8000/index.html";
    if (args.length > 1)
    {
        test = args[1];
    }

    URL url = new URL(test);
    Browser browser = new Browser();
    browser.load(url);
    
    // run message loop
    return Platform.instance.enterMessageLoop();
}
