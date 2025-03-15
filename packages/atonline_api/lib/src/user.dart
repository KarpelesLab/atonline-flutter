import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'links.dart';

/// User information model class
/// 
/// Contains basic user profile information from AtOnline
class UserInfo {
  /// User's email address
  String? email;
  /// User's display name
  String? displayName;
  /// URL to user's profile picture
  String? profilePicture;
  /// Raw user object data
  dynamic object;
}

/// User authentication and profile management
/// 
/// Provides methods for checking login status, fetching user details,
/// and updating profiles
class User extends ChangeNotifier {
  /// Reference to the AtOnline API instance
  final AtOnline api;
  /// Standard image variation for profile pictures
  static const String imageVariation = "strip&format=jpeg&scale_crop=160x160";

  /// Constructor takes an API instance
  User(this.api);

  /// Whether user details are still loading
  bool loading = true;
  /// User information when logged in
  UserInfo? info;

  /// Check if the user is currently logged in
  /// 
  /// Note: This cannot be async. Instead, subscribe to events using
  /// api.user.addListener() and call it again on updates.
  /// 
  /// @return true if the user is logged in, false otherwise
  bool isLoggedIn() {
    if (loading) {
      return false;
    }
    return info != null;
  }

  /// Fetch or refresh user login details
  /// 
  /// Makes an API request to get the current user information
  /// 
  /// @return true if successfully logged in, false otherwise
  Future<bool> fetchLogin() async {
    try {
      final res = await api.authReq("User:get", body: {"image_variation": imageVariation});
      
      // Parse user information from response
      final userInfo = UserInfo();
      userInfo.object = res.data;
      
      // Safely extract email
      if (res.data is Map && res.data.containsKey('Email')) {
        userInfo.email = res.data['Email']?.toString();
      }
      
      // Safely extract display name
      if (res.data is Map && 
          res.data.containsKey('Profile') &&
          res.data['Profile'] is Map && 
          res.data['Profile'].containsKey('Display_Name')) {
        userInfo.displayName = res.data['Profile']['Display_Name']?.toString();
      }
      
      // Safely extract profile picture
      try {
        // Nested path for profile picture, using null-aware operators
        userInfo.profilePicture = res.data?['Profile']?['Drive_Item']?['Media_Image']
            ?['Variation']?['strip&format=jpeg&scale_crop=160x160']?.toString();
      } catch (e) {
        // Keep profile picture as null if not found or error occurs
        if (kDebugMode) {
          print('Error getting profile picture: $e');
        }
      }
      
      // Update state and notify listeners
      info = userInfo;
      loading = false;
      notifyListeners();
      return true;
    } on AtOnlineLoginException catch (e) {
      // Not logged in (no login info)
      if (kDebugMode) {
        print('Login error: ${e.msg}');
      }
      _resetUserState();
      return false;
    } on AtOnlinePlatformException catch (e) {
      // Error from platform (access denied, etc)
      if (kDebugMode) {
        print('Platform error during login: ${e.data}');
      }
      _resetUserState();
      return false;
    } catch (e) {
      // Other error
      if (kDebugMode) {
        print('Unexpected error during login: $e');
      }
      _resetUserState();
      return false;
    }
  }
  
  /// Helper method to reset user state on errors or logout
  void _resetUserState() {
    info = null;
    loading = false;
    notifyListeners();
  }
  
  /// Checks if a token exists without making a network request
  /// Useful for UI to determine if login should be shown
  /// 
  /// @return true if a refresh token exists in storage
  Future<bool> hasStoredCredentials() async {
    try {
      final refreshToken = await api.storage.read(key: "refresh_token");
      return refreshToken != null && refreshToken.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking stored credentials: $e');
      }
      return false;
    }
  }

  /// Log the user out
  /// 
  /// Clears tokens and user information
  Future<void> logout() async {
    try {
      await api.voidToken();
      _resetUserState();
    } catch (e) {
      if (kDebugMode) {
        print('Error during logout: $e');
      }
      // Still reset user state even if token voiding fails
      _resetUserState();
    }
  }

  /// Update user profile picture
  /// 
  /// @param img The image file to upload
  /// @param fetch Whether to refresh user info after updating
  /// @return true if the update succeeded, false otherwise
  Future<bool> setProfilePicture(File img, {bool fetch = true}) async {
    try {
      if (!img.existsSync()) {
        throw AtOnlinePlatformException({'error': 'Image file does not exist'});
      }
      
      await api.authReqUpload(
        "User/@/Profile:addImage", 
        img,
        body: {"purpose": "main"}
      );
      
      // Refresh user info if requested
      if (fetch) {
        return await fetchLogin();
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating profile picture: $e');
      }
      return false;
    }
  }

  /// Update user profile information
  /// 
  /// @param profile Map of profile fields to update
  /// @param fetch Whether to refresh user info after updating
  /// @return true if the update succeeded, false otherwise
  Future<bool> updateProfile(Map<String, String> profile, {bool fetch = true}) async {
    try {
      await api.authReq(
        "User/@/Profile", 
        method: "PATCH", 
        body: profile
      );
      
      // Refresh user info if requested
      if (fetch) {
        return await fetchLogin();
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating profile: $e');
      }
      return false;
    }
  }
  
  /// Get the user profile data
  /// 
  /// This is a convenience method to access the profile data directly
  /// 
  /// @return Map of profile data or null if not logged in
  Map<String, dynamic>? getProfileData() {
    if (info?.object == null) {
      return null;
    }
    
    try {
      return info!.object?['Profile'] as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}

/// Widget for handling user login
/// 
/// Displays a loading screen and initiates the OAuth2 login flow
class LoginPage extends StatefulWidget {
  /// The AtOnline API instance
  final AtOnline api;
  /// OAuth2 redirect URI for completing authentication
  final String redirectUri;

  /// Constructor
  LoginPage(this.api, this.redirectUri);

  @override
  LoginPageState createState() {
    return new LoginPageState();
  }
}

/// State for the login page
class LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    // Register for login callback
    Links().addListener("login", loginListener);
    // Start login process
    _initiateLogin();
  }

  @override
  void dispose() {
    // Clean up listener when page is disposed
    Links().removeListener("login", loginListener);
    super.dispose();
  }

  /// Handles the OAuth2 callback with authorization code
  /// 
  /// @param l The URI from the callback
  void loginListener(Uri l) async {
    var qp = l.queryParameters;
    // Check if code is present
    if (qp["code"] == null) {
      await closeInAppWebView();
      Navigator.of(context).pop();
      return;
    }

    // Exchange authorization code for tokens
    var auth = await widget.api.req("OAuth2:token",
        method: "POST",
        skipDecode: true,
        body: <String, String?>{
          "client_id": widget.api.appId,
          "grant_type": "authorization_code",
          "redirect_uri": widget.redirectUri,
          "code": qp["code"],
        });
    
    // Store tokens and fetch user information
    await widget.api.storeToken(auth);
    await widget.api.user.fetchLogin();

    // Handle navigation based on login result
    if (widget.api.user.isLoggedIn()) {
      print("closing view");
      await closeInAppWebView();
      print("close complete");
      Navigator.of(context).pop();
      Navigator.of(context).pushReplacementNamed("/home");
    } else {
      await closeInAppWebView();
      Navigator.of(context).pop();
    }
  }

  /// Initiates the OAuth2 login flow
  /// 
  /// Launches the authentication URL in a browser or app
  void _initiateLogin() async {
    // Start with default auth endpoint
    Uri url = Uri.parse(widget.api.authEndpoint);
    
    // Try using app protocol if available
    if (await canLaunchUrl(Uri.parse("atonline://oauth2/auth"))) {
      print("launch via local protocol");
      url = Uri.parse("atonline://oauth2/auth");
    }

    // Set up OAuth2 parameters
    Map<String, String> params = {
      "client_id": widget.api.appId,
      "response_type": "code",
      "redirect_uri": widget.redirectUri,
      "scope": "profile",
    };

    // Build the full authentication URL
    url = Uri(
        scheme: url.scheme,
        host: url.host,
        path: url.path,
        queryParameters: {}
          ..addAll(url.queryParameters)
          ..addAll(params));

    // Launch the authentication URL
    print("launch url");
    await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Login"),
      ),
      body: Center(
        // Show loading indicator while waiting for authentication
        child: CircularProgressIndicator(value: null),
      ),
    );
  }
}
