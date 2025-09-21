import 'dart:async';

import 'package:dumb_and_dumber/dumb_and_dumber.dart';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';

class Level extends World with HasGameRef<DumbandDumber> {
  late TiledComponent level;

  @override
  FutureOr<void> onLoad() async {
    level = await TiledComponent.load('level-01.tmx', Vector2.all(16));
    add(level);
    super.onLoad();
  }
}
