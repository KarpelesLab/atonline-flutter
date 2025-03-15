import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Callback function for handling URI links
typedef void LinkListener(Uri link);

/// Manages deep links and URL scheme handling
/// 
/// Provides path-based routing for deep links and app URL schemes
class Links {
  /// Singleton instance
  static Links _instance = new Links._internal();
  /// Map of path prefixes to their registered listeners
  Map<String, ObserverList<LinkListener>> _listeners = {};

  /// Factory constructor that returns the singleton instance
  factory Links() {
    return _instance;
  }

  /// Private constructor for singleton pattern
  Links._internal();

  /// Initialize the links system
  /// 
  /// This method must be called after adding listeners for your app
  /// Sets up the app_links package to listen for incoming links
  static Future<void> init() async {
    await _instance._init();
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
  void _fireNotification(Uri link) {
    var prefix = link.path;

    // Try to find matching listeners by shortening the path
    while (!_listeners.containsKey(prefix)) {
      if (prefix.length < 8) return;

      // Remove trailing slashes
      while (prefix[prefix.length - 1] == '/')
        prefix = prefix.substring(0, prefix.length - 1);

      // Find last path segment
      var pos = prefix.lastIndexOf('/');
      if (pos == -1) return;

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
  }

  /// Process an incoming link by notifying appropriate listeners
  /// 
  /// @param link The URI link to process
  void processLink(Uri link) {
    _fireNotification(link);
  }

  /// Internal initialization method
  /// 
  /// Sets up app_links to listen for incoming URI links
  Future<Null> _init() async {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen(processLink);
  }
}
