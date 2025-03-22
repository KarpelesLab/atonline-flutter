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
    if (kDebugMode) {
      print("Running $method $path");
    }

    // Prepare request parameters
    headers ??= {};
    var _ctx = await _prepareRequestContext(context, method, body);
    
    // Add cookies and client ID
    if (cookies.isNotEmpty) {
      headers['cookie'] = _generateCookieHeader();
    }
    headers["Sec-ClientId"] = appId;

    // Construct the full URL with query parameters
    Uri urlPath = _buildRequestUrl(path, _ctx);
    
    if (kDebugMode) {
      print("API $method request: $urlPath");
    }

    // Execute request with retry logic for token issues
    http.Response res;
    try {
      res = await _executeRequest(method, urlPath, headers, body);
    } catch (e) {
      if (kDebugMode) {
        print("Request error: $e");
        print("Stack trace: ${StackTrace.current}");
      }
      rethrow;
    }

    // Update cookies from response
    _updateCookie(res);

    // Handle error responses
    if (res.statusCode >= 300) {
      return await _handleErrorResponse(res);
    }

    // Parse successful response
    dynamic responseData;
    try {
      responseData = json.decode(res.body);
    } catch (e) {
      throw AtOnlineNetworkException("Failed to parse response as JSON: $e");
    }

    // Return raw JSON if skipDecode is true
    if (skipDecode) {
      return responseData;
    }

    // Check for API-level error
    if (responseData["result"] != "success") {
      if (kDebugMode) {
        print("Got API error: ${responseData.toString()}");
      }
      throw AtOnlinePlatformException(responseData);
    }

    // Return structured API result
    return AtOnlineApiResult(responseData);
  }
  
  /// Prepares query parameters for a request
  /// 
  /// This method builds the query string parameters that will be included in the URL
  /// 
  /// @param context Custom context parameters
  /// @param method HTTP method
  /// @param body Request body (for GET requests, body is sent as query parameter)
  /// @return Map of query parameters
  Future<Map<String, String?>> _prepareRequestContext(
      Map<String, String>? context, String method, dynamic body) async {
    var queryParams = <String, String?>{};
    
    // Add locale and timezone to context
    queryParams["_ctx[l]"] = Intl.defaultLocale;
    queryParams["_ctx[t]"] = DateTime.now().timeZoneName;
    
    // Add custom context parameters
    if (context != null) {
      context.forEach((k, v) => queryParams["_ctx[$k]"] = v);
    }
    
    // For GET requests, body is passed as a special query parameter
    if (method == "GET" && body != null) {
      queryParams["_"] = json.encode(body);
    }
    
    return queryParams;
  }
  
  /// Builds the request URL with query parameters
  /// 
  /// @param path API endpoint path
  /// @param queryParams Query parameters to include
  /// @return Fully constructed URI
  Uri _buildRequestUrl(String path, Map<String, String?> queryParams) {
    Uri urlPath = Uri.parse(prefix + path);
    return Uri(
      scheme: urlPath.scheme,
      host: urlPath.host,
      path: urlPath.path,
      queryParameters: queryParams
    );
  }
  
  /// Executes an HTTP request with automatic token refresh on failure
  /// 
  /// @param method HTTP method
  /// @param url Request URL
  /// @param headers HTTP headers
  /// @param body Request body
  /// @return HTTP response
  Future<http.Response> _executeRequest(
      String method, Uri url, Map<String, String> headers, dynamic body) async {
    // First attempt
    try {
      return await _performRequest(method, url, headers, body);
    } on http.ClientException catch(e) {
      // Handle token errors
      if (e.message == "Failed to parse header value" && headers.containsKey("Authorization")) {
        // Token might be expired, mark as expired and retry with a new token
        expiresV = 0;
        headers["Authorization"] = "Bearer ${await token()}";
        return await _performRequest(method, url, headers, body);
      }
      rethrow;
    }
  }
  
  /// Performs the actual HTTP request
  /// 
  /// @param method HTTP method
  /// @param url Request URL
  /// @param headers HTTP headers
  /// @param body Request body
  /// @return HTTP response
  Future<http.Response> _performRequest(
      String method, Uri url, Map<String, String> headers, dynamic body) async {
    switch (method) {
      case "GET":
        return await http.get(url, headers: headers);
        
      case "POST":
        // Encode body as JSON for POST requests
        Map<String, String> postHeaders = Map.from(headers);
        String? encodedBody;
        
        if (body != null) {
          postHeaders["Content-Type"] = "application/json";
          encodedBody = json.encode(body);
        }
        
        return await http.post(url, headers: postHeaders, body: encodedBody);
        
      default:
        // For other HTTP methods (PUT, DELETE, etc.)
        var request = http.Request(method, url);
        
        // Add headers
        headers.forEach((String k, String v) {
          request.headers[k] = v;
        });
        
        // Add body if present
        if (body != null) {
          request.body = json.encode(body);
          request.headers["Content-Type"] = "application/json";
        }
        
        // Send request
        var streamedResponse = await http.Client().send(request);
        return await http.Response.fromStream(streamedResponse);
    }
  }
  
  /// Handles error responses from the API
  /// 
  /// @param response HTTP response with error status
  /// @return Never returns - always throws an appropriate exception
  Future<dynamic> _handleErrorResponse(http.Response response) async {
    // Check if response has a content type
    if (!response.headers.containsKey("content-type")) {
      throw AtOnlineNetworkException(
          "Invalid response from API: ${response.statusCode} (no content type)");
    }
    
    // Extract content type
    String contentType = response.headers["content-type"]!;
    int separatorIndex = contentType.indexOf(';');
    if (separatorIndex > 0) {
      contentType = contentType.substring(0, separatorIndex);
    }
    
    // Handle JSON errors
    if (contentType == "application/json" && response.body.isNotEmpty) {
      try {
        final data = json.decode(response.body);
        
        // Handle token errors
        if (data is Map && data.containsKey("token")) {
          switch (data["token"]) {
            case "error_invalid_oauth_refresh_token":
            case "error_invalid_refresh_token":
              if (kDebugMode) {
                print("Invalid token error, voiding token");
              }
              await voidToken();
              throw AtOnlineLoginException(data["error"] ?? "Invalid refresh token");
          }
        }
        
        throw AtOnlinePlatformException(data);
      } catch (e) {
        if (e is AtOnlineLoginException || e is AtOnlinePlatformException) {
          rethrow;
        }
      }
    }
    
    // Handle non-JSON errors
    if (kDebugMode) {
      print("API Error: ${response.statusCode}");
      print("Response body: ${response.body}");
    }
    
    throw AtOnlineNetworkException(
        "Invalid response from API: ${response.statusCode}");
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

    // Return cached token if it's valid with at least 60s margin
    if ((expiresV > now + 60) && (tokenV != null && tokenV!.isNotEmpty)) {
      return tokenV!;
    }
    
    // Try to load token from secure storage if we haven't already completed that step
    if (!storageLoadCompleted) {
      try {
        await _loadTokenFromStorage(now);
        
        // If we have a valid token now, return it
        if ((expiresV > now + 60) && (tokenV != null && tokenV!.isNotEmpty)) {
          return tokenV!;
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error loading token from storage: $e");
        }
        // Continue to token refresh
      }
    }

    // Need to refresh token using refresh_token
    return await _refreshToken();
  }
  
  /// Loads authentication tokens from secure storage
  /// 
  /// @param now Current timestamp in seconds
  /// @return true if valid token was loaded, false otherwise
  Future<bool> _loadTokenFromStorage(int now) async {
    try {
      final expireStr = await storage.read(key: "expires");
      
      if (kDebugMode) {
        print("Loading token, expire = $expireStr");
      }
      
      if (expireStr != null) {
        final expireTime = int.parse(expireStr);
        
        // Check if token is still valid
        if (expireTime > now) {
          final accessToken = await storage.read(key: "access_token");
          
          if (accessToken != null && accessToken.isNotEmpty) {
            tokenV = accessToken;
            expiresV = expireTime;
            storageLoadCompleted = true;
            return true;
          }
        }
      }
      
      // Mark storage as checked even if we didn't find a valid token
      storageLoadCompleted = true;
      return false;
    } catch (e) {
      // Mark storage as checked to avoid repeated failing attempts
      storageLoadCompleted = true;
      if (kDebugMode) {
        print("Error reading token from storage: $e");
        print("Stack trace: ${StackTrace.current}");
      }
      return false;
    }
  }
  
  /// Refreshes the access token using the refresh token
  /// 
  /// @return New access token
  /// @throws AtOnlineLoginException if refresh fails or no refresh token is available
  Future<String> _refreshToken() async {
    // Get refresh token
    final refreshToken = await storage.read(key: "refresh_token");
    
    if (refreshToken == null || refreshToken.isEmpty) {
      // No refresh token available, user needs to log in again
      if (tokenV != null && tokenV!.isNotEmpty) {
        tokenV = "";
        expiresV = 0;
        notifyListeners(); // Notify about logout state
      }
      throw AtOnlineLoginException("No refresh token available");
    }

    if (kDebugMode) {
      print("Token expired, refreshing");
    }

    try {
      // Perform token refresh using OAuth2 flow
      final requestBody = <String, dynamic>{
        "grant_type": "refresh_token",
        "client_id": appId,
        "refresh_token": refreshToken,
      };
      
      // Note: We use a more direct request method here to avoid recursion
      final requestPath = '${prefix}OAuth2:token';
      final url = Uri.parse(requestPath);
      final headers = <String, String>{
        "Content-Type": "application/json",
        "Sec-ClientId": appId,
      };
      
      // Add cookies if available
      if (cookies.isNotEmpty) {
        headers['cookie'] = _generateCookieHeader();
      }
      
      // Make the refresh token request
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(requestBody),
      );
      
      if (response.statusCode >= 300) {
        throw AtOnlineLoginException("Token refresh failed: ${response.statusCode}");
      }
      
      final responseData = json.decode(response.body);
      
      if (kDebugMode) {
        print("Got new token, storing");
      }

      // Store the new token
      await storeToken(responseData);

      if (kDebugMode) {
        print("Token stored");
      }

      return responseData["access_token"].toString();
    } catch (e) {
      // Clear token state on error
      await voidToken();
      
      if (e is AtOnlineLoginException) {
        rethrow;
      }
      
      throw AtOnlineLoginException("Failed to refresh token: $e");
    }
  }

  /// Stores authentication tokens in secure storage
  /// 
  /// @param res The OAuth2 token response containing access_token, expires_in, etc.
  Future<void> storeToken(Map<String, dynamic> res) async {
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
    final allSetCookie = response.headers['set-cookie'];

    if (allSetCookie != null && allSetCookie.isNotEmpty) {
      // RFC 6265 requires multiple cookies to be sent in separate Set-Cookie headers,
      // but sometimes they're combined with commas. We handle both cases.
      
      // First, try to split by comma, but be careful about commas within values
      // This is a simplified approach; for a full proper parser, use a specialized cookie library
      List<String> parsedCookies = [];
      
      // Simple comma splitting - works for most cases
      final rawCookies = allSetCookie.split(',');
      
      // Process each raw cookie
      for (var rawCookie in rawCookies) {
        // Check if this is a new cookie or part of the previous one (comma in value)
        if (parsedCookies.isNotEmpty && !rawCookie.contains('=')) {
          // This is likely part of the previous cookie's value containing a comma
          parsedCookies[parsedCookies.length - 1] += ',$rawCookie';
        } else {
          parsedCookies.add(rawCookie);
        }
      }
      
      // Process each cookie
      for (var cookieStr in parsedCookies) {
        // Each cookie string can have multiple parts separated by semicolons
        // The first part is the name-value pair, rest are attributes
        final cookieParts = cookieStr.split(';');
        
        if (cookieParts.isNotEmpty) {
          // Process the name-value part
          _setCookie(cookieParts[0].trim());
        }
      }
    }
  }

  /// Parses and stores a single cookie from a Set-Cookie header
  /// 
  /// @param rawCookie The raw cookie name-value part
  void _setCookie(String rawCookie) {
    if (rawCookie.isEmpty) {
      return;
    }
    
    // Split cookie into key and value at the first equals sign
    final equalsIndex = rawCookie.indexOf('=');
    
    if (equalsIndex > 0) {
      final key = rawCookie.substring(0, equalsIndex).trim();
      final value = rawCookie.substring(equalsIndex + 1);
      
      // Skip cookie attributes like path and expires
      if (key.toLowerCase() == 'path' || 
          key.toLowerCase() == 'expires' ||
          key.toLowerCase() == 'domain' ||
          key.toLowerCase() == 'max-age' ||
          key.toLowerCase() == 'secure' ||
          key.toLowerCase() == 'httponly' ||
          key.toLowerCase() == 'samesite') {
        return;
      }
      
      // Store the cookie
      cookies[key] = value;
      
      if (kDebugMode) {
        print("Cookie set: $key (value hidden for security)");
      }
    }
  }

  /// Generates a Cookie header value from stored cookies
  /// 
  /// @return Formatted cookie string for use in HTTP requests
  String _generateCookieHeader() {
    if (cookies.isEmpty) {
      return "";
    }
    
    // Join all cookies with semicolons
    return cookies.entries
        .map((entry) => "${entry.key}=${entry.value}")
        .join('; ');
  }
}
