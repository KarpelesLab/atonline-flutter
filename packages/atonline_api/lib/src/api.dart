import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' show Intl;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import 'user.dart';

class AtOnlineNetworkException implements Exception {
  String msg;

  AtOnlineNetworkException(this.msg);
}

class AtOnlineLoginException implements Exception {
  String msg;

  AtOnlineLoginException(this.msg);
}

class AtOnlinePlatformException implements Exception {
  dynamic data;

  AtOnlinePlatformException(this.data);
}

class AtOnlinePaging {
  int count;
  int pageMax;
  int pageNumber;
  int resultPerPage;

  AtOnlinePaging(this.count, this.pageMax, this.pageNumber, this.resultPerPage);
}

class AtOnlineApiResult extends Iterable<dynamic> {
  dynamic res;
  AtOnlinePaging? paging;
  double? time;
  String? result;
  dynamic get data => res["data"];

  // Used when data is a key/values pair and not accessible by index.
  dynamic _iterableValue;

  Iterator<dynamic> get iterator {
    if (this.data is Map) {
      if (_iterableValue == null) {
        _iterableValue = this.data.values;
      }
      return _iterableValue.iterator;
    } else if (this.data is Iterable) {
      return this.data.iterator;
    }

    throw new Exception("AtOnlineApiResult are not iterable");
  }

  AtOnlineApiResult(this.res) {
    if (this.res.containsKey("paging")) {
      this.paging = new AtOnlinePaging(
          int.parse(this.res["paging"]["count"].toString()),
          int.parse(this.res["paging"]["page_max"].toString()),
          int.parse(this.res["paging"]["page_no"].toString()),
          int.parse(this.res["paging"]["results_per_page"].toString()));
    }

    if (this.res.containsKey("time")) this.time = res["time"];
    if (this.res.containsKey("result")) this.result = res["result"];
  }

  dynamic operator [](String key) {
    if (key.startsWith("@")) {
      return res[key.substring(1)];
    }

    return res["data"][key];
  }
}

typedef void ProgressCallback(double status);

class AtOnline with ChangeNotifier {
  final String appId;
  final String prefix;
  final String authEndpoint;
  static Map<String, AtOnline> _instances = {};
  Map<String, String> cookies = {};

  factory AtOnline(appId,
      {prefix = "https://hub.atonline.com/_special/rest/",
      authEndpoint = "https://hub.atonline.com/_special/rest/OAuth2:auth"}) {
    if (!_instances.containsKey(appId))
      _instances[appId] = new AtOnline._internal(appId, prefix, authEndpoint);

    return _instances[appId]!;
  }

  AtOnline._internal(this.appId, this.prefix, this.authEndpoint);

  final storage = new FlutterSecureStorage();

  // details of current session
  int expiresV = 0;
  String? tokenV = "";
  bool storageLoadCompleted = false;
  User? _user;

  User get user {
    if (_user == null) _user = User(this);

    return _user!;
  }

  Future<dynamic> req(String path,
      {String method = "GET",
      dynamic body,
      Map<String, String>? headers,
      Map<String, String>? context,
      bool skipDecode = false}) async {
    print("Running $method $path");

    http.Response res;

    var _ctx = <String, String?>{};

    _ctx["_ctx[l]"] = Intl.defaultLocale;
    _ctx["_ctx[t]"] = DateTime.now().timeZoneName; // grab timezone name...?

    if (context != null) {
      context.forEach((k, v) => _ctx["_ctx[" + k + "]"] = v);
    }
    if ((method == "GET") && (body != null)) {
      _ctx["_"] = json.encode(body);
    }

    if (cookies.isNotEmpty) {
      headers ??= {};
      headers['cookie'] = _generateCookieHeader();
    }

    Uri urlPath = Uri.parse(prefix + path);
    urlPath = Uri(
        scheme: urlPath.scheme,
        host: urlPath.host,
        path: urlPath.path,
        queryParameters: _ctx);

    switch (method) {
      case "GET":
        print("API GET request: $urlPath");
        try {
          res = await http.get(urlPath, headers: headers);
        } on http.ClientException catch(e) {
          if (e.message == "Failed to parse header value") {
            // [ERROR:flutter/lib/ui/ui_dart_state.cc(198)] Unhandled Exception: Failed to parse header value
            // See: https://github.com/dart-lang/sdk/issues/46442
            // Flutter does not handle properly Bearer auth failure and will return a crap error. Our token is shit.
            if ((headers == null) || (!headers.containsKey("Authorization"))) {
              throw e;
            }
            expiresV = 0; // mark token as expired.
            // retry
            headers["Authorization"] = "Bearer " + await token();
            res = await http.get(urlPath, headers: headers);
          }
          throw e; // no idea
        }
        break;
      case "POST":
        if (body != null) {
          if (headers == null) {
            headers = <String, String>{};
          }
          headers["Content-Type"] = "application/json";
          body = json.encode(body);
        }

        try {
          res = await http.post(urlPath, body: body, headers: headers);
        } on http.ClientException catch(e) {
          if (e.message == "Failed to parse header value") {
            // [ERROR:flutter/lib/ui/ui_dart_state.cc(198)] Unhandled Exception: Failed to parse header value
            // See: https://github.com/dart-lang/sdk/issues/46442
            // Flutter does not handle properly Bearer auth failure and will return a crap error. Our token is shit.
            if ((headers == null) || (!headers.containsKey("Authorization"))) {
              throw e;
            }
            expiresV = 0; // mark token as expired.
            // retry
            headers["Authorization"] = "Bearer " + await token();
            res = await http.post(urlPath, body: body, headers: headers);
          }
          throw e; // no idea
        }
        break;
      default:
        var req = http.Request(method, urlPath);
        if (headers != null) {
          headers.forEach((String k, String v) {
            req.headers[k] = v;
          });
        }
        if (body != null) {
          req.body = json.encode(body);
          req.headers["Content-Type"] = "application/json";
        }

        try {
          var stream = await http.Client().send(req);
          res = await http.Response.fromStream(stream);
        } on http.ClientException catch(e) {
          if (e.message == "Failed to parse header value") {
            // [ERROR:flutter/lib/ui/ui_dart_state.cc(198)] Unhandled Exception: Failed to parse header value
            // See: https://github.com/dart-lang/sdk/issues/46442
            // Flutter does not handle properly Bearer auth failure and will return a crap error. Our token is shit.
            if (!req.headers.containsKey("Authorization")) {
              throw e;
            }
            expiresV = 0; // mark token as expired.
            // retry
            req.headers["Authorization"] = "Bearer " + await token();
            var stream = await http.Client().send(req);
            res = await http.Response.fromStream(stream);
          }
          throw e; // no idea
        }
    }

    _updateCookie(res);

    if (res.statusCode >= 300) {
      // something is wrong

      // check if response is json
      String ct = res.headers["content-type"]!;
      int idx = ct.indexOf(';');
      if (idx > 0) {
        ct = ct.substring(0, idx);
      }
      if (ct == "application/json") {
        // this is a platform error
        var d = json.decode(res.body);
        print("Got error: ${d["error"]}");
        throw new AtOnlinePlatformException(d);
      }
      print("Error from API: ${res.body}");
      throw new AtOnlineNetworkException(
          "invalid response from api ${res.statusCode} ${res.body}");
    }

    var d = json.decode(res.body);

    if (skipDecode) {
      return d;
    }

    if (d["result"] != "success") {
      print("Got error: $d");
      throw AtOnlinePlatformException(d);
    }

    return AtOnlineApiResult(d);
  }

  Future<dynamic> authReq(String path,
      {String method = "GET",
      dynamic body,
      Map<String, String>? headers,
      Map<String, String>? context}) async {
    if (headers == null) {
      headers = <String, String>{};
    }
    headers["Authorization"] = "Bearer " + await token();
    return req(path,
        method: method, body: body, headers: headers, context: context);
  }

  Future<dynamic> optAuthReq(String path,
      {String method = "GET",
      dynamic body,
      Map<String, String>? headers,
      Map<String, String>? context}) async {
    try {
      if (headers == null) {
        headers = <String, String>{};
      }
      headers["Authorization"] = "Bearer " + await token();
    } on AtOnlineLoginException {
    } on AtOnlinePlatformException {}
    return req(path,
        method: method, body: body, headers: headers, context: context);
  }

  Future<dynamic> authReqUpload(String path, File f,
      {Map<String, dynamic>? body,
      Map<String, String>? headers,
      Map<String, String>? context,
      ProgressCallback? progress}) async {

    if (body == null) {
      body = <String, dynamic>{};
    }
    var size = await f.length();
    body["filename"] ??= p.basename(f.path);
    body["type"] ??= lookupMimeType(body["filename"]) ?? "application/octet-stream";
    body["size"] = size;

    // first, get upload ready
    var res = await authReq(path, method: "POST", body: body, context: context);

    var r = http.StreamedRequest("PUT", Uri.parse(res["PUT"]));
    r.contentLength = size; // required so upload is not chunked
    r.headers["Content-Type"] = body["type"];

    void Function(List<int> event) add = r.sink.add;

    if (progress != null) {
      int current = 0;
      var add2 = add;
      add = (List<int> event) {
        current += event.length;
        progress(current / size);
        add2(event); // this shall call the original add
      };
    }

    // connect file to sink
    f.openRead().listen(add, onDone: r.sink.close, onError: r.sink.addError);

    // perform upload
    var postRes = await http.Client().send(r);

    if (postRes.statusCode >= 300) {
      // something went wrong
      var postBody = await postRes.stream.bytesToString();
      throw AtOnlineNetworkException(postBody);
    }

    // call finalize, return response
    return await req(res["Complete"], method: "POST", context: context);
  }

  Future<String> token() async {
    int now = (DateTime.now().millisecondsSinceEpoch / 1000).round();

    if ((expiresV > now) && (tokenV != null)) {
      return tokenV!;
    }
    // grab token

    if (!storageLoadCompleted) {
      var e = await storage.read(key: "expires");
      print("loading token, expire = $e");
      if (e != null) {
        int exp = int.parse(e);
        if (exp > now) {
          // token is still valid (in theory)
          tokenV = await storage.read(key: "access_token");
          if (tokenV != null) {
            expiresV = exp;
            storageLoadCompleted = true;
            return tokenV!;
          }
        }
      }
    }

    // need a new token
    String? ref = await storage.read(key: "refresh_token");
    if ((ref == null) || (ref == "")) {
      // user is not logged in or we don't have a refresh_token, need to have user login again
      if (tokenV != "") {
        tokenV = "";
        expiresV = 0;
	notifyListeners(); // change in state → not logged in anymore
      }
      throw new AtOnlineLoginException("no token available");
    }

    print("token expired, refreshing");

    // perform refresh
    var req = <String, dynamic>{
      "grant_type": "refresh_token",
      "client_id": appId,
      "refresh_token": ref,
    };
    var res = await this
        .req("OAuth2:token", method: "POST", body: req, skipDecode: true);

    print("got new token, storing");

    await storeToken(res);

    print("token stored");

    return res["access_token"].toString();
  }

  Future<void> storeToken(dynamic res) async {
    int now = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    expiresV = int.parse(res["expires_in"].toString()) + now;
    tokenV = res["access_token"];
    storageLoadCompleted = true; // local version is authoritative

    await storage.write(key: "access_token", value: tokenV);
    await storage.write(key: "expires", value: expiresV.toString());

    if ((res["refresh_token"] != null) && (res["refresh_token"] != "")) {
      await storage.write(key: "refresh_token", value: res["refresh_token"]);
    }
    notifyListeners();
  }

  voidToken() async {
    // remove token
    if (tokenV == "") {
      // nothing to do
      return;
    }
    expiresV = 0;
    tokenV = "";

    await Future.wait([
      storage.delete(key: "access_token"),
      storage.delete(key: "expires"),
      storage.delete(key: "refresh_token")
    ]);
    notifyListeners();
  }

  void _updateCookie(http.Response response) {
    String? allSetCookie = response.headers['set-cookie'];

    if (allSetCookie != null) {
      var setCookies = allSetCookie.split(',');

      for (var setCookie in setCookies) {
        var cookies = setCookie.split(';');

        for (var cookie in cookies) {
          _setCookie(cookie);
        }
      }
    }
  }

  void _setCookie(String rawCookie) {
    if (rawCookie.length > 0) {
      var keyValue = rawCookie.split('=');
      if (keyValue.length == 2) {
        var key = keyValue[0].trim();
        var value = keyValue[1];

        // ignore keys that aren't cookies
        if (key == 'path' || key == 'expires')
          return;

        this.cookies[key] = value;
      }
    }
  }

  String _generateCookieHeader() {
    String cookie = "";

    for (var key in cookies.keys) {
      if (cookie.length > 0)
        cookie += ";";
      cookie += key + "=" + cookies[key]!;
    }

    return cookie;
  }
}
