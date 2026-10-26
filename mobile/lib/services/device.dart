import 'dart:async';
import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class GeoFix {
  const GeoFix(this.lat, this.lon, this.accuracyM);

  final double lat;
  final double lon;
  final double accuracyM;
}

enum LocationProblem { serviceOff, denied, timeout }

class LocationException implements Exception {
  const LocationException(this.problem);

  final LocationProblem problem;
}

class PickedPhoto {
  const PickedPhoto(this.bytes);

  final Uint8List bytes;

  /// 'image/jpeg', 'image/png', or null for formats the gateway refuses
  /// (e.g. HEIC); checked from the file's first bytes, like the server does.
  String? get mimeType {
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (bytes.length > 8 && List.generate(8, (i) => bytes[i]).join() == png.join()) {
      return 'image/png';
    }
    return null;
  }
}

/// Camera, GPS and phone dialer, behind one interface so screens can be
/// tested without a device.
abstract class DeviceServices {
  Future<PickedPhoto?> pickPhoto({required bool camera});

  /// Throws [LocationException] when no position can be had.
  Future<GeoFix> currentPosition();

  Future<bool> dial(String number);
}

class RealDeviceServices implements DeviceServices {
  final _picker = ImagePicker();

  @override
  Future<PickedPhoto?> pickPhoto({required bool camera}) async {
    // Resizing keeps uploads well under the gateway's 5 MB limit and
    // re-encodes as JPEG.
    final x = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
      requestFullMetadata: false,
    );
    return x == null ? null : PickedPhoto(await x.readAsBytes());
  }

  @override
  Future<GeoFix> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationProblem.serviceOff);
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw const LocationException(LocationProblem.denied);
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return GeoFix(p.latitude, p.longitude, p.accuracy);
    } on TimeoutException {
      throw const LocationException(LocationProblem.timeout);
    }
  }

  @override
  Future<bool> dial(String number) => launchUrl(Uri(scheme: 'tel', path: number));
}
