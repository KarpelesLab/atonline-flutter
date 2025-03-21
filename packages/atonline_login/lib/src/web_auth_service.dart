import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// Service for handling web authentication
abstract class WebAuthService {
  /// Authenticate using a web view
  Future<String> authenticate(
      {required String url, required String callbackUrlScheme});
}

/// Default implementation using flutter_web_auth_2
class DefaultWebAuthService implements WebAuthService {
  @override
  Future<String> authenticate(
      {required String url, required String callbackUrlScheme}) {
    return FlutterWebAuth2.authenticate(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
    );
  }
}
