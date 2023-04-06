import 'dart:io';

import 'package:http/http.dart' as http;

import 'cookie_store.dart';

class CookieClient extends http.BaseClient {
  final http.Client _inner;

  final CookieStore store;

  CookieClient({http.Client? inner, CookieStore? store})
      : _inner = inner ?? http.Client(),
        store = store ?? CookieStore();

  @override
  void close() {
    _inner.close();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers[HttpHeaders.cookieHeader] = store.toCookieHeaderFor(
      uri: request.url,
      secure: request.url.scheme == 'https' ? null : false,
    );

    final response = await _inner.send(request);

    store.executeHeader(
      response.headers[HttpHeaders.setCookieHeader],
      domain: request.url,
    );

    return response;
  }
}
