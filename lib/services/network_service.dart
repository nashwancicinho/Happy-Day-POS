import 'dart:io';

class NetworkService {
  static Future<List<String>> getAllLocalIpAddresses() async {
    final List<String> ips = [];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('loopback') || name.contains('vbox') || name.contains('wsl') || name.contains('vmnet')) {
          continue;
        }

        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            if (!ips.contains(addr.address)) {
              // Prioritize Wi-Fi / en0 / en1 interfaces first
              if (name.contains('wi-fi') || name.contains('wifi') || name.contains('en0') || name.contains('wlan')) {
                ips.insert(0, addr.address);
              } else {
                ips.add(addr.address);
              }
            }
          }
        }
      }
    } catch (_) {}
    return ips;
  }

  static Future<String?> getLocalIpAddress() async {
    final list = await getAllLocalIpAddresses();
    return list.isNotEmpty ? list.first : null;
  }
}
