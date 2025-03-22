import 'dart:convert';
import 'dart:io';
import 'package:atonline_api/atonline_api.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for handling AtOnline login API interactions
abstract class LoginService {
  /// Submit login form data to AtOnline API
  Future<dynamic> submitLoginData({
    required String action,
    required String session,
    Map<String, String>? formData,
  });

  /// Process OAuth2 login - v2 format
  Future<dynamic> processOAuth2Login({
    required String oauth2Id,
    required String redirectUri,
    required String session,
  });

  /// Store token and fetch user details
  ///
  /// Token must be a Map object (treated as opaque)
  Future<bool> completeLogin(Map<String, dynamic> token);

  /// Upload files associated with the login
  Future<void> uploadFiles(
      Map<String, File> files, Map<String, dynamic> fileFields);

  /// Fetch data for dynamic select options
  Future<dynamic> fetchDynamicOptions(String api);

  /// Check if user is logged in
  bool isUserLoggedIn();
}

/// Default implementation of LoginService using AtOnline API
class DefaultLoginService implements LoginService {
  final AtOnline api;

  DefaultLoginService(this.api);

  @override
  Future<dynamic> submitLoginData({
    required String action,
    required String session,
    Map<String, String>? formData,
  }) async {
    // generate request
    var body = <String, dynamic>{};

    // For initial requests (no session), include action, v2, and client_id
    if (session.isEmpty) {
      body["action"] = action;
      body["v2"] = true; // Enable v2 API format - using boolean true
      body["client_id"] = api.appId;
    } else {
      // For subsequent requests, include session but NOT action/v2/client_id
      body["session"] = session;
      body["image_variation"] = User.imageVariation;
    }

    // Add form data if available
    if (formData != null && formData.isNotEmpty) {
      // Convert string values to appropriate types when adding form data
      formData.forEach((key, value) {
        body[key] = value;
      });
    }

    // Log request data in debug mode
    if (kDebugMode) {
      print('📡 User:flow API request:');
      if (session.isEmpty) {
        print('Initial request with action: $action');
      } else {
        print('Continued request with session: $session');
      }

      // JSON encode the exact request body with all data
      final bodyJson = jsonEncode(body);
      print('Request body: $bodyJson');
    }

    // Make API request
    final response =
        await api.optAuthReq("User:flow", method: "POST", body: body);

    // Log response data in debug mode - show everything in dev mode
    if (kDebugMode) {
      print('📥 User:flow API response - Type: ${response.runtimeType}');

      // Log the actual response data without masking
      try {
        if (response is Map) {
          print('Response data: ${jsonEncode(response)}');
        } else if (response is List) {
          print('Response data (list): ${jsonEncode(response)}');
        } else if (response is AtOnlineApiResult) {
          final data = response.data ?? response.res;
          print('Response data (API result): ${jsonEncode(data)}');
        } else {
          print(
              'Response data type not directly serializable: ${response.runtimeType}');
        }
      } catch (e) {
        print('Failed to serialize response: $e');
      }
    }

    // Convert AtOnlineApiResult to Map if needed
    if (response is AtOnlineApiResult) {
      if (kDebugMode) {
        print('Converting AtOnlineApiResult to Map');
      }

      // Check if the data field is what we need
      if (response.data != null) {
        return response.data;
      }

      // Fallback to raw response
      return response.res;
    }

    return response;
  }

  @override
  Future<dynamic> processOAuth2Login({
    required String oauth2Id,
    required String redirectUri,
    required String session,
  }) async {
    if (kDebugMode) {
      print('🔐 Processing OAuth2 login:');

      // Prepare actual parameters that will be used
      final Map<String, dynamic> requestParams = {
        'oauth2': oauth2Id,
        'redirect_uri': redirectUri,
      };

      // Log whether this is initial or continued request
      if (session.isEmpty) {
        requestParams['action'] = 'login';
        requestParams['v2'] = true;
        requestParams['client_id'] = api.appId;
        print('Initial OAuth2 request (no session)');
      } else {
        requestParams['session'] = session;
        requestParams['image_variation'] = User.imageVariation;
        print('Continued OAuth2 request with session: $session');
      }

      // JSON encode the actual parameters without masking
      final logJson = jsonEncode(requestParams);
      print('OAuth2 request parameters: $logJson');
    }

    // Only include necessary fields based on if this is an initial request
    final Map<String, String> formParams = {
      "oauth2": oauth2Id,
      "redirect_uri": redirectUri,
    };

    return await submitLoginData(
      action: "login", // action will only be included if session is empty
      session: session,
      formData: formParams,
    );
  }

  @override
  Future<bool> completeLogin(Map<String, dynamic> token) async {
    try {
      if (kDebugMode) {
        print('🔑 Completing login with token object');
        print('Token: ${jsonEncode(token)}');
      }

      await api.storeToken(token);
    } catch (e) {
      // token was invalid
      if (kDebugMode) {
        print('❌ Token validation failed: $e');
      }
      await api.voidToken();
      return false;
    }

    await api.user.fetchLogin();
    final isLoggedIn = api.user.isLoggedIn();

    if (kDebugMode) {
      print(
          '👤 User login status: ${isLoggedIn ? 'Logged in' : 'Login failed'}');
      if (isLoggedIn) {
        print('User data: ${api.user.info?.object}');
      }
    }

    return isLoggedIn;
  }

  @override
  Future<void> uploadFiles(
      Map<String, File> files, Map<String, dynamic> fileFields) async {
    if (files.isEmpty) return;

    if (kDebugMode) {
      print('📤 Uploading files:');
      print('  Number of files: ${files.length}');
      files.forEach((key, file) {
        print('  File "$key": ${file.path} (${file.lengthSync()} bytes)');
        final fileFieldData = fileFields[key];
        print('  Upload target: ${fileFieldData["target"]}');
        print('  Parameters: ${fileFieldData["param"]}');
      });
    }

    var futures = <Future>[];
    files.forEach((k, f) {
      var fi = fileFields[k];
      futures.add(api.authReqUpload(fi["target"], f, body: fi["param"]));
    });

    try {
      await Future.wait(futures);
      if (kDebugMode) {
        print('✅ All files uploaded successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error uploading files: $e');
      }
      rethrow;
    }

    await api.user.fetchLogin(); // Refresh user data
    if (kDebugMode) {
      print('👤 User data refreshed after file uploads');
    }
  }

  @override
  Future<dynamic> fetchDynamicOptions(String api) async {
    if (kDebugMode) {
      print('🔍 Fetching dynamic options from API: $api');
    }

    try {
      // Make an API request to fetch the options
      final result = await this.api.optAuthReq(api);

      if (kDebugMode) {
        print('📥 Dynamic options API response:');
        print(result);
      }

      // Convert AtOnlineApiResult to Map if needed
      if (result is AtOnlineApiResult) {
        if (kDebugMode) {
          print('Converting AtOnlineApiResult to Map for dynamic options');
        }
        // Access the data field from AtOnlineApiResult
        return result.data;
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching dynamic options: $e');
      }
      throw e;
    }
  }

  @override
  bool isUserLoggedIn() {
    return api.user.isLoggedIn();
  }
}
