import std.stdio;
import url, browser;
import dlangui;
import std.getopt;

mixin APP_ENTRY_POINT;

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args) // @suppress(dscanner.style.phobos_naming_convention)
{
    string test = "https://example.org";
    test = "https://browser.engineering/styles.html";
    // test = "http://httpforever.com/";
    // test = "http://localhost:8000/index.html";
    version(Windows)
    {
        // for some reason, the arguments are not passed correctly on Windows
        if (args.length > 2)
        {
            test = args[2];
        }
    }
    else
    {
        if (args.length > 1)
        {
            test = args[1];
        }
    }

    URL url = new URL(test);
    Browser browser = new Browser();
    browser.load(url);
    
    // run message loop
    return Platform.instance.enterMessageLoop();
}
