String? invitationTokenFromLink(String value) {
  value = value.trim();
  if (RegExp(r'^[A-Za-z0-9_-]{43}=$').hasMatch(value)) return value;
  try {
    final uri = Uri.parse(value);
    final token = Uri.splitQueryString(uri.fragment)['invite'];
    return token != null && RegExp(r'^[A-Za-z0-9_-]{43}=$').hasMatch(token)
        ? token
        : null;
  } on FormatException {
    return null;
  }
}

String invitationLink(String token) {
  final base = Uri.base.hasAuthority
      ? Uri.base
      : Uri.parse('http://localhost:8082/');
  return base.replace(query: '', fragment: 'invite=$token').toString();
}

String? invitationTokenFromRoute(Uri uri) {
  if (uri.hasFragment) return invitationTokenFromLink(uri.toString());
  if (uri.hasAuthority || uri.hasQuery) return null;
  // Flutter's hash URL strategy forwards the fragment as a route path.
  final fragment = uri.path.replaceFirst(RegExp(r'^/'), '');
  return invitationTokenFromLink('#$fragment');
}
