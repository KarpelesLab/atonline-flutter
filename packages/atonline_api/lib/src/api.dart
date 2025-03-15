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

/// Exception thrown when a network error occurs during API requests
class AtOnlineNetworkException implements Exception {
  String msg;

  AtOnlineNetworkException(this.msg);
}

/// Exception thrown when a login or authentication error occurs
class AtOnlineLoginException implements Exception {
  String msg;

  AtOnlineLoginException(this.msg);
}

/// Exception thrown when the AtOnline platform returns an error response
class AtOnlinePlatformException implements Exception {
  dynamic data;

  AtOnlinePlatformException(this.data);
}

/// Represents pagination information for API responses
class AtOnlinePaging {
  /// Total number of items available
  int count;
  /// Maximum page number
  int pageMax;
  /// Current page number
  int pageNumber;
  /// Number of items per page
  int resultPerPage;

  AtOnlinePaging(this.count, this.pageMax, this.pageNumber, this.resultPerPage);
}

/// Wrapper for API responses that provides iteration and property access
class AtOnlineApiResult extends Iterable<dynamic> {
  /// Raw response data from the API
  dynamic res;
  /// Pagination information if available
  AtOnlinePaging? paging;
  /// Response processing time
  double? time;
  /// Result status (e.g. "success")
  String? result;
  /// Shortcut to access the data field in the response
  dynamic get data => res["data"];

  // Used when data is a key/values pair and not accessible by index.
  dynamic _iterableValue;

  /// Allows iteration over the data in the response
  @override
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

  /// Parses the API response and extracts pagination and metadata
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

  /// Access response data by key
  /// Keys that start with @ access top-level response properties
  /// Other keys access data within the "data" field
  dynamic operator [](String key) {
    if (key.startsWith("@")) {
      return res[key.substring(1)];
    }

    return res["data"][key];
  }
}

/// Callback for tracking upload progress
typedef void ProgressCallback(double status);

/// Main class for interacting with AtOnline APIs
/// 
/// Handles authentication, API requests, and token management
class AtOnline with ChangeNotifier {
  /// Application ID used for authentication
  final String appId;
  /// Base URL prefix for API requests
  final String prefix;
  /// Authentication endpoint URL
  final String authEndpoint;
  /// Singleton instances for each app ID
  static Map<String, AtOnline> _instances = {};
  /// Cookies for maintaining session state
  Map<String, String> cookies = {};

  /// Factory constructor that maintains singleton instances per appId
  /// 
  /// @param appId The application ID for AtOnline
  /// @param prefix The API base URL (defaults to AtOnline hub)
  /// @param authEndpoint The OAuth2 authentication endpoint
  factory AtOnline(appId,
      {prefix = "https://hub.atonline.com/_special/rest/",
      authEndpoint = "https://hub.atonline.com/_special/rest/OAuth2:auth"}) {
    if (!_instances.containsKey(appId))
      _instances[appId] = new AtOnline._internal(appId, prefix, authEndpoint);

    return _instances[appId]!;
  }

  /// Internal constructor used by the factory
  AtOnline._internal(this.appId, this.prefix, this.authEndpoint);

  /// Secure storage for tokens and authentication data
  final storage = new FlutterSecureStorage();

  /// Token expiration timestamp (Unix epoch seconds)
  int expiresV = 0;
  /// Current access token
  String? tokenV = "";
  /// Flag indicating if token has been loaded from storage
  bool storageLoadCompleted = false;
  /// User object for the current session
  User? _user;

  /// Access the User object for the current session
  /// Instantiates a new User if not already created
  User get user {
    if (_user == null) _user = User(this);

    return _user!;
  }

  /// Makes a request to the AtOnline API
  /// 
  /// @param path The API endpoint path
  /// @param method HTTP method (GET, POST, etc.)
  /// @param body Request body (will be JSON encoded)
  /// @param headers Additional HTTP headers
  /// @param context Context parameters to send with the request
  /// @param skipDecode If true, returns raw response instead of AtOnlineApiResult
  /// @return API response as AtOnlineApiResult or raw JSON if skipDecode is true
  Future<dynamic> req(String path,
      {String method = "GET",
      dynamic body,
      Map<String, String>? headers,
      Map<String, String>? context,
      bool skipDecode = false}) async {
    print("Running $method $path");

    http.Response res;

    var _ctx = <String, String?>{};
    headers ??= {};

    // Add locale and timezone to context
    _ctx["_ctx[l]"] = Intl.defaultLocale;
    _ctx["_ctx[t]"] = DateTime.now().timeZoneName; // grab timezone name

    // Add custom context parameters
    if (context != null) {
      context.forEach((k, v) => _ctx["_ctx[" + k + "]"] = v);
    }
    // For GET requests, body is passed as a special query parameter
    if ((method == "GET") && (body != null)) {
      _ctx["_"] = json.encode(body);
    }

    // Add cookies if present
    if (cookies.isNotEmpty) {
      headers['cookie'] = _generateCookieHeader();
    }
    // Add client ID header
    headers["Sec-ClientId"] = appId;

    // Construct the full URL with query parameters
    Uri urlPath = Uri.parse(prefix + path);
    urlPath = Uri(
        scheme: urlPath.scheme,
        host: urlPath.host,
        path: urlPath.path,
        queryParameters: _ctx);

    // Execute request based on HTTP method
    switch (method) {
      case "GET":
        print("API GET request: $urlPath");
        try {
          res = await http.get(urlPath, headers: headers);
        } on http.ClientException catch(e) {
          if (e.message == "Failed to parse header value") {
            // [ERROR:flutter/lib/ui/ui_dart_state.cc(198)] Unhandled Exception: Failed to parse header value
            // See: https://github.com/dart-lang/sdk/issues/46442
            // Flutter does not handle properly Bearer auth failure and will return a crap error
            if (!headers.containsKey("Authorization")) {
              throw e;
            }
            // Token might be expired, mark as expired and retry with a new token
            expiresV = 0; 
            headers["Authorization"] = "Bearer " + await token();
            res = await http.get(urlPath, headers: headers);
          }
          throw e; // Rethrow other exceptions
        }
        break;
      case "POST":
        // Encode body as JSON for POST requests
        if (body != null) {
          headers["Content-Type"] = "application/json";
          body = json.encode(body);
        }

        try {
          res = await http.post(urlPath, body: body, headers: headers);
        } on http.ClientException catch(e) {
          if (e.message == "Failed to parse header value") {
            // Same token error handling as in GET
            if (!headers.containsKey("Authorization")) {
              throw e;
            }
            expiresV = 0; 
            headers["Authorization"] = "Bearer " + await token();
            res = await http.post(urlPath, body: body, headers: headers);
          }
          throw e;
        }
        break;
      default:
        // For other HTTP methods (PUT, DELETE, etc.)
        var req = http.Request(method, urlPath);
        headers.forEach((String k, String v) {
          req.headers[k] = v;
        });
        if (body != null) {
          req.body = json.encode(body);
          req.headers["Content-Type"] = "application/json";
        }

        try {
          var stream = await http.Client().send(req);
          res = await http.Response.fromStream(stream);
        } on http.ClientException catch(e) {
          if (e.message == "Failed to parse header value") {
            // Same token error handling
            if (!req.headers.containsKey("Authorization")) {
              throw e;
            }
            expiresV = 0;
            req.headers["Authorization"] = "Bearer " + await token();
            var stream = await http.Client().send(req);
            res = await http.Response.fromStream(stream);
          }
          throw e;
        }
    }

    // Update cookies from response
    _updateCookie(res);

    // Handle error responses
    if (res.statusCode >= 300) {
      // Check if error response is in JSON format
      String ct = res.headers["content-type"]!;
      int idx = ct.indexOf(';');
      if (idx > 0) {
        ct = ct.substring(0, idx);
      }
      if (ct == "application/json") {
        // Platform error with JSON payload
        var d = json.decode(res.body);
        print("Got error: ${res.body}");
        
        // Handle special token errors
        if (d.containsKey("token")) {
          switch (d["token"]) {
            case "error_invalid_oauth_refresh_token":
              // Invalid refresh token, clear tokens and throw login exception
              print("got invalid token error, voiding token");
              await voidToken();
              throw new AtOnlineLoginException(d.error);
          }
        }
        throw new AtOnlinePlatformException(d);
      }
      // Non-JSON error response
      print("Error from API: ${res.body}");
      throw new AtOnlineNetworkException(
          "invalid response from api ${res.statusCode} ${res.body}");
    }

    // Parse successful response
    var d = json.decode(res.body);

    // Return raw JSON if skipDecode is true
    if (skipDecode) {
      return d;
    }

    // Check for API-level error
    if (d["result"] != "success") {
      print("Got error: $d");
      throw AtOnlinePlatformException(d);
    }

    // Return structured API result
    return AtOnlineApiResult(d);
  }

  /// Makes an authenticated request to the AtOnline API
  /// 
  /// Automatically adds Bearer token authentication header
  /// 
  /// @param path The API endpoint path
  /// @param method HTTP method (GET, POST, etc.)
  /// @param body Request body
  /// @param headers Additional HTTP headers
  /// @param context Context parameters
  /// @return API response
  Future<dynamic> authReq(String path,
      {String method = "GET",
      dynamic body,
      Map<String, String>? headers,
      Map<String, String>? context}) async {
    if (headers == null) {
      headers = <String, String>{};
    }
    // Add authorization header with token
    headers["Authorization"] = "Bearer " + await token();
    return req(path,
        method: method, body: body, headers: headers, context: context);
  }

  /// Makes an optionally authenticated request to the AtOnline API
  /// 
  /// Tries to add authentication but continues if authentication fails
  /// 
  /// @param path The API endpoint path
  /// @param method HTTP method (GET, POST, etc.)
  /// @param body Request body
  /// @param headers Additional HTTP headers
  /// @param context Context parameters
  /// @return API response
  Future<dynamic> optAuthReq(String path,
      {String method = "GET",
      dynamic body,
      Map<String, String>? headers,
      Map<String, String>? context}) async {
    try {
      if (headers == null) {
        headers = <String, String>{};
      }
      // Try to add authorization but continue even if it fails
      headers["Authorization"] = "Bearer " + await token();
    } on AtOnlineLoginException {
      // Continue without authentication
    } on AtOnlinePlatformException {
      // Continue without authentication
    }
    return req(path,
        method: method, body: body, headers: headers, context: context);
  }

  /// Uploads a file to the AtOnline API with optional progress tracking
  /// 
  /// Uses a two-step process: first requests an upload URL, then uploads the file
  /// 
  /// @param path The API endpoint path for initiating upload
  /// @param f The file to upload
  /// @param body Additional parameters for the upload
  /// @param headers Additional HTTP headers
  /// @param context Context parameters
  /// @param progress Optional callback for tracking upload progress
  /// @return API response after upload is complete
  Future<dynamic> authReqUpload(String path, File f,
      {Map<String, dynamic>? body,
      Map<String, String>? headers,
      Map<String, String>? context,
      ProgressCallback? progress}) async {

    if (body == null) {
      body = <String, dynamic>{};
    }
    // Get file information
    var size = await f.length();
    body["filename"] ??= p.basename(f.path);
    body["type"] ??= lookupMimeType(body["filename"]) ?? "application/octet-stream";
    body["size"] = size;

    // First step: get upload URL from API
    var res = await authReq(path, method: "POST", body: body, context: context);

    // Prepare upload request
    var r = http.StreamedRequest("PUT", Uri.parse(res["PUT"]));
    r.contentLength = size; // required so upload is not chunked
    r.headers["Content-Type"] = body["type"];

    // Set up file streaming
    void Function(List<int> event) add = r.sink.add;

    // Add progress tracking if requested
    if (progress != null) {
      int current = 0;
      var add2 = add;
      add = (List<int> event) {
        current += event.length;
        progress(current / size);
        add2(event); // Call the original add function
      };
    }

    // Connect file to request sink
    f.openRead().listen(add, onDone: r.sink.close, onError: r.sink.addError);

    // Second step: send the file to the upload URL
    var postRes = await http.Client().send(r);

    if (postRes.statusCode >= 300) {
      // Handle upload errors
      var postBody = await postRes.stream.bytesToString();
      throw AtOnlineNetworkException(postBody);
    }

    // Final step: finalize the upload
    return await req(res["Complete"], method: "POST", context: context);
  }

  /// Gets a valid access token, refreshing if necessary
  /// 
  /// First checks if the current token is valid, then tries to load from storage,
  /// and finally attempts to refresh the token using the refresh token
  /// 
  /// @return A valid access token string
  /// @throws AtOnlineLoginException if no valid token or refresh token is available
  Future<String> token() async {
    int now = (DateTime.now().millisecondsSinceEpoch / 1000).round();

    // Return cached token if it's valid
    if ((expiresV > now) && (tokenV != null)) {
      return tokenV!;
    }
    
    // Try to load token from secure storage if we haven't already
    if (!storageLoadCompleted) {
      var e = await storage.read(key: "expires");
      print("loading token, expire = $e");
      if (e != null) {
        int exp = int.parse(e);
        if (exp > now) {
          // Token from storage is still valid
          tokenV = await storage.read(key: "access_token");
          if (tokenV != null) {
            expiresV = exp;
            storageLoadCompleted = true;
            return tokenV!;
          }
        }
      }
    }

    // Need to refresh token using refresh_token
    String? ref = await storage.read(key: "refresh_token");
    if ((ref == null) || (ref == "")) {
      // No refresh token available, user needs to log in again
      if (tokenV != "") {
        tokenV = "";
        expiresV = 0;
        notifyListeners(); // Notify about logout state
      }
      throw new AtOnlineLoginException("no token available");
    }

    print("token expired, refreshing");

    // Perform token refresh using OAuth2 flow
    var req = <String, dynamic>{
      "grant_type": "refresh_token",
      "client_id": appId,
      "refresh_token": ref,
    };
    var res = await this
        .req("OAuth2:token", method: "POST", body: req, skipDecode: true);

    print("got new token, storing");

    // Store the new token
    await storeToken(res);

    print("token stored");

    return res["access_token"].toString();
  }

  /// Stores authentication tokens in secure storage
  /// 
  /// @param res The OAuth2 token response containing access_token, expires_in, etc.
  Future<void> storeToken(dynamic res) async {
    // Calculate expiration time
    int now = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    expiresV = int.parse(res["expires_in"].toString()) + now;
    tokenV = res["access_token"];
    storageLoadCompleted = true; // Mark storage as loaded

    // Save tokens to secure storage
    await storage.write(key: "access_token", value: tokenV);
    await storage.write(key: "expires", value: expiresV.toString());

    // Store refresh token if provided
    if ((res["refresh_token"] != null) && (res["refresh_token"] != "")) {
      await storage.write(key: "refresh_token", value: res["refresh_token"]);
    }
    
    // Notify listeners about login state change
    notifyListeners();
  }

  /// Clears all authentication tokens (logout)
  /// 
  /// Removes tokens from secure storage and resets the current session
  Future<void> voidToken() async {
    // Remove tokens from secure storage
    await Future.wait([
      storage.delete(key: "access_token"),
      storage.delete(key: "expires"),
      storage.delete(key: "refresh_token")
    ]);

    // Skip notification if already logged out
    if (tokenV == "") {
      return;
    }
    
    // Reset session state
    expiresV = 0;
    tokenV = "";

    // Notify listeners about logout
    notifyListeners();
  }

  /// Updates cookies from a HTTP response
  /// 
  /// Extracts Set-Cookie headers and stores them for future requests
  void _updateCookie(http.Response response) {
    String? allSetCookie = response.headers['set-cookie'];

    if (allSetCookie != null) {
      // Split multiple cookies if present (separated by commas)
      var setCookies = allSetCookie.split(',');

      for (var setCookie in setCookies) {
        // Each cookie can have multiple parts separated by semicolons
        var cookies = setCookie.split(';');

        for (var cookie in cookies) {
          _setCookie(cookie);
        }
      }
    }
  }

  /// Parses and stores a single cookie from a Set-Cookie header
  /// 
  /// @param rawCookie The raw cookie string to parse
  void _setCookie(String rawCookie) {
    if (rawCookie.length > 0) {
      // Split cookie into key and value
      var keyValue = rawCookie.split('=');
      if (keyValue.length == 2) {
        var key = keyValue[0].trim();
        var value = keyValue[1];

        // Skip cookie attributes like path and expires
        if (key == 'path' || key == 'expires')
          return;

        // Store the cookie
        this.cookies[key] = value;
      }
    }
  }

  /// Generates a Cookie header value from stored cookies
  /// 
  /// @return Formatted cookie string for use in HTTP requests
  String _generateCookieHeader() {
    String cookie = "";

    // Join all cookies with semicolons
    for (var key in cookies.keys) {
      if (cookie.length > 0)
        cookie += ";";
      cookie += key + "=" + cookies[key]!;
    }

    return cookie;
  }
}
