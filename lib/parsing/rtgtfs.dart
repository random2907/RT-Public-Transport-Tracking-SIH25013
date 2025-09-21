import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:public_transport/src/generated/gtfs-realtime.pb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'utils.dart';
import 'package:intl/intl.dart';

class GTFSDatabase {
  static Database? _database;
  static final String _dbName = "gtfs.db";

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = documentsDirectory.path;

    if (!path.endsWith(Platform.pathSeparator)) {
      path += Platform.pathSeparator;
    }
    path += _dbName;

    bool exists = await databaseExists(path);

    if (!exists) {
      ByteData data = await rootBundle.load('assets/$_dbName');
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await File(path).writeAsBytes(bytes, flush: true);
    }

    return await openDatabase(path);
  }
}

class Route {
  final String agencyId;
  final int routeId;
  final String routeLongName;
  final String? routeShortName;
  final int routeType;
  const Route({
    required this.agencyId,
    required this.routeId,
    required this.routeLongName,
    this.routeShortName,
    required this.routeType,
  });
  factory Route.fromMap(Map<String, dynamic> map) {
    return Route(
      agencyId: map['agency_id'],
      routeId: map['route_id'],
      routeLongName: map['route_long_name'],
      routeShortName: map['route_short_name'],
      routeType: map['route_type'],
    );
  }
}

class Trips {
  final int routeId;
  final List<int> serviceId;
  final List<String> tripId;
  const Trips({
    required this.routeId,
    required this.serviceId,
    required this.tripId,
  });
  factory Trips.fromDb(int routeId, List<Map<String, dynamic>> trips) {
    List<int> serviceId = [];
    List<String> tripId = [];
    for (var i in trips) {
      serviceId.add(i['service_id']);
      tripId.add(i['trip_id']);
    }
    return Trips(routeId: routeId, serviceId: serviceId, tripId: tripId);
  }
}

class StopTimes {
  final String tripId;
  final List<DateTime> arrivalTime;
  final List<DateTime> departureTime;
  final List<int> stopId;
  final List<int> stopSequence;
  const StopTimes({
    required this.tripId,
    required this.arrivalTime,
    required this.departureTime,
    required this.stopId,
    required this.stopSequence,
  });
  factory StopTimes.fromDb(
    String tripId,
    List<Map<String, dynamic>> stopTimes,
  ) {
    final dateFormat = DateFormat('HH:mm:ss');
    List<DateTime> arrivalTime = [];
    List<DateTime> departureTime = [];
    List<int> stopId = [];
    List<int> stopSequence = [];
    for (var i in stopTimes) {
      if (tripId == i['trip_id']) {
        arrivalTime.add(dateFormat.parse(i['arrival_time']));
        departureTime.add(dateFormat.parse(i['departure_time']));
        stopId.add(i['stop_id']);
        stopSequence.add(i['stop_sequence']);
      }
    }
    return StopTimes(
      tripId: tripId,
      arrivalTime: arrivalTime,
      departureTime: departureTime,
      stopId: stopId,
      stopSequence: stopSequence,
    );
  }
}

class Stops {
  final String stopCode;
  final int stopId;
  final LatLng position;
  final String stopName;
  final int zoneId;
  const Stops({
    required this.stopCode,
    required this.stopId,
    required this.position,
    required this.stopName,
    required this.zoneId,
  });
  factory Stops.fromMap(Map<String, dynamic> map) {
    return Stops(
      stopCode: map['stop_code'],
      stopId: map['stop_id'],
      position: LatLng(map['stop_lat'], map['stop_lon']),
      stopName: map['stop_name'],
      zoneId: map['zone_id'],
    );
  }
}

class GtfsData {
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

  Future<List<Stops>> loadStopsFromDb() async {
    Database db = await GTFSDatabase().database;
    print("hi");
    await compressDatabase(db);
    print("bye");
    List<Map<String, dynamic>> maps = await db.query('stops');
    print("stops: $maps");

    return List.generate(maps.length, (i) {
      return Stops.fromMap(maps[i]);
    });
  }

  Future<List<Route>> loadRoutesFromDb() async {
    Database db = await GTFSDatabase().database;
    await compressDatabase(db);
    List<Map<String, dynamic>> maps = await db.query('routes');

    return List.generate(maps.length, (i) {
      return Route.fromMap(maps[i]);
    });
  }

  Future<List<StopTimes>> loadStopTimesFromDb() async {
    List<StopTimes> busStopTimes = [];
    Database db = await GTFSDatabase().database;
    await compressDatabase(db);
    List<Map<String, dynamic>> result = await db.query('stop_times');

    Map<String, List<Map<String, dynamic>>> tripIdGroupedData = {};

    for (var row in result) {
      String tripId = row['trip_id'];
      if (!tripIdGroupedData.containsKey(tripId)) {
        tripIdGroupedData[tripId] = [];
      }
      tripIdGroupedData[tripId]!.add(row);
    }

    tripIdGroupedData.forEach((tripId, tripRows) {
      busStopTimes.add(StopTimes.fromDb(tripId, tripRows));
    });

    return busStopTimes;
  }

  Future<List<Trips>> loadTripsFromDb() async {
    List<Trips> busTrips = [];
    Database db = await GTFSDatabase().database;
    await compressDatabase(db);
    List<Map<String, dynamic>> result = await db.query('trips');

    Map<int, List<Map<String, dynamic>>> routeIdGroupedData = {};

    for (var row in result) {
      int routeId = row['route_id'];
      if (!routeIdGroupedData.containsKey(routeId)) {
        routeIdGroupedData[routeId] = [];
      }
      routeIdGroupedData[routeId]!.add(row);
    }

    routeIdGroupedData.forEach((routeId, routeRows) {
      busTrips.add(Trips.fromDb(routeId, routeRows));
    });

    return busTrips;
  }

  List<VehiclePosition> parseGtfs(Uint8List byteData) {
    List<VehiclePosition> vehiclePostition = [];
    FeedMessage feedEntities = FeedMessage.fromBuffer(byteData);
    for (var i in feedEntities.entity) {
      vehiclePostition.add(i.vehicle);
    }
    return vehiclePostition;
  }

  Future<void> runVacuumOnce(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    bool vacuumDone = prefs.getBool('vacuum_done') ?? false;

    if (!vacuumDone) {
      await compressDatabase(db);
      await prefs.setBool('vacuum_done', true);
    }
  }

  Future<void> compressDatabase(Database db) async {
    await db.execute('VACUUM;');
  }
}
