module url;

import std.range : split, empty;
import std.algorithm : canFind, startsWith;
import std.string : splitLines, toLower, strip;
import std.typecons : tuple, Tuple;
import std.array : join;
import std.stdio;
import std.conv : to;
import std.sumtype;
import std.utf;
import std.socket;
import deimos.openssl.ssl, deimos.openssl.err;

class URL
{
    public string scheme, host, path;
    public ushort port;

    struct HttpResponse
    {
        string[string] headers;
        string htmlBody;
    }

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

        split = url.split("/");

        host = split[0];
        path = "/" ~ split[1];

        if (host.canFind(":"))
        {
            split = host.split(":");
            host = split[0];
            port = split[1].to!ushort;
        }
    }

    HttpResponse request()
    {
        if (scheme == "https")
            return requestHttps();
        else
            return requestHttp();
    }

    HttpResponse requestHttp()
    {
        auto tcpSocket = new TcpSocket(AddressFamily.INET);
        scope (exit)
            tcpSocket.close();
        auto address = new InternetAddress(host, port);
        tcpSocket.connect(address);

        tcpSocket.send(("GET " ~ path ~ " HTTP/1.0\r\n" ~ "Host: " ~ host ~ " \r\n\r\n").toUTF8);

        char[1024] buf;
        string receivedData;
        long bytesRead;

        while ((bytesRead = tcpSocket.receive(buf)) > 0)
        {
            receivedData ~= buf[0 .. bytesRead];
        }

        auto lines = receivedData.splitLines();

        auto statusLine = lines[0];
        auto splitStatus = statusLine.split();
        auto httpVersion = splitStatus[0];
        auto status = splitStatus[1];
        auto explanation = splitStatus[2];
        assert(status == "200", status ~ ":" ~ explanation);

        string[string] responseHeaders;
        ulong begin = 0;
        foreach (i, line; lines[1 .. $])
        {
            if (line.length == 0)
            {
                begin = i + 1;
                break;
            }

            auto splitLine = line.split(":");
            responseHeaders[splitLine[0].toLower()] = splitLine[1].strip();
        }

        assert("transfer-encoding" !in responseHeaders, "Unsupported header: " ~ "transfer-encoding");
        assert("content-encoding" !in responseHeaders, "Unsupported header: " ~ "content-encoding");

        auto responseBody = lines[begin .. $].join("\n");

        return HttpResponse(responseHeaders, responseBody);
    }

    HttpResponse requestHttps()
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
            return HttpResponse.init;
        }
        scope(exit)
        {
            SSL_shutdown(ssl);
            SSL_free(ssl);
        }
        writeln("SSL success");

        auto request = ("GET " ~ path ~ " HTTP/1.0\r\n" ~ "Host: " ~ host ~ " \r\n\r\n").toUTF8;
        SSL_write(ssl, request.ptr, cast(int)request.length);

        char[1024] buf;
        string receivedData;
        long bytesRead;

        while ((bytesRead = SSL_read(ssl, buf.ptr, buf.length)) > 0)
        {
            receivedData ~= buf[0 .. bytesRead];
        }

        auto lines = receivedData.splitLines();

        auto statusLine = lines[0];
        auto splitStatus = statusLine.split();
        auto httpVersion = splitStatus[0];
        auto status = splitStatus[1];
        auto explanation = splitStatus[2];
        assert(status == "200", status ~ ":" ~ explanation);

        string[string] responseHeaders;
        ulong begin = 0;
        foreach (i, line; lines[1 .. $])
        {
            if (line.length == 0)
            {
                begin = i + 1;
                break;
            }

            auto splitLine = line.split(":");
            responseHeaders[splitLine[0].toLower()] = splitLine[1].strip();
        }

        assert("transfer-encoding" !in responseHeaders, "Unsupported header: " ~ "transfer-encoding");
        assert("content-encoding" !in responseHeaders, "Unsupported header: " ~ "content-encoding");

        auto responseBody = lines[begin .. $].join("\n");

        return HttpResponse(responseHeaders, responseBody);
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
