import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:uni_links/uni_links.dart';

typedef void LinkListener(Uri link);

class Links {
  static Links _instance = new Links._internal();
  Map<String, ObserverList<LinkListener>> _listeners = {};
  Map<String, bool> acceptableProto = {"https": true};

  factory Links() {
    return _instance;
  }

  Links._internal();

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
    if (!_listeners.containsKey(prefix)) {
      return;
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
    print("got link = $link");
    Uri l = Uri.parse(link);
    if (acceptableProto[l.scheme] == null) return;
    // extract first element of path
    String e = l.path;
    while (e[0] == '/') {
      e = e.substring(1);
    }
    int pos = e.indexOf("/");
    if (pos > 0) {
      e = e.substring(0, pos);
    }
    _fireNotification(e, l);
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
