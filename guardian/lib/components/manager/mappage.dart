import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<LatLng> coordinates = [];
  List<Map<String, dynamic>> zones = [];
  String _zoneType = 'restricted';
  TextEditingController latController = TextEditingController();
  TextEditingController longController = TextEditingController();
  TextEditingController zoneNameController = TextEditingController();
  List<Polygon> polygons = [];

  void deleteZone(int index) {
    setState(() {
      zones.removeAt(index);
      polygons.removeAt(index);
    });
  }

  Widget _buildPolygonLayer() {
    // Only create the PolygonLayer if there are polygons to display
    if (polygons.isEmpty && coordinates.isEmpty) {
      return SizedBox.shrink(); // Return empty widget if no polygons
    }

    List<Polygon> allPolygons = List<Polygon>.from(polygons);

    // Add the current in-progress polygon if there are coordinates
    if (coordinates.isNotEmpty) {
      allPolygons.add(
        Polygon(
          points: coordinates,
          color: _zoneType == 'restricted'
              ? Colors.red.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
          borderStrokeWidth: 2.0,
          borderColor: _zoneType == 'restricted'
              ? Colors.red
              : Colors.green,
        ),
      );
    }

    return PolygonLayer(polygons: allPolygons);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MapZones'),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(17.380326, 78.382345),
              minZoom: 6.0,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: coordinates.map(
                      (coordinate) => Marker(
                    point: coordinate,
                    child: Icon(
                      Icons.location_on,
                      color: Colors.blue,
                      size: 30.0,
                    ),
                  ),
                ).toList(),
              ),
              _buildPolygonLayer(), // Use the new method here
            ],
          ),
          DraggableScrollableSheet(
            minChildSize: 0.2,
            maxChildSize: 0.7,
            initialChildSize: 0.5,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black26)],
                ),
                padding: EdgeInsets.all(16.0),
                child: ListView(
                  controller: scrollController,
                  children: [
                    TextField(
                      controller: zoneNameController,
                      decoration: InputDecoration(
                        labelText: 'Zone Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latController,
                            decoration: InputDecoration(
                              labelText: 'Latitude',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: longController,
                            decoration: InputDecoration(
                              labelText: 'Longitude',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => setState(() => _zoneType = 'restricted'),
                          child: Text('Restricted'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _zoneType == 'restricted' ? Colors.red : Colors.grey,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => setState(() => _zoneType = 'throwable'),
                          child: Text('Throwable'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _zoneType == 'throwable' ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            double lat = double.tryParse(latController.text) ?? 0.0;
                            double lon = double.tryParse(longController.text) ?? 0.0;
                            if (lat != 0.0 && lon != 0.0) {
                              setState(() {
                                coordinates.add(LatLng(lat, lon));
                              });
                            }
                          },
                          child: Text('Add Coordinates'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (coordinates.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Please add coordinates before creating a zone')),
                              );
                              return;
                            }
                            if (coordinates.length < 4) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('At least 4 coordinates are required to create a zone')),
                              );
                              return;
                            }
                            setState(() {
                              String zoneName = zoneNameController.text.isEmpty
                                  ? 'Zone ${zones.length + 1}'
                                  : zoneNameController.text;

                              zones.add({
                                'name': zoneName,
                                'coordinates': List.from(coordinates),
                                'type': _zoneType,
                              });

                              polygons.add(
                                Polygon(
                                  points: List.from(coordinates),
                                  color: _zoneType == 'restricted'
                                      ? Colors.red.withOpacity(0.5)
                                      : Colors.green.withOpacity(0.5),
                                  borderStrokeWidth: 3.0,
                                  borderColor: _zoneType == 'restricted'
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              );
                              coordinates.clear();
                              zoneNameController.clear();
                            });
                          },
                          child: Text('Add Zone'),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Added Zones:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: zones.length,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 5),
                          child: ListTile(
                            title: Text(zones[index]['name']),
                            subtitle: Text('Coordinates: ${zones[index]['coordinates'].map((coord) => '(${coord.latitude}, ${coord.longitude})').join(', ')}'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteZone(index),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}