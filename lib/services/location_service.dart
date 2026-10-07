import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class GeoAddress {
  final double latitude;
  final double longitude;
  final String area;
  final String city;
  final String pincode;
  final String formatted;
  final String? building;
  final String? street;

  GeoAddress({
    required this.latitude,
    required this.longitude,
    required this.area,
    required this.city,
    required this.pincode,
    required this.formatted,
    this.building,
    this.street,
  });
}

class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  static const String awsApiKey =
      'v1.public.eyJqdGkiOiIzNDgzZTFjMC01N2ZjLTRkZTYtODM0OS0xYzE4ZTRiNTIwZDcifYygLYhkH3uJ1gQKmlS63fWlZqkzwuWBrKS09slqUhs-pQTyD6lY8hmpmVwlPi3WIInOUSs8oc7hGvd_NJwLf6SlKaBh1Ci7fHCtKVWlyGVCnQzg4gNF1oc-tWI_4UO2j9Ghu-TGuII60MboUZBMSCKijerOKdWx3Q05pVF8FrhND80Kjjxl80Ezd67P9sqvVLqyE3HvSc4bvT0AWwg7wo0NM0YB7YfnIoTxpR40Kl10Y4PquQ9BT1Nk1gGWfCAnEWdkqHGNEQqZdHzlewr6bQXyuLSzKfpdHINmUmY6vusKQ9YuDMVsar7EkPs-RszYKQz54G19scq83LHvBx2KfSc.Njg1MGZlZTUtYTI2ZS00MDdlLWJjNDktMDNmZDlkNzVmMjQ0';

  static const String awsRegion = 'ap-south-1';

  /// Fetch live device coordinates using device GPS hardware via Geolocator
  Future<Map<String, double>?> getDeviceCoordinates() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location service is not enabled on device
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return {
        'lat': position.latitude,
        'lng': position.longitude,
      };
    } catch (_) {
      return null;
    }
  }

  /// Primary: AWS Location Service Reverse Geocode
  Future<GeoAddress?> reverseGeocodeAws(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://places.geo.$awsRegion.amazonaws.com/v2/reverse-geocode?key=$awsApiKey',
      );
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'QueryPosition': [lng, lat],
              'MaxResults': 1,
            }),
          )
          .timeout(const Duration(seconds: 7));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final items = data['ResultItems'] as List?;
        if (items != null && items.isNotEmpty) {
          final first = items[0] as Map<String, dynamic>;
          final addr = first['Address'] as Map<String, dynamic>? ?? {};

          final label = addr['Label']?.toString() ?? first['Title']?.toString() ?? '';
          final locality = addr['Locality']?.toString() ?? 'Hyderabad';
          final district = addr['District']?.toString() ?? '';
          final subdistrict = addr['SubDistrict']?.toString() ?? '';
          final street = addr['Street']?.toString() ?? '';
          final building = addr['Building']?.toString() ?? '';
          final postal = addr['PostalCode']?.toString() ?? '';

          final areaCandidate = [building, street, district, subdistrict]
              .where((s) => s.isNotEmpty)
              .join(', ');
          final area = areaCandidate.isNotEmpty ? areaCandidate : locality;

          return GeoAddress(
            latitude: lat,
            longitude: lng,
            area: area,
            city: locality,
            pincode: postal,
            formatted: label.isNotEmpty ? label : '$area, $locality $postal',
            building: building.isNotEmpty ? building : null,
            street: street.isNotEmpty ? street : null,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Search Places via AWS Location Service Places API (Real map query)
  Future<List<GeoAddress>> searchPlaces(
    String queryText, {
    double biasLat = 17.3850,
    double biasLng = 78.4867,
  }) async {
    final trimmed = queryText.trim();
    if (trimmed.isEmpty) return [];

    try {
      final url = Uri.parse(
        'https://places.geo.$awsRegion.amazonaws.com/v2/search-text?key=$awsApiKey',
      );
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'QueryText': trimmed,
              'BiasPosition': [biasLng, biasLat],
              'MaxResults': 6,
            }),
          )
          .timeout(const Duration(seconds: 7));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final items = data['ResultItems'] as List?;
        if (items != null && items.isNotEmpty) {
          return items.map((it) {
            final map = it as Map<String, dynamic>;
            final addr = map['Address'] as Map<String, dynamic>? ?? {};
            final pos = map['Position'] as List? ?? [biasLng, biasLat];
            final pLng = (pos[0] as num).toDouble();
            final pLat = (pos[1] as num).toDouble();

            final label = addr['Label']?.toString() ?? map['Title']?.toString() ?? trimmed;
            final locality = addr['Locality']?.toString() ?? 'Hyderabad';
            final district = addr['District']?.toString() ?? '';
            final postal = addr['PostalCode']?.toString() ?? '';
            final street = addr['Street']?.toString() ?? '';

            final areaCandidate = [street, district].where((s) => s.isNotEmpty).join(', ');
            final area = areaCandidate.isNotEmpty ? areaCandidate : locality;

            return GeoAddress(
              latitude: pLat,
              longitude: pLng,
              area: area,
              city: locality,
              pincode: postal,
              formatted: label,
              street: street.isNotEmpty ? street : null,
            );
          }).toList();
        }
      }
    } catch (_) {}

    // Fallback to OpenStreetMap / Nominatim if AWS returns empty
    try {
      final nomUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=jsonv2&q=${Uri.encodeComponent('$trimmed, Hyderabad')}&countrycodes=in&limit=6',
      );
      final nomResp = await http.get(nomUrl, headers: {
        'User-Agent': 'YesDhobiCustomerApp/1.0',
      }).timeout(const Duration(seconds: 5));

      if (nomResp.statusCode == 200) {
        final List list = jsonDecode(nomResp.body);
        if (list.isNotEmpty) {
          return list.map((it) {
            final m = it as Map<String, dynamic>;
            final pLat = double.tryParse(m['lat']?.toString() ?? '') ?? biasLat;
            final pLng = double.tryParse(m['lon']?.toString() ?? '') ?? biasLng;
            final name = m['name']?.toString() ?? '';
            final display = m['display_name']?.toString() ?? trimmed;
            return GeoAddress(
              latitude: pLat,
              longitude: pLng,
              area: name.isNotEmpty ? name : trimmed,
              city: 'Hyderabad',
              pincode: '500081',
              formatted: display,
            );
          }).toList();
        }
      }
    } catch (_) {}

    return [];
  }

  /// Calculates real driving distance and duration via AWS Location Routes API
  Future<Map<String, dynamic>?> calculateRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final url = Uri.parse(
        'https://routes.geo.$awsRegion.amazonaws.com/v2/routes?key=$awsApiKey',
      );
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'Origin': [originLng, originLat],
              'Destination': [destLng, destLat],
            }),
          )
          .timeout(const Duration(seconds: 7));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final routes = data['Routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final summary = routes[0]['Summary'] as Map<String, dynamic>;
          final distMeters = (summary['Distance'] as num?)?.toDouble() ?? 0.0;
          final durationSec = (summary['Duration'] as num?)?.toInt() ?? 0;
          return {
            'distanceKm': (distMeters / 1000.0),
            'durationMinutes': (durationSec / 60.0).ceil(),
            'distanceMeters': distMeters,
            'durationSeconds': durationSec,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  /// Generates a live AWS Static Map image URL centered at coordinates
  String getStaticMapUrl({
    required double lat,
    required double lng,
    int width = 600,
    int height = 300,
    int zoom = 15,
  }) {
    return 'https://maps.geo.$awsRegion.amazonaws.com/v2/static/map?key=$awsApiKey&center=$lng,$lat&zoom=$zoom&width=$width&height=$height';
  }

  /// Current location address: Uses device GPS + AWS Location Service with OpenStreetMap as fallback
  Future<GeoAddress?> getCurrentLocationAddress() async {
    try {
      final coords = await getDeviceCoordinates();
      if (coords == null) return null;

      final lat = coords['lat']!;
      final lng = coords['lng']!;

      // 1. Try AWS Location Service (Enterprise precision)
      final awsResult = await reverseGeocodeAws(lat, lng);
      if (awsResult != null) {
        return awsResult;
      }

      // 2. Fallback to OpenStreetMap if AWS reverse-geocode fails
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng',
      );
      final resp = await http.get(
        url,
        headers: {'User-Agent': 'YesDhobiCustomerApp/1.0'},
      ).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final suburb = addr['suburb'] ?? addr['neighbourhood'] ?? addr['residential'] ?? addr['subdistrict'] ?? '';
        final city = addr['city'] ?? addr['town'] ?? addr['state_district'] ?? 'Hyderabad';
        final pincode = addr['postcode'] ?? '';
        final road = addr['road'] ?? '';

        final areaParts = [road, suburb].where((s) => s.toString().isNotEmpty).toList();
        final area = areaParts.isNotEmpty
            ? areaParts.join(', ')
            : (suburb.toString().isNotEmpty ? suburb.toString() : city.toString());
        final formatted = [area, city, pincode].where((s) => s.toString().isNotEmpty).join(', ');

        return GeoAddress(
          latitude: lat,
          longitude: lng,
          area: area.toString(),
          city: city.toString(),
          pincode: pincode.toString(),
          formatted: formatted,
        );
      }
    } catch (_) {}
    return null;
  }
}
