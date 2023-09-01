module url;

import std.range: split;
import std.algorithm: canFind;

class URL {
    public string scheme, host, path;

    this(string url)
    {
        auto split = url.split("://");
        scheme = split[0];
        assert(scheme == "http", "Unknown scheme: " ~ scheme);

        url = split[1];
        if (!canFind(url, "/"))
            url ~= "/";
        
        split = url.split("/");
        host = split[0];
        path = "/" ~ split[1];
    }
}

unittest
{
    URL url = new URL("http://example.org");
    assert(url.scheme == "http");
    assert(url.host == "example.org");
    assert(url.path == "/");
}