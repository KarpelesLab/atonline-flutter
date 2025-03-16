import 'package:flutter_test/flutter_test.dart';
import 'package:atonline_login/src/web_auth_service.dart';

class MockWebAuthService implements WebAuthService {
  final Function(String, String)? onAuthenticate;
  final String returnValue;
  
  MockWebAuthService({
    this.onAuthenticate,
    this.returnValue = 'test://callback?session=test_session',
  });
  
  @override
  Future<String> authenticate({required String url, required String callbackUrlScheme}) async {
    if (onAuthenticate != null) {
      onAuthenticate!(url, callbackUrlScheme);
    }
    return returnValue;
  }
}

void main() {
  group('WebAuthService', () {
    test('DefaultWebAuthService - creates an instance', () {
      final service = DefaultWebAuthService();
      expect(service, isA<WebAuthService>());
    });
    
    test('MockWebAuthService - calls onAuthenticate with correct parameters', () async {
      String? capturedUrl;
      String? capturedScheme;
      
      final mockService = MockWebAuthService(
        onAuthenticate: (url, scheme) {
          capturedUrl = url;
          capturedScheme = scheme;
        },
      );
      
      await mockService.authenticate(
        url: 'https://example.com/auth',
        callbackUrlScheme: 'test',
      );
      
      expect(capturedUrl, 'https://example.com/auth');
      expect(capturedScheme, 'test');
    });
    
    test('MockWebAuthService - returns the configured return value', () async {
      final mockService = MockWebAuthService(
        returnValue: 'test://specific-callback?session=specific_session',
      );
      
      final result = await mockService.authenticate(
        url: 'https://example.com/auth',
        callbackUrlScheme: 'test',
      );
      
      expect(result, 'test://specific-callback?session=specific_session');
    });
  });
}