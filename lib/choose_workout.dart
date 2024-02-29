
import 'package:flutter/material.dart';

class ChooseWorkoutTypeScreen extends StatelessWidget {
  const ChooseWorkoutTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
            child: Container(
              color: Colors.black,
              height: screenSize.height + 10,
              width: screenSize.width + 10,
              child: ListView(children: <Widget>[
                  const Text(
                    "CHOOSE",
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    "WORKOUT MODE",
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                    const SizedBox(height: 5),
                    RoundedButton(
                      name: "PairedWorkoutButton",
                      height: 40,
                      color: const Color.fromRGBO(48, 79, 254, 1),
                      onPressed: () => {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ChooseWorkoutScreen(partnerWorkout: true
                          )
                        )
                      },
                      child: const Text(
                        "PAIRED",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 5),
                    RoundedButton(
                      name: "SoloWorkoutButton",
                      height: 40,
                      color: const Color.fromRGBO(48, 79, 254, 1),
                      onPressed: () => {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ChooseWorkoutScreen(partnerWorkout: false)
                          )
                        )
                      },
                      child: const Text(
                      "SOLO",
                      style: TextStyle(color: Colors.white),
                      )
                    ),
                    RoundedButton(
                        name: "BackButton",
                        height: 40,
                        color: const Color.fromRGBO(48, 79, 254, 1),
                        onPressed: () => {
                          Navigator.pop(context)
                        },
                        child: const Text(
                          "Back",
                          style: TextStyle(color: Colors.white),
                        )
                    )
                  ])
            )
      )
    )
  }
}
