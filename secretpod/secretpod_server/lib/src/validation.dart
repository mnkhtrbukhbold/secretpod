import 'generated/protocol.dart';

String bounded(
  String value,
  String label, {
  int max = 120,
  bool empty = false,
}) {
  final result = value.trim();
  if ((!empty && result.isEmpty) || result.length > max) {
    throw VaultException(
      message: '$label must be ${empty ? '0' : '1'}–$max characters.',
    );
  }
  return result;
}

String normalizedEmail(String value) {
  final email = bounded(value, 'Email', max: 254).toLowerCase();
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    throw VaultException(message: 'Enter a valid email address.');
  }
  return email;
}
