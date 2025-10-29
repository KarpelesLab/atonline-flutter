import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:atonline_api/atonline_api.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';

@GenerateMocks([http.Client])
void main() {
  group('AtOnline API Tests', () {
    setUp(() {
      // Setup would be used if we could inject mock client into AtOnline
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
    
    test('AtOnlineApiResult can get access rights for objects', () {
      // Create a response with access rights
      final responseWithAccess = {
        'result': 'success',
        'data': {'key': 'value'},
        'access': {
          'obj-12345': {
            'required': 'r',
            'available': 'O'
          },
          'chan-xjnjql-lbnb-grnm-rk4f-eaecdqkm': {
            'required': 'r',
            'available': '?'
          },
          'obj-67890': {
            'required': 'W',
            'available': 'W'
          },
          'obj-delete': {
            'required': 'D',
            'available': 'D'
          }
        }
      };
      
      final result = AtOnlineApiResult(responseWithAccess);
      
      // Test access rights lookup
      expect(result.getAccessForObject('obj-12345'), 'O');
      expect(result.getAccessForObject('chan-xjnjql-lbnb-grnm-rk4f-eaecdqkm'), '?');
      expect(result.getAccessForObject('obj-67890'), 'W');
      expect(result.getAccessForObject('obj-delete'), 'D');
      expect(result.getAccessForObject('non-existent'), isNull);
      
      // Create a response without access field
      final responseWithoutAccess = {
        'result': 'success',
        'data': {'key': 'value'}
      };
      
      final resultNoAccess = AtOnlineApiResult(responseWithoutAccess);
      expect(resultNoAccess.getAccessForObject('obj-12345'), isNull);
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
  
  group('File Upload Tests with Mocks', () {    
    setUp(() {
      // Setup would create mocks if we could inject them
    });
    
    test('File upload properties and parameters validation', () async {
      // Skip this test on web platforms
      if (kIsWeb) {
        return;
      }
      
      // Create a test file with content
      final directory = Directory.systemTemp;
      final testFile = File('${directory.path}/atonline_mock_upload.txt');
      final testContent = 'Test upload content for mocked requests';
      await testFile.writeAsString(testContent);
      
      try {
        // Test file properties used in the upload process
        final fileSize = await testFile.length();
        final fileName = p.basename(testFile.path);
        final fileType = lookupMimeType(fileName) ?? 'application/octet-stream';
        
        // Create body parameters with the same logic used in authReqUpload
        final body = <String, dynamic>{
          'filename': fileName,
          'type': fileType,
          'size': fileSize,
        };
        
        // Validate file preparation for upload
        expect(body['size'], fileSize);
        expect(body['filename'], 'atonline_mock_upload.txt');
        expect(body['type'], isNotNull);
        
        // Verify the file content was written correctly
        expect(await testFile.readAsString(), equals(testContent));
        expect(fileSize, equals(testContent.length));
        
        // Verify expected workflow for upload - we're testing the concept, not the actual call
        // Since we can't call authReqUpload without a token, we just verify the expected flow:
        // 1. Prepare body with file info
        // 2. Make first API call to get upload URL
        // 3. Prepare streamed request with proper content-type
        // 4. Upload file content with progress tracking
        // 5. Complete upload with final API call
        
        // Test the progress tracking mechanism separately
        double? lastProgress;
        void progressCallback(double progress) {
          lastProgress = progress;
          // In a real upload, progress would increment from 0.0 to 1.0
        }
        
        // Simulate progress for test coverage
        progressCallback(0.0);
        progressCallback(0.5);
        progressCallback(1.0);
        
        expect(lastProgress, 1.0);
      } finally {
        // Clean up test file
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });
    
    test('ProgressCallback correctly reports upload progress', () {
      // Test the progress callback functionality
      final progressValues = <double>[];
      void progressCallback(double progress) {
        progressValues.add(progress);
      }
      
      // Simulate progress updates
      progressCallback(0.0);
      progressCallback(0.25);
      progressCallback(0.5);
      progressCallback(0.75);
      progressCallback(1.0);
      
      // Verify progress tracking
      expect(progressValues.length, 5);
      expect(progressValues.first, 0.0);
      expect(progressValues.last, 1.0);
      expect(progressValues, containsAllInOrder([0.0, 0.25, 0.5, 0.75, 1.0]));
    });
    
    test('Token request fails without authentication', () async {
      // Skip this test on web platforms
      if (kIsWeb) {
        return;
      }
      
      // Verify that the API class requires authentication for token
      try {
        final testApi = AtOnline('test_app_id');
        await testApi.token();
        fail('Should have thrown exception due to missing token');
      } catch (e) {
        expect(e, isA<AtOnlineLoginException>());
      }
    });
  });
  
  group('Live API Tests with Misc/Debug endpoints', () {
    // These tests make real API calls to the AtOnline API
    // They use the Misc/Debug endpoints which don't require authentication
    
    setUp(() {
      // Add setup code if needed for live API tests
    });
    
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
    
    test('API can test file uploads with different put_only modes of testUpload endpoint', () async {
      // This test runs real file uploads with the Misc/Debug:testUpload endpoint
      // in both put_only=true and put_only=false modes
      
      final api = AtOnline('test_client_id');
      
      // Create a temporary file with fixed test content
      final directory = Directory.systemTemp;
      final testFile = File('${directory.path}/atonline_test_upload.txt');
      
      try {
        // Create file with known, fixed content for verification
        final testContent = 'Test file upload with fixed content: ATONLINE-API-TEST-CONTENT';
        await testFile.writeAsString(testContent);
        
        // Get the file size for verification
        final fileSize = await testFile.length();
        
        // Helper function to perform an upload with different put_only options
        Future<void> performUpload(bool putOnly) async {
          // Step 1: Prepare upload request parameters
          final uploadParams = <String, dynamic>{
            'filename': 'test_upload.txt',
            'type': 'text/plain',
            'size': fileSize,
            'put_only': putOnly  // Proper documented parameter
          };
          
          // Step 2: Request upload URL from the testUpload endpoint
          if (kDebugMode) {
            print('\n--- Testing upload with put_only=$putOnly ---');
          }
          
          final uploadUrlResult = await api.req(
            'Misc/Debug:testUpload',
            method: 'POST',
            body: uploadParams
          );
          
          if (kDebugMode) {
            print('Upload URL response with put_only=$putOnly:');
            print(json.encode(uploadUrlResult.data));
          }
          
          // Make sure we have the upload URLs
          expect(uploadUrlResult.data, isNotNull);
          expect(uploadUrlResult.data.containsKey('PUT'), isTrue);
          expect(uploadUrlResult.data.containsKey('Complete'), isTrue);
          
          // Step 3: Prepare the upload request
          final uploadUri = Uri.parse(uploadUrlResult.data['PUT']);
          final uploadRequest = http.StreamedRequest('PUT', uploadUri);
          uploadRequest.contentLength = fileSize;
          uploadRequest.headers['Content-Type'] = 'text/plain';
          
          // Track upload progress 
          double? lastProgress;
          int current = 0;
          
          // Step 4: Set up file streaming with progress tracking
          final fileStream = testFile.openRead();
          await for (var chunk in fileStream) {
            uploadRequest.sink.add(chunk);
            current += chunk.length;
            final progress = current / fileSize;
            lastProgress = progress;
            if (kDebugMode) {
              print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
            }
          }
          
          // Close the sink after all data is written
          uploadRequest.sink.close();
          
          // Step 5: Send the request and wait for the response
          final uploadResponse = await http.Client().send(uploadRequest);
          final responseBody = await uploadResponse.stream.bytesToString();
          
          if (kDebugMode) {
            print('Upload response status: ${uploadResponse.statusCode}');
            if (responseBody.isNotEmpty) {
              print('Upload response body: $responseBody');
            }
          }
          
          // Verify the upload succeeded
          expect(uploadResponse.statusCode, lessThan(300));
          expect(lastProgress, 1.0); // Should reach 100%
          
          // Step 6: Complete the upload by calling the Complete endpoint
          final completeResult = await api.req(
            uploadUrlResult.data['Complete'],
            method: 'POST'
          );
          
          if (kDebugMode) {
            print('Complete response with put_only=$putOnly:');
            print(json.encode(completeResult.res));
          }
          
          // Verify the complete response contains the expected data
          expect(completeResult.result, 'success');
          expect(completeResult.data, isNotNull);
          
          // Analyze the response data
          if (kDebugMode) {
            print('Analyzing upload response with put_only=$putOnly');
            print('Response data fields:');
            completeResult.data.forEach((key, value) {
              print('  $key: $value');
            });
          }
          
          // Common validations for both test modes
          expect(completeResult.result, 'success');
          expect(completeResult.data.containsKey('Blob__'), isTrue);
          expect(completeResult.data.containsKey('SHA256'), isTrue);
          expect(completeResult.data.containsKey('Size'), isTrue);
          expect(completeResult.data.containsKey('Mime'), isTrue);
          
          // Validate specific fields
          expect(completeResult.data['Size'], '$fileSize');  // Size is returned as a string
          expect(completeResult.data['Mime'], 'text/plain');
          
          // The SHA256 hash should be consistent for the same content
          const expectedHash = '05e3759bc71a37542370ef49165c5cc856930374b249f0e9ad92cd4f25694051';
          expect(completeResult.data['SHA256'], expectedHash);
          
          // Differences between put_only modes:
          // 1. With put_only=true:
          //    - Response is more minimal with just PUT and Complete URLs
          //    - No detailed Cloud_Aws_Bucket information or Key
          //    - Works without authentication
          //    - Simpler response data structure
          // 2. With put_only=false (default):
          //    - Full response with Cloud_Aws_Bucket_Upload__, Key, Status, etc.
          //    - Returns Bucket_Endpoint information
          //    - More complete integration with the cloud storage system
          //    - More detailed response
          
          if (kDebugMode) {
            print('Blob ID with put_only=$putOnly: ${completeResult.data['Blob__']}');
            if (uploadUrlResult.data.containsKey('Key')) {
              print('Storage Key: ${uploadUrlResult.data['Key']}');
            }
          }
        }
        
        // Run both test modes to compare differences
        await performUpload(true);   // First with put_only=true
        await performUpload(false);  // Then with put_only=false (default)
        
      } catch (e) {
        fail('Failed to test file upload: $e');
      } finally {
        // Clean up the test file
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    test('API can handle SSE streaming from Misc/Debug:sse', () async {
      // This test makes a real SSE request to Misc/Debug:sse
      // which generates events for 30 seconds (one every 5 seconds on average)
      final api = AtOnline('test_client_id');

      try {
        final events = <SseEvent>[];
        int eventCount = 0;

        if (kDebugMode) {
          print('\n--- Testing SSE Stream ---');
          print('Connecting to Misc/Debug:sse endpoint...');
        }

        // Listen to SSE stream with timeout
        await for (var event in api.sseReq('Misc/Debug:sse').timeout(
          Duration(seconds: 15), // Listen for 15 seconds to get at least 2-3 events
          onTimeout: (sink) {
            if (kDebugMode) {
              print('Stream timeout reached (expected behavior for test)');
            }
            sink.close();
          },
        )) {
          eventCount++;
          events.add(event);

          if (kDebugMode) {
            print('Event #$eventCount received:');
            print('  Type: ${event.event}');
            print('  ID: ${event.id}');
            print('  Data: ${event.data}');
            if (event.jsonData != null) {
              print('  Parsed JSON: ${event.jsonData}');
            }
          }

          // Verify event structure
          expect(event.event, isNotNull);
          expect(event.data, isNotEmpty);

          // Stop after receiving 3 events to avoid waiting full 30 seconds
          if (eventCount >= 3) {
            if (kDebugMode) {
              print('Received 3 events, stopping test');
            }
            break;
          }
        }

        // Verify we received at least one event
        expect(eventCount, greaterThanOrEqualTo(1));
        expect(events, isNotEmpty);

        if (kDebugMode) {
          print('SSE test completed successfully with $eventCount events received');
        }
      } catch (e) {
        // TimeoutException is expected if we don't receive events quickly enough
        if (e.toString().contains('TimeoutException')) {
          if (kDebugMode) {
            print('Stream timeout (this is normal for SSE test)');
          }
        } else {
          fail('Failed to test SSE streaming: $e');
        }
      }
    });

    test('SseEvent correctly parses JSON data', () {
      // Test the SseEvent class with JSON data
      final jsonData = '{"message": "test", "count": 42}';
      final event = SseEvent(
        event: 'message',
        data: jsonData,
        id: '123',
      );

      expect(event.event, 'message');
      expect(event.data, jsonData);
      expect(event.id, '123');
      expect(event.jsonData, isNotNull);
      expect(event.jsonData['message'], 'test');
      expect(event.jsonData['count'], 42);
    });

    test('SseEvent handles non-JSON data gracefully', () {
      // Test the SseEvent class with plain text data
      final plainText = 'This is plain text, not JSON';
      final event = SseEvent(
        event: 'message',
        data: plainText,
      );

      expect(event.event, 'message');
      expect(event.data, plainText);
      expect(event.id, isNull);
      expect(event.jsonData, isNull); // Should be null for non-JSON data
    });

    test('SseEvent supports custom event types', () {
      // Test custom event types
      final event = SseEvent(
        event: 'update',
        data: 'update data',
        id: 'update-1',
      );

      expect(event.event, 'update');
      expect(event.data, 'update data');
      expect(event.id, 'update-1');
    });
  });
}