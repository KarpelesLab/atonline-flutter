import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:uni_links/uni_links.dart';

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
    _listeners[prefix].add(listener);
  }

  void removeListener(String prefix, LinkListener listener) {
    if (!_listeners.containsKey(prefix)) {
      return;
    }
    _listeners[prefix].remove(listener);
    if (_listeners[prefix].isEmpty) {
      _listeners.remove(prefix);
    }
  }

  void _fireNotification(String prefix, Uri link) {
    int pos = prefix.indexOf('?');
    if (pos != -1) {
      // need to remove query string from url
      prefix = prefix.substring(0, pos);
    }

    while (!_listeners.containsKey(prefix)) {
      if (prefix.length < 8) return;

      // get rid of any "/" suffix
      while (prefix[prefix.length - 1] == '/')
        prefix = prefix.substring(0, prefix.length - 1);

      // find last /
      pos = prefix.lastIndexOf('/');
      if (pos == -1) return;

      // update prefix
      prefix = prefix.substring(0, pos);
    }

    final List<LinkListener> localListeners =
        List<LinkListener>.from(_listeners[prefix]);

    for (LinkListener listener in localListeners) {
      try {
        listener(link);
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          context: 'while notifying listeners for link action',
        ));
      }
    }
  }

  void processLink(String link) {
    Uri l = Uri.parse(link);
    _fireNotification(link, l);
  }

  Future<Null> _init() async {
    try {
      String initialLink = await getInitialLink();
      if (initialLink != null) {
        processLink(initialLink);
      }
    } on PlatformException {}

    getLinksStream().listen(processLink);
  }
}
