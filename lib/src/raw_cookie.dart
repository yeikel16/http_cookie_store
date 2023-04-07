// Copyright (c) 2023, Paul Suckow.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import 'package:collection/collection.dart';

import 'cookie.dart';
import 'cookie_attributes.dart';
import 'set_cookie_header_parser.dart';
import 'uri_matches.dart';

class RawCookie extends DelegatingMap<String, Object>
    implements MapEntry<String, String> {
  final String name;

  @override
  String get key => name;

  @override
  final String value;

  final Map<String, Object> attributes;

  RawCookie(this.name, this.value, [this.attributes = const {}])
      : super(attributes);

  factory RawCookie.fromSetCookieHeader(String value) {
    return SetCookieHeaderParser.parse(value);
  }

  Cookie toCookie({Uri? domain, DateTime? time}) {
    final maxAge = attributes[CookieAttributes.maxAge] as Duration?;

    final expires = maxAge == null
        ? attributes[CookieAttributes.expires] as DateTime?
        : maxAge <= Duration.zero
            ? DateTime.utc(-271821, 04, 20)
            : (time ?? DateTime.now()).toUtc().add(maxAge);

    final domainAttrib = attributes[CookieAttributes.domain] as Uri?;

    if (domainAttrib != null && domain != null) {
      if (!domain.isSubdomainOf(domainAttrib)) {
        throw IgnoreCookieException(
            "Domain attribute is not a subdomain of the request domain");
      }
    }

    return Cookie(
      name,
      value,
      isRemoveCookie: value.isEmpty,
      domain: domainAttrib ?? (domain != null ? Uri(host: domain.host) : null),
      hostOnly: domainAttrib == null,
      expires: expires,
      httpOnly: attributes.containsKey(CookieAttributes.httpOnly),
      path: attributes[CookieAttributes.path] as Uri? ?? Uri(path: '/'),
      secure: attributes.containsKey(CookieAttributes.secure),
      sameSite:
          attributes[CookieAttributes.sameSite] as SameSite? ?? SameSite.lax,
      creationTime: time,
    );
  }

  @override
  String toString() {
    return '$name=$value; ${attributes.entries.map((e) => e.value != valueExists ? '${e.key}=${e.value}' : e.key).join('; ')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RawCookie &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          value == other.value &&
          const MapEquality().equals(attributes, other.attributes);

  @override
  int get hashCode => name.hashCode ^ value.hashCode ^ attributes.hashCode;
}

const valueExists = ValueExists();

class ValueExists {
  const ValueExists();
}
