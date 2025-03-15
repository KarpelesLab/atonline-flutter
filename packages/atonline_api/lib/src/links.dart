import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Callback function for handling URI links
typedef LinkListener = void Function(Uri link);

/// Manages deep links and URL scheme handling
/// 
/// Provides path-based routing for deep links and app URL schemes
class Links {
  /// Singleton instance
  static final Links _instance = Links._internal();
  
  /// Map of path prefixes to their registered listeners
  final Map<String, ObserverList<LinkListener>> _listeners = {};
  
  /// AppLinks instance for handling deep links
  late final AppLinks _appLinks;
  
  /// Whether the links system has been initialized
  bool _isInitialized = false;

  /// Factory constructor that returns the singleton instance
  factory Links() {
    return _instance;
  }

  /// Private constructor for singleton pattern
  Links._internal() {
    _appLinks = AppLinks();
  }

  /// Initialize the links system
  /// 
  /// This method must be called after adding listeners for your app
  /// Sets up the app_links package to listen for incoming links
  /// 
  /// @return Future that completes when initialization is done
  static Future<bool> init() async {
    return await _instance._init();
  }

  /// Register a listener for a specific URL path prefix
  /// 
  /// @param prefix The URL path prefix to listen for
  /// @param listener The callback function to invoke when a matching link is received
  void addListener(String prefix, LinkListener listener) {
    if (!_listeners.containsKey(prefix)) {
      _listeners[prefix] = ObserverList<LinkListener>();
    }
    _listeners[prefix]!.add(listener);
    
    if (kDebugMode) {
      print("Added listener for prefix: $prefix");
    }
  }

  /// Remove a previously registered listener
  /// 
  /// @param prefix The URL path prefix the listener was registered for
  /// @param listener The callback function to remove
  void removeListener(String prefix, LinkListener listener) {
    if (!_listeners.containsKey(prefix)) {
      return;
    }
    _listeners[prefix]!.remove(listener);
    
    // Clean up empty listener lists
    if (_listeners[prefix]!.isEmpty) {
      _listeners.remove(prefix);
    }
  }

  /// Find the appropriate listeners and notify them about a link
  /// 
  /// Uses a path-based routing system that matches the most specific prefix
  /// by shortening the path until a matching prefix is found
  /// 
  /// @param link The URI link that was received
  /// @return true if any listeners were notified, false otherwise
  bool _fireNotification(Uri link) {
    var prefix = link.path;
    bool notified = false;

    // Try to find matching listeners by shortening the path
    while (!_listeners.containsKey(prefix)) {
      if (prefix.length < 2) return false;

      // Remove trailing slashes
      while (prefix.isNotEmpty && prefix[prefix.length - 1] == '/') {
        prefix = prefix.substring(0, prefix.length - 1);
      }

      // Find last path segment
      var pos = prefix.lastIndexOf('/');
      if (pos == -1) return false;

      // Shorten path to parent directory
      prefix = prefix.substring(0, pos);
    }

    // Create a local copy of listeners to avoid concurrent modification issues
    final List<LinkListener> localListeners =
        List<LinkListener>.from(_listeners[prefix]!);

    // Notify all listeners for this prefix
    for (LinkListener listener in localListeners) {
      try {
        listener(link);
        notified = true;
      } catch (exception, stack) {
        // Report errors in listeners
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          context: DiagnosticsNode.message(
              'while notifying listeners for link action'),
        ));
      }
    }
    
    return notified;
  }

  /// Process an incoming link by notifying appropriate listeners
  /// 
  /// @param link The URI link to process
  /// @return true if any listeners were notified, false otherwise
  bool processLink(Uri link) {
    if (kDebugMode) {
      print("Processing link: $link");
    }
    return _fireNotification(link);
  }
  
  /// Manually handle a URI
  /// 
  /// This is useful for testing or handling URIs from other sources
  /// 
  /// @param uri The URI to handle
  /// @return true if any listeners were called, false otherwise
  bool handleUri(Uri uri) {
    return processLink(uri);
  }

  /// Initialize the links system
  /// 
  /// @return true if initialization was successful, false otherwise
  Future<bool> _init() async {
    if (_isInitialized) {
      return true;
    }
    
    try {
      // Get initial link that launched the app (if any)
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        if (kDebugMode) {
          print("Processing initial link: $initialLink");
        }
        processLink(initialLink);
      }
      
      // Listen for links while the app is running
      _appLinks.uriLinkStream.listen((uri) {
        processLink(uri);
      });
      
      _isInitialized = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Error initializing Links: $e");
      }
      return false;
    }
  }
  
  /// Get all registered prefixes
  /// 
  /// @return List of registered prefix strings
  List<String> getRegisteredPrefixes() {
    return _listeners.keys.toList();
  }
}
