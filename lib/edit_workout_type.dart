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

  bool addMetric()
  {
    return true;
  }

  // TODO: allow the metrics being returned here to be draggable except for the add button.
  // upon dragging and reordering the metrics, store the new map on the device.
  List<Widget> getTopBoxMetrics()
  {
    try {
      List<Widget> widgetList = [];

      print("Organized Metrics: $organizedMetrics");

      for (int i = 0; i < organizedMetrics[0]!.length; i++)
      {
        print ("organized metrics $i: ${organizedMetrics[0]![i]}");
        TextButton newButton = TextButton(
          style: ButtonStyle(foregroundColor: MaterialStateProperty.all<Color>(
              const Color(0xFF4F45C2))),
          onPressed: () {},
          child: Text(organizedMetrics[0]![i], style: const TextStyle(color: Colors.white, fontSize: 16)),
        );
        widgetList.add(newButton);
      }

      if (organizedMetrics[0]!.length < 4)
      {
        IconButton addButton = IconButton(
            iconSize: 25,
            icon: const Icon(Icons.add),
            onPressed: () {
              addMetric();
            }
        );
        widgetList.add(addButton);
      }
      return widgetList;
    }
    catch (e)
    {
      print('exception: ${e.toString()}');
      return [const Center(child: CircularProgressIndicator())];
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

  @override
  void initState() {
    _getCurrentLocation();
    loadMetrics();
    print(organizedMetrics);
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
            Padding(
              padding: EdgeInsets.fromLTRB(0, screenHeight * .015, 0, 0),
              child: SizedBox(
                height: screenHeight * 0.12,
                width: screenWidth * 0.95,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFF4F45C2), borderRadius: BorderRadius.circular(20.0)),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      //crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                            children:
                            getTopBoxMetrics()
                        ),
                      ]
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
