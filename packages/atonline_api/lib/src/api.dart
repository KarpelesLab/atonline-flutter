import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:ui' show VoidCallback;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' show Intl;
import 'package:mime/mime.dart';

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

typedef void ProgressCallback(double status);

class AtOnline {
  final String appId;
  final String prefix;
  final String authEndpoint;
  static Map<String, AtOnline> _instances = {};

  factory AtOnline(appId,
      {prefix = "https://hub.atonline.com/_special/rest/",
      authEndpoint = "https://hub.atonline.com/_special/rest/OAuth2:auth"}) {
    if (!_instances.containsKey(appId))
      _instances[appId] = new AtOnline._internal(appId, prefix, authEndpoint);

    return _instances[appId];
  }

  AtOnline._internal(this.appId, this.prefix, this.authEndpoint);

  final storage = new FlutterSecureStorage();
  final ObserverList<VoidCallback> _listeners = ObserverList<VoidCallback>();

  // details of current session
  int expiresV = 0;
  String tokenV = "";
  bool storageLoadCompleted = false;
  User _user;

  User get user {
    if (_user == null) _user = User(this);

    return _user;
  }

  Future<dynamic> req(String path,
      {String method = "GET",
      dynamic body,
      Map<String, String> headers,
      bool skipDecode = false}) async {
    print("Running $method $path");

    http.Response res;

    var _ctx = <String, String>{};

    _ctx["_ctx[l]"] = Intl.defaultLocale;

    Uri urlPath = Uri.parse(prefix + path);
    urlPath = Uri(
        scheme: urlPath.scheme,
        host: urlPath.host,
        path: urlPath.path,
        queryParameters: _ctx);

    switch (method) {
      case "GET":
        if (body != null) {
          urlPath = Uri(
              scheme: urlPath.scheme,
              host: urlPath.host,
              path: urlPath.path,
              queryParameters: {}
                ..addAll(urlPath.queryParameters)
                ..addAll(body));
          res = await http.get(urlPath, headers: headers);
        } else {
          res = await http.get(urlPath.toString(), headers: headers);
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

        res = await http.post(urlPath.toString(), body: body, headers: headers);
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

        var stream = await http.Client().send(req);
        res = await http.Response.fromStream(stream);
    }

    if (res.statusCode >= 300) {
      // something is wrong

      // check if response is json
      String ct = res.headers["content-type"];
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
      throw new AtOnlinePlatformException(d);
    }

    return d["data"];
  }

  Future<dynamic> authReq(String path,
      {String method = "GET",
      dynamic body,
      Map<String, String> headers}) async {
    if (headers == null) {
      headers = <String, String>{};
    }
    headers["Authorization"] = "Bearer " + await token();
    return req(path, method: method, body: body, headers: headers);
  }

  Future<dynamic> optAuthReq(String path,
      {String method = "GET",
      dynamic body,
      Map<String, String> headers}) async {
    try {
      if (headers == null) {
        headers = <String, String>{};
      }
      headers["Authorization"] = "Bearer " + await token();
    } on AtOnlineLoginException {} on AtOnlinePlatformException {}
    return req(path, method: method, body: body, headers: headers);
  }

  Future<dynamic> authReqUpload(String path, File f,
      {Map<String, dynamic> body,
      Map<String, String> headers,
      ProgressCallback progress}) async {
    var mime = lookupMimeType(f.path) ?? "application/octet-stream";
    var size = await f.length();

    if (body == null) {
      body = <String, dynamic>{};
    }
    body["filename"] = f.path;
    body["type"] = mime;
    body["size"] = size;

    // first, get upload ready
    var res = await authReq(path, method: "POST", body: body);

    var r = http.StreamedRequest("PUT", Uri.parse(res["PUT"]));
    r.contentLength = size; // required so upload is not chunked
    r.headers["Content-Type"] = mime;

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
    return await req(res["Complete"], method: "POST");
  }

  Future<String> token() async {
    int now = (DateTime.now().millisecondsSinceEpoch / 1000).round();

    if (expiresV > now) {
      return tokenV;
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
          expiresV = exp;
          storageLoadCompleted = true;
          return tokenV;
        }
      }
    }

    // need a new token
    String ref = await storage.read(key: "refresh_token");
    if ((ref == null) || (ref == "")) {
      // user is not logged in or we don't have a refresh_token, need to have user login again
      if (tokenV != "") {
        tokenV = "";
        expiresV = 0;
        _fireNotification(); // change in state → not logged in anymore
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
    _fireNotification();
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
    _fireNotification();
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _fireNotification() {
    final List<VoidCallback> localListeners =
        List<VoidCallback>.from(_listeners);
    for (VoidCallback listener in localListeners) {
      try {
        listener();
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'Api library',
          context: 'while notifying listeners for Api',
        ));
      }
    }
  }
}
