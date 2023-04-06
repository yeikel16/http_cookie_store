import 'package:collection/collection.dart';

import 'cookie.dart';
import 'set_cookie_header_parser.dart';
import 'uri_matches.dart';

class CookieStore extends DelegatingMap<CookieKey, Cookie> {
  CookieStore([Map<CookieKey, Cookie>? cookies]) : super(cookies ?? {});

  Iterable<Cookie> get cookies => values;

  /// https://www.rfc-editor.org/rfc/rfc6265#section-5.3
  void executeHeader(String? header, {Uri? domain, DateTime? time}) {
    if (header == null) return;

    executeHeaders(
      header.split(RegExp(r',(?=[^;,=\s]+\s*=)')),
      domain: domain,
      time: time,
    );
  }

  /// https://www.rfc-editor.org/rfc/rfc6265#section-5.3
  void executeHeaders(Iterable<String> headers, {Uri? domain, DateTime? time}) {
    time ??= DateTime.now().toUtc();

    for (String itemStr in headers) {
      try {
        final cookie = Cookie.fromSetCookieHeader(
          itemStr,
          domain: domain,
          time: time,
        );
        if (cookie.isRemoveCookie) {
          remove(cookie);
        } else {
          add(cookie);
        }
      } on IgnoreCookieException catch (_) {
        // TODO: Provide a way to log this
      }
    }
  }

  void endSession({Uri? domain}) {
    if (domain != null) {
      removeWhere((k, c) => c.isSessionCookie && c.domain == domain);
    } else {
      removeWhere((k, c) => c.isSessionCookie);
    }
  }

  void add(Cookie value) {
    this[value.key] = value;
  }

  @override
  void operator []=(CookieKey key, Cookie value) {
    assert(key == value.key);

    final old = this[key];
    if (old != null) {
      value = value.copyWith(
        creationTime: old.creationTime,
      );
    }
    super[key] = value;
  }

  @override
  Cookie? operator [](Object? key) => super[key is Cookie ? key.key : key];

  @override
  bool containsKey(Object? key) =>
      super.containsKey(key is Cookie ? key.key : key);

  @override
  void addAll(Map<CookieKey, Cookie> other) {
    for (final cookie in other.entries) {
      this[cookie.key] = cookie.value;
    }
  }

  @override
  Cookie? remove(Object? key) {
    return super.remove(key is Cookie ? key.key : key);
  }

  @override
  Cookie putIfAbsent(Object key, [Cookie Function()? ifAbsent]) {
    if (key is Cookie) {
      key = key.key;
      ifAbsent ??= () => key as Cookie;
    }
    assert(key is CookieKey);
    assert(ifAbsent != null);
    return super.putIfAbsent(key as CookieKey, ifAbsent!);
  }

  DateTime? _debugLastPumpTime;

  void pump({DateTime? time, int? maxCountPerDomain}) {
    // TODO: Implement maxCount
    //       The goal is to remove cookies from the fullest domains first

    time ??= DateTime.now();
    time = time.toUtc();

    assert(_debugLastPumpTime == null || _debugLastPumpTime!.isBefore(time));
    assert(() {
      _debugLastPumpTime = time;
      return true;
    }());

    removeWhere((k, c) => c.isExpired(time));

    // TODO: Increase performance
    if (maxCountPerDomain != null) {
      final domains = groupBy<Cookie, Uri?>(values, (c) => c.domain);
      for (final domain in domains.values) {
        if (domain.length > maxCountPerDomain) {
          domain.sort((a, b) => a.creationTime.compareTo(b.creationTime));
          for (final cookie in domain.take(domain.length - maxCountPerDomain)) {
            remove(cookie);
          }
        }
      }
    }
  }

  /// https://www.rfc-editor.org/rfc/rfc6265#section-5.4
  Iterable<Cookie> cookiesFor({
    Uri? domain,
    Uri? path,
    Uri? uri,
    bool? secure,
    bool? httpOnly,
    DateTime? time,
    bool refreshAccessTime = true,
  }) sync* {
    assert((uri == null) || (domain == null && path == null));

    if (uri != null) {
      domain = uri;
      path = uri;
    }

    time = (time ?? DateTime.now()).toUtc();

    for (final cookie in values) {
      if (cookie.isExpired(time)) continue;
      if (domain != null) {
        if (cookie.hostOnly) {
          if (domain.host != cookie.domain?.host) continue;
        } else {
          if (!domain.isSubdomainOf(cookie.domain!)) continue;
        }
      }
      if (path != null && !path.isSubPathOf(cookie.path)) continue;
      if (secure != null && secure != cookie.secure) continue;
      if (httpOnly != null && httpOnly != cookie.httpOnly) continue;

      if (refreshAccessTime) {
        cookie.lastAccessTime = time;
      }

      // TODO: order by path length and creation time (path length first)

      yield cookie;
    }
  }

  /// https://www.rfc-editor.org/rfc/rfc6265#section-5.4
  String toCookieHeaderFor({
    Uri? domain,
    Uri? path,
    Uri? uri,
    bool? secure,
    bool? httpOnly,
    DateTime? time,
    bool refreshAccessTime = true,
  }) {
    assert((uri == null) || (domain == null && path == null));
    return cookiesFor(
      domain: domain,
      path: path,
      secure: secure,
      httpOnly: httpOnly,
      time: time,
      refreshAccessTime: refreshAccessTime,
    ).map((e) => e.toCookieHeader).join('; ');
  }

  /// https://www.rfc-editor.org/rfc/rfc6265#section-5.4
  String get toCookieHeader {
    return values.map((e) => e.toCookieHeader).join('; ');
  }
}
