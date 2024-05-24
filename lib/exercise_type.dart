import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'app_logger.dart';

class ExerciseType extends StatefulWidget {
  final LayerLink link;
  final OverlayEntry overlayEntry;
  final Offset offset;
  final double dialogWidth;
  final double dialogHeight;
  final AppLogger logger;
  final String exerciseType;
  final Function(String) callBack;

  const ExerciseType({Key? key,
    required this.link,
    required this.offset,
    required this.dialogWidth,
    required this.dialogHeight,
    required this.overlayEntry,
    required this.logger,
    required this.callBack,
    required this.exerciseType,
  }) : super(key: key);

  @override
  State<ExerciseType> createState() => _ExerciseTypeState();
}

class _ExerciseTypeState extends State<ExerciseType> {
  Color _inWalkColor = Color.fromRGBO(90, 90, 90, 0.5);
  Color _outWalkColor =Color.fromRGBO(90, 90, 90, 0.5);
  Color _outRunColor = Color.fromRGBO(90, 90, 90, 0.5);
  Color _inRunColor = Color.fromRGBO(90, 90, 90, 0.5);
  Color _outCycleColor = Color.fromRGBO(90, 90, 90, 0.5);
  Color _inCycleColor = Color.fromRGBO(90, 90, 90, 0.5);

  @override
  void initState() {
    super.initState();
    _setColor(widget.exerciseType);
  }

  void _setColor(String type) {
    setState(() {
      _outWalkColor = Color.fromRGBO(90, 90, 90, 0.5);
      _inWalkColor = Color.fromRGBO(90, 90, 90, 0.5);
      _outRunColor = Color.fromRGBO(90, 90, 90, 0.5);
      _inRunColor = Color.fromRGBO(90, 90, 90, 0.5);
      _outCycleColor = Color.fromRGBO(90, 90, 90, 0.5);
      _inCycleColor = Color.fromRGBO(90, 90, 90, 0.5);

      if (type == 'Outdoor Walk')
      {
        _outWalkColor = Colors.green;
      }
      if (type == 'Indoor Walk')
      {
        _inWalkColor = Colors.green;
      }
      else if (type == 'Outdoor Run')
      {
        _outRunColor = Colors.green;
      }
      else if (type == 'Indoor Run')
      {
        _inRunColor = Colors.green;
      }
      else if (type == 'Outdoor Biking')
      {
        _outCycleColor = Colors.green;
      }
      else if (type == 'Indoor Biking')
      {
        _inCycleColor = Colors.green;
      }
    });
  }

  Future<List<Widget>> getWorkoutTypes(BuildContext context) async {
    String appDocumentsDirectory = (await getApplicationDocumentsDirectory()).path;
    Directory pageOrderDir = Directory("$appDocumentsDirectory/pageOrder");

    try {
      return pageOrderDir
          .listSync()
          .map((entry) => entry.path)
          .where((path) => path.endsWith(".json"))
          .map((path) {
        String fileName = path.substring(path.lastIndexOf("/") + 1);

        final String workoutType = fileName.substring(0, fileName.lastIndexOf(".json"));
        String type = '';
        Icon workoutIcon = const Icon(Icons.directions_walk_outlined, size: 50);
        Color workoutColor = _outRunColor;

          switch (workoutType) {
          case "Outdoor Run":
            workoutIcon = const Icon(Icons.directions_run_outlined, size: 50);
            workoutColor = _outRunColor;
            break;
            case "Indoor Run":
            workoutIcon = const Icon(Icons.directions_run_outlined, size: 50);
            workoutColor = _inRunColor;
            break;
          case "Outdoor Walk":
            workoutColor = _outWalkColor;
            break;
          case "Indoor Walk":
            workoutColor = _inWalkColor;
            break;
          case "Outdoor Biking":
            workoutIcon = const Icon(Icons.directions_bike_outlined, size: 50);
            workoutColor = _outCycleColor;
            break;
          case "Indoor Biking":
            workoutIcon = const Icon(Icons.directions_bike_outlined, size: 50);
            workoutColor = _inCycleColor;
            break;
        }

        return Padding(
          padding: const EdgeInsets.only(top: 20), // Add 20 pixels of padding above each button
          child: ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(workoutColor),
              padding: MaterialStateProperty.all(const EdgeInsets.all(20)), // Padding inside the button
              fixedSize: MaterialStateProperty.all<Size>(Size(widget.dialogWidth * .8, widget.dialogHeight * .2)),
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
              ),
            ),
            onPressed: () {
              _setColor(workoutType);

              // this should just be setExerciseType in home_screen.dart
              // I might be wrong though.
              widget.callBack(workoutType);
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Wrap(
                spacing: widget.dialogWidth * .25,
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  workoutIcon,
                  Text(
                    workoutType,
                    style: GoogleFonts.openSans(
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList();
    } catch (e) {
      print(e);
      return [];
    }
  }


  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      offset: widget.offset,
      link: widget.link,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(45.0)),
        color: Colors.black,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            SizedBox(
              width: widget.dialogWidth * 0.9,
              child: Column(
                children: [
                  SizedBox(height: widget.dialogWidth * .12),
                  Flexible(
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        Container(
                          width: double.infinity,
                          height: 600,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(45),
                            color: Colors.black,
                          ),
                          padding: EdgeInsets.fromLTRB(10, 0, 20, 70),
                          child: SingleChildScrollView(
                            child: FutureBuilder<List<Widget>>(
                              future: getWorkoutTypes(context),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return CircularProgressIndicator();
                                } else if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                  return Text('No workout types found.');
                                } else {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: snapshot.data!,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: widget.dialogHeight * 0.15,
              child: Stack(
                children: [
                  Positioned(
                      width: widget.dialogWidth * .12,
                      height: widget.dialogWidth * .12,
                      top: widget.dialogWidth * .05,
                      right: widget.dialogWidth * .05,
                      child: FloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.red,
                          onPressed: () {
                            widget.overlayEntry.remove();
                          },
                          child: Icon(Icons.clear_rounded, size: widget.dialogWidth * .11))),
                  Positioned(
                      top: widget.dialogWidth * .05,
                      left: widget.dialogWidth * .15,
                      height: widget.dialogHeight * .12,
                      width: widget.dialogWidth * .6,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Select exercise type:',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.openSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.7,
                              color: Colors.white),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

