import 'package:flutter/material.dart';
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
    List<Marker> markers = gtfsdata.stops
        .map(
          (e) => Marker(
            point: LatLng(e.latitude, e.longitude),
            child: const Icon(Icons.directions_bus, color: Colors.blue),
          ),
        )
        .toList();
    List<Marker>? vehiclemarkers;
    if (vehiclePosition != null) {
      vehiclemarkers = vehiclePosition!
          .map(
            (e) => Marker(
              point: LatLng(e.position.latitude, e.position.longitude),
              width: 80,
              height: 80,
              child: const Icon(Icons.bus_alert_rounded, color: Colors.red),
            ),
          )
          .toList();
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Map"), centerTitle: true),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
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
            await gtfsdata.parseStopsFromCsv();
            if (gtfsdata.stops.isNotEmpty) {
              _mapcontroller.move(
                LatLng(gtfsdata.stops[0].latitude, gtfsdata.stops[0].longitude),
                12,
              );
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
          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              markers: markers,
              builder: (context, markers) {
                return SizedBox.shrink();
              },
            ),
          ),
          if (vehiclemarkers != null)
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                markers: vehiclemarkers,
                builder: (context, markers) {
                  return SizedBox.shrink();
                },
              ),
            ),
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
