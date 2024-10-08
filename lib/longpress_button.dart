import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hello_world/workout_database.dart';

import 'app_logger.dart';
import 'completed_workout.dart';

class LongPressButton extends StatefulWidget {
  final AppLogger logger;
  final String exerciseType;
  final Set<Polyline> polylines;

  const LongPressButton({super.key, required this.logger, required this.exerciseType, required this.polylines});

  @override
  _LongPressButtonState createState() => _LongPressButtonState();
}

class _LongPressButtonState extends State<LongPressButton> {
  Timer? _timer;
  double _progress = 0;
  bool _callbackExecuted = false;

  void _startTimer() {
    const interval = const Duration(milliseconds: 10);
    var elapsed = const Duration();
    _callbackExecuted = false;
    _timer = Timer.periodic(interval, (timer) {
      elapsed += interval;
      setState(() {
        _progress = elapsed.inMilliseconds / 1000;
        if (_progress >= 1 && !_callbackExecuted) {
          _callbackExecuted = true;
          _timer?.cancel();
          _timer = null;
          _progress = 0;
          LoggerEvent loggedEvent = LoggerEvent(eventType: "6");
          loggedEvent.workoutType = widget.exerciseType;
          loggedEvent.processEvent();
          widget.logger.loggerEvents.events.add(loggedEvent);

          widget.logger.workout?.endTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

          // Finish creating workout log.
          widget.logger.saveLog();

          // Send logger data to analytics group.
          widget.logger.uploadWorkoutLogs();

          // TODO: grab all information before transitioning to new screen
          String jsonString = jsonEncode(widget.logger.toSave());

          Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => CompletedWorkout(jsonString: jsonString, polylines: widget.polylines,)));
        }
      });
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _progress = 0;
      _callbackExecuted = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;
    var screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTapDown: (_) => _startTimer(),
      onTapCancel: _cancelTimer,
      onTapUp: (_) => _cancelTimer(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: screenHeight * .07,
            height: screenHeight * .07,
            child: CircularProgressIndicator(
              strokeWidth: 6.0,
              color: const Color(0xFF4F45C2),
              value: _progress,
            ),
          ),
          CircleAvatar(
            radius: screenHeight * .03,
            backgroundColor: const Color(0xFF4F45C2),
            child: Icon(
              Icons.stop,
              size: screenHeight * .05,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
