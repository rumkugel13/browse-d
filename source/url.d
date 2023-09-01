module url;

import std.range : split;
import std.algorithm : canFind, startsWith;
import std.string;
import std.typecons : tuple, Tuple;
import std.array : join;
import std.stdio;

class URL
{
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

    Tuple!(string[string], string) request()
    {
        import std.socket;

        auto s = new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
        auto address = new InternetAddress(host, 80);
        s.connect(address);

        import std.utf;

        s.send(("GET " ~ path ~ " HTTP/1.0\r\n" ~ "Host: " ~ host ~ " \r\n\r\n").toUTF8);

        char[1024] buf;
        string receivedData;
        long bytesRead;

        while ((bytesRead = s.receive(buf)) > 0)
        {
            receivedData ~= buf[0 .. bytesRead];
        }

        auto lines = receivedData.splitLines();

        auto statusLine = lines[0];
        auto splitStatus = statusLine.split();
        auto ver = splitStatus[0];
        auto status = splitStatus[1];
        auto explanation = splitStatus[2];
        assert(status == "200", status ~ ":" ~ explanation);

        string[string] headers;
        ulong begin = 0;
        foreach (i, line; lines[1 .. $])
        {
            if (line.length == 0)
            {
                begin = i + 1;
                break;
            }

            auto splitLine = line.split(":");
            headers[splitLine[0].toLower()] = splitLine[1].strip();
        }

        assert("transfer-encoding" !in headers);
        assert("content-encoding" !in headers);

        auto bod = lines[begin .. $].join;
        s.close();

        return tuple(headers, bod);
    }

    void show(string bod)
    {
        bool inAngle = false;
        foreach (character; bod)
        {
            if (character == '<')
                inAngle = true;
            else if (character == '>')
                inAngle = false;
            else if (!inAngle)
                write(character);
        }
        writeln();
    }
}

unittest
{
    URL url = new URL("http://example.org");
    assert(url.scheme == "http");
    assert(url.host == "example.org");
    assert(url.path == "/");
}
