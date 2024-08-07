import 'dart:async';
import 'dart:math';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hello_world/ble_manager.dart';
import 'package:hello_world/longpress_button.dart';
import 'package:hello_world/app_logger.dart';
import 'package:hello_world/ble_sensor_device.dart';
import 'package:hello_world/bluetooth_manager.dart';
import 'package:hello_world/settings.dart';

import 'home_screen.dart';

class ActiveWorkout extends StatefulWidget {
  final AppLogger logger;
  final String exerciseType;
  final SettingsStorage settings;

  const ActiveWorkout({
    super.key,
    required this.logger,
    required this.exerciseType,
    required this.settings,
  });

  @override
  State<ActiveWorkout> createState() => _ActiveWorkoutState();
}

class _ActiveWorkoutState extends State<ActiveWorkout> {
  bool _showProgressIndicator = false;
  bool _changeDistance = false;
  bool _displayPercent = false;
  int lastLoggedDistance = 0;
  var rng = Random();
  GoogleMapController? controller;
  Duration duration = Duration();
  Timer? timer;
  double speed = 0.0;
  int? heartrate = 0;
  int? peerHeartRate = 0;
  int? power = 0;
  int? peerPower = 0;
  double distance = 0.0;
  bool pauseWorkout = true;
  bool stopWorkout = false;
  late StreamSubscription peerSubscription;
  StreamSubscription? stateSubscription;
  late List<BleSensorDevice> deviceList;

  bool peerNameConfirmed = false;
  bool peerDeviceConfirmed = false;

  String peerName = "";
  String peerDeviceId = "";

  String? userDevice = "";
  String userName = "";
  String peerInfo = "";

  String distanceUnits = "mi";

  Position? _initialPosition;
  Position? _currentPosition;
  List<LatLng> _points = [];
  Set<Polyline> _polyLines = {};
  late StreamSubscription<Position> _positionStreamSubscription;

  StreamSubscription<List<int>>? subscribeStreamHR;
  StreamSubscription<List<int>>? subscribeStreamPower;

  @override
  void initState() {
    super.initState();
    widget.logger.startWorkout();
    widget.logger.workout?.workoutType = widget.exerciseType;
    deviceList = BleManager.instance.connectedSensors;
    widget.logger.workout?.loggerHeartRate.maxHeartRate = widget.settings.maxHR;
    widget.logger.workout?.loggerPower.ftp = widget.settings.ftp;
    userName = widget.settings.name;
    userDevice = widget.logger.userDevice?.deviceId;
    _getCurrentLocation();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
    ).listen(_onPositionUpdate);
    startTimer();
    debugPrint('Exercise Type = ${widget.exerciseType}');

    // Read data from connected BLE sensors
    if (deviceList.isNotEmpty && pauseWorkout) {
      for (BleSensorDevice device in deviceList) {
        if (device.type == 'HR') {
          subscribeStreamHR = BleManager.flutterReactiveBle.subscribeToCharacteristic(
            QualifiedCharacteristic(
              characteristicId: device.characteristicId,
              serviceId: device.serviceId,
              deviceId: device.deviceId,
            ),
          ).listen((event) {
            setState(() {
              heartrate = event[1];
              BluetoothManager.instance.broadcastString('0: $heartrate');
              widget.logger.workout?.logHeartRate(event[1].toString());
            });
          });
        } else if (device.type == 'POWER') {
          subscribeStreamPower = BleManager.flutterReactiveBle.subscribeToCharacteristic(
            QualifiedCharacteristic(
              characteristicId: device.characteristicId,
              serviceId: device.serviceId,
              deviceId: device.deviceId,
            ),
          ).listen((event) {
            setState(() {
              int temp = event[3] << 8;
              power = event[2] + temp;
              BluetoothManager.instance.broadcastString('1: $power');
              widget.logger.workout?.logHeartRate(event[1].toString());
            });
          });
        }
      }
    }

    // Read data received from partners
    peerSubscription = BluetoothManager.instance.deviceDataStream.listen((event) {
      setState(() {
        int type = int.parse(event.substring(0, 1));
        switch (type) {
          case 0:
            int value = int.parse(event.substring(3));
            peerHeartRate = value;
            break;
          case 1:
            int value = int.parse(event.substring(3));
            peerPower = value;
            break;
          case 2:
            peerName = event.substring(3);
            widget.logger.workout?.partnerName = peerName;
            BluetoothManager.instance.broadcastString('4');
            if (!peerNameConfirmed) {
              BluetoothManager.instance.broadcastString('2: $userName');
            }
            break;
          case 3:
            peerDeviceId = event.substring(3);
            widget.logger.workout?.partnerDeviceId = peerDeviceId;
            BluetoothManager.instance.broadcastString('5');
            if (!peerDeviceConfirmed) {
              BluetoothManager.instance.broadcastString('3: $userDevice');
            }
            break;
          case 4:
            peerNameConfirmed = true;
            break;
          case 5:
            peerDeviceConfirmed = true;
            break;
          default:
        }
      });
    });

    // Broadcast user info to partner.
    if (BluetoothManager.instance.connectedDevices.isNotEmpty) {
      if (!peerNameConfirmed) {
        BluetoothManager.instance.broadcastString('2: $userName');
      }
      if (!peerDeviceConfirmed) {
        BluetoothManager.instance.broadcastString('3: $userDevice');
      }
    }

    stateSubscription = BluetoothManager.instance.reconnectStateSubscription();

    // Get speed update
    Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation))
      .listen((Position position) => setSpeed(position.speed));

    initPlatformState();
  }

  Future<void> initPlatformState() async {
    BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        enableHeadless: true,
        startOnBoot: true,
      ),
      (String taskId) async {
        BackgroundFetch.finish(taskId);
      },
    ).then((int status) {
      // handle success
    }).catchError((e) {
      // handle error
    });
  }

  @override
  void dispose() {
    peerSubscription.cancel();
    subscribeStreamHR?.cancel();
    subscribeStreamPower?.cancel();
    stateSubscription?.cancel();
    _positionStreamSubscription.cancel();
    BackgroundFetch.stop();
    super.dispose();
  }

  void addTime() {
    setState(() {
      final seconds = duration.inSeconds + 1;
      duration = Duration(seconds: seconds);
    });
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) => addTime());
  }

  void setSpeed(double speed) {
    this.speed = speed;
  }

  void _currentLocation() async {
    final GoogleMapController? cntrl = controller;
    Position position = await Geolocator.getCurrentPosition();
    cntrl?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 15.0,
      ),
    ));
  }

  void _getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
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
          points: [LatLng(_initialPosition!.latitude, _initialPosition!.longitude)],
          color: Colors.blue,
          width: 5,
        ));
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
          }
        });
      }
    });
  }

  void _onPositionUpdate(Position newPosition) {
    setState(() {
      _currentPosition = newPosition;
      if (_initialPosition != null) {
        _points.add(LatLng(newPosition.latitude, newPosition.longitude));
        widget.logger.workout?.logDistance(_calculateTotalDistance().toStringAsFixed(2));
        String location = "${newPosition.latitude}/${newPosition.longitude}";
        widget.logger.workout?.logLocation(location);
        widget.logger.workout?.logSpeed(speed.toStringAsFixed(1));
      }
    });
  }

  _onMapCreated(GoogleMapController _controller) {
    setState(() {
      controller = _controller;
    });
  }

  double _calculateTotalDistance() {
    double totalDistance = 0;
    for (int i = 0; i < _points.length - 1; i++) {
      LatLng location1 = _points[i];
      LatLng location2 = _points[i + 1];
      double distanceInMeters = Geolocator.distanceBetween(
        location1.latitude,
        location1.longitude,
        location2.latitude,
        location2.longitude,
      );
      totalDistance += distanceInMeters;
    }
    return totalDistance;
  }

  @override
  Widget build(BuildContext context) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String? hours, minutes, seconds;
    hours = twoDigits(duration.inHours.remainder(60));
    minutes = twoDigits(duration.inMinutes.remainder(60));
    seconds = twoDigits(duration.inSeconds.remainder(60));

    var screenWidth = MediaQuery.of(context).size.width;
    var screenHeight = MediaQuery.of(context).size.height;

    final double pace = _changeDistance
        ? ((duration.inSeconds / _calculateTotalDistance()) * 1000 / 60)
        : ((duration.inSeconds / _calculateTotalDistance()) * 1609 / 60);

    final double distance = _changeDistance
        ? (_calculateTotalDistance() / 1000)
        : (_calculateTotalDistance() / 1609);

    final double speedDisplay = _changeDistance
        ? speed * 1.60934
        : speed;

    final int? maxHR = int.tryParse(widget.settings.maxHR);
    final int? displayHRPercent = _displayPercent
        ? ((heartrate! / maxHR!) * 100).round()
        : heartrate;
    final String heartRateText = _displayPercent ? '%' : 'bpm';

    int logInterval = int.parse(seconds) % 5;
    if (timer!.isActive && logInterval == 0) {
      widget.logger.saveTempLog();
    }

    var statsRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          color: Colors.black,
          child: SizedBox(
            width: screenWidth * .45,
            child: Column(
              children: [
                SizedBox(
                  height: 35,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        userName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: screenWidth * .1,
                        child: const Icon(
                          Icons.heart_broken,
                          size: 30,
                          color: Colors.white60,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (maxHR != null) {
                            setState(() {
                              _displayPercent = !_displayPercent;
                            });
                          }
                        },
                        child: SizedBox(
                          width: screenWidth * .15,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "$displayHRPercent",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 25,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: screenWidth * .1,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            heartRateText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white60,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 45,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: screenWidth * .1,
                        child: const Icon(
                          Icons.electric_bolt_sharp,
                          size: 30,
                          color: Colors.white60,
                        ),
                      ),
                      SizedBox(
                        width: screenWidth * .15,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "$power",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 25,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: screenWidth * .1,
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "W",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white60,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
              ],
            ),
          ),
        )
      ],
    );

    if (BluetoothManager.instance.connectedDevices.isNotEmpty) {
      statsRow.children.add(
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          color: Colors.black,
          child: SizedBox(
            width: screenWidth * .45,
            child: Column(
              children: [
                SizedBox(
                  height: 35,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        peerName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: screenWidth * .1,
                        child: const Icon(
                          Icons.heart_broken,
                          size: 30,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(
                        width: screenWidth * .15,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "$peerHeartRate",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              color: Colors.red.shade200,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: screenWidth * .1,
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "bpm",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 45,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: screenWidth * .1,
                        child: const Icon(
                          Icons.electric_bolt_sharp,
                          size: 30,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(
                        width: screenWidth * .15,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "$peerPower",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              color: Colors.red.shade200,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: screenWidth * .1,
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "W",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Change distance units if needed.
    if (_changeDistance) {
      distanceUnits = 'km';
    } else {
      distanceUnits = 'mi';
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.black87),
        child: Column(
          children: [
            /// Map
            SizedBox(
              height: screenHeight * 0.52,
              width: screenWidth,
              child: _initialPosition == null
                  ? Center(
                      child: Text(
                        'loading map..',
                        style: TextStyle(fontFamily: 'Avenir-Medium', color: Colors.grey[400]),
                      ),
                    )
                  : Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(_initialPosition!.latitude, _initialPosition!.longitude),
                            zoom: 15,
                          ),
                          mapType: MapType.normal,
                          onMapCreated: _onMapCreated,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          gestureRecognizers: Set()..add(Factory<PanGestureRecognizer>(() => PanGestureRecognizer())),
                          polylines: _polyLines,
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(350, 50, 30, 0),
                          child: FloatingActionButton(
                            backgroundColor: Colors.white,
                            onPressed: _currentLocation,
                            child: Icon(Icons.location_on, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
            ),

            /// Top info box
            Padding(
              padding: EdgeInsets.fromLTRB(0, screenHeight * .015, 0, 0),
              child: SizedBox(
                height: screenHeight * 0.12,
                width: screenWidth * 0.95,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20.0)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          /// Duration
                          ElevatedButton(
                            onPressed: () {},
                            style: ButtonStyle(
                              padding: MaterialStateProperty.all(const EdgeInsets.fromLTRB(0, 0, 0, 0)),
                              backgroundColor: MaterialStateProperty.all(Colors.black),
                              overlayColor: MaterialStateProperty.all(Colors.transparent),
                              shape: MaterialStateProperty.all(const CircleBorder()),
                            ),
                            child: SizedBox(
                              height: screenHeight * 0.12,
                              width: (screenWidth * 0.95) / 4,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Duration',
                                      style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w400),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                    ),
                                    Text(
                                      '$minutes:$seconds',
                                      style: const TextStyle(
                                        fontSize: 30,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        height: 1.45,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                    ),
                                    const Text(
                                      'min:s',
                                      style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w400, height: 1.3),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          /// Distance
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _changeDistance = !_changeDistance;
                              });
                            },
                            style: ButtonStyle(
                              padding: MaterialStateProperty.all(const EdgeInsets.fromLTRB(0, 0, 0, 0)),
                              backgroundColor: MaterialStateProperty.all(Colors.black),
                              overlayColor: MaterialStateProperty.all(Colors.transparent),
                              shape: MaterialStateProperty.all(const CircleBorder()),
                            ),
                            child: SizedBox(
                              height: screenHeight * 0.12,
                              width: (screenWidth * 0.95) / 4,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Distance',
                                      style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w400),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      _calculateTotalDistance() < 15 ? "-" : distance.toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontSize: 30,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        height: 1.45,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      distanceUnits,
                                      style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w400, height: 1.3),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          /// Speed
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _changeDistance = !_changeDistance;
                              });
                            },
                            style: ButtonStyle(
                              padding: MaterialStateProperty.all(const EdgeInsets.fromLTRB(0, 0, 0, 0)),
                              backgroundColor: MaterialStateProperty.all(Colors.black),
                              overlayColor: MaterialStateProperty.all(Colors.transparent),
                              shape: MaterialStateProperty.all(const CircleBorder()),
                            ),
                            child: SizedBox(
                              height: screenHeight * 0.12,
                              width: (screenWidth * 0.95) / 4,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Speed',
                                      style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w400),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      _calculateTotalDistance() < 15 ? "-" : (speedDisplay).toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 30,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        height: 1.45,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      '$distanceUnits/hour',
                                      style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w400, height: 1.3),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          /// Pace
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _changeDistance = !_changeDistance;
                              });
                            },
                            style: ButtonStyle(
                              padding: MaterialStateProperty.all(const EdgeInsets.fromLTRB(0, 0, 0, 0)),
                              backgroundColor: MaterialStateProperty.all(Colors.black),
                              overlayColor: MaterialStateProperty.all(Colors.transparent),
                              shape: MaterialStateProperty.all(const CircleBorder()),
                            ),
                            child: SizedBox(
                              height: screenHeight * 0.12,
                              width: (screenWidth * 0.95) / 4,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Pace',
                                      style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w400),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      _calculateTotalDistance() < 15 ? "-" : pace.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 30,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        height: 1.45,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      'min/$distanceUnits',
                                      style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w400, height: 1.3),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: screenHeight * .01),
            statsRow,
            SizedBox(height: screenHeight * .01),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ButtonStyle(
                    overlayColor: MaterialStateProperty.all(Colors.transparent),
                    elevation: MaterialStateProperty.all(0.0),
                    backgroundColor: MaterialStateProperty.all(Colors.transparent.withOpacity(0.0)),
                  ),
                  onPressed: () {
                    setState(() {
                      if (pauseWorkout) {
                        widget.logger.loggerEvents.events.add(LoggerEvent(eventType: "7"));
                        LoggerEvent loggedEvent = LoggerEvent(eventType: "2");
                        loggedEvent.buttonName = "pause_workout";
                        loggedEvent.processEvent();
                        widget.logger.loggerEvents.events.add(loggedEvent);

                        timer?.cancel();
                        pauseWorkout = !pauseWorkout;
                        stopWorkout = !stopWorkout;
                      } else {
                        widget.logger.loggerEvents.events.add(LoggerEvent(eventType: "8"));
                        LoggerEvent loggedEvent = LoggerEvent(eventType: "2");
                        loggedEvent.buttonName = "resume_workout";
                        loggedEvent.processEvent();
                        widget.logger.loggerEvents.events.add(loggedEvent);

                        startTimer();
                        pauseWorkout = !pauseWorkout;
                        stopWorkout = !stopWorkout;
                      }
                    });
                  },
                  child: CircleAvatar(
                    radius: screenHeight * .06,
                    backgroundColor: Colors.orange,
                    child: pauseWorkout
                        ? Icon(Icons.pause, size: screenHeight * .1, color: Colors.white)
                        : Icon(Icons.play_arrow, size: screenHeight * .11, color: Colors.white),
                  ),
                ),
                Visibility(
                  visible: stopWorkout,
                  child: LongPressButton(
                    logger: widget.logger,
                    exerciseType: widget.exerciseType,
                    polylines: _polyLines,
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
