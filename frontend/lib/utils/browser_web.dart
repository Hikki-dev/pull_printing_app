import 'dart:js_interop';

extension type _Location._(JSObject _) implements JSObject {
  external void assign(String url);
  external String get pathname;
  external String get search;
}

extension type _History._(JSObject _) implements JSObject {
  external void replaceState(JSAny? state, String title, String url);
}

@JS('location')
external _Location get _location;

@JS('history')
external _History get _history;

/// Leaves the app for [url], for example the Microsoft or Google sign-in page.
void goTo(String url) => _location.assign(url);

/// Removes `#token=...` from the address bar so the sign-in token is not left in the history.
void removeAddressFragment() =>
    _history.replaceState(null, '', _location.pathname + _location.search);
