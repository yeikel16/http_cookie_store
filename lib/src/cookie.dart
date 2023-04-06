import 'dart:io' show HttpDate;

import 'set_cookie_header_parser.dart';

enum SameSite { lax, strict, none }

class Cookie implements MapEntry<String, String> {
  /// The name of the cookie.
  @override
  final String key;
  @override
  final String value;

  /// The domain for which this cookie is valid.
  ///
  /// If not set, the cookie is considered valid for all domains by a [CookieStore].
  ///
  /// If set, the cookie is only valid for the given domain and its subdomains.
  final Uri? domain;

  /// The path for which this cookie is valid.
  ///
  /// Defaults to the root path '/'.
  ///
  /// If set, the cookie is only valid for the given path and its subpaths.
  final Uri path;

  /// Whether this cookie is only valid for the given [domain], or also for its subdomains.
  final bool hostOnly;

  final DateTime? expires;

  /// In a browser environment, this indicates whether the cookie is visible to client-side scripts.
  ///
  /// When set to true, the cookie is not accessible via JavaScript's `Document.cookie` API.
  ///
  /// Has no effect in this library.
  final bool httpOnly;

  /// Whether this cookie should only be sent over secure connections (http**s**).
  final bool secure;

  final SameSite sameSite;

  final DateTime creationTime;

  DateTime lastAccessTime;

  /// Whether to remove the cookie from any [CookieStore].
  ///
  /// This is set to true, when a Set-Cookie header specifies the empty string for this cookie.
  final bool isRemoveCookie;

  /// Whether this cookie should only exist for this session.
  ///
  /// This is equivalent to `expires == null`.
  ///
  /// See also: [isPersistentCookie]
  bool get isSessionCookie => expires == null;

  /// Whether this cookie should be persisted.
  ///
  /// This is equivalent to `expires != null`.
  ///
  /// See also: [isSessionCookie]
  bool get isPersistentCookie => !isSessionCookie;

  Duration? maxAge([DateTime? now]) {
    return expires?.difference((now ?? DateTime.now()).toUtc());
  }

  Cookie(
    this.key,
    this.value, {
    this.domain,
    bool? hostOnly,
    DateTime? expires,
    this.httpOnly = false,
    Uri? path,
    this.secure = false,
    this.sameSite = SameSite.lax,
    this.isRemoveCookie = false,
    DateTime? creationTime,
    DateTime? lastAccessTime,
  })  : path = path ?? Uri(path: '/'),
        hostOnly = hostOnly ?? domain == null,
        expires = expires?.toUtc(),
        creationTime = creationTime?.toUtc() ?? DateTime.now().toUtc(),
        lastAccessTime = lastAccessTime?.toUtc() ??
            creationTime?.toUtc() ??
            DateTime.now().toUtc();

  factory Cookie.fromSetCookieHeader(String header,
      {DateTime? time, Uri? domain}) {
    return SetCookieHeaderParser.parse(header)
        .toCookie(domain: domain, time: time);
  }

  String get toSetCookieHeader => [
        '$key=$value',
        if (expires != null) 'Expires=${HttpDate.format(expires!)}',
        if (!hostOnly && domain != null) 'Domain=${domain!.host}',
        if (path.path != '/') 'Path=${path.path}',
        if (secure) 'Secure',
        if (httpOnly) 'HttpOnly',
        if (sameSite != SameSite.lax)
          'SameSite=${sameSite.name[0].toUpperCase()}${sameSite.name.substring(1)}',
      ].join('; ');

  String get toCookieHeader => '$key=$value';

  bool isExpired([DateTime? now]) {
    return expires != null && expires!.isBefore(now ?? DateTime.now().toUtc());
  }

  @override
  String toString() => toSetCookieHeader;

  Cookie copyWith({
    String? key,
    String? value,
    Uri? domain,
    bool? hostOnly,
    DateTime? expires,
    bool? httpOnly,
    Uri? path,
    bool? secure,
    SameSite? sameSite,
    bool? isRemoveCookie,
    DateTime? creationTime,
    DateTime? lastAccessTime,
  }) {
    return Cookie(
      key ?? this.key,
      value ?? this.value,
      domain: domain ?? this.domain,
      hostOnly: hostOnly ?? this.hostOnly,
      expires: expires ?? this.expires,
      httpOnly: httpOnly ?? this.httpOnly,
      path: path ?? this.path,
      secure: secure ?? this.secure,
      sameSite: sameSite ?? this.sameSite,
      isRemoveCookie: isRemoveCookie ?? this.isRemoveCookie,
      creationTime: creationTime ?? this.creationTime,
      lastAccessTime: lastAccessTime ?? this.lastAccessTime,
    );
  }

  bool sameIdentityAs(Cookie other) {
    return key == other.key && domain == other.domain && path == other.path;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cookie &&
          key == other.key &&
          value == other.value &&
          domain == other.domain &&
          hostOnly == other.hostOnly &&
          expires == other.expires &&
          httpOnly == other.httpOnly &&
          path == other.path &&
          secure == other.secure &&
          sameSite == other.sameSite &&
          isRemoveCookie == other.isRemoveCookie &&
          creationTime == other.creationTime &&
          lastAccessTime == other.lastAccessTime;

  @override
  int get hashCode =>
      key.hashCode ^
      value.hashCode ^
      domain.hashCode ^
      hostOnly.hashCode ^
      expires.hashCode ^
      httpOnly.hashCode ^
      path.hashCode ^
      secure.hashCode ^
      sameSite.hashCode ^
      isRemoveCookie.hashCode ^
      creationTime.hashCode ^
      lastAccessTime.hashCode;
}
