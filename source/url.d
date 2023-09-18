module url;

import std.range : split, empty;
import std.algorithm : canFind, startsWith, findSplit;
import std.string : splitLines, toLower, strip;
import std.typecons : tuple, Tuple;
import std.array : join;
import std.stdio;
import std.conv : to;
import std.sumtype;
import std.utf;
import std.socket;
import deimos.openssl.ssl, deimos.openssl.err;

struct HttpRequest
{
    string request;
    string[string] headers;
}

struct HttpResponse
{
    string[string] headers;
    string htmlBody;
}

class URL
{
    public string scheme, host, path;
    public ushort port;

    this(string url)
    {
        auto split = url.split("://");
        scheme = split[0];
        assert(["http", "https"].canFind(scheme), "Unknown scheme: " ~ scheme);
        if (scheme == "http")
            port = 80;
        else if (scheme == "https")
            port = 443;

        url = split[1];
        if (!canFind(url, "/"))
            url ~= "/";

        auto fsplit = url.findSplit("/");

        host = fsplit[0];
        path = "/" ~ fsplit[2];

        if (host.canFind(":"))
        {
            split = host.split(":");
            host = split[0];
            port = split[1].to!ushort;
        }
    }

    HttpResponse request()
    {
        string receivedData;
        if (scheme == "https")
            receivedData = requestHttps();
        else
            receivedData = requestHttp();

        if (receivedData.empty) return HttpResponse.init;

        import std.algorithm : findSplit;
        auto temp = receivedData.findSplit("\r\n");

        auto statusLine = temp[0];
        auto splitStatus = statusLine.split();
        auto httpVersion = splitStatus[0];
        auto status = splitStatus[1];
        auto explanation = splitStatus[2];
        assert(status == "200", status ~ ":" ~ explanation);

        string[string] responseHeaders;

        while (true)
        {
            temp = temp[2].findSplit("\r\n");
            if (temp[2].startsWith("\r\n"))
                break;
            auto splitLine = temp[0].findSplit(":");
            responseHeaders[splitLine[0].toLower()] = splitLine[2].strip();
        }

        assert("transfer-encoding" !in responseHeaders, "Unsupported header: " ~ "transfer-encoding");
        assert("content-encoding" !in responseHeaders, "Unsupported header: " ~ "content-encoding");

        auto responseBody = temp[2][2..$];

        return HttpResponse(responseHeaders, responseBody);
    }

    string requestHttp()
    {
        auto tcpSocket = new TcpSocket(AddressFamily.INET);
        scope (exit)
            tcpSocket.close();
        auto address = new InternetAddress(host, port);
        tcpSocket.connect(address);

        tcpSocket.send(makeRequest.toUTF8);

        char[1024] buf;
        string receivedData;
        long bytesRead;

        while ((bytesRead = tcpSocket.receive(buf)) > 0)
        {
            receivedData ~= buf[0 .. bytesRead];
        }

        return receivedData;
    }

    string requestHttps()
    {
        auto tcpSocket = new TcpSocket(AddressFamily.INET);
        scope (exit)
            tcpSocket.close();
        writeln("Created socket");
        auto address = new InternetAddress(host, port);
        tcpSocket.connect(address);
        writeln("Socket connect");

        SSL_load_error_strings();

        SSL_CTX *ctx = SSL_CTX_new(TLS_client_method());
	    assert(!(ctx is null));
        scope(exit) SSL_CTX_free(ctx);
        writeln("CTX");

        // SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, null);
        // SSL_CTX_set_default_verify_paths(ctx);

        SSL *ssl = SSL_new(ctx);
        SSL_set_fd(ssl, cast(int)tcpSocket.handle());
        writeln("SSL");

        SSL_set_tlsext_host_name(ssl, host.ptr);
        SSL_set1_host(ssl, host.ptr);

        auto result = SSL_connect(ssl);
        if (result == -1)
        {
            writeln("Error ssl connect");
            char[256] buf;
            ERR_error_string(ERR_get_error(), buf.ptr);
            writeln(buf);
            // import deimos.openssl.applink : app_stderr;
            // import core.stdc.stdio : stderr;
            // ERR_print_errors_fp(cast(shared(_iobuf)*)stderr);
            return string.init;
        }
        scope(exit)
        {
            SSL_shutdown(ssl);
            SSL_free(ssl);
        }
        writeln("SSL success");

        auto request = makeRequest.toUTF8;
        SSL_write(ssl, request.ptr, cast(int)request.length);

        char[1024] buf;
        string receivedData;
        long bytesRead;

        while ((bytesRead = SSL_read(ssl, buf.ptr, buf.length)) > 0)
        {
            receivedData ~= buf[0 .. bytesRead];
        }

        return receivedData;
    }

    URL resolve(string url)
    {
        if (url.canFind("://")) return new URL(url);
        if (!url.startsWith("/"))
        {
            import std.string : lastIndexOf, indexOf;
            auto i = path.lastIndexOf("/"); // pythons rsplit workaround
            if (i != -1)
            {
                auto dir = path[0..i];
                while (url.startsWith("../"))
                {
                    url = url.findSplit("/")[2]; // pythons split(x, 1) workaround
                    if (dir.canFind("/"))
                    {
                        auto k = dir.lastIndexOf("/");
                        if (k != -1)
                        {
                            dir = dir[0..k];
                        }
                    }
                }
                url = dir ~ "/" ~ url;
            }
        }
        return new URL(scheme ~ "://" ~ host ~ ":" ~ port.to!string ~ url);
    }

    private string makeRequest()
    {
        HttpRequest request;
        request.request = "GET " ~ path ~ " HTTP/1.1\r\n";

        request.headers["Host"] = host;
        request.headers["Connection"] = "close";
        request.headers["User-Agent"] = "Drowsey";

        string s = request.request;
        foreach (header, value; request.headers)
        {
            s ~= header ~ ": " ~ value ~ "\r\n";
        }
        s ~= "\r\n";
        return s;
    }

    override string toString() const
    {
        auto portPart = ":" ~ port.to!string;
        if (scheme == "https" && port == 443)
            portPart = "";
        if (scheme == "http" && port == 80)
            portPart = "";

        import std.string : format;
        return format("%s://%s%s%s", scheme, host, portPart, path);
    }
}

unittest
{
    URL url = new URL("http://example.org");
    assert(url.scheme == "http");
    assert(url.host == "example.org");
    assert(url.path == "/");
    assert(url.port == 80);
}

unittest
{
    URL url = new URL("http://example.org:8000/index.html");
    assert(url.scheme == "http");
    assert(url.host == "example.org");
    assert(url.path == "/index.html");
    assert(url.port == 8000);
}
