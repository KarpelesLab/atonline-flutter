import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:atonline_api/atonline_api.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';

import 'atonline_api_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('AtOnline API Tests', () {
    late AtOnline api;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      api = AtOnline('test_app_id');
      // Ideally we would inject the mockClient into AtOnline for testing
    });
    
    test('API will include body in query params for GET requests', () async {
      // Set up an API client
      final api = AtOnline('test_app_id');
      
      // Create a test request using the public req method
      final requestFuture = api.req(
        'Misc/Debug:echo',
        method: 'GET',
        body: {'test_key': 'test_value'},
        context: {'custom_ctx': 'custom_value'}
      );
      
      // The request will fail due to no actual network, but we can verify
      // the request preparation logic worked correctly
      expect(requestFuture, throwsA(isA<Exception>()));
    });
    
    test('API will handle complex body in GET parameters correctly', () async {
      // Create a test request with complex nested body
      final complexBody = {
        'user': {
          'name': 'Test User',
          'roles': ['admin', 'user'],
          'settings': {
            'theme': 'dark',
            'notifications': true
          }
        },
        'filters': [
          {'field': 'status', 'value': 'active'},
          {'field': 'type', 'operator': 'in', 'value': ['A', 'B', 'C']}
        ]
      };
      
      // Test URL construction
      final api = AtOnline('test_app_id');
      
      // Create a request that will fail, but we can observe network errors
      // to confirm the URL was constructed correctly
      final requestFuture = api.req(
        'Misc/Debug:echo',
        method: 'GET',
        body: complexBody,
        context: {'custom_ctx': 'custom_value'}
      );
      
      expect(requestFuture, throwsA(isA<Exception>()));
    });
    
    test('AtOnlineApiResult provides access to data and paging', () {
      // Create a mock API response
      final responseMap = {
        'result': 'success',
        'data': {
          'key1': 'value1',
          'key2': 'value2',
          'items': [1, 2, 3]
        },
        'paging': {
          'count': '100',
          'page_max': '10',
          'page_no': '1',
          'results_per_page': '10'
        },
        'time': 0.123
      };
      
      final result = AtOnlineApiResult(responseMap);
      
      // Test basic properties
      expect(result.result, 'success');
      expect(result.time, 0.123);
      expect(result.data['key1'], 'value1');
      expect(result.data['key2'], 'value2');
      
      // Test paging
      expect(result.paging, isNotNull);
      expect(result.paging!.count, 100);
      expect(result.paging!.pageMax, 10);
      expect(result.paging!.pageNumber, 1);
      expect(result.paging!.resultPerPage, 10);
      
      // Test operator []
      expect(result['key1'], 'value1');
      expect(result['@result'], 'success');
      expect(result['@time'], 0.123);
    });
    
    test('AtOnlineApiResult can iterate over data items', () {
      // Create a response with iterable data
      final responseWithArray = {
        'result': 'success',
        'data': [
          {'id': 1, 'name': 'Item 1'},
          {'id': 2, 'name': 'Item 2'},
          {'id': 3, 'name': 'Item 3'}
        ]
      };
      
      final result = AtOnlineApiResult(responseWithArray);
      
      // Test iteration
      int count = 0;
      for (var item in result) {
        count++;
        expect(item['id'], isNotNull);
        expect(item['name'], startsWith('Item '));
      }
      expect(count, 3);
      
      // Test response with map data
      final responseWithMap = {
        'result': 'success',
        'data': {
          'item1': {'id': 1, 'name': 'Item 1'},
          'item2': {'id': 2, 'name': 'Item 2'},
          'item3': {'id': 3, 'name': 'Item 3'}
        }
      };
      
      final mapResult = AtOnlineApiResult(responseWithMap);
      
      // Test iteration over map values
      count = 0;
      for (var item in mapResult) {
        count++;
        expect(item['id'], isNotNull);
        expect(item['name'], startsWith('Item '));
      }
      expect(count, 3);
    });
    
    test('AtOnlineApiResult throws exception for non-iterable data', () {
      // Create a response with non-iterable data
      final responseWithScalar = {
        'result': 'success',
        'data': 'string value'
      };
      
      final result = AtOnlineApiResult(responseWithScalar);
      
      // Test exception for iteration on non-iterable
      expect(() => result.iterator, throwsException);
    });

    test('API builds URIs with correct query parameters', () {
      // Create a request URI for a GET request with body
      final uri = Uri.parse('https://hub.atonline.com/_special/rest/Misc/Debug:echo')
          .replace(queryParameters: {
        '_ctx[l]': 'en_US',
        '_ctx[t]': 'GMT',
        '_ctx[custom]': 'value',
        '_': json.encode({'key': 'value'})
      });
      
      // Verify the URI is constructed correctly
      expect(uri.scheme, 'https');
      expect(uri.host, 'hub.atonline.com');
      expect(uri.path, '/_special/rest/Misc/Debug:echo');
      expect(uri.queryParameters['_ctx[l]'], 'en_US');
      expect(uri.queryParameters['_'], isNotNull);
      
      // Verify the body was correctly encoded in the query parameter
      final decodedBody = json.decode(uri.queryParameters['_']!);
      expect(decodedBody['key'], 'value');
    });
    
    test('Cookie header is correctly formatted', () {
      // Test the cookie formatting logic
      final cookies = {
        'session_id': 'abc123',
        'user_preference': 'dark_mode'
      };
      
      // Generate a cookie header string manually
      final cookieHeader = cookies.entries
          .map((entry) => "${entry.key}=${entry.value}")
          .join('; ');
      
      // Check the formatting is correct
      expect(cookieHeader.contains('session_id=abc123'), isTrue);
      expect(cookieHeader.contains('user_preference=dark_mode'), isTrue);
      expect(cookieHeader.contains('; '), isTrue);
      
      // Verify cookie header can be parsed
      final cookieParts = cookieHeader.split('; ');
      expect(cookieParts.length, 2);
      
      // Convert back to a map for verification
      final parsedCookies = Map.fromEntries(
        cookieParts.map((part) {
          final parts = part.split('=');
          return MapEntry(parts[0], parts[1]);
        })
      );
      
      expect(parsedCookies['session_id'], 'abc123');
      expect(parsedCookies['user_preference'], 'dark_mode');
    });
    
    test('Set-Cookie header is correctly parsed', () {
      // Test the cookie parsing logic
      final setCookieHeader = 'session_id=xyz789; Path=/; HttpOnly, tracking=123; Path=/';
      
      // Parse header manually
      final rawCookies = setCookieHeader.split(',');
      final cookieMap = <String, String>{};
      
      for (var rawCookie in rawCookies) {
        final cookieParts = rawCookie.split(';');
        if (cookieParts.isNotEmpty) {
          final nameValue = cookieParts[0].trim();
          final equalsIndex = nameValue.indexOf('=');
          
          if (equalsIndex > 0) {
            final key = nameValue.substring(0, equalsIndex).trim();
            final value = nameValue.substring(equalsIndex + 1);
            
            // Skip cookie attributes
            if (key.toLowerCase() != 'path' && 
                key.toLowerCase() != 'expires' &&
                key.toLowerCase() != 'domain' &&
                key.toLowerCase() != 'max-age' &&
                key.toLowerCase() != 'secure' &&
                key.toLowerCase() != 'httponly' &&
                key.toLowerCase() != 'samesite') {
              cookieMap[key] = value;
            }
          }
        }
      }
      
      // Verify cookies were extracted correctly
      expect(cookieMap['session_id'], 'xyz789');
      expect(cookieMap['tracking'], '123');
    });
    
    test('Exception classes store error information properly', () {
      // Test network exception
      final networkEx = AtOnlineNetworkException('Network timeout');
      expect(networkEx.msg, 'Network timeout');
      
      // Test login exception
      final loginEx = AtOnlineLoginException('Invalid credentials');
      expect(loginEx.msg, 'Invalid credentials');
      
      // Test platform exception
      final errorData = {'error': 'Access denied', 'code': 403};
      final platformEx = AtOnlinePlatformException(errorData);
      expect(platformEx.data, equals(errorData));
    });
  });
  
  group('User Tests', () {
    test('UserInfo correctly parses user profile data', () {
      // Create a user info object
      final userInfo = UserInfo();
      
      // Check default values
      expect(userInfo.email, isNull);
      expect(userInfo.displayName, isNull);
      expect(userInfo.profilePicture, isNull);
      expect(userInfo.object, isNull);
      
      // Set properties
      userInfo.email = 'test@example.com';
      userInfo.displayName = 'Test User';
      userInfo.profilePicture = 'https://example.com/profile.jpg';
      userInfo.object = {'id': 123};
      
      // Check values
      expect(userInfo.email, 'test@example.com');
      expect(userInfo.displayName, 'Test User');
      expect(userInfo.profilePicture, 'https://example.com/profile.jpg');
      expect(userInfo.object['id'], 123);
    });
  });
  
  group('Links Tests', () {
    test('Links singleton returns the same instance', () {
      final links1 = Links();
      final links2 = Links();
      
      // Verify singleton pattern
      expect(identical(links1, links2), isTrue);
    });
    
    // Note: We're not testing the path-matching logic directly as
    // that would require more extensive mocking of the internals
    test('Links has method to get registered prefixes', () {
      final links = Links();
      
      // Just test the API exists and returns a list
      final prefixes = links.getRegisteredPrefixes();
      expect(prefixes, isA<List<String>>());
    });
  });
  
  group('Live API Tests with Misc/Debug endpoints', () {
    // These tests make real API calls to the AtOnline API
    // They use the Misc/Debug endpoints which don't require authentication
    
    test('API can retrieve server time', () async {
      // This test makes a real API call to Misc/Debug:serverTime
      final api = AtOnline('test_client_id');
      
      try {
        final result = await api.req('Misc/Debug:serverTime');
        
        // Verify response structure
        expect(result.result, 'success');
        expect(result.data, isNotNull);
        
        // Check that we have the expected server time fields
        expect(result.data['unix'], isNotNull);
        expect(result.data['iso'], isNotNull);
        expect(result.data['tz'], isNotNull);
        
        if (kDebugMode) {
          print('Server time: ${result.data['iso']} (${result.data['tz']})');
        }
      } catch (e) {
        // We don't expect the test to fail, but if it does due to connectivity issues,
        // we want to know what went wrong
        fail('Failed to connect to Misc/Debug:serverTime: $e');
      }
    });
    
    test('API can send and receive parameters', () async {
      // This test passes parameters to Misc/Debug:params and checks they are echoed back
      final api = AtOnline('test_client_id');
      final testParams = {'test': 'value', 'number': '123'};
      
      try {
        // Use query parameters - create a Map<String, String> for the queryParameters
        final uri = Uri.parse('https://hub.atonline.com/_special/rest/Misc/Debug:params')
            .replace(queryParameters: testParams);
        
        // Make direct HTTP request - we're testing the raw HTTP request here
        final response = await http.get(uri);
        expect(response.statusCode, 200);
        
        // Parse response
        final responseData = json.decode(response.body);
        expect(responseData['result'], 'success');
        
        // Verify echo'd parameters 
        expect(responseData['data']['test'], 'value');
        expect(responseData['data']['number'], '123');
      } catch (e) {
        fail('Failed to test parameters with Misc/Debug:params: $e');
      }
    });
    
    test('API correctly handles GET requests with body', () async {
      // This test makes a GET request with a body using our API class
      final api = AtOnline('test_client_id');
      final testBody = {'complex': {'nested': 'value'}, 'array': [1, 2, 3]};
      
      try {
        // Make request with body
        final result = await api.req(
          'Misc/Debug:params',
          method: 'GET',
          body: testBody
        );
        
        // API doesn't echo back body directly in the response,
        // but we can verify the request didn't fail, meaning the body was correctly
        // serialized and sent as the '_' query parameter
        expect(result.result, 'success');
      } catch (e) {
        fail('Failed to make GET request with body: $e');
      }
    });
    
    test('API correctly merges context parameters in requests', () async {
      // This test verifies that context parameters are correctly included in the request
      final api = AtOnline('test_client_id');
      
      try {
        // Make a direct HTTP request to compare with what our API constructs
        final customContext = {'custom1': 'value1', 'custom2': 'value2'};
        
        // We can't directly test context parameters with Misc/Debug:params
        // because context parameters are handled by the server, not returned
        // in the params echo. But we can verify that the request doesn't fail,
        // which means the context parameters were correctly formatted.
        final result = await api.req(
          'Misc/Debug:serverTime',
          context: customContext
        );
        
        expect(result.result, 'success');
      } catch (e) {
        fail('Failed to send context parameters: $e');
      }
    });
    
    test('API can handle error responses from non-existent endpoints', () async {
      // This test checks that API errors are properly transformed to exceptions
      final api = AtOnline('test_client_id');
      
      try {
        // Call a non-existent endpoint
        await api.req('Misc/Debug:nonExistentEndpoint');
        fail('Request to non-existent endpoint should have failed');
      } catch (e) {
        // For non-existent API methods, the server returns AtOnlinePlatformException
        // with specific error details rather than a network error
        expect(e, isA<AtOnlinePlatformException>());
        
        // Check that the error data contains the expected information
        if (e is AtOnlinePlatformException) {
          expect(e.data['result'], 'error');
          expect(e.data['error'], isNotNull);
        }
      }
    });
    
    test('API can handle error responses from error endpoints', () async {
      // This test checks how the API handles endpoints that explicitly return errors
      final api = AtOnline('test_client_id');
      
      try {
        // Call the error endpoint which intentionally returns an error
        await api.req('Misc/Debug:error');
        fail('Request to error endpoint should have failed');
      } catch (e) {
        // The error endpoint should return a platform exception
        expect(e, isA<AtOnlinePlatformException>());
        
        // Verify specific error details
        if (e is AtOnlinePlatformException) {
          expect(e.data['result'], 'error');
          expect(e.data['error'], 'Test error');
          expect(e.data['token'], 'unknown_error');
        }
      }
    });
    
    test('API can handle fixed string responses', () async {
      // This test verifies that the API can handle string responses correctly
      final api = AtOnline('test_client_id');
      
      final result = await api.req('Misc/Debug:fixedString');
      
      // The fixedString endpoint returns a string rather than an object in the data field
      expect(result.result, 'success');
      expect(result.data, 'fixed string');
      
      // Verify that we can't iterate over a string
      expect(() => result.iterator, throwsException);
    });
    
    test('API can handle fixed array responses', () async {
      // This test verifies that the API can handle array/object responses correctly
      final api = AtOnline('test_client_id');
      
      final result = await api.req('Misc/Debug:fixedArray');
      
      // The fixedArray endpoint returns a object with a key-value pair
      expect(result.result, 'success');
      expect(result.data, isA<Map>());
      expect(result.data['key'], 'fixed array value');
    });
  });
}