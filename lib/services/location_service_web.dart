// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

Future<Map<String, double>?> getPlatformCoordinates() async {
  final completer = Completer<Map<String, double>?>();
  try {
    html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 8),
    ).then((pos) {
      if (pos.coords != null && pos.coords!.latitude != null && pos.coords!.longitude != null) {
        completer.complete({
          'lat': pos.coords!.latitude!.toDouble(),
          'lng': pos.coords!.longitude!.toDouble(),
        });
      } else {
        completer.complete(null);
      }
    }).catchError((_) {
      completer.complete(null);
    });
  } catch (_) {
    return null;
  }

  return completer.future;
}
