import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'dart:io';

enum WorkoutType { cycling, running, walking }

// TODO: Transmit logged data.
// Class to be initialized at app start and log all events.
class AppLogger {
  LoggerDevice? userDevice;

  LoggerWorkout workout = LoggerWorkout();
  LoggerEvents loggerEvents = LoggerEvents();


  AppLogger() {
    // Send app launch event when constructor is called (always from home screen).
    LoggerEvent loggedEvent = LoggerEvent(eventType: 0);
    loggedEvent.currentPage = "home_page";
    loggedEvent.processEvent();
    loggerEvents.events.add(loggedEvent);
  }

  // Prepare serializable object for export.
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};

    map['group_id'] = '2'.toString();
    map['name'] = userDevice?.name;
    map['device_id'] = userDevice?.deviceId;
    // map['serial_number'] = userDevice?.serialNumber;
    map['workout'] = workout.toMap();
    map['events'] = loggerEvents.toMap();

    return map;
  }

  // Function to send JSON data to analytics group.
  void insertToDatabase() async {

    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.postUrl(Uri.parse('https://us-east-1.aws.data.mongodb-api.com/app/data-nphof/endpoint/data/v1/action/insertOne'));
    request.headers.set('apiKey', 'e1G2HlcHaZPlJ2NOoFtP3ocZilWoQOoPIdZ8pndoFpECJhoNn7e5684PV0NTZSXg');
    request.headers.contentType = ContentType('application', 'json');

    Map<String, dynamic> body = {
      'dataSource': 'FitnessLog',
      'database': 'FitnessLog',
      'collection': 'Test',
      'document': toMap()
    };

    debugPrint(jsonEncode(body));
    request.write(jsonEncode(body));

    HttpClientResponse response = await request.close();
    String reply = await response.transform(utf8.decoder).join();
    httpClient.close();

    if (response.statusCode == 200) {
      debugPrint(reply);
      // debugPrint(await response.stream.bytesToString());
    }
    else {
      debugPrint(response.reasonPhrase);
    }
  }

  void testInsertToDatabase() async {
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.postUrl(Uri.parse("https://us-east-1.aws.data.mongodb-api.com/app/data-nphof/endpoint/data/v1/action/find"));

    request.headers.contentType = ContentType('application', 'json', charset: 'utf-8');

    request.headers.set("apiKey", "e1G2HlcHaZPlJ2NOoFtP3ocZilWoQOoPIdZ8pndoFpECJhoNn7e5684PV0NTZSXg");
    // request.headers.set("Content-Type", "application/json");

    request.write(jsonEncode(
        {
          "dataSource": "FitnessLog",
          "database": "FitnessLog",
          "collection": "Test",
        }
    ));

    HttpClientResponse response = await request.close();
    String reply = await response.transform(utf8.decoder).join();
    httpClient.close();

    if (response.statusCode == 200) {
      debugPrint(reply);
      //debugPrint(await response.stream.bytesToString());
    }
    else {
      debugPrint(response.statusCode.toString());
      debugPrint(response.reasonPhrase);
    }
  }
}

// Class to gather data during workout.
class LoggerWorkout {
  String workoutType = "";
  LoggerDevice? partnerDevice;
  String? startTimestamp;
  String? endTimestamp;
  LoggerHeartRate loggerHeartRate = LoggerHeartRate();
  LoggerDistance loggerDistance = LoggerDistance();

  String partnerName = "";
  String partnerDeviceId = "";

  // Constructor.
  LoggerWorkout() {
    startTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();;
  }

  // Create a new LoggerWorkoutData object and add it to loggerHeartRate.data.
  void logHeartRate(int heartRate) {
    loggerHeartRate.data.add(LoggerWorkoutData(value: heartRate));
  }

  // Create a new LoggerWorkoutData object and add it to loggerDistance.data.
  void logDistance(int distance) {
    loggerDistance.data.add(LoggerWorkoutData(value: distance));
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};

    map['workout_type'] = workoutType;
    map['start_timestamp'] = startTimestamp;
    map['end_timestamp'] = endTimestamp;
    map['partners'] = [{ // TODO: Multiple partners?
      'name': partnerName,
      'device_id': partnerDeviceId,
    }];
    map['heart_rate'] = loggerHeartRate.toMap();
    map['distance'] = loggerDistance.toMap();

    return map;
  }
}

class LoggerEvents {
  List<LoggerEvent> events = [];

  List<Map<String, dynamic>> toMap() {
    List<Map<String, dynamic>> map = [];
    for (LoggerEvent event in events) {
      map.add(event.toMap());
    }

    return map;
  }

}

// Class for app events.
class LoggerEvent {
  final int eventType;
  String timestamp = "";
  String prevPage = "";
  String nextPage = "";
  String currentPage = "";
  String buttonName = "";
  String workoutType = "";
  String bleDeviceName = "";
  String partnerName = "";
  String partnerDeviceId = "";

  Map<String, dynamic> map = {};


  LoggerEvent({required this.eventType}) {
    // Every event has a timestamp.
    timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();;

    map['event_type'] = eventType;
    map['timestamp'] = timestamp;
  }

  void processEvent() {
    switch (eventType) {
      // App is launched.
      case 0: {
        map['current_page'] = currentPage;
      } break;

      // App is closed.
      case 1: {
        map['current_page'] = currentPage;
      } break;

      // Button is pressed.
      // TODO: Call on every button press :(
      case 2: {
        map['button_name'] = buttonName;
      } break;

      // Page is switched.
    // TODO: Call on every page switch :(
      case 3: {
        map['page_before_switch'] = prevPage;
        map['page_after_switch'] = nextPage;
      } break;

      // Setting is changed.
      case 4: {
        // TODO: Log what setting, the previous and current value. Examples are a metric change for heart rate, change in displayed metric on the screen, change profile type, etc.
      } break;

      // Workout is started.
      case 5: {
        map['workout_type'] = workoutType;
      } break;

      // Workout is ended.
      case 6: {
        map['workout_type'] = workoutType;
      } break;

      // Workout is paused. Only records timestamp.
      case 7: {

      } break;

      // Workout is unpaused. Only records timestamp.
      case 8: {

      } break;

      // TODO: Make sure partner_device_id makes sense.
      // Partner is connected.
      case 9: {
        map['partner_name'] = partnerName;
        map['partner_device_id'] = partnerDeviceId;
      } break;

      // Partner is disconnected.
      case 10: {
        map['partner_name'] = partnerName;
        map['partner_device_id'] = partnerDeviceId;
      } break;

      // Bluetooth scan started. Only records timestamp.
      case 11: {

      } break;

      // BLE device connected.
      case 12: {
        map['device_name'] = bleDeviceName;
      } break;

      // BLE device disconnected.
      // TODO: Specs from analytics group should call for device type in separate field.?
      case 13: {
        map['device_name'] = bleDeviceName;
      } break;
    }
  }

  Map<String, dynamic> toMap() {
    return map;
  }
}

// Class for basic info about a user/device.
class LoggerDevice {
  String name = "";
  String deviceId = "";
  String serialNumber = "";
}

// Class to store heart rate data.
class LoggerHeartRate {
  String units = "";
  String maxHeartRate = "";
  List<LoggerWorkoutData> data = [];

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};

    map['units'] = units;
    map['max_heart_rate'] = maxHeartRate;

    List<Map<String, dynamic>> dataMap = [];
    for (LoggerWorkoutData event in data) {
      dataMap.add(event.toMap());
    }
    map['data'] = dataMap;

    return map;
  }
}

// Class to store distance data.
class LoggerDistance {
  String units = "";
  List<LoggerWorkoutData> data = [];

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};

    map['units'] = units;

    List<Map<String, dynamic>> dataMap = [];
    for (LoggerWorkoutData event in data) {
      dataMap.add(event.toMap());
    }
    map['data'] = dataMap;

    return map;
  }
}

// Data object for workout lists
class LoggerWorkoutData {
  final int value;
  String? timestamp;
  
  LoggerWorkoutData({required this.value}) {
    timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};

    map['value'] = value;
    map['timestamp'] = timestamp;

    return map;
  }
}
