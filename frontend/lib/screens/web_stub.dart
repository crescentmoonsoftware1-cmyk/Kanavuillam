// This file contains stubs for web-only classes to allow compilation on mobile.
// These classes and methods do nothing on non-web platforms.
// ignore_for_file: camel_case_types

class HTMLIFrameElement {
  dynamic style;
  String? src;
  dynamic contentWindow;
}

class HTMLAnchorElement {
  String? href;
  String? download;
  void click() {}
  void remove() {}
}

class HTMLImageElement {
  dynamic style;
  String? src;
}

class window {
  static void addEventListener(String type, Function listener) {}
}

class MessageEvent {
  dynamic data;
}

class Event {}

extension ToJS on Object? {
  dynamic get toJS => this;
}

// For ui_web stub
class platformViewRegistry {
  static void registerViewFactory(String id, Function factory) {}
}

// For download_screen
class Blob {
  Blob(List<dynamic> parts, [dynamic options]);
}

class BlobPropertyBag {
  BlobPropertyBag({String? type});
}

class URL {
  static String createObjectURL(dynamic blob) => '';
  static void revokeObjectURL(String url) {}
}

class document {
  static Body? get body => null;
}

class Body {
  void append(dynamic child) {}
}
