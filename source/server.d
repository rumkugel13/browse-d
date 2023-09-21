#!dub
/+ dub.sdl:
	name "hello"
    dependency "urllibparse" version="*"
+/

module server;

import std.socket;
import std.algorithm : findSplit, findSplitAfter, canFind;
import std.string : split, toLower, strip;
import std.stdio : writeln, write;
import std.conv : to;
import std.utf : toUTF8;
import urllibparse : unquotePlus;

auto ENTRIES = ["stromkugel was here"];
const auto SOCK_BUF = 4 * 1024;

struct ResponseData
{
    string status, body;
}

int main(string[] args)
{
    start();
    return 0;
}

void start()
{
    auto socket = new TcpSocket(AddressFamily.INET);
    socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    auto addr = new InternetAddress(8000);
    socket.bind(addr);
    socket.listen(1);
    writeln("Listening on port 8000...");
    while(true)
    {
        auto conn = socket.accept();
        handleConnection(conn);
    }
}

void handleConnection(Socket socket)
{
    writeln("New Connection: ", socket.remoteAddress);
    char[] readBuffer = new char[SOCK_BUF];
    size_t available = 0;

    string line = readLine(socket, readBuffer, available);
    auto split = line.split();
    auto method = split[0];
    auto url = split[1];
    auto ver = split[2];

    write(line);
    assert(["GET", "POST"].canFind(method), "Unknown method " ~ method);

    string[string] headers;
    while (true)
    {
        line = readLine(socket, readBuffer, available);
        if (line == "\r\n")
            break;

        auto find = line.findSplit(":");
        headers[find[0].toLower] = find[2];
    }

    writeln("Got ", headers.length, " headers");

    string body = "";
    if ("content-length" in headers)
    {
        auto length = headers["content-length"].strip.to!int;
        auto data = socket.read(length, readBuffer, available);
        writeln("Got ", data.length, " bytes of data");
        body ~= data;
    }

    auto responseData = doRequest(method, url, headers, body);
    string response = "HTTP/1.0 " ~ responseData.status ~ "\r\n";
    response ~= "Connection: close";
    response ~= "Content-Length: " ~ responseData.body.toUTF8.length.to!string ~ "\r\n";
    response ~= "\r\n" ~ responseData.body;
    socket.send(response);
    writeln("Closing Connection: ", socket.remoteAddress);
    socket.close();
}

ResponseData doRequest(string method, string url, string[string] headers, string body)
{
    if (method == "GET" && url == "/")
        return ResponseData("200 OK", showComments());
    else if (method == "POST" && url == "/add")
    {
        auto params = formDecode(body);
        return ResponseData("200 OK", addEntry(params));
    }
    else {
        return ResponseData("404 Not Found", notFound(url, method));
    }
}

string showComments()
{
    string output = "<!doctype html>";
    foreach (entry; ENTRIES)
    {
        output ~= "<p>" ~ entry ~ "</p>";
    }
    output ~= "<form action=add method=post>";
    output ~=   "<p><input name=guest></p>";
    output ~=   "<p><button>Sign the book!</button></p>";
    output ~= "</form>";
    return output;
}

string[string] formDecode(string b)
{
    string[string] params;
    foreach (field; b.split("&"))
    {
        auto keyAndValue = field.findSplit("=");
        auto name = keyAndValue[0].unquotePlus;
        auto value = keyAndValue[2].unquotePlus;
        params[name] = value;
    }
    return params;
}

string addEntry(string[string] params)
{
    if ("guest" in params)
        ENTRIES ~= params["guest"];
    return showComments();
}

string notFound(string url, string method)
{
    string output = "<!doctype html>";
    output ~= "<h1>" ~ method ~ " " ~ url ~ " not found!<!h1>";
    return output;
}

string read(Socket socket, size_t bytes, ref char[] buffer, ref size_t available)
{
    string line = "";

    if (available > 0)
    {
        line ~= buffer[0..available];
        available = 0;

        if (line.length > bytes)
        {
            available = line.length - bytes;
            for (int i = 0; i < available; i++)
                buffer[i] = line[bytes + i];
            line = line[0..bytes];
            return line;
        }
    }

    while (true)
    {
        auto read = socket.receive(buffer);
        if (read > 0)
        {
            line ~= buffer;
            if (line.length > bytes)
            {
                available = line.length - bytes;
                for (int i = 0; i < available; i++)
                    buffer[i] = line[bytes + i];
                line = line[0..bytes];
                return line;
            }
        }
        else
        {
            break;
        }
    }

    return line;
}

string readLine(Socket socket, ref char[] buffer, ref size_t available)
{
    string line = "";

    if (available > 0)
    {
        line ~= buffer[0..available];
        available = 0;
        if (canFind(line, "\r\n"))
        {
            auto find = findSplitAfter(line, "\r\n");
            line = find[0];
            available = find[1].length;
            for (int i = 0; i < available; i++)
                buffer[i] = find[1][i];
            return line;
        }
    }

    while (true)
    {
        auto read = socket.receive(buffer);
        if (read > 0)
        {
            line ~= buffer;
            if (canFind(line, "\r\n"))
            {
                auto find = findSplitAfter(line, "\r\n");
                line = find[0];
                available = find[1].length;
                for (int i = 0; i < available; i++)
                    buffer[i] = find[1][i];
                return line;
            }
        }
        else
        {
            break;
        }
    }

    return line;
}