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

extension UriMatchesExtension on Uri {
  /// Returns true if this Uris host is a subdomain of the other Uris host.
  ///
  /// https://www.rfc-editor.org/rfc/rfc6265#section-5.1.3
  ///
  /// Note: The case, when one or both of the hosts is an IP address, is not
  /// handled
  bool isSubdomainOf(Uri other) {
    final thisHost = host;
    final otherHost = other.host;
    // Already normalized to lowercase

    if (thisHost == otherHost) return true;

    final index = thisHost.lastIndexOf(otherHost);

    if (index == -1) return false;

    if (index == thisHost.length - otherHost.length) {
      return (index == 0 || thisHost[index - 1] == '.');
    }
    return false;
  }

  String _normalizePath(String path) {
    if (path.isEmpty || path == '/' || !path.startsWith('/')) return '/';

    return path.replaceAll(RegExp(r'(?<!\/)$'), '/');
  }

  bool isSubPathOf(Uri other) {
    final thisPath = _normalizePath(path);
    final otherPath = _normalizePath(other.path);

    return thisPath.startsWith(otherPath);
  }
}
