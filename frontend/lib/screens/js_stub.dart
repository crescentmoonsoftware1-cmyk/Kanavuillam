// Stub for dart:js_interop on non-web platforms.
// This allows compiling the .toJS calls on mobile without errors.

extension JSAnyStub on Object? {
  dynamic dartify() => this;
}

class JSString {
  String get toDart => this.toString();
}
