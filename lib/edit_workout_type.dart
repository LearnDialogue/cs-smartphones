import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';

class ModifyExerciseType extends StatefulWidget {
  final String exerciseType;

  const ModifyExerciseType({
    Key? key,
    required this.exerciseType,
  }) : super(key: key);

  @override
  _ModifyExerciseTypeState createState() => _ModifyExerciseTypeState();
}

class _ModifyExerciseTypeState extends State<ModifyExerciseType> {

  Position? _initialPosition;
  Position? _currentPosition;
  List<LatLng> _points = [];
  Set<Polyline> _polyLines = {};
  GoogleMapController? controller;

  late Map<int, List<String>> organizedMetrics = {};
  bool isLoading = true;
  String? errorMessage;
  bool addWidget = false;

  // initializes map of int : List<String> that represents the metric UI boxes and the metrics they contain.
  Future<void> loadMetrics() async {
    try {
      String jsonString = await readJsonFile();
      print("json String: $jsonString");

      Map<String, dynamic> decodedJson = json.decode(jsonString);

      Map<String, List<String>> metricsMap = {};
      decodedJson.forEach((key, value) {
        if (value is List<dynamic>) {
          metricsMap[key] = List<String>.from(value);
        }
      });

      setState(() {
        organizedMetrics = metricsMap.map((key, value) => MapEntry(int.parse(key), value));
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        print('error: ${e.toString()}');
        isLoading = false;
      });
    }
  }

  // opens file and gets string that represents json object stored
  Future<String> readJsonFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/pageOrder/${widget.exerciseType}.json');
    return await file.readAsString();
  }

  // Adds the metric to the map and stores in file
  Future<void> updateAfterAdd(String newMetric, int box)
  async {
    organizedMetrics[box]?.add(newMetric);
    if (box == 0)
    {
        if (organizedMetrics[0]!.length >= 4)
        {
            addWidget = false;
        }
    }
    Map<String, List<String>> mapToStore = convertIntKeyToString(organizedMetrics);

    String jsonString = jsonEncode(mapToStore);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/pageOrder/${widget.exerciseType}.json');

    await file.writeAsString(jsonString);
  }

  // Basically, this is called when a widget needs to be added to a box.
  // It checks which metrics are already present, and based on that, the dialog that
  // appears will present the options for metrics to be added.
  Future<void> addMetric(List<String> metrics, int box, BuildContext context)
  async {
    List<String> possibleMetrics = [];
    switch (box)
    {
      case 1:
        possibleMetrics = ["Distance", "Pace", "Speed", "Heart Rate Zone"];
        possibleMetrics.removeWhere((metric) => metrics.contains(metric));
        return showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context){
            return AlertDialog(
              title: const Text("Choose a Metric:", textAlign: TextAlign.center),
              content: SingleChildScrollView(
                child: ListBody(
                  children: [
                    ...possibleMetrics.map((metric) {
                      return TextButton(
                        child: Text(metric),
                        onPressed: () {
                          setState(() {
                            updateAfterAdd(metric, 0);
                            Navigator.of(context).pop();
                          });
                        },
                      );
                    }).toList(),
                    TextButton(
                      child: const Text("Exit"),
                      onPressed: () {
                        setState(() {
                          Navigator.of(context).pop();
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }
        );
      case 2:
        possibleMetrics = ["Heart Rate", "Power"];
        break;
      case 3:
        possibleMetrics = ["Peer Heart Rate", "Peer Power"];
        break;
    }
  }

  // this deletes the metric from the files
  Future<void> handleDelete(String metric, int box)
  async {
      organizedMetrics[box]?.remove(metric);
      Map<String, List<String>> mapToStore = convertIntKeyToString(organizedMetrics);

      String jsonString = jsonEncode(mapToStore);

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/pageOrder/${widget.exerciseType}.json');

      await file.writeAsString(jsonString);
  }

  Future<void> showDeleteDialog(BuildContext context, String metric, int box)
  {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete $metric?"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextButton(
                  child: const Text("Yes"),
                  onPressed: () {
                    setState(() {
                      handleDelete(metric, box);
                      Navigator.of(context).pop();
                    });
                  }
                ),
                TextButton(
                  child: const Text("No"),
                  onPressed: () {
                    setState(() {
                      Navigator.of(context).pop();
                    });
                  }
                )
              ]
            )
          )
        );
      }
    );
  }

  List<Widget> getTopBoxMetrics()
  {
    if (isLoading) {
      return [const Center(key: ValueKey('loading'), child: CircularProgressIndicator())];
    }

    try {
      List<Widget> widgetList = [];

      for (int i = 0; i < organizedMetrics[0]!.length; i++)
      {
        TextButton newButton = TextButton(
          key: ValueKey('top-box-metric-$i'),
          style: ButtonStyle(
            foregroundColor: MaterialStateProperty.all<Color>(const Color(0xFF4F45C2)),
            backgroundColor: MaterialStateProperty.all<Color>(const Color(0xFF4F45C2)),
            overlayColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                // This will prevent any color change on press or long-press
                if (states.contains(MaterialState.pressed)) {
                  return Colors.transparent; // Set to transparent to disable overlay color
                }
                return null; // Use default overlay color
              },
            ),
          ),
          onPressed: () {
              showDeleteDialog(context, organizedMetrics[0]![i], 0);
          },
          child: Text(organizedMetrics[0]![i], style: const TextStyle(color: Colors.white, fontSize: 16)),
        );
        widgetList.add(newButton);
      }

      if (organizedMetrics[0]!.length < 4)
      {
        addWidget = true;
      }

      return widgetList;
    }
    catch (e)
    {
      print('exception: ${e.toString()}');
      return [const Center(key: ValueKey('loading'), child: CircularProgressIndicator())];
    }
  }

  // if the map is created, initialize the controller.
  _onMapCreated(GoogleMapController _controller) {
    setState(() {
      controller = _controller;
    });
  }

  void _currentLocation() async {
    final GoogleMapController? cntrl = controller;
    Position position = await Geolocator.getCurrentPosition();
    cntrl!.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 15.0,
      ),
    ));
  }

  void _getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _initialPosition = position;
      _currentPosition = position;
      _points.add(LatLng(position.latitude, position.longitude));

      if (controller != null) {
        controller!.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ));

        _polyLines.add(Polyline(
          polylineId: const PolylineId('userRoute'),
          visible: true,
          points: [
            LatLng(_initialPosition!.latitude, _initialPosition!.longitude)
          ],
          color: Colors.blue,
          width: 5,));
      }
    });
    _listenToLocationChanges();
  }

  void _listenToLocationChanges() {
    Geolocator.getPositionStream().listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _points.add(LatLng(position.latitude, position.longitude));
          _polyLines.add(Polyline(
            polylineId: PolylineId("workout_route"),
            color: Colors.blue,
            width: 5,
            points: _points,
          ));

          if (controller != null) {
            controller!.animateCamera(CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 15,
              ),
            ));
          }});
      }
    });
  }

  Map<String, List<String>> convertIntKeyToString(Map<int, List<String>> originalMap)
  {
    return originalMap.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<void> updateMyTopItems(int oldIndex, int newIndex)
  async {

    if (isLoading) {
      return;
    }

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = organizedMetrics[0]!.removeAt(oldIndex);
      organizedMetrics[0]!.insert(newIndex, item);
    });

    if (!organizedMetrics.isEmpty)
    {
      Map<String, List<String>> mapToStore = convertIntKeyToString(organizedMetrics);
      String jsonString = jsonEncode(mapToStore);

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/pageOrder/${widget.exerciseType}.json');

      await file.writeAsString(jsonString);
    }
  }

  @override
  void initState() {
    _getCurrentLocation();
    loadMetrics();
    super.initState();

    // Initialize any necessary state or start loading data here.
  }

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    var screenHeight = MediaQuery
        .of(context)
        .size
        .height;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Color(0xFF4F45C2),
          size: 25, //change your color here
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        title: Text('Edit Workout Type: \n${widget.exerciseType}', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
      ),
      body: Center(
          child: Column(
              children: [

                /// Map
                SizedBox(
                  height: screenHeight * 0.45,
                  width: screenWidth,
                  child:
                  _initialPosition == null ? Center(child:Text('loading map..', style: TextStyle(fontFamily: 'Avenir-Medium', color: Colors.grey[400]),),) :
                  Stack(
                    children: [
                      GoogleMap(
                          initialCameraPosition: CameraPosition(target: LatLng(_initialPosition!.latitude, _initialPosition!.longitude), zoom: 15),
                          mapType: MapType.normal,
                          onMapCreated: _onMapCreated,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          gestureRecognizers: Set()
                            ..add(Factory<PanGestureRecognizer>(() => PanGestureRecognizer())),
                          polylines: _polyLines

                      ),
                      Padding(
                          padding: EdgeInsets.fromLTRB(350, 50, 30, 0),
                          child: FloatingActionButton(
                            backgroundColor: Colors.transparent,
                            onPressed: _currentLocation,
                            child: const Icon(Icons.location_on, color: Color(0xFF4F45C2)),
                          )
                      ),
                    ],
                  ),
                ),

                // this is the top box edit screen
                Padding(
                  padding: EdgeInsets.fromLTRB(0, screenHeight * .015, 0, 0),
                  child: SizedBox(
                    height: screenHeight * 0.12,
                    width: screenWidth * 0.95,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF4F45C2),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Row(
                        children: [
                          // Expanded widget for the ReorderableListView to take available space
                          Expanded(
                            child: ReorderableListView(
                              scrollDirection: Axis.horizontal,
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  updateMyTopItems(oldIndex, newIndex);
                                });
                              },
                              proxyDecorator: (Widget child, int index, Animation<double> animation) {
                                return Material(
                                  color: Colors.transparent,
                                  child: child,
                                );
                              },
                              children: getTopBoxMetrics(),
                            ),
                          ),
                          // Add your new widget here
                          if (addWidget)
                            IconButton(
                              iconSize: 40,
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  addMetric(organizedMetrics[0]!, 1, context);
                                });
                              }
                            )
                        ],
                      ),
                    ),
                  ),
                ),
              ]
          )
      ),
    );
  }
}