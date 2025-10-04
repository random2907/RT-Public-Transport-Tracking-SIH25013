import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:public_transport/src/generated/gtfs-realtime.pb.dart';
import 'utils.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

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
  factory Route.fromCsv(List<dynamic> route) {
    return Route(
      agencyId: route[0].toString(),
      routeId: route[1] as int,
      routeLongName: route[2].toString(),
      routeShortName: route[3] == '' ? null : route[3].toString(),
      routeType: route[4] as int,
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
  factory Trips.fromCsv(int routeId, List<List<dynamic>> trips) {
    List<int> serviceId = [];
    List<String> tripId = [];
    for (var i in trips) {
      if (routeId == i[0]) {
        serviceId.add((i[1] as int));
        tripId.add(i[2].toString());
      }
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
  factory StopTimes.fromCsv(String tripId, List<List<dynamic>> stopTimes) {
    final dateFormat = DateFormat('HH:mm:ss');
    List<DateTime> arrivalTime = [];
    List<DateTime> departureTime = [];
    List<int> stopId = [];
    List<int> stopSequence = [];
    for (var i in stopTimes) {
      if (tripId == (i[0].toString())) {
        arrivalTime.add(dateFormat.parse(i[1].toString()));
        departureTime.add(dateFormat.parse(i[2].toString()));
        stopId.add((i[3] as int));
        stopSequence.add((i[4] as int));
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
  factory Stops.fromCsv(List<dynamic> stop) {
    return Stops(
      stopCode: stop[0].toString(),
      stopId: stop[1] as int,
      position: LatLng(stop[2], stop[3]),
      stopName: stop[4].toString(),
      zoneId: stop[5] as int,
    );
  }
}

class GtfsData {
  Future<http.Response> fetchGtfs() {
    http.Client client = http.Client();
    const String apiKey = String.fromEnvironment('API_KEY_GTFS');
    final uri =
        Uri.https('delhi.transportstack.in', '/api/dataset/otd/get-file', {
          'agency': 'delhi-buses',
          'category': 'realtime_gtfs',
          'filename': 'VehiclePositions.pb',
        });
    Map<String, String> headers = {'x-api-key': apiKey};
    http.Request req = http.Request("GET", uri);
    req.headers.addAll(headers);
    return requestPage(client, req);
  }

  Future<Map<int, List<Stops>>> getStopsOfRoute() async {
    try {
      final rawData = await rootBundle.loadString('assets/trips.txt');
      List<List<dynamic>> tripsData = CsvToListConverter().convert(
        rawData,
        eol: '\n',
      );

      // Map tripId to routeId
      Map<String, int> tripToRoute = {};
      for (var row in tripsData.sublist(1)) {
        String tripId = row[2];
        int routeId = row[0];
        tripToRoute[tripId] = routeId;
      }

      final stopTimesRawData = await rootBundle.loadString(
        'assets/stop_times.txt',
      );
      List<List<dynamic>> stopTimesData = CsvToListConverter().convert(
        stopTimesRawData,
        eol: '\n',
      );

      // Map routeId to stopIds
      Map<int, Set<int>> routeToStops = {};
      for (var row in stopTimesData.sublist(1)) {
        String tripId = row[0];
        int stopId = row[3];
        int? routeId = tripToRoute[tripId];
        if (routeId != null) {
          routeToStops.putIfAbsent(routeId, () => {}).add(stopId);
        }
      }

      // Load routes data
      Map<int, Route> routes = {};
      final routesData = await rootBundle.loadString('assets/routes.txt');
      List<List<dynamic>> routeAsListOfValues = CsvToListConverter().convert(
        routesData,
        eol: '\n',
      );
      for (var i in routeAsListOfValues.sublist(1)) {
        routes[i[1]] = Route.fromCsv(i);
      }

      // Load stops data
      Map<int, Stops> busStops = {};
      final stopsData = await rootBundle.loadString('assets/stops.txt');
      List<List<dynamic>> rowsAsListOfValues = CsvToListConverter().convert(
        stopsData,
        eol: '\n',
      );
      for (var i in rowsAsListOfValues.sublist(1)) {
        busStops[i[1]] = Stops.fromCsv(i);
      }

      // Map routeId to list of stops
      Map<int, List<Stops>> routesOfStops = {};
      routeToStops.forEach((routeId, stops) {
        routesOfStops[routeId] = stops
            .map((stopId) => busStops[stopId])
            .where((stop) => stop != null)
            .cast<Stops>()
            .toList();
      });

      return routesOfStops;
    } catch (e) {
      print('Error fetching or processing GTFS data: $e');
      return {};
    }
  }

  // Future<Map<int, List<Stops>>> getStopsOfRoute() async {
  //   final rawData = await rootBundle.loadString('assets/trips.txt');
  //   List<List<dynamic>> tripsData = CsvToListConverter().convert(
  //     rawData,
  //     eol: '\n',
  //   );
  //   Map<String, int> tripToRoute = {};
  //   for (var row in tripsData.sublist(1)) {
  //     String tripId = row[2];
  //     int routeId = row[0];
  //     tripToRoute[tripId] = routeId;
  //   }
  //   final stopTimesRawData = await rootBundle.loadString(
  //     'assets/stop_times.txt',
  //   );
  //   List<List<dynamic>> stopTimesData = CsvToListConverter().convert(
  //     stopTimesRawData,
  //     eol: '\n',
  //   );
  //   Map<int, Set<int>> routeToStops = {};
  //   for (var row in stopTimesData.sublist(1)) {
  //     String tripId = row[0];
  //     int stopId = row[3];
  //     int? routeId = tripToRoute[tripId];
  //     if (routeId != null) {
  //       if (!routeToStops.containsKey(routeId)) {
  //         routeToStops[routeId] = {};
  //       }
  //       routeToStops[routeId]!.add(stopId);
  //     }
  //   }
  //   Map<int, Route> routes = {};
  //   final routesData = await rootBundle.loadString('assets/routes.txt');
  //   List<List<dynamic>> routeAsListOfValues = CsvToListConverter().convert(
  //     routesData,
  //     eol: '\n',
  //   );
  //   for (var i in routeAsListOfValues.sublist(1)) {
  //     routes[i[1]] = Route.fromCsv(i);
  //   }
  //
  //   Map<int, Stops> busStops = {};
  //   final stopsData = await rootBundle.loadString('assets/stops.txt');
  //   List<List<dynamic>> rowsAsListOfValues = CsvToListConverter().convert(
  //     stopsData,
  //     eol: '\n',
  //   );
  //   for (var i in rowsAsListOfValues.sublist(1)) {
  //     busStops[i[1]] = Stops.fromCsv(i);
  //   }
  //   Map<int, List<Stops>> routesOfStops = {};
  //
  //   routeToStops.forEach((routeId, stops) {
  //     routesOfStops[routeId] = stops
  //         .map((stopId) => busStops[stopId]) // Map stopId to Stops
  //         .where(
  //           (stop) => stop != null,
  //         )
  //         .cast<Stops>()
  //         .toList();
  //   });
  //
  //   return routesOfStops;
  // }

  // Future<List<Stops>> parseStopsFromCsv() async {
  //   List<Stops> busStops = [];
  //   final rawData = await rootBundle.loadString('assets/stops.txt');
  //   List<List<dynamic>> rowsAsListOfValues = CsvToListConverter().convert(
  //     rawData,
  //     eol: '\n',
  //   );
  //   for (var i in rowsAsListOfValues.sublist(1, rowsAsListOfValues.length)) {
  //     busStops.add(Stops.fromCsv(i));
  //   }
  //   return busStops;
  // }
  //
  // Future<List<Route>> parseRoutesFromCsv() async {
  //   List<Route> routes = [];
  //   final rawData = await rootBundle.loadString('assets/routes.txt');
  //   List<List<dynamic>> rowsAsListOfValues = CsvToListConverter().convert(
  //     rawData,
  //     eol: '\n',
  //   );
  //   for (var i in rowsAsListOfValues.sublist(1)) {
  //     routes.add(Route.fromCsv(i));
  //   }
  //   return routes;
  // }
  //
  // Future<List<StopTimes>> parseStopTimesFromCsv() async {
  //   List<StopTimes> busStopTimes = [];
  //   final rawData = await rootBundle.loadString('assets/stop_times.txt');
  //   List<List<dynamic>> rowsAsListOfValues = CsvToListConverter().convert(
  //     rawData,
  //     eol: '\n',
  //   );
  //   List<List<dynamic>> stopTimesData = rowsAsListOfValues.sublist(1);
  //
  //   Map<String, List<List<dynamic>>> tripIdGroupedData = {};
  //
  //   for (var row in stopTimesData) {
  //     String tripId = row[0].toString();
  //     if (!tripIdGroupedData.containsKey(tripId)) {
  //       tripIdGroupedData[tripId] = [];
  //     }
  //     tripIdGroupedData[tripId]!.add(row);
  //   }
  //
  //   tripIdGroupedData.forEach((tripId, tripRows) {
  //     busStopTimes.add(StopTimes.fromCsv(tripId, tripRows));
  //   });
  //
  //   return busStopTimes;
  // }
  //
  // Future<List<Trips>> parseTripsFromCsv() async {
  //   List<Trips> busTrips = [];
  //   final rawData = await rootBundle.loadString('assets/trips.txt');
  //   List<List<dynamic>> rowsAsListOfValues = CsvToListConverter().convert(
  //     rawData,
  //     eol: '\n',
  //   );
  //   List<List<dynamic>> tripsData = rowsAsListOfValues.sublist(1);
  //
  //   Map<int, List<List<dynamic>>> routeIdGroupedData = {};
  //
  //   for (var row in tripsData) {
  //     int routeId = row[0];
  //     if (!routeIdGroupedData.containsKey(routeId)) {
  //       routeIdGroupedData[routeId] = [];
  //     }
  //     routeIdGroupedData[routeId]!.add(row);
  //   }
  //
  //   routeIdGroupedData.forEach((routeId, routeRows) {
  //     busTrips.add(Trips.fromCsv(routeId, routeRows));
  //   });
  //
  //   return busTrips;
  // }

  List<VehiclePosition> parseGtfs(Uint8List byteData) {
    List<VehiclePosition> vehiclePostition = [];
    FeedMessage feedEntities = FeedMessage.fromBuffer(byteData);
    for (var i in feedEntities.entity) {
      vehiclePostition.add(i.vehicle);
    }
    return vehiclePostition;
  }
}
