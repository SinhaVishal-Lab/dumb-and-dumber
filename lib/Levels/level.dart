import 'dart:async';

import 'package:dumb_and_dumber/characters/player.dart';
import 'package:dumb_and_dumber/components/ground_component.dart';
import 'package:dumb_and_dumber/dumb_and_dumber.dart';
import 'package:flame/components.dart';

class Level extends World with HasGameReference<DumbandDumber> {
  final String levelName; // reserved for future multi-level support
  final Player player;

  // Fixed camera resolution (matches CameraComponent in DumbandDumber)
  static const double viewW = 1080;
  static const double viewH = 500;

  // Y position of the visible street surface in level-01.jpg.
  // Viewport is 500 px tall; street sits at ≈84 % from top → y ≈ 420.
  static const double groundY = 420;

  // Physics ground is 20 px above the visual street so the character
  // appears to stand on the surface rather than sink into it.
  static const double platformY = groundY - 20; // 400

  Level({required this.levelName, required this.player});

  @override
  FutureOr<void> onLoad() async {
    _spawnPlayer();
    _addGroundCollider();
    return super.onLoad();
  }

  void _spawnPlayer() {
    // Player sprite: 384 × 384 (4 ×).
    // Hitbox sits at (96, 40) with height 320 → hitbox bottom = y + 360.
    // Center horizontally: (1080 − 384) / 2 = 348.
    // Stand on platform: hitbox bottom = position.y + 360 = platformY.
    // Spawn 40 px above so gravity gives a short drop onto the ground.
    player.position = Vector2(
      (viewW - 384) / 2, // 348 — centered
      platformY - 360 - 40, //  — 40 px airborne above platform
    );
    add(player);
  }

  void _addGroundCollider() {
    // Invisible physics strip 20 px above the visual street surface.
    add(
      GroundComponent(
        position: Vector2(0, platformY),
        size: Vector2(viewW, viewH - platformY + 20),
      ),
    );
  }
}
