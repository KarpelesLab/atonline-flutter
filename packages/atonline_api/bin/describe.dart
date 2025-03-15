#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';
import 'package:atonline_api/atonline_api.dart';

/// Command-line tool to explore AtOnline APIs
void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage information')
    ..addFlag('auth', abbr: 'a', negatable: false, help: 'Make an authenticated request')
    ..addFlag('code', abbr: 'c', negatable: false, help: 'Generate sample code')
    ..addOption('app-id', abbr: 'i', help: 'AtOnline application ID');

  try {
    final results = parser.parse(args);

    if (results['help'] || results.rest.isEmpty) {
      _printUsage(parser);
      exit(0);
    }

    final endpoint = results.rest[0];
    final authenticated = results['auth'];
    final generateCode = results['code'];
    final appId = results['app-id'] ?? Platform.environment['ATONLINE_APP_ID'];

    if (appId == null) {
      print('Error: No app ID provided. Use --app-id option or set ATONLINE_APP_ID environment variable.');
      exit(1);
    }

    // Initialize the API client and explorer
    final api = AtOnline(appId);
    final explorer = ApiExplorer(api);

    try {
      if (authenticated) {
        // For a real CLI tool, we'd need to handle authentication here
        print('Note: For authenticated requests, you need to be logged in.');
        print('This tool currently does not handle the authentication process.');
        print('');
      }

      // Get API information
      final info = await explorer.getEndpointInfo(endpoint, authenticated: authenticated);
      
      // Print API information
      print('API Endpoint: ${info.path}');
      print('Available Methods: ${info.methods.join(', ')}');
      
      if (info.documentation != null && info.documentation!.isNotEmpty) {
        print('\nDocumentation:');
        print(info.documentation);
      }
      
      if (info.parameters != null && info.parameters!.isNotEmpty) {
        print('\nParameters:');
        _printMap(info.parameters!, '  ');
      }
      
      if (info.response != null && info.response!.isNotEmpty) {
        print('\nResponse:');
        _printMap(info.response!, '  ');
      }

      // Generate and print code if requested
      if (generateCode) {
        final code = await explorer.generateEndpointCode(endpoint, authenticated: authenticated);
        print('\nGenerated Code:');
        print('---------------');
        print(code);
      }
    } catch (e) {
      print('Error: $e');
      exit(2);
    }
  } catch (e) {
    print('Error parsing arguments: $e');
    _printUsage(parser);
    exit(1);
  }
}

/// Print usage information
void _printUsage(ArgParser parser) {
  print('AtOnline API Explorer');
  print('');
  print('Usage: dart bin/describe.dart [options] <endpoint>');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  dart bin/describe.dart --app-id=your_app_id User');
  print('  dart bin/describe.dart --auth --code User:get');
  print('');
  print('You can also set the ATONLINE_APP_ID environment variable instead of using --app-id.');
}

/// Recursively print a map with proper indentation
void _printMap(Map<String, dynamic> map, String indent) {
  map.forEach((key, value) {
    if (value is Map) {
      print('$indent$key:');
      _printMap(value.cast<String, dynamic>(), '$indent  ');
    } else if (value is List) {
      print('$indent$key: [${value.join(', ')}]');
    } else {
      print('$indent$key: $value');
    }
  });
}