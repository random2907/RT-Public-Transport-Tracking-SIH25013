import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:public_transport/src/generated/gtfs-realtime.pb.dart';
import 'utils.dart';
import 'package:csv/csv.dart';

class GtfsFeed {
  final String id;
  final bool isDeleted;
  final TripUpdate tripUpdate;
  final VehiclePosition vehicle;
  final Alert alert;
  final Shape shape;
  final Stop stop;
  final TripModifications tripModifications;

  const GtfsFeed({
    required this.id,
    required this.isDeleted,
    required this.tripUpdate,
    required this.vehicle,
    required this.alert,
    required this.shape,
    required this.stop,
    required this.tripModifications,
  });
  factory GtfsFeed.fromJson(Map<String, dynamic> json) {
    return GtfsFeed(
      id: json['id'] as String,
      isDeleted: json['isDeleted'] as bool,
      tripUpdate: json['tripUpdate'] as TripUpdate,
      vehicle: json['vehicle'] as VehiclePosition,
      alert: json['alert'] as Alert,
      shape: json['shape'] as Shape,
      stop: json['stop'] as Stop,
      tripModifications: json['tripModifications'] as TripModifications,
    );
  }
}

class GtfsData {
  List<LatLng> stops = [];

  Future<http.Response> fetchGtfs() {
    http.Client client = http.Client();
    const String apiKey = String.fromEnvironment('API_KEY_GTFS');
    final uri = Uri.https(
      'otd.delhi.gov.in',
      '/api/realtime/VehiclePositions.pb',
      {'key': apiKey},
    );
    http.Request req = http.Request("GET", uri);
    req.headers["Content-Type"] = "application/x-protobuf";
    req.headers["Connection"] = "Keep-Alive";
    return requestPage(client, req);
  }

  Future<void> parseStopsFromCsv() async {
    final rawData = await rootBundle.loadString('assets/stops.txt');
    List<List<dynamic>> rowsAsListOfValues = CsvToListConverter().convert(
      rawData,
      eol: '\n',
    );
    int latIndex = rowsAsListOfValues[0].indexOf('stop_lat');
    int lonIndex = rowsAsListOfValues[0].indexOf('stop_lon');

    for (var i = 1; i < rowsAsListOfValues.length; i++) {
      final row = rowsAsListOfValues[i];
      stops.add(LatLng(row[latIndex], row[lonIndex]));
    }
  }

  List<VehiclePosition> parseGtfs(Uint8List byteData) {
    List<VehiclePosition> vehiclePostition = [];
    FeedMessage feedEntities = FeedMessage.fromBuffer(byteData);
    for (var i in feedEntities.entity) {
      vehiclePostition.add(i.vehicle);
    }
    return vehiclePostition;
  }
}
