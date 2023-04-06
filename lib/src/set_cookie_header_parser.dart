import 'dart:async';
import 'dart:io' show HttpDate;

import 'cookie.dart';
import 'cookie_attributes.dart';
import 'raw_cookie.dart';

class IgnoreCookieException implements Exception {
  final dynamic message;

  IgnoreCookieException([this.message]);

  @override
  String toString() {
    if (message == null) return "IgnoreCookieException";
    return "IgnoreCookieException: $message";
  }
}

class SetCookieHeaderParser {
  /// https://www.rfc-editor.org/rfc/rfc6265#section-5.2
  static RawCookie parse(String header) {
    final matches = RegExp(r'\s*(?<key>[^;=\s]*)(?:\s*=\s*(?<value>[^;]*))?')
        .allMatches(header)
        .where((m) => m.start != m.end);

    final key = matches.first.namedGroup('key')!;
    final value = matches.first.namedGroup('value')?.trim();

    if (key.isEmpty) {
      throw IgnoreCookieException("Cookie name is empty");
    }
    if (value == null) {
      throw IgnoreCookieException("Cookie is missing '='");
    }

    Map<String, Object> attributes = Map.fromEntries(matches
        .skip(1)
        .map((match) => parseAttribute(
              match.namedGroup('key')!,
              match.namedGroup('value')?.trim(),
            ))
        .where((e) => e != null)
        .cast());

    return RawCookie(key, value, attributes);
  }

  /// https://www.rfc-editor.org/rfc/rfc6265#section-5.2
  static MapEntry<String, Object>? parseAttribute(String key, String? value,
      {bool throwOnError = false, bool passUnhandledErrorToZone = false}) {
    final lowerKey = key.toLowerCase();
    final parser = _parsers[lowerKey];

    if (parser == null) {
      if (passUnhandledErrorToZone) {
        Zone.current.handleUncaughtError(
            Exception("Unknown attribute '$key'"), StackTrace.current);
      }
      return null;
    }

    final result = parser(value);

    if (result is _UnsuccessfulParsingResult) {
      if (throwOnError) {
        throw result.toError(key);
      }
      if (passUnhandledErrorToZone) {
        Zone.current.handleUncaughtError(
            result.toError(key),
            (result is _IsError ? result.stackTrace : null) ??
                StackTrace.current);
      }
      return null;
    }

    return MapEntry(lowerKey, result);
  }

  static final _parsers = {
    CookieAttributes.expires: (String? value) {
      if (value == null) return _shouldNotBeNull;
      if (value.isEmpty) return _shouldNotBeEmpty;

      try {
        return HttpDate.parse(value);
      } catch (e, st) {
        return _IsError(e, st);
      }
    },
    CookieAttributes.maxAge: (String? value) {
      if (value == null) return _shouldNotBeNull;
      if (value.isEmpty) return _shouldNotBeEmpty;

      try {
        return Duration(seconds: int.parse(value));
      } catch (e, st) {
        return _IsError(e, st);
      }
    },
    CookieAttributes.domain: (String? value) {
      if (value == null) return _shouldNotBeNull;
      if (value.isEmpty) return _shouldNotBeEmpty;

      // Note: rejection of "public suffixes" is not implemented (https://www.rfc-editor.org/rfc/rfc6265#section-5.3 at 5.)
      // Note: canonicalization of the domain is not implemented

      return Uri(host: value.replaceFirst(RegExp(r'^\.'), ''));
    },
    CookieAttributes.path: (String? value) {
      if (value == null) return _shouldNotBeNull;

      if (!value.startsWith('/')) value = '/';
      return Uri.parse(value.replaceAll(RegExp(r'(?<=.)\/$'), ''));
    },
    CookieAttributes.secure: (String? value) {
      return valueExists;
    },
    CookieAttributes.httpOnly: (String? value) {
      return valueExists;
    },
    CookieAttributes.sameSite: (String? value) {
      if (value == null) return _shouldNotBeNull;
      if (value.isEmpty) return _shouldNotBeEmpty;

      try {
        return SameSite.values.byName(value.toLowerCase());
      } catch (e, st) {
        return _IsError(e, st);
      }
    },
  };
}

const _shouldNotBeNull = _ShouldNotBeNull();
const _shouldNotBeEmpty = _ShouldNotBeEmpty();

abstract class _UnsuccessfulParsingResult {
  const _UnsuccessfulParsingResult();

  Object toError(String key);
}

class _ShouldNotBeNull extends _UnsuccessfulParsingResult {
  const _ShouldNotBeNull();

  @override
  Object toError(String key) => ArgumentError.notNull(key);
}

class _ShouldNotBeEmpty extends _UnsuccessfulParsingResult {
  const _ShouldNotBeEmpty();

  @override
  Object toError(String key) =>
      ArgumentError.value('', key, "Must not be empty");
}

class _IsError extends _UnsuccessfulParsingResult {
  final Object? error;
  final StackTrace? stackTrace;

  const _IsError([this.error, this.stackTrace]);

  @override
  Object toError(String key) => error ?? ArgumentError('Error', key);
}
