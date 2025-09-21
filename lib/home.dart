import 'package:flutter/material.dart' hide Route;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
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
  LatLng? selected;

  List<Stops>? stops;
  List<Route>? routes;
  List<StopTimes>? stoptimes;
  List<Trips>? trips;

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
    // List<Marker>? vehiclemarkers;
    // if (vehiclePosition != null) {
    //   vehiclemarkers = vehiclePosition!
    //       .map(
    //         (e) => Marker(
    //           point: LatLng(e.position.latitude, e.position.longitude),
    //           width: 80,
    //           height: 80,
    //           child: const Icon(Icons.bus_alert_rounded, color: Colors.red),
    //         ),
    //       )
    //       .toList();
    // }
    //
    return Scaffold(
      appBar: AppBar(title: const Text("Map"), centerTitle: true),
      floatingActionButton: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'searchButton',
            onPressed: () async {
              selected = await showSearch<LatLng>(
                context: context,
                delegate: SearchItem(vehiclePosition!, stops!),
              );
              setState(() {
                _mapcontroller.move(selected!, 12);
              });
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
            onPressed: _getGtfsData,
            child: const Icon(Icons.refresh),
          ),
          FloatingActionButton(
            onPressed: () {
              setState(() {
                points = [];
                tapPostion = [];
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
            // stops = await gtfsdata.loadStopsFromDb();
            print(stops);
            routes = await gtfsdata.loadRoutesFromDb();
            stoptimes = await gtfsdata.loadStopTimesFromDb();
            trips = await gtfsdata.loadTripsFromDb();
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
          if (markers != null)
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                markers: markers,
                builder: (context, markers) {
                  return SizedBox.shrink();
                },
              ),
            ),
          // if (vehiclemarkers != null)
          //   MarkerClusterLayerWidget(
          //     options: MarkerClusterLayerOptions(
          //       markers: vehiclemarkers,
          //       builder: (cont, markers) {
          //         return SizedBox.shrink();
          //       },
          //     ),
          //   ),
          MarkerLayer(
            markers: [
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
                  point: selected!,
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

class SearchItem extends SearchDelegate<LatLng> {
  List<VehiclePosition> vehiclePosition;
  List<Stops> stops;
  SearchItem(this.vehiclePosition, this.stops);

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
      return e.vehicle.id.contains(query);
    }).toList();

    return ListView.builder(
      itemCount: matchPosition.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            close(
              context,
              LatLng(
                matchPosition[index].position.latitude,
                matchPosition[index].position.longitude,
              ),
            );
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
                  Text("Vehicle Label: ${matchPosition[index].timestamp}"),
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
