import 'package:geolocator/geolocator.dart';
import 'package:osrm/osrm.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  final osrm = Osrm();

  Future<Position> getLocation() async {
    return await Geolocator.getCurrentPosition();
  }

  Future<List<LatLng>> getShortest(List<LatLng> points) async {
    final options = RouteRequest(
      coordinates: points.map((e) => (e.longitude, e.latitude)).toList(),
    );
    final route = await osrm.route(options);
    return route.routes.first.geometry!.lineString!.coordinates.map((e) {
      var location = e.toLocation();
      return LatLng(location.lat, location.lng);
    }).toList();
  }
}
