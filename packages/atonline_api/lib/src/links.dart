import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

typedef void LinkListener(Uri link);

class Links {
  static Links _instance = new Links._internal();
  Map<String, ObserverList<LinkListener>> _listeners = {};

  factory Links() {
    return _instance;
  }

  Links._internal();

  // this method needs to be called after adding listeners for your app
  static Future<void> init() async {
    await _instance._init();
  }

  void addListener(String prefix, LinkListener listener) {
    if (!_listeners.containsKey(prefix)) {
      _listeners[prefix] = ObserverList<LinkListener>();
    }
    _listeners[prefix]!.add(listener);
  }

  void removeListener(String prefix, LinkListener listener) {
    if (!_listeners.containsKey(prefix)) {
      return;
    }
    _listeners[prefix]!.remove(listener);
    if (_listeners[prefix]!.isEmpty) {
      _listeners.remove(prefix);
    }
  }

  void _fireNotification(Uri link) {
    var prefix = link.path;

    while (!_listeners.containsKey(prefix)) {
      if (prefix.length < 8) return;

      // get rid of any "/" suffix
      while (prefix[prefix.length - 1] == '/')
        prefix = prefix.substring(0, prefix.length - 1);

      // find last /
      var pos = prefix.lastIndexOf('/');
      if (pos == -1) return;

      // update prefix
      prefix = prefix.substring(0, pos);
    }

    final List<LinkListener> localListeners =
        List<LinkListener>.from(_listeners[prefix]!);

    for (LinkListener listener in localListeners) {
      try {
        listener(link);
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          context: DiagnosticsNode.message(
              'while notifying listeners for link action'),
        ));
      }
    }
  }

  void processLink(Uri link) {
    _fireNotification(link);
  }

  Future<Null> _init() async {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen(processLink);
  }
}
