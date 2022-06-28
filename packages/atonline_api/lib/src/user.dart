import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'links.dart';

// basic user information
class UserInfo {
  String? email;
  String? displayName;
  String? profilePicture;
  dynamic object;
}

class User extends ChangeNotifier {
  final AtOnline api;
  static const String imageVariation = "strip&format=jpeg&scale_crop=160x160";

  User(this.api);

  bool loading = true;
  UserInfo? info;

  // this cannot be async, instead subscribe to events (api.user.addListener()) and call it again on update
  bool isLoggedIn() {
    if (loading) {
      return false;
    }
    return info != null;
  }

  Future<bool> fetchLogin() async {
    try {
      var res = await api
          .authReq("User:get", body: {"image_variation": imageVariation});
      //print("Received user = $res");
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
      info = u;
      loading = false;
      notifyListeners();
      return true;
    } on AtOnlineLoginException {
      // failed (no login info)
      info = null;
      loading = false;
      notifyListeners();
      return false;
    } on AtOnlinePlatformException {
      // failed (access denied, etc)
      info = null;
      loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      // not logged in
      info = null;
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Null> logout() async {
    await api.voidToken();
    info = null;
  }

  Future<Null> setProfilePicture(File img, {bool fetch = true}) async {
    await api.authReqUpload("User/@/Profile:addImage", img,
        body: {"purpose": "main"});
    if (fetch) {
      await fetchLogin();
    }
  }

  Future<Null> updateProfile(Map<String, String> profile,
      {bool fetch = true}) async {
    await api.authReq("User/@/Profile", method: "PATCH", body: profile);
    if (fetch) {
      await fetchLogin();
    }
  }
}

class LoginPage extends StatefulWidget {
  final AtOnline api;
  final String redirectUri;

  LoginPage(this.api, this.redirectUri);

  @override
  LoginPageState createState() {
    return new LoginPageState();
  }
}

class LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    Links().addListener("login", loginListener);
    _initiateLogin();
  }

  @override
  void dispose() {
    Links().removeListener("login", loginListener);
    super.dispose();
  }

  void loginListener(Uri l) async {
    var qp = l.queryParameters;
    if (qp["code"] == null) {
      await closeWebView();
      Navigator.of(context).pop();
      return;
    }

    // we got a code, fetch the matching auth info
    var auth = await widget.api.req("OAuth2:token",
        method: "POST",
        skipDecode: true,
        body: <String, String?>{
          "client_id": widget.api.appId,
          "grant_type": "authorization_code",
          "redirect_uri": widget.redirectUri,
          "code": qp["code"],
        });
    await widget.api.storeToken(auth);
    await widget.api.user.fetchLogin();

    if (widget.api.user.isLoggedIn()) {
      print("closing view");
      await closeWebView();
      print("close complete");
      Navigator.of(context).pop();
      Navigator.of(context).pushReplacementNamed("/home");
    } else {
      await closeWebView();
      Navigator.of(context).pop();
    }
  }

  void _initiateLogin() async {
    // perform login initialization
    Uri url = Uri.parse(widget.api.authEndpoint);
    if (await canLaunch("atonline://oauth2/auth")) {
      print("launch via local protocol");
      url = Uri.parse("atonline://oauth2/auth");
    }

    Map<String, String> params = {
      "client_id": widget.api.appId,
      "response_type": "code",
      "redirect_uri": widget.redirectUri,
      "scope": "profile",
    };

    // rebuild url with new parameters
    url = Uri(
        scheme: url.scheme,
        host: url.host,
        path: url.path,
        queryParameters: {}
          ..addAll(url.queryParameters)
          ..addAll(params));

    // launch it
    print("launch url");
    await launch(url.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Login"),
      ),
      body: Center(
        child: CircularProgressIndicator(value: null),
      ),
    );
  }
}
