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
      var res = await api
          .authReq("User:get", body: {"image_variation": imageVariation});
      
      // Parse user information from response
      var u = new UserInfo();
      u.object = res.data;
      u.email = res["Email"];
      
      try {
        u.displayName = res["Profile"]["Display_Name"];
      } catch (e) {}
      
      try {
        u.profilePicture = res["Profile"]["Drive_Item"]["Media_Image"]
            ["Variation"]["strip&format=jpeg&scale_crop=160x160"];
      } catch (e) {}
      
      // Update state and notify listeners
      info = u;
      loading = false;
      notifyListeners();
      return true;
    } on AtOnlineLoginException {
      // Not logged in (no login info)
      info = null;
      loading = false;
      notifyListeners();
      return false;
    } on AtOnlinePlatformException {
      // Error from platform (access denied, etc)
      info = null;
      loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      // Other error
      info = null;
      loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Log the user out
  /// 
  /// Clears tokens and user information
  Future<Null> logout() async {
    await api.voidToken();
    info = null;
  }

  /// Update user profile picture
  /// 
  /// @param img The image file to upload
  /// @param fetch Whether to refresh user info after updating
  Future<Null> setProfilePicture(File img, {bool fetch = true}) async {
    await api.authReqUpload("User/@/Profile:addImage", img,
        body: {"purpose": "main"});
    
    // Refresh user info if requested
    if (fetch) {
      await fetchLogin();
    }
  }

  /// Update user profile information
  /// 
  /// @param profile Map of profile fields to update
  /// @param fetch Whether to refresh user info after updating
  Future<Null> updateProfile(Map<String, String> profile,
      {bool fetch = true}) async {
    await api.authReq("User/@/Profile", method: "PATCH", body: profile);
    
    // Refresh user info if requested
    if (fetch) {
      await fetchLogin();
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
