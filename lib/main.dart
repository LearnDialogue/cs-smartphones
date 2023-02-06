import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
// import 'package:beacon_broadcast/beacon_broadcast.dart';
// import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.green,
        backgroundColor: Colors.black,
      ),
      home: const MyHomePage(title: 'First Flutter App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  // Obtain FlutterBlue instance.
  final flutterReactiveBle = FlutterReactiveBle();

  // Start BeaconBroadcast instance.
  // BeaconBroadcast beaconBroadcast = BeaconBroadcast();

  //final FlutterBlePeripheral blePeripheral = FlutterBlePeripheral();
//
  //final AdvertiseData advertiseData = AdvertiseData(
  //  serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
  //  manufacturerId: 1234,
  //  manufacturerData: Uint8List.fromList([1, 2, 3, 4, 5, 6]),
  //);
  //final AdvertiseSettings advertiseSettings = AdvertiseSettings(
  //  advertiseMode: AdvertiseMode.advertiseModeBalanced,
  //  txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
  //  timeout: 3000,
  //);
  //final AdvertiseSetParameters advertiseSetParameters = AdvertiseSetParameters(
  //  txPowerLevel: txPowerMedium,
  //);
//
  //Future<void> _toggleAdvertise() async {
  //  if (await blePeripheral.isAdvertising) {
  //    await blePeripheral.stop();
  //  } else {
  //    await blePeripheral.start(advertiseData: advertiseData);
  //  }
  //}
//
  //Future<void> _toggleAdvertiseSet() async {
  //  if (await blePeripheral.isAdvertising) {
  //    await blePeripheral.stop();
  //  } else {
  //    await blePeripheral.start(
  //      advertiseData: advertiseData,
  //      advertiseSetParameters: advertiseSetParameters,
  //    );
  //  }
  //}

  Future<Map<Permission, PermissionStatus>> _getBluetoothPermissions() async {
    // Get permissions.
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();
    return statuses;
  }



  void _floatingActionButtonOnPressed() {
    // Get permissions.
    Future<Map<Permission,
        PermissionStatus>> statuses = _getBluetoothPermissions();

    // Start scanning
    StreamSubscription<DiscoveredDevice> bleScan = flutterReactiveBle
        .scanForDevices(withServices: [],
        scanMode: ScanMode.lowLatency).listen((device) {
      print(device.name);
    });

    showDialog(
      context: context,
      builder: (BuildContext context) =>
          SimpleDialog(
              title: const Text('Connect to a partner'),
              children: <Widget>[
                SimpleDialogOption(
                  onPressed: () {
                    bleScan.cancel();
                    Navigator.pop(context);
                  },
                  child: const Text('Stop scan'),
                ),
              ]
          ),
    );

    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      // appBar: AppBar(
      //   // Here we take the value from the MyHomePage object that was created by
      //   // the App.build method, and use it to set our appbar title.
      //   title: Text(widget.title),
      // ),
      // body: Image.asset('assets/images/map.jpg'),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Container(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          alignment: Alignment.topCenter,
          child: Image.asset(
              'assets/images/map.jpg',
              height: 800,
              fit: BoxFit.fitHeight)
          ,
        ),

      ),
      persistentFooterButtons:
      [FloatingActionButton(
        onPressed: _floatingActionButtonOnPressed,
        tooltip: 'Increment',
        child: const Icon(Icons.bluetooth),
      ),
      FloatingActionButton(
        onPressed: _floatingActionButtonOnPressed,
        tooltip: 'Increment',
        child: const Icon(Icons.play_arrow_sharp),
      )],// This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
