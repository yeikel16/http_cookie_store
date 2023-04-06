extension UriMatchesExtension on Uri {
  /// Returns true if this Uris host is a subdomain of the other Uris host.
  ///
  /// https://www.rfc-editor.org/rfc/rfc6265#section-5.1.3
  ///
  /// Note: The case, when one or both of the hosts is an IP address, is not handled
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
