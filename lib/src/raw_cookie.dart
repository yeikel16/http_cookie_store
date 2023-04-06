import 'package:collection/collection.dart';

import 'cookie.dart';
import 'cookie_attributes.dart';
import 'set_cookie_header_parser.dart';
import 'uri_matches.dart';

class RawCookie extends DelegatingMap<String, dynamic>
    implements MapEntry<String, String> {
  @override
  final String key;

  @override
  final String value;

  final Map<String, dynamic> attributes;

  RawCookie(this.key, this.value, [this.attributes = const {}])
      : super(attributes);

  Cookie toCookie({Uri? domain, DateTime? time}) {
    final maxAge = attributes[CookieAttributes.maxAge] as Duration?;

    final expires = maxAge == null
        ? attributes[CookieAttributes.expires] as DateTime?
        : maxAge <= Duration.zero
            ? DateTime.utc(-271821, 04, 20)
            : (time ?? DateTime.now()).toUtc().add(maxAge);

    final domainAttrib = attributes[CookieAttributes.domain] as Uri?;

    if (domainAttrib != null && domain != null) {
      if (!domainAttrib.isSubdomainOf(domain)) {
        throw IgnoreCookieException(
            "Domain attribute is not a subdomain of the request domain");
      }
    }

    return Cookie(
      key,
      value,
      isRemoveCookie: value.isEmpty,
      domain: domainAttrib ?? domain,
      hostOnly: domainAttrib == null,
      expires: expires,
      httpOnly: attributes[CookieAttributes.httpOnly] as bool? ?? false,
      path: attributes[CookieAttributes.path] as Uri? ?? Uri(path: '/'),
      secure: attributes[CookieAttributes.secure] as bool? ?? false,
      sameSite:
          attributes[CookieAttributes.sameSite] as SameSite? ?? SameSite.lax,
      creationTime: time,
    );
  }

  @override
  String toString() {
    return '$key=$value; ${attributes.entries.map((e) => e.value != null ? '${e.key}=${e.value}' : e.key).join('; ')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RawCookie &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          value == other.value &&
          const MapEquality().equals(attributes, other.attributes);

  @override
  int get hashCode => key.hashCode ^ value.hashCode ^ attributes.hashCode;
}
