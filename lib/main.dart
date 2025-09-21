import 'package:dumb_and_dumber/game_wrapper.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.fullScreen();
  await Flame.device.setLandscape();
  runApp(GameAppWidget());
}

class GameAppWidget extends StatelessWidget {
  const GameAppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dumb and Dumber',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: GameWrapper(),
    );
  }
}
