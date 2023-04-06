import 'package:collection/collection.dart' hide DelegatingList;
import 'package:quiver/collection.dart';

import 'cookie.dart';
import 'set_cookie_header_parser.dart';
import 'uri_matches.dart';

class CookieStore extends DelegatingList<Cookie> {
  final List<Cookie> cookies = [];

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
          removeWhere((c) => c.sameIdentityAs(cookie));
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
      removeWhere((c) => c.isSessionCookie && c.domain == domain);
    } else {
      removeWhere((c) => c.isSessionCookie);
    }
  }

  @override
  void add(Cookie value) {
    final old = where((c) => c.sameIdentityAs(value));
    if (old.isNotEmpty) {
      value = value.copyWith(
        creationTime: old.last.creationTime,
      );
      removeWhere((c) => c.sameIdentityAs(value));
    }
    cookies.add(value);
  }

  @override
  void addAll(Iterable<Cookie> iterable) {
    for (final cookie in iterable) {
      add(cookie);
    }
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

    removeWhere((c) => c.isExpired(time));

    // TODO: Increase performance
    if (maxCountPerDomain != null) {
      final domains = groupBy<Cookie, Uri?>(cookies, (c) => c.domain);
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
    bool? secure,
    bool? httpOnly,
    DateTime? time,
    bool refreshAccessTime = true,
  }) sync* {
    time = (time ?? DateTime.now()).toUtc();

    for (final cookie in this) {
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
    bool? secure,
    bool? httpOnly,
    DateTime? time,
    bool refreshAccessTime = true,
  }) {
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
    return map((e) => e.toCookieHeader).join('; ');
  }

  @override
  List<Cookie> get delegate => cookies;
}
