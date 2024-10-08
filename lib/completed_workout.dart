import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hello_world/workout_model.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'workout_database.dart';


import 'home_screen.dart';

class CompletedWorkout extends StatefulWidget {
  final String jsonString;
  final Set<Polyline> polylines;
  const CompletedWorkout({super.key, required this.jsonString, required this.polylines});

  @override
  State<CompletedWorkout> createState() => _CompletedWorkoutState();
}

class _CompletedWorkoutState extends State<CompletedWorkout> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String name = '';
  Position? initialPosition;
  GoogleMapController? mapController;
  late Map<String, dynamic> workoutJson;


  @override
  void initState() {
    super.initState();
    workoutJson = jsonDecode(widget.jsonString)['workout'];
    _getInitialLocation();
  }

  _setState() {
    setState(() {

    });
  }

  String _getStartTime() {
    int? seconds = workoutJson['start_timestamp'];
    if (seconds != null) {
      DateTime date = DateTime.fromMillisecondsSinceEpoch((seconds*1000));
      String time = DateFormat.jm().format(date);
      return "$time ${date.month}/${date.day}/${date.year}";
    }
    else {
      return "Date not found";
    }
  }

  String _getDuration() {
    int? start = workoutJson['start_timestamp'];
    int? end = workoutJson['end_timestamp'];
    if (start != null && end != null) {
      int seconds = end - start;
      int hours = seconds~/360;
      int minutes = ((seconds-(hours*360))~/60);
      seconds = seconds - (minutes*60) - (hours*360);
      return "Duration: ${hours}h:${minutes}m:${seconds}s";
    }
    else {
      return "Duration unavailable";
    }
  }

  String _getDistance() {
    if (workoutJson['distance'] != null) {
      return "Distance: ${workoutJson['distance']['data'].last['value']} meters";
    }
    else {
      return "Distance: 0.0 meters";
    }
  }

  String _getPartners() {
    if (workoutJson['partners'] != null) {
      return "Partners: ";
    }
    else {
      return "No partners";
    }
  }

  String _getWorkoutType() {
    return "Workout type: ${workoutJson['workout_type']}";
  }

  _getInitialLocation() async {
    initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high).whenComplete(() => _setState());
  }

  String _getPolylineJson() {
    List<Polyline> polylineList = widget.polylines.toList();
    String polyLineJson = jsonEncode(PolylineList(polylineList).toJson());
    return polyLineJson;
  }


  _onMapCreated(GoogleMapController controller) {
    controller = controller;
  }

  //Dialog for naming workout
  void _showDialog() {
    showDialog(
        context: this.context,
        builder: (BuildContext context) {
          return SimpleDialog(
              backgroundColor: Colors.white,
              children:[ Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text('Workout Name:'),
                      TextFormField(
                        decoration: const InputDecoration(
                          hintText: 'Enter workout name',
                        ),
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                        onChanged: (value) => setState(() {
                          name = value;
                        }),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                String polylineJson = _getPolylineJson();
                                //push to database
                                final workout = Workout(name: name, jsonString: widget.jsonString, polylines: polylineJson);
                                WorkoutDatabase.instance.createWorkout(workout);

                                setState(() {
                                  Navigator.of(context).push(
                                      MaterialPageRoute(builder: (context) => const HomeScreen()));
                                });
                              }
                            },
                            child: const Text('Confirm'),
                          )
                        ],
                      )
                    ],
                  )
              )
          ]
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {

    var screenWidth = MediaQuery.of(context).size.width;
    var screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
        backgroundColor: Colors.grey[850],
        body:
              Container(
                  padding: const EdgeInsets.fromLTRB(0, 75, 0, 0),
                  alignment: Alignment.bottomCenter,
                  color: Colors.grey[850],
                  child: Column(
                      children: [
                        const FittedBox(
                          fit: BoxFit.fitWidth,
                          child: Text(
                              "Workout Complete!",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 45
                              )
                          ),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          width: screenWidth*.8,
                          height: screenHeight*.4,
                          child: initialPosition == null ? Center(child:Text('loading map..', style: TextStyle(fontFamily: 'Avenir-Medium', color: Colors.grey[400]),),) :
                          GoogleMap(
                            initialCameraPosition: CameraPosition(target: LatLng(initialPosition!.latitude, initialPosition!.longitude), zoom: 15),
                            rotateGesturesEnabled: false,
                            zoomGesturesEnabled: false,
                            zoomControlsEnabled: false,
                            tiltGesturesEnabled: false,
                            myLocationButtonEnabled: false,
                            onMapCreated: _onMapCreated,
                            //cameraTargetBounds: ,
                            polylines: widget.polylines,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                            _getStartTime(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 27
                            )
                        ),
                        Text(
                            _getWorkoutType(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 27
                            )
                        ),
                        Text(
                            _getDuration(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 27
                            )
                        ),
                        Text(
                            _getDistance(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 27
                            )
                        ),
                        Text(
                            _getPartners(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 27
                            )
                        ),
                        Padding(
                            padding: const EdgeInsets.fromLTRB(0, 15, 0, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(builder: (context) => const HomeScreen()));
                                  });
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F45C2)),
                                child: const Text('Discard', style: TextStyle(color: Color(0xFFF1F1F1))),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  _showDialog();
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F45C2)),
                                child: const Text('Save', style: TextStyle(color: Color(0xFFF1F1F1))),
                              ),
                            ],
                          ),
                        ),

                      ]
                  )
              ),
    );
  }
}