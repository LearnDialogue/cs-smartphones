import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hello_world/settings_model.dart';
import 'package:hello_world/workout_database.dart';

import 'home_screen.dart';

// Class to pass settings value between pages.
class SettingsStorage {
  String name = "";
  String age = "";
  String maxHR = "";
  String ftp = "";
}

class Settings extends StatefulWidget {
  SettingsStorage settings;
  Settings({super.key, required this.settings});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final hrController = TextEditingController();
  final ftpController = TextEditingController();

  int? profileID;

  @override
  void initState() {
    super.initState();
    _getPreviousSettings();
  }

  Future _getPreviousSettings() async {
    ProfileSettings? previous = await WorkoutDatabase.instance.readSettings();
    if (previous != null) {
      nameController.text = previous.name;
      profileID = previous.id;
      if (previous.age != null) {
        ageController.text = previous.age.toString();
      }
      if (previous.maxHR != null) {
        hrController.text = previous.maxHR.toString();
      }
      if (previous.ftp != null) {
        ftpController.text = previous.ftp.toString();
      }
    }
  }

//these methods allow the values from each textbox's controller to be grabbed.
  String getName() {
    return nameController.text;
  }

  String getAge() {
    return ageController.text;
  }

  String getMaxHR() {
    return hrController.text;
  }

  String getTargetFTP() {
    return ftpController.text;
  }

// This method takes in the user's age as a string and applies the Max HR formula to return a string of the user's max heart rate.
  String calculateMaxHRString(String age) {
    return (208 - (0.7 * int.parse(age))).floor().toString();
  }

  // Not sure if there should also be a method for calculating max FTP. Possible TODO?

  @override
  void deactivate() {
    super.deactivate();
  }

  //saves the current settings to local database
  void _saveSettings() async {
    String name = getName();
    String ageString = getAge();
    int? age = int.tryParse(ageString);
    String maxHRString = getMaxHR();
    int? maxHR = int.tryParse(maxHRString);
    String targetFTPString = getTargetFTP();
    int? ftp = int.tryParse(targetFTPString);
    ProfileSettings settings;
    debugPrint("$name $age $maxHR $ftp");
    if (profileID == null) {
      settings = ProfileSettings(name: name, age: age, maxHR: maxHR, ftp: ftp);
    } else {
      settings = ProfileSettings(
          id: profileID, name: name, age: age, maxHR: maxHR, ftp: ftp);
    }
    ProfileSettings newSettings =
        await WorkoutDatabase.instance.updateSettings(settings);
    profileID = newSettings.id;
    debugPrint(profileID.toString());
    // navigate to home screen
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var screenWidth = MediaQuery.of(context).size.width;
    var screenHeight = MediaQuery.of(context).size.height;
    return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.black,
            body: ListView(children: [
              Padding(padding: EdgeInsets.all(10)),
              Text("Edit Profile",
                  style: TextStyle(fontSize: 25, color: Colors.white),
                  textAlign: TextAlign.center),
              Padding(padding: EdgeInsets.all(5)),
              Container(
                height: screenHeight / 10,
                width: screenWidth / 5,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(width: 2, color: Colors.white)),
                child:
                    FittedBox(child: Icon(Icons.person, color: Colors.white)),
              ),
              Padding(padding: EdgeInsets.all(5)),
              SizedBox(
                  child: Column(
                children: [
                  Align(
                      alignment: Alignment.center,
                      child: Container(
                        child: Text(
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          "Name",
                          textAlign: TextAlign.left,
                        ),
                      )),
                  Padding(padding: EdgeInsets.all(5)),
                  Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                          width: screenWidth / 1.5,
                          child: TextField(
                              onChanged: (value) {
                                widget.settings.name = getName();
                              },
                              // Controller paradigm used to get values from the textboxes.
                              controller: nameController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.grey,
                                hintText: 'Enter name',
                              )))),
                  Padding(padding: EdgeInsets.all(5)),
                  Align(
                      alignment: Alignment.center,
                      child: Container(
                        child: Text(
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          "Age",
                          textAlign: TextAlign.left,
                        ),
                      )),
                  Padding(padding: EdgeInsets.all(5)),
                  Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                          width: screenWidth / 1.5,
                          child: TextField(
                              onChanged: (value) {
                                // Calculate user's max heart rate upon entering of age.
                                hrController.text = calculateMaxHRString(value);
                                widget.settings.maxHR = getMaxHR();
                                widget.settings.age = getAge();
                                widget.settings.ftp = getTargetFTP();
                              },
                              controller: ageController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.grey,
                                hintText: 'Enter age',
                              )))),
                  Padding(padding: EdgeInsets.all(5)),
                  Align(
                      alignment: Alignment.center,
                      child: Container(
                        child: Text(
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          "Max Heart Rate",
                          textAlign: TextAlign.left,
                        ),
                      )),
                  Padding(padding: EdgeInsets.all(5)),
                  Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                          width: screenWidth / 1.5,
                          child: TextField(
                              onChanged: (value) {
                                widget.settings.maxHR = getMaxHR();
                              },
                              onSubmitted: (value) {
                                widget.settings.maxHR = getMaxHR();
                              },
                              controller: hrController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.grey,
                                hintText: 'Enter max HR',
                              )))),
                  Padding(padding: EdgeInsets.all(5)),
                  Align(
                      alignment: Alignment.center,
                      child: Container(
                        child: Text(
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          "Target FTP",
                          textAlign: TextAlign.left,
                        ),
                      )),
                  Padding(padding: EdgeInsets.all(5)),
                  Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                          width: screenWidth / 1.5,
                          child: TextField(
                              onChanged: (value) {
                                widget.settings.ftp = getTargetFTP();
                              },
                              onSubmitted: (value) {
                                widget.settings.ftp = getTargetFTP();
                              },
                              controller: ftpController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.grey,
                                hintText: 'Enter target FTP',
                              )))),
                  Padding(padding: EdgeInsets.all(10)),
                  ElevatedButton(
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all(const Color(0xFF4F45C2)),),
                    onPressed: () {
                      _saveSettings();
                    },
                    child: const Text('Save Settings', style: TextStyle(color: Color(0xFFF1F1F1))),
                  )
                ],
              ))
            ])));
  }
}
