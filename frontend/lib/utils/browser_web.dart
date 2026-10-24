import 'dart:js_interop';

extension type _Location._(JSObject _) implements JSObject {
  external void assign(String url);
}

@JS('location')
external _Location get _location;

@JS('pullPrintHash')
external String? get _hash;

@JS('pullPrintHash')
external set _hash(String? value);

/// Leaves the app for [url], for example the Microsoft or Google sign-in page.
void goTo(String url) => _location.assign(url);

/// The `token=...` or `error=...` the page was opened with after signing in, once.
/// web/index.html moves it out of the address bar before the app starts.
String takeSignInFragment() {
  final value = _hash ?? '';
  _hash = null;
  return value;
}
