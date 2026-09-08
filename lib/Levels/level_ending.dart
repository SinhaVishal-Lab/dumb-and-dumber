import 'dart:math' as math;
import 'dart:ui' hide TextStyle;

import 'package:dumb_and_dumber/Levels/level.dart';
import 'package:dumb_and_dumber/Levels/level_00_yard.dart';
import 'package:dumb_and_dumber/characters/player.dart';
import 'package:dumb_and_dumber/characters/yami.dart';
import 'package:dumb_and_dumber/components/placeholder.dart';
import 'package:dumb_and_dumber/dialogue/dialogue.dart';
import 'package:dumb_and_dumber/state/game_state.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show TextStyle;

/// THE FALL HOME, then §7 — the ending.
///
/// One ending, with a variation. There is no failure ending and no route
/// where Yami stays dead. Four or more contracts kept and the creatures
/// Sakamoto spared are standing at the edge of the yard when he lands.
class EndingLevel extends GameLevel {
  EndingLevel({required super.player}) : super(id: LevelId.ending);

  late final Yami yami;

  @override
  Future<void> build() async {
    levelWidth = GameLevel.viewW;
    cameraFollows = false;

    // The yard again, exactly as it was.
    final sprite = Sprite(game.images.fromCache('level-01.jpg'));
    final imageSize = sprite.srcSize;
    final scale = math.max(
      GameLevel.viewW / imageSize.x,
      GameLevel.viewH / imageSize.y,
    );
    add(
      SpriteComponent(
        sprite: sprite,
        size: imageSize * scale,
        anchor: Anchor.center,
        position: Vector2(GameLevel.viewW / 2, GameLevel.viewH / 2),
        priority: -100,
      ),
    );
    add(
      RectangleComponent(
        size: Vector2(GameLevel.viewW, GameLevel.viewH),
        paint: Paint()..color = const Color(0x33201538),
        priority: -99,
      ),
    );
    ground(0, GameLevel.viewW, color: const Color(0xFF473627));
    add(
      Prop(
        position: Vector2(520, YardLevel.woodpileTop),
        size: Vector2(120, GameLevel.groundY - YardLevel.woodpileTop),
        color: const Color(0xFF6B4A2A),
        label: 'WOODPILE',
        lightText: true,
      ),
    );

    yami = Yami(position: Vector2(700, GameLevel.groundY - Player.feetOffset));
    add(yami);
    yami.lieStill();
    yami.face(false);

    // §7 Four or more contracts kept: the creatures he spared are standing at
    // the edge of the yard. No line of dialogue acknowledges them.
    if (game.state.contractCount >= 4) {
      for (var i = 0; i < game.state.contractCount.clamp(0, 5); i++) {
        add(
          Prop(
            position: Vector2(40.0 + i * 74, 320),
            size: Vector2(60, 80),
            color: const Color(0xFF4E5A45),
            label: 'SPARED',
            lightText: true,
          ),
        );
      }
    } else {
      // Default: the Registrar's bill comes due off-screen — the last shot of
      // the yard has one extra shadow in it, and nobody ever mentions it.
      add(
        Prop(
          position: Vector2(120, 384),
          size: Vector2(150, 16),
          color: const Color(0xCC0A0A0A),
          label: '',
          lightText: true,
        ),
      );
    }

    placePlayer(430);
    setCheckpoint(430);
    player.controlsLocked = true;
  }

  @override
  Future<void> script() async {
    await wait(1.0);
    await say([
      const Line.narration(
        'The drain, the Registry, the shore, the ravine, the pines.',
      ),
      const Line.narration('Then the yard, and the dirt, and the body in it.'),
    ]);

    prompt('PUT IT BACK  —  hold ATK');
    player.controlsLocked = false;
    await waitUntil(() => player.isCharging || player.isAttacking);
    prompt(null);
    player.controlsLocked = true;

    await game.hud.flash.flash(duration: 1.6);
    await wait(0.6);

    yami.idle();
    yami.position = Vector2(700, GameLevel.groundY - Player.feetOffset);
    await wait(1.2);

    // Neither of them says anything about it.
    await say([
      const Line.narration(
        'Yami sits up. Neither of them says anything about it.',
      ),
      const Line.narration('A long time passes in the yard at dusk.'),
    ]);

    await wait(1.0);
    await say([
      const Line('YAMI', 'So.'),
      const Line('SAKAMOTO', 'So.'),
      const Line('YAMI', 'We never actually settled it.'),
    ]);

    yami.taunt();
    await say([
      const Line.narration(
        'He stands up and picks up the sword that killed him.',
      ),
    ]);

    await game.hud.flash.flash(duration: 0.35);
    await _titleCard();
  }

  Future<void> _titleCard() async {
    add(
      RectangleComponent(
        size: Vector2(GameLevel.viewW, GameLevel.viewH),
        paint: Paint()..color = const Color(0xFF12100E),
        priority: 500,
      ),
    );
    add(
      TextComponent(
        text: 'バカとアホ',
        position: Vector2(GameLevel.viewW / 2, 190),
        anchor: Anchor.center,
        priority: 501,
        textRenderer: TextPaint(
          style: const TextStyle(color: Color(0xFFFE9E8F), fontSize: 52),
        ),
      ),
    );
    add(
      TextComponent(
        text: 'THE ARGUMENT WAS NEVER GOING TO BE SETTLED',
        position: Vector2(GameLevel.viewW / 2, 260),
        anchor: Anchor.center,
        priority: 501,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFD8A44A),
            fontSize: 16,
            letterSpacing: 4,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
    add(
      TextComponent(
        text:
            'contracts kept: ${game.state.contractCount}    '
            'creatures killed: ${game.state.creaturesKilled}',
        position: Vector2(GameLevel.viewW / 2, 320),
        anchor: Anchor.center,
        priority: 501,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0x99FFFFFF),
            fontSize: 13,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );

    await wait(4);
    game.onShowMainMenu();
  }

  @override
  void onPlayerFellOut() {
    placePlayer(430);
  }
}
