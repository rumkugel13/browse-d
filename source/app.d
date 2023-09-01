import std.stdio;

import url;

void main(string[] args)
{
    string test = "http://example.org";
    if (args.length > 1)
    {
        test = args[1];
    }

    URL url = new URL(test);
    auto result = url.request();
    url.show(result[1]);
}
