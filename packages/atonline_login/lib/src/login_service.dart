import 'dart:io';
import 'package:atonline_api/atonline_api.dart';

/// Service responsible for handling AtOnline login API interactions
abstract class LoginService {
  /// Submit login form data to AtOnline API
  Future<Map<String, dynamic>> submitLoginData({
    required String action,
    required String clientSessionId,
    required String session,
    Map<String, String>? formData,
  });
  
  /// Process OAuth2 login - v2 format
  Future<Map<String, dynamic>> processOAuth2Login({
    required String oauth2Id,
    required String redirectUri,
    required String clientSessionId,
    required String session,
  });
  
  /// Store token and fetch user details
  Future<bool> completeLogin(String token);
  
  /// Upload files associated with the login
  Future<void> uploadFiles(Map<String, File> files, Map<String, dynamic> fileFields);
  
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
  Future<Map<String, dynamic>> submitLoginData({
    required String action,
    required String clientSessionId,
    required String session,
    Map<String, String>? formData,
  }) async {
    // generate request
    var body = <String, String>{
      "client_id": api.appId,
      "image_variation": User.imageVariation,
      "action": action,
      "session": session,
      "client_sid": clientSessionId,
    };
    
    // Add form data if available
    if (formData != null && formData.isNotEmpty) {
      body.addAll(formData);
    }
    
    // Make API request
    return await api.optAuthReq("User:flow", method: "POST", body: body);
  }
  
  @override
  Future<Map<String, dynamic>> processOAuth2Login({
    required String oauth2Id,
    required String redirectUri,
    required String clientSessionId,
    required String session,
  }) async {
    return await submitLoginData(
      action: "login",
      clientSessionId: clientSessionId,
      session: session,
      formData: {
        "oauth2": oauth2Id,
      },
    );
  }
  
  @override
  Future<bool> completeLogin(String token) async {
    try {
      await api.storeToken(token);
    } catch (e) {
      // token was invalid
      await api.voidToken();
      return false;
    }
    
    await api.user.fetchLogin();
    return api.user.isLoggedIn();
  }
  
  @override
  Future<void> uploadFiles(Map<String, File> files, Map<String, dynamic> fileFields) async {
    if (files.isEmpty) return;
    
    var futures = <Future>[];
    files.forEach((k, f) {
      var fi = fileFields[k];
      futures.add(api.authReqUpload(fi["target"], f, body: fi["param"]));
    });
    
    await Future.wait(futures);
    await api.user.fetchLogin(); // Refresh user data
  }
  
  @override
  Future<dynamic> fetchDynamicOptions(String api) async {
    try {
      // Make an API request to fetch the options
      final result = await this.api.optAuthReq(api);
      return result;
    } catch (e) {
      print("Error fetching dynamic options: $e");
      throw e;
    }
  }
  
  @override
  bool isUserLoggedIn() {
    return api.user.isLoggedIn();
  }
}