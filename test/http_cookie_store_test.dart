import 'dart:math';

import 'package:test/test.dart';

import 'package:http_cookie_store/http_cookie_store.dart';

final minDateTime = DateTime.utc(-271821, 04, 20);
final maxDateTime = DateTime.utc(275760, 09, 13);

void main() {
  group('SetCookieHeaderParser', () {
    // https://www.rfc-editor.org/rfc/rfc6265#section-5.2

    test('Ignore if no =', () {
      try {
        SetCookieHeaderParser.parse('foo');
      } on IgnoreCookieException catch (e) {
        expect(e.message, "Cookie is missing '='");
      }
    });

    test('Empty name should be ignored', () {
      try {
        SetCookieHeaderParser.parse('=foo');
      } on IgnoreCookieException catch (e) {
        expect(e.message, "Cookie name is empty");
      }
    });

    test('Name/value trimmed', () {
      final cookie = SetCookieHeaderParser.parse('  foo  =  bar  ');

      expect(cookie.key, "foo");
      expect(cookie.value, "bar");
    });

    test('Attribute name/value trimmed', () {
      final cookie = SetCookieHeaderParser.parse(
        'foo=bar;   domain  =  example.com   ',
      );

      expect(cookie.key, "foo");
      expect(cookie.value, "bar");
      expect(cookie[CookieAttributes.domain], Uri(host: 'example.com'));
    });

    test('Unrecognized attributes are ignored', () {
      final cookie = SetCookieHeaderParser.parse(
        'foo=bar;   domain  =  example.com   ;   baz  =  qux   ',
      );

      expect(cookie.key, "foo");
      expect(cookie.value, "bar");
      expect(cookie[CookieAttributes.domain], Uri(host: 'example.com'));
      expect(cookie.containsKey('baz'), isFalse);
    });

    group('Expires attribute', () {
      test('Ignore when wrong format', () {
        final cookie = SetCookieHeaderParser.parse(
          'foo=bar; Expires=2020-01-01',
        );

        expect(cookie.containsKey(CookieAttributes.expires), isFalse);
      });

      test('Uses UTC', () {
        final cookie = SetCookieHeaderParser.parse(
          'foo=bar; Expires=Thu, 01 Jan 2038 00:00:00 GMT',
        );

        expect(cookie[CookieAttributes.expires], DateTime.utc(2038, 1, 1));
        expect(cookie[CookieAttributes.expires], isNot(DateTime(2038, 1, 1)));
      });

      test('Value should be trimmed', () {
        final cookie = SetCookieHeaderParser.parse(
          'foo=bar;  Expires  =  Thu, 01 Jan 2038 00:00:00 GMT  ',
        );

        expect(cookie[CookieAttributes.expires], DateTime.utc(2038, 1, 1));
      });
    });

    group('Max-Age attribute', () {
      test('Ignore when malformed', () {
        final cookie = SetCookieHeaderParser.parse(
          'foo=bar; Max-Age=foo',
        );

        expect(cookie.containsKey(CookieAttributes.maxAge), isFalse);
      });

      test('Do not ignore when negative', () {
        final cookie = SetCookieHeaderParser.parse(
          'foo=bar; Max-Age=-1',
        );

        expect(cookie.containsKey(CookieAttributes.maxAge), isTrue);
      });

      test('Value should be trimmed', () {
        final cookie = SetCookieHeaderParser.parse(
          'foo=bar;  Max-Age  =  3600  ',
        );

        expect(cookie[CookieAttributes.maxAge], Duration(hours: 1));
      });
    });

    group('Domain attribute', () {
      test('Ignore when empty', () {
        final cookie = SetCookieHeaderParser.parse(
          'foo=bar; Domain=',
        );

        expect(cookie.containsKey(CookieAttributes.domain), isFalse);
      });

      test('Remove first character when it is a dot', () {
        final cookie = SetCookieHeaderParser.parse(
          'foo=bar; Domain=.example.com',
        );

        expect(cookie[CookieAttributes.domain], Uri(host: 'example.com'));
        expect((cookie[CookieAttributes.domain] as Uri).host, 'example.com');
      });

      test('Converts to lowercase', () {
        final cookie = SetCookieHeaderParser.parse(
          'foo=bar; Domain=EXAMPLE.COM',
        );

        expect(cookie[CookieAttributes.domain], Uri(host: 'example.com'));
        expect((cookie[CookieAttributes.domain] as Uri).host, 'example.com');
      });

      test('Value should be trimmed', () {
        final cookie = SetCookieHeaderParser.parse(
          'foo=bar;  Domain  =  example.com  ',
        );

        expect(cookie[CookieAttributes.domain], Uri(host: 'example.com'));
        expect((cookie[CookieAttributes.domain] as Uri).host, 'example.com');
      });
    });

    group('Path attribute', () {
      test('Default when not starting with /', () {
        final cookies = [
          SetCookieHeaderParser.parse('foo=bar; Path=foo'),
          SetCookieHeaderParser.parse('foo=bar; Path='),
        ];

        for (final cookie in cookies) {
          expect(cookie[CookieAttributes.path], Uri(path: '/'));
          expect((cookie[CookieAttributes.path] as Uri).path, '/');
        }
      });

      test('Value should be trimmed', () {
        final cookies = [
          SetCookieHeaderParser.parse('foo=bar; Path=/foo/bar'),
          SetCookieHeaderParser.parse('foo=bar; Path=/foo/bar/'),
          SetCookieHeaderParser.parse('foo=bar;  Path  =  /foo/bar/  '),
        ];

        for (final cookie in cookies) {
          expect(cookie[CookieAttributes.path], Uri(path: '/foo/bar'));
          expect((cookie[CookieAttributes.path] as Uri).path, '/foo/bar');
        }
      });
    });

    group('Secure attribute', () {
      test('Attribute set', () {
        final cookies = [
          SetCookieHeaderParser.parse('foo=bar; Secure'),
          SetCookieHeaderParser.parse('foo=bar;  Secure  '),
        ];

        for (final cookie in cookies) {
          expect(cookie.containsKey(CookieAttributes.secure), isTrue);
        }
      });

      test('Attribute not set', () {
        final cookies = [
          SetCookieHeaderParser.parse('foo=bar'),
          SetCookieHeaderParser.parse('foo=bar;'),
          SetCookieHeaderParser.parse('foo=bar; foo'),
          SetCookieHeaderParser.parse('foo=bar;  foo  '),
        ];

        for (final cookie in cookies) {
          expect(cookie.containsKey(CookieAttributes.secure), isFalse);
        }
      });
    });

    group('HttpOnly attribute', () {
      test('Attribute set', () {
        final cookies = [
          SetCookieHeaderParser.parse('foo=bar; HttpOnly'),
          SetCookieHeaderParser.parse('foo=bar;  HttpOnly  '),
        ];

        for (final cookie in cookies) {
          expect(cookie.containsKey(CookieAttributes.httpOnly), isTrue);
        }
      });

      test('Attribute not set', () {
        final cookies = [
          SetCookieHeaderParser.parse('foo=bar'),
          SetCookieHeaderParser.parse('foo=bar;'),
          SetCookieHeaderParser.parse('foo=bar; foo'),
          SetCookieHeaderParser.parse('foo=bar;  foo  '),
        ];

        for (final cookie in cookies) {
          expect(cookie.containsKey(CookieAttributes.httpOnly), isFalse);
        }
      });
    });

    // TODO: SameSite attribute
  });

  group('RawCookie to Cookie', () {
    test('Persistent when Expire attribute', () {
      final cookie = Cookie.fromSetCookieHeader(
        'foo=bar; Expires=Thu, 01 Jan 2038 00:00:00 GMT',
      );

      expect(cookie.isPersistentCookie, isTrue);
    });

    test('Persistent when Max-Age attribute', () {
      final cookie = Cookie.fromSetCookieHeader(
        "foo=bar; Max-Age=3600",
      );

      expect(cookie.isPersistentCookie, isTrue);
    });

    test('Not persistent otherwise', () {
      final cookie = Cookie.fromSetCookieHeader(
        "foo=bar",
      );

      expect(cookie.isSessionCookie, isTrue);
    });

    test('Max-Age has precedence', () {
      final time = DateTime.utc(2020, 1, 1);
      final cookie = Cookie.fromSetCookieHeader(
        "foo=bar; Expires=Thu, 01 Jan 2038 00:00:00 GMT; Max-Age=3600",
        time: time,
      );

      expect(cookie.isPersistentCookie, isTrue);
      expect(cookie.expires, isNotNull);
      expect(cookie.expires, time.add(Duration(seconds: 3600)));
    });

    group('Domain attribute', () {
      test('Host only true', () {
        final cookie = Cookie.fromSetCookieHeader(
          'foo=bar',
          domain: Uri(host: 'example.com'),
        );

        expect(cookie.hostOnly, isTrue);
        expect(cookie.domain, Uri(host: 'example.com'));
      });

      test('Host only false', () {
        final cookie = Cookie.fromSetCookieHeader(
          'foo=bar; Domain=example.com',
        );

        expect(cookie.hostOnly, isFalse);
        expect(cookie.domain, Uri(host: 'example.com'));
      });

      test('Ignore when not a subdomain of requested domain', () {
        try {
          Cookie.fromSetCookieHeader(
            'foo=bar; Domain=example.com',
            domain: Uri(host: 'example.org'),
          );
        } on IgnoreCookieException catch (e) {
          expect(e.message,
              "Domain attribute is not a subdomain of the request domain");
        }
      });
    });

    group('Path attribute', () {
      test('Default path', () {
        final cookie = Cookie.fromSetCookieHeader(
          'foo=bar',
        );

        expect(cookie.path, Uri(path: '/'));
        expect(cookie.path.path, '/');
      });
    });

    group('Secure Attribute', () {
      test('Secure true', () {
        final cookie = Cookie.fromSetCookieHeader(
          'foo=bar; Secure',
        );

        expect(cookie.secure, isTrue);
      });

      test('Secure false', () {
        final cookie = Cookie.fromSetCookieHeader(
          'foo=bar',
        );

        expect(cookie.secure, isFalse);
      });
    });

    group('HttpOnly attribute', () {
      test('HttpOnly true', () {
        final cookie = Cookie.fromSetCookieHeader(
          'foo=bar; HttpOnly',
        );

        expect(cookie.httpOnly, isTrue);
      });

      test('HttpOnly false', () {
        final cookie = Cookie.fromSetCookieHeader(
          'foo=bar',
        );

        expect(cookie.httpOnly, isFalse);
      });
    });

    group('Max-Age attribute', () {
      test('Min DateTime when 0', () {
        final cookies = [
          Cookie.fromSetCookieHeader('foo=bar; Max-Age=0'),
          Cookie.fromSetCookieHeader('foo=bar; Max-Age=-1'),
        ];

        for (final cookie in cookies) {
          expect(cookie.expires, minDateTime);
        }
      });

      test('Correct expiring date', () {
        final cookie = Cookie.fromSetCookieHeader(
          'foo=bar; Max-Age=3600',
          time: DateTime.utc(2020, 1, 1),
        );

        expect(cookie.expires, DateTime.utc(2020, 1, 1, 1));
      });

      test('Uses UTC', () {
        final cookie = Cookie.fromSetCookieHeader(
          'foo=bar; Max-Age=3600',
          time: DateTime(2020, 1, 1),
        );

        expect(cookie.expires, DateTime(2020, 1, 1, 1).toUtc());
      });
    });
  });

  group('Cookie.fromSetCookieHeader', () {
    test('Data 1', () {
      final cookie = Cookie.fromSetCookieHeader("foo=bar",
          domain: Uri(host: "example.com"));

      expect(cookie.isRemoveCookie, isFalse);
      expect(cookie.isSessionCookie, isTrue);
      expect(cookie.key, equals("foo"));
      expect(cookie.value, equals("bar"));
      expect(cookie.domain?.host, equals("example.com"));
      expect(cookie.expires, isNull);
      expect(cookie.httpOnly, isFalse);
      expect(cookie.path.path, equals("/"));
      expect(cookie.secure, isFalse);
      expect(cookie.sameSite, equals(SameSite.lax));
    });

    test('Data 2', () {
      final cookie = Cookie.fromSetCookieHeader(
        "foo=bar; "
        "Domain=example.com; "
        "Expires=Wed, 21 Oct 2015 07:28:00 GMT; "
        "HttpOnly; "
        "Path=/; "
        "Secure; "
        "SameSite=Lax",
        domain: Uri(host: "example.com"),
      );

      expect(cookie.isRemoveCookie, isFalse);
      expect(cookie.isSessionCookie, isFalse);
      expect(cookie.key, equals("foo"));
      expect(cookie.value, equals("bar"));
      expect(cookie.domain?.host, equals("example.com"));
      expect(
          cookie.expires, equals(DateTime.utc(2015, 10, 21, 7, 28, 0, 0, 0)));
      expect(cookie.httpOnly, isTrue);
      expect(cookie.path.path, equals("/"));
      expect(cookie.secure, isTrue);
      expect(cookie.sameSite, equals(SameSite.lax));
    });

    test('Case insensitive', () {
      final cookie = Cookie.fromSetCookieHeader(
        "foo=bar; "
        "dOmAin=example.com; "
        "expIres=Wed, 21 Oct 2015 07:28:00 GMT; "
        "httponly; "
        "paTH=; "
        "secure; "
        "samesite=Lax",
        domain: Uri(host: "example.com"),
      );

      expect(cookie.isRemoveCookie, isFalse);
      expect(cookie.isSessionCookie, isFalse);
      expect(cookie.key, equals("foo"));
      expect(cookie.value, equals("bar"));
      expect(cookie.domain?.host, equals("example.com"));
      expect(
          cookie.expires, equals(DateTime.utc(2015, 10, 21, 7, 28, 0, 0, 0)));
      expect(cookie.httpOnly, isTrue);
      expect(cookie.path.path, equals("/"));
      expect(cookie.secure, isTrue);
      expect(cookie.sameSite, equals(SameSite.lax));
    });

    test('Remove cookie', () {
      final cookies = [
        Cookie.fromSetCookieHeader("foo="),
        Cookie.fromSetCookieHeader("  foo  =  "),
        Cookie.fromSetCookieHeader("foo  =  ;"),
      ];

      for (var cookie in cookies) {
        expect(cookie.isRemoveCookie, isTrue);
        expect(cookie.isSessionCookie, isTrue);
        expect(cookie.key, equals("foo"));
        expect(cookie.value, equals(""));
        expect(cookie.domain, isNull);
        expect(cookie.expires, isNull);
        expect(cookie.httpOnly, isFalse);
        expect(cookie.path.path, equals("/"));
        expect(cookie.secure, isFalse);
        expect(cookie.sameSite, equals(SameSite.lax));
      }
    });

    test('Same after parsing 1', () {
      final rand = Random();
      final time = DateTime(2020, 1, 1);
      for (var i = 0; i < 100; i++) {
        final cookie = Cookie(
          rand.nextString(10, additionalCharacters: "._-"),
          rand.nextString(10,
              additionalCharacters: "!§\$%&/()=?`´*+~#'-_.:<>|"),
          domain: Uri(host: "example.com"),
          expires: DateTime(2020, 1, 1),
          httpOnly: true,
          path: Uri(path: "/foo"),
          secure: true,
          sameSite: SameSite.strict,
          creationTime: time,
        );

        final header = cookie.toSetCookieHeader;

        final parsed = Cookie.fromSetCookieHeader(header, time: time);

        expect(parsed, equals(cookie));
      }
    });

    test('Same after parsing 2', () {
      final time = DateTime(2020, 1, 1);
      final cookie = Cookie("foo", "bar", creationTime: time);

      final header = cookie.toSetCookieHeader;

      expect(header, equalsIgnoringWhitespace("foo=bar"));

      final parsed = Cookie.fromSetCookieHeader(header, time: time);

      expect(parsed, equals(cookie));
    });
  });

  group('CookieStore', () {
    group('executeHeader', () {
      final time = DateTime(2020, 1, 1);
      test('Test 1', () {
        final store = CookieStore()
          ..executeHeader(
            "foo=bar",
            domain: Uri(host: "example.com"),
            time: time,
          );

        expect(store.cookies, hasLength(1));
        expect(
          store.cookies.first,
          equals(Cookie(
            "foo",
            "bar",
            domain: Uri(host: "example.com"),
            hostOnly: true,
            creationTime: time,
          )),
        );
      });
      test('Test 2', () {
        final store = CookieStore()
          ..executeHeader(
            "foo=bar,foo=foo; path=/bar",
            domain: Uri(host: "example.com"),
            time: time,
          )
          ..executeHeader(
            "foo=baz; path=/",
            domain: Uri(host: "example.com"),
            time: time.add(Duration(seconds: 1)),
          );

        expect(store.cookies, hasLength(2));
        expect(
          store.cookies.first,
          equals(Cookie(
            "foo",
            "foo",
            path: Uri(path: "/bar"),
            domain: Uri(host: "example.com"),
            hostOnly: true,
            creationTime: time,
          )),
        );
        expect(
          store.cookies.last,
          equals(Cookie(
            "foo",
            "baz",
            domain: Uri(host: "example.com"),
            hostOnly: true,
            creationTime: time,
            lastAccessTime: time.add(Duration(seconds: 1)),
          )),
        );
      });

      test('Ignored cookie', () {
        final store = CookieStore()
          ..executeHeader(
            "foo=bar; domain=foo.com",
            domain: Uri(host: "example.com"),
            time: time,
          );

        expect(store.cookies, isEmpty);
      });
    });

    group('pump', () {
      test('Test 1', () {
        final time = DateTime.utc(2015, 10, 21, 7, 28, 0, 0, 0);
        final store = CookieStore()
          ..executeHeaders([
            "foo=bar; expires=Wed, 21 Oct 2015 07:28:00 GMT",
            "bar=baz; max-age=1",
          ], domain: Uri(host: "example.com"), time: time);

        expect(store.cookies, hasLength(2));

        store.pump(time: time);

        expect(store.cookies, hasLength(2));

        store.pump(time: time.add(const Duration(seconds: 1)));

        expect(store.cookies, hasLength(1));

        store.pump(time: time.add(const Duration(seconds: 2)));

        expect(store.cookies, isEmpty);
      });

      test('MaxCountPerDomain', () {
        final time = DateTime.utc(2020, 1, 1);
        final store = CookieStore()
          ..executeHeader(
            "bar=baz",
            time: time.add(const Duration(seconds: 1)),
          )
          ..executeHeader(
            "foo=bar",
            time: time,
          )
          ..executeHeader(
            "baz=foo",
            time: time.add(const Duration(seconds: 2)),
          );

        store.pump(time: time, maxCountPerDomain: 2);

        expect(store.cookies, hasLength(2));
        expect(store.cookies.first.key, equals("bar"));
        expect(store.cookies.last.key, equals("baz"));
      });
    });

    group('cookiesFor', () {
      test('Test 1', () {
        final store = CookieStore()
          ..executeHeaders([
            "foo=bar; domain=example.com",
            "bar=baz; domain=foo.example.com",
            "baz=foo; domain=bar.example.com",
          ]);

        expect(
            store.cookiesFor(domain: Uri(host: "example.com")), hasLength(1));
        expect(store.cookiesFor(domain: Uri(host: "foo.example.com")),
            hasLength(2));
        expect(store.cookiesFor(domain: Uri(host: "bar.example.com")),
            hasLength(2));

        expect(
            store.cookiesFor(
              domain: Uri(host: "example.com"),
              path: Uri(path: "/foo"),
            ),
            hasLength(1));
        expect(
            store.cookiesFor(
              domain: Uri(host: "foo.example.com"),
              path: Uri(path: "/foo"),
            ),
            hasLength(2));
        expect(
            store.cookiesFor(
              domain: Uri(host: "bar.example.com"),
              path: Uri(path: "/foo"),
            ),
            hasLength(2));
      });

      test('Test 2', () {
        final store = CookieStore()
          ..executeHeaders([
            "foo=bar; domain=example.com; path=/foo",
            "bar=baz; domain=example.com; ",
          ]);

        expect(
            store.cookiesFor(
              path: Uri(path: "/foo"),
            ),
            hasLength(2));
        expect(
            store.cookiesFor(
              path: Uri(path: "/foo/bar"),
            ),
            hasLength(2));
        expect(
            store.cookiesFor(
              path: Uri(path: "/"),
            ),
            hasLength(1));
      });
    });
  });

  group('Domain match (Uri.isSubdomainOf)', () {
    test('Test 1', () {
      final uri1 = Uri(host: "example.com");
      final uri2 = Uri(host: "www.example.com");

      expect(uri1.isSubdomainOf(uri1), isTrue);
      expect(uri2.isSubdomainOf(uri2), isTrue);
      expect(uri2.isSubdomainOf(uri1), isTrue);
      expect(uri1.isSubdomainOf(uri2), isFalse);
    });

    test('Test 2', () {
      final uri1 = Uri(host: "example.com");
      final uri2 = Uri(host: "www.foo-example.com");

      expect(uri1.isSubdomainOf(uri2), isFalse);
      expect(uri2.isSubdomainOf(uri1), isFalse);
    });
  });

  group('Path match (Uri.isSubPathOf)', () {
    test('Test 1', () {
      final uri1 = Uri(path: "/foo/bar");
      final uri2 = Uri(path: "/foo/bar/baz");

      expect(uri1.isSubPathOf(uri1), isTrue);
      expect(uri2.isSubPathOf(uri2), isTrue);
      expect(uri2.isSubPathOf(uri1), isTrue);
      expect(uri1.isSubPathOf(uri2), isFalse);
    });

    test('Test 2', () {
      final uri1 = Uri(path: "/foo/bar");
      final uri2 = Uri(path: "/foo/bar/");

      expect(uri1.isSubPathOf(uri2), isTrue);
      expect(uri2.isSubPathOf(uri1), isTrue);
    });

    test('Test 3', () {
      final uri1 = Uri(path: "/foo/bar");
      final uri2 = Uri(path: "/foo/barbaz");

      expect(uri1.isSubPathOf(uri2), isFalse);
      expect(uri2.isSubPathOf(uri1), isFalse);
    });
  });
}

extension RandomExtension on Random {
  String nextString(int length,
      {bool includeNumbers = true, String additionalCharacters = ""}) {
    String characters =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ$additionalCharacters";
    if (includeNumbers) {
      characters += "0123456789";
    }

    final codeUnits = List.generate(length, (index) {
      return characters.codeUnitAt(nextInt(characters.length));
    });

    return String.fromCharCodes(codeUnits);
  }
}
