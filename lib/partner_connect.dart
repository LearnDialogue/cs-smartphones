import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hello_world/app_logger.dart';
import 'package:hello_world/bluetooth_manager.dart';

enum DeviceType { advertiser, browser }

class PartnerConnect extends StatefulWidget {
  final DeviceType deviceType;
  final LayerLink link;
  final Offset offset;
  final double dialogWidth;
  final double dialogHeight;
  final OverlayEntry overlayEntry;
  final AppLogger logger;
  final String myFullName;

  const PartnerConnect({
    super.key,
    required this.deviceType,
    required this.link,
    required this.offset,
    required this.dialogWidth,
    required this.dialogHeight,
    required this.overlayEntry,
    required this.logger,
    required this.myFullName,
  });

  @override
  State<PartnerConnect> createState() => _PartnerConnectState();
}

class _PartnerConnectState extends State<PartnerConnect> {
  List<Device> devices = [];
  NearbyService nearbyService = BluetoothManager.nearbyService;
  late StreamSubscription? subscription;

  bool isInit = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    subscription?.cancel();
    BluetoothManager.instance.startStateSubscription();
    super.dispose();
  }

  String getStateName(SessionState state) {
    switch (state) {
      case SessionState.notConnected:
        return "disconnected";
      case SessionState.connecting:
        return "waiting";
      default:
        return "connected";
    }
  }

  String getButtonStateName(SessionState state) {
    switch (state) {
      case SessionState.notConnected:
        return "Connect";
      case SessionState.connecting:
        return "Connecting";
      default:
        return "Disconnect";
    }
  }

  Color getStateColor(SessionState state) {
    switch (state) {
      case SessionState.notConnected:
        return Colors.white;
      case SessionState.connecting:
        return Colors.yellow;
      default:
        return Colors.green;
    }
  }

  Color getButtonColor(SessionState state) {
    switch (state) {
      case SessionState.notConnected:
        return Colors.white;
      case SessionState.connecting:
        return Colors.yellow;
      default:
        return Colors.red;
    }
  }

  _onTabItemListener(Device device) {
    if (device.state == SessionState.connected) {
      nearbyService.sendMessage(device.deviceId, "Hello world");
    }
  }

  int getItemCount() {
    debugPrint("devices.length: ${devices.length}");
    return devices.length;
  }

  _onButtonClicked(Device device) {
    switch (device.state) {
      case SessionState.notConnected:
        nearbyService.invitePeer(
          deviceID: device.deviceId,
          deviceName: device.deviceName,
        );
        break;
      case SessionState.connected:
        BluetoothManager.instance.connectedDevices.remove(device);
        nearbyService.disconnectPeer(deviceID: device.deviceId);
        break;
      case SessionState.connecting:
        break;
    }
  }

  void init() async {
    String devInfo = '';
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      devInfo = androidInfo.model;
    }
    if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      devInfo = iosInfo.localizedModel;
    }

    // Scan for devices or show connected devices
    // NOTE: for partner devices to stay connected, the devices must always be advertising and browsing
    if (BluetoothManager.instance.connectedDevices.isEmpty) {
      await nearbyService.init(
        serviceType: 'mp-connection',
        deviceName: widget.myFullName.isEmpty
            ? devInfo
            : "${widget.myFullName} ($devInfo)",
        strategy: Strategy.P2P_CLUSTER,
        callback: (isRunning) async {
          if (isRunning) {
            debugPrint("NearbyService is running");
            widget.logger.loggerEvents.events.add(LoggerEvent(eventType: "11"));

            await nearbyService.stopAdvertisingPeer();
            await nearbyService.stopBrowsingForPeers();
            await Future.delayed(Duration(milliseconds: 200));
            nearbyService.startAdvertisingPeer();
            nearbyService.startBrowsingForPeers();
          } else {
            debugPrint("NearbyService is not running");
          }
        },
      );
    } else {
      debugPrint('Connecting devices: ${BluetoothManager.instance.connectedDevices}');
      setState(() {
        devices.addAll(
          BluetoothManager.instance.connectedDevices.values
              .where((d) => d.state == SessionState.connected)
              .toList(),
        );
      });
    }

    // State stream used to get list of scanned devices
    // NOTE: new devices are only found when there is a change in state
    subscription = BluetoothManager.instance.startStateSubscription();
    subscription?.onData((devicesList) {
      debugPrint("<----- Devices ----->");
      debugPrint(devicesList.toString());
      devicesList.forEach((element) {
        debugPrint(
            "deviceId: ${element.deviceId} | deviceName: ${element.deviceName} | state: ${element.state}");
        if (element.state == SessionState.connected &&
            !BluetoothManager.instance.connectedDevices
                .containsKey(element.deviceId)) {
          BluetoothManager.instance.connectedDevices[element.deviceId] = element;
        }
        if (element.state == SessionState.notConnected &&
            BluetoothManager.instance.connectedDevices
                .containsKey(element.deviceId)) {
          BluetoothManager.instance.connectedDevices.remove(element.deviceId);
        }
      });
      setState(() {
        devices.clear();
        devices.addAll(devicesList);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      offset: widget.offset,
      link: widget.link,
      child: Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(45.0)),
        color: Colors.black,
        child: Stack(alignment: Alignment.topCenter, children: [
          SizedBox(
            width: widget.dialogWidth * 0.9,
            child: Column(
              children: [
                SizedBox(
                  height: widget.dialogWidth * .12,
                ), // Margin for ListView
                Flexible(
                  child: ListView.builder(
                    itemCount: getItemCount(),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return Container(
                        margin: EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _onTabItemListener(device),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          device.deviceName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          getStateName(device.state),
                                          style: TextStyle(
                                              color: getStateColor(
                                                  device.state)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _onButtonClicked(device),
                                  child: Container(
                                    margin: EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    padding: EdgeInsets.all(8.0),
                                    height: 35,
                                    width: 100,
                                    color: getButtonColor(device.state),
                                    child: Center(
                                      child: Text(
                                        getButtonStateName(device.state),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 8.0,
                            ),
                            const Divider(
                              height: 1,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
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
                    child: Icon(Icons.clear_rounded,
                        size: widget.dialogWidth * .11),
                  ),
                ),
                Positioned(
                  top: widget.dialogWidth * .05,
                  left: widget.dialogWidth * .15,
                  height: widget.dialogHeight * .12,
                  width: widget.dialogWidth * .6,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: Row(
                      children: [
                        Text(
                          'Searching for partners',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.openSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.7,
                              color: Colors.white),
                        ),
                        Padding(padding: EdgeInsets.only(left: 15.0)),
                        CircularProgressIndicator(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
