Process and store cookies in a cookie store, or directly use it as a http client.

This package should mostly conform to [RFC 6265](https://www.rfc-editor.org/rfc/rfc6265) with some minor exceptions

## Features

- [x] `Cookie`
- [x] `CookieStore`
- [x] `CookieClient` http client (using [http package](https://pub.dev/packages/http))

## Usage

### `CookieKey`

A `CookieKey` is used, to uniquely identify a cookie in a `CookieStore`. It is a combination of the cookie's name, domain and path.

### `Cookie`

Cookies can be parsed from a [`Set-Cookie`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie) header field:

```dart
Cookie cookie = Cookie.fromSetCookieHeader(
    "foo=bar; Domain=example.com; Path=/; Secure; HttpOnly",
    // Optional, defaults to DateTime.now()
    time: DateTime.now(),
    // Optional, is important for validation and when the 'Domain' attribute is omitted
    domain: Uri(host: "example.com"),
);

print(cookie.domain); // => example.com
print(cookie.path); // => /
print(cookie.secure); // => true
print(cookie.httpOnly); // => true
```

> Note: `DateTime` objects are always converted to UTC, since this is required by the standard.

### `RawCookie`

This is a simpler form of `Cookie` that only contains the name, value and a map of attributes. It can be parsed from a [`Set-Cookie`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie) header field, the same way as `Cookie`.

### `CookieStore`

A `CookieStore` can be used to store cookies and retrieve them for a given domain and path. This class implements `Map<CookieKey, Cookie>`.

```dart
CookieStore store = CookieStore();

DateTime time = DateTime.utc(2015, 10, 21, 7, 0);

store.executeHeaders([
    "foo=bar; Domain=example.com; Path=/; Secure; HttpOnly",
    "foo=baz; Path=/bar; HttpOnly; Expires=Wed, 21 Oct 2015 07:28:00 GMT",
    "bar=foo; Domain=bar.example.com; Secure; Max-Age=3600",
], domain: Uri(host: "bar.example.com"), time: time);

print(store.cookiesFor(uri: Uri(host: "bar.example.com"), time: time));
// => [foo=bar; Domain=example.com; Secure; HttpOnly,
//     bar=foo; Expires=Wed, 21 Oct 2015 08:00:00 GMT; Domain=bar.example.com; Secure]

time = time.add(Duration(hours: 2));

store.pump(time: time);

print(store.cookiesFor(uri: Uri(host: "bar.example.com"), time: time));
// => [foo=bar; Domain=example.com; Secure; HttpOnly]
```

### `CookieClient`

A `CookieClient` is a wrapper around the [http package's](https://pub.dev/packages/http) `Client` that uses a `CookieStore` to manage cookies.

```dart
CookieClient client = CookieClient();

final client = CookieClient();

await client.get(Uri.parse('https://www.nytimes.com/'));

await client.get(Uri.parse('https://edition.cnn.com/'));

groupBy(client.store.cookies, (c) => c.domain).forEach((key, value) {
    print("$key:");
    for (var cookie in value) {
        print('\t$cookie');
    }
});

print(client.store[CookieKey('geoData', Uri(host: 'cnn.com'))]);

client.close();

```

## Additional information

Feel free to open an issue or a PR if you find a bug or have a feature request!
