import 'package:flutter/material.dart' hide Route;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:public_transport/parsing/rtgtfs.dart';
import 'package:public_transport/src/generated/gtfs-realtime.pb.dart'
    hide Position;
import 'common_drawer.dart';
import 'location_service.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});
  @override
  HomepageState createState() => HomepageState();
}

class HomepageState extends State<Homepage> {
  final _mapcontroller = MapController();
  Position? personPos;
  List<LatLng> tapPostion = [];
  List<LatLng> points = [];
  GtfsData gtfsdata = GtfsData();
  List<VehiclePosition>? vehiclePosition;
  LocationService locationService = LocationService();
  VehiclePosition? selected;
  LatLng? startSelected;
  LatLng? stopSelected;

  List<Stops>? stops;
  List<Route>? routes;
  List<StopTimes>? stoptimes;
  List<Trips>? trips;
  Map<int, List<Stops>>? routeStops;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _getGtfsData() async {
    try {
      final response = await gtfsdata.fetchGtfs();
      if (response.statusCode == 200) {
        vehiclePosition = gtfsdata.parseGtfs(response.bodyBytes);
        setState(() {});
      } else {
        debugPrint('Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Marker>? markers;
    if (stops != null) {
      markers = stops!
          .map(
            (e) => Marker(
              point: e.position,
              child: const Icon(Icons.directions_bus, color: Colors.blue),
            ),
          )
          .toList();
    }
    return Scaffold(
      appBar: AppBar(title: const Text("Map"), centerTitle: true),
      floatingActionButton: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'start',
            onPressed: () async {
              if (stops != null) {
                startSelected = await showSearch<LatLng>(
                  context: context,
                  delegate: SearchDestination(stops!),
                );
              }
              if (startSelected != null) {
                setState(() {
                  _mapcontroller.move(startSelected!, 12);
                  tapPostion.add(startSelected!);
                });
              }
            },
            child: const Text("Start"),
          ),
          FloatingActionButton(
            heroTag: 'stop',
            onPressed: () async {
              stopSelected = await showSearch<LatLng>(
                context: context,
                delegate: SearchDestination(stops!),
              );
              if (stopSelected != null) {
                setState(() {
                  _mapcontroller.move(stopSelected!, 12);
                  tapPostion.add(stopSelected!);
                });
                if (stops!.length > 1) {
                  List<LatLng> newPoints = await locationService.getShortest(
                    stops!
                        .map(
                          (e) =>
                              LatLng(e.position.latitude, e.position.longitude),
                        )
                        .toList(),
                  );
                  setState(() {
                    points = newPoints;
                  });
                }
              }
            },
            child: const Text("Stop"),
          ),
          FloatingActionButton(
            heroTag: 'searchButton',
            onPressed: () async {
              selected = await showSearch<VehiclePosition>(
                context: context,
                delegate: SearchItem(
                  vehiclePosition!
                      .where(
                        (e) =>
                            e.position.latitude != 0.0 ||
                            e.position.longitude != 0.0,
                      )
                      .toList(),
                ),
              );
              if (selected != null) {
                stops = routeStops![int.parse(selected!.trip.routeId)];
                debugPrint("selected: ${selected!.position}");
                if (stops != null && stops!.length > 1) {
                  List<LatLng> newPoints = await locationService.getShortest(
                    stops!
                        .map(
                          (e) =>
                              LatLng(e.position.latitude, e.position.longitude),
                        )
                        .toList(),
                  );
                  debugPrint("Points: $newPoints");
                  setState(() {
                    points.addAll(newPoints);
                  });
                  debugPrint("updated");
                }
                setState(() {
                  _mapcontroller.move(
                    LatLng(
                      selected!.position.latitude,
                      selected!.position.longitude,
                    ),
                    12,
                  );
                });
              }
            },
            child: const Icon(Icons.search),
          ),
          FloatingActionButton(
            heroTag: 'locationButton',
            onPressed: () async {
              Position newPostion = await locationService.getLocation();
              setState(() {
                personPos = newPostion;
              });
              if (personPos != null) {
                _mapcontroller.move(
                  LatLng(personPos!.latitude, personPos!.longitude),
                  12,
                );
              }
            },
            child: const Icon(Icons.my_location),
          ),
          FloatingActionButton(
            heroTag: 'refreshButton',
            onPressed: () async {
              await _getGtfsData();
              selected = vehiclePosition!.firstWhere((e) {
                debugPrint("${e.vehicle.id} ?= ${selected!.vehicle.id}");
                return e.vehicle.id == selected?.vehicle.id;
              });
              debugPrint("updated selected: ${selected!.position}");
            },
            child: const Icon(Icons.refresh),
          ),
          FloatingActionButton(
            onPressed: () {
              setState(() {
                points = [];
                tapPostion = [];
                stops = [];
                selected = null;
              });
            },
            child: const Icon(Icons.clear),
          ),
        ],
      ),
      drawer: const CommonDrawer(),
      body: FlutterMap(
        mapController: _mapcontroller,
        options: MapOptions(
          onMapReady: () async {
            routeStops = await gtfsdata.getStopsOfRoute();
            // stops = await gtfsdata.parseStopsFromCsv();
            // routes = await gtfsdata.parseRoutesFromCsv();
            // stoptimes = await gtfsdata.parseStopTimesFromCsv();
            // trips = await gtfsdata.parseTripsFromCsv();
            await _getGtfsData();
            if (stops != null) {
              _mapcontroller.move(stops![0].position, 12);
              setState(() {});
            }
          },
          onTap: (postion, latlng) async {
            setState(() {
              tapPostion.add(latlng);
            });
            if (tapPostion.length > 1) {
              List<LatLng> newPoints = await locationService.getShortest(
                tapPostion,
              );
              setState(() {
                points = newPoints;
              });
            }
          },
          initialZoom: 20,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'dev.fleaflet.flutter_map.example',
          ),
          MarkerLayer(
            markers: [
              if (markers != null) ...markers,

              if (personPos != null)
                Marker(
                  point: LatLng(personPos!.latitude, personPos!.longitude),
                  child: const Icon(Icons.person_3, color: Colors.green),
                ),

              if (tapPostion.isNotEmpty)
                for (var i in tapPostion)
                  Marker(
                    point: i,
                    child: const Icon(Icons.location_on, color: Colors.yellow),
                  ),
              if (selected != null)
                Marker(
                  point: LatLng(
                    selected!.position.latitude,
                    selected!.position.longitude,
                  ),
                  child: const Icon(Icons.bus_alert_sharp, color: Colors.red),
                ),
            ],
          ),
          if (points.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 4,
                  color: Colors.blueAccent,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class SearchItem extends SearchDelegate<VehiclePosition> {
  List<VehiclePosition> vehiclePosition;
  SearchItem(this.vehiclePosition);

  @override
  List<Widget>? buildActions(BuildContext context) {
    List<IconButton> button = [];
    button.add(
      IconButton(
        onPressed: () {
          query = "";
        },
        icon: Icon(Icons.clear),
      ),
    );
    return button;
  }

  @override
  Widget buildResults(BuildContext context) {
    List<VehiclePosition> matchPosition = vehiclePosition.where((e) {
      return e.vehicle.id.contains(query.toUpperCase());
    }).toList();

    return ListView.builder(
      itemCount: matchPosition.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            close(context, matchPosition[index]);
          },
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bus ID: ${matchPosition[index].vehicle.id}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text("Trip ID: ${matchPosition[index].trip.tripId}"),
                  Text("Start Time: ${matchPosition[index].trip.startTime}"),
                  Text("Start Date: ${matchPosition[index].trip.startDate}"),
                  Text("Route ID: ${matchPosition[index].trip.routeId}"),
                  Text(
                    "Schedule Relationship: ${matchPosition[index].trip.scheduleRelationship}",
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Position: Latitude: ${matchPosition[index].position.latitude}, Longitude: ${matchPosition[index].position.longitude}",
                  ),
                  Text("Speed: ${matchPosition[index].position.speed} km/h"),
                  SizedBox(height: 12),
                  Text("Timestamp: ${matchPosition[index].timestamp}"),
                  Text("Vehicle Label: ${matchPosition[index].vehicle.label}"),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ListView.builder(
      itemCount: vehiclePosition.length,
      itemBuilder: (context, index) {
        return Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bus ID: ${vehiclePosition[index].vehicle.id}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text("Trip ID: ${vehiclePosition[index].trip.tripId}"),
                Text("Start Time: ${vehiclePosition[index].trip.startTime}"),
                Text("Start Date: ${vehiclePosition[index].trip.startDate}"),
                Text("Route ID: ${vehiclePosition[index].trip.routeId}"),
                Text(
                  "Schedule Relationship: ${vehiclePosition[index].trip.scheduleRelationship}",
                ),
                SizedBox(height: 12),
                Text(
                  "Position: Latitude: ${vehiclePosition[index].position.latitude}, Longitude: ${vehiclePosition[index].position.longitude}",
                ),
                Text("Speed: ${vehiclePosition[index].position.speed} km/h"),
                SizedBox(height: 12),
                Text("Timestamp: ${vehiclePosition[index].timestamp}"),
                Text("Vehicle Label: ${vehiclePosition[index].vehicle.label}"),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return BackButton(
      onPressed: () {
        Navigator.pop(context);
      },
    );
  }
}

class SearchDestination extends SearchDelegate<LatLng> {
  List<Stops> stops;
  SearchDestination(this.stops);

  @override
  List<Widget>? buildActions(BuildContext context) {
    List<IconButton> button = [];
    button.add(
      IconButton(
        onPressed: () {
          query = "";
        },
        icon: Icon(Icons.clear),
      ),
    );
    return button;
  }

  @override
  Widget buildResults(BuildContext context) {
    List<Stops> matchstops = stops.where((e) {
      return e.stopName.contains(query);
    }).toList();

    return ListView.builder(
      itemCount: matchstops.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            close(context, matchstops[index].position);
          },
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stop Code: ${matchstops[index].stopCode}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text("Stop ID: ${matchstops[index].stopId}"),
                  Text(
                    "Position: ${matchstops[index].position.latitude} ${matchstops[index].position.longitude}",
                  ),
                  Text("Stop Name: ${matchstops[index].stopName}"),
                  Text("Zone ID: ${matchstops[index].zoneId}"),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ListView.builder(
      itemCount: stops.length,
      itemBuilder: (context, index) {
        return Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stop Code: ${stops[index].stopCode}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text("Stop ID: ${stops[index].stopId}"),
                Text(
                  "Position: ${stops[index].position.latitude} ${stops[index].position.longitude}",
                ),
                Text("Stop Name: ${stops[index].stopName}"),
                Text("Zone ID: ${stops[index].zoneId}"),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return BackButton(
      onPressed: () {
        Navigator.pop(context);
      },
    );
  }
}
