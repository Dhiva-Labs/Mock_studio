import 'dart:io';

/// Discovers the machine's LAN IPv4 addresses so mocks can be reached from
/// phones, emulators and teammates on the same network.
class NetworkInfo {
  /// Returns non-loopback IPv4 addresses, preferring common private ranges.
  static Future<List<String>> lanAddresses() async {
    final result = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) result.add(addr.address);
        }
      }
    } catch (_) {}
    // Prefer typical private LAN ranges first.
    result.sort((a, b) => _rank(b).compareTo(_rank(a)));
    return result;
  }

  static int _rank(String ip) {
    if (ip.startsWith('192.168.')) return 3;
    if (ip.startsWith('10.')) return 2;
    if (ip.startsWith('172.')) return 1;
    return 0;
  }

  static Future<String> primaryLanAddress() async {
    final list = await lanAddresses();
    return list.isNotEmpty ? list.first : '127.0.0.1';
  }
}
