import 'package:dumb_and_dumber/Levels/level.dart';
import 'package:dumb_and_dumber/Levels/level_00_yard.dart';
import 'package:dumb_and_dumber/Levels/level_e1_road.dart';
import 'package:dumb_and_dumber/Levels/level_ending.dart';
import 'package:dumb_and_dumber/Levels/level_h1_registry.dart';
import 'package:dumb_and_dumber/Levels/level_hv1_gate.dart';
import 'package:dumb_and_dumber/characters/player.dart';
import 'package:dumb_and_dumber/dumb_and_dumber.dart';
import 'package:dumb_and_dumber/state/game_state.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boots the real game against the real assets. Anything that throws during
/// a level's build() or its opening script beats fails here rather than on a
/// device.
Future<DumbandDumber> boot(WidgetTester tester) async {
  final game = DumbandDumber(
    onShowMainMenu: () {},
    onPauseGame: () {},
    onResumeGame: () {},
    playerName: 'Sakamoto',
  );
  // Image decoding is real async work, which the fake-async zone a widget
  // test runs in will not resolve. Warming the cache here means the game's
  // own onLoad finds everything already loaded.
  await tester.runAsync(() => game.images.loadAll(DumbandDumber.spriteAssets));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: GameWidget(game: game)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 32));
  return game;
}

Future<void> run(WidgetTester tester, {int frames = 60}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Plays the game the way a very obedient player would: reads the prompt,
/// does what it says, taps through every line, always picks the first option.
Future<void> autoplay(
  WidgetTester tester,
  DumbandDumber game, {
  required int frames,
  bool Function()? until,
}) async {
  for (var i = 0; i < frames; i++) {
    if (until != null && until()) return;

    final dialogue = game.dialogue;
    if (dialogue.isActive) {
      // First press finishes the reveal, second advances; choices take 1.
      dialogue.advance();
      dialogue.advance();
      dialogue.pick(0);
    } else {
      final player = game.level?.player;
      final prompt = game.hud.prompt.text ?? '';
      if (player != null && !player.dead) {
        if (prompt.contains('GUARD')) {
          player.guardDown();
        } else {
          player.guardUp();
          // Swing on the prompt, and throughout any boss bar — a real
          // player does not need to be told twice.
          if (prompt.contains('ATTACK') ||
              prompt.contains('ATK') ||
              game.hud.bossBar.visible) {
            player.attackDown();
            player.attackUp();
          }
          // Walk right; the level clamps and the physics resolve it.
          player.position.x += 3;
        }
      }
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('the game boots into the prologue', (tester) async {
    final game = await boot(tester);
    await run(tester);

    expect(game.level, isA<YardLevel>());
    expect(game.level!.player.isMounted, isTrue);
    expect(game.state.currentLevel, LevelId.yard);
    // The yard is one flat screen with a floor at the doc's y=400.
    expect(game.level!.platforms, isNotEmpty);
    expect(game.level!.cameraFollows, isFalse);
  });

  testWidgets('the prologue opens on dialogue and the box takes input', (
    tester,
  ) async {
    final game = await boot(tester);
    await run(tester, frames: 90);

    expect(game.dialogue.isActive, isTrue, reason: 'the argument should start');

    // Tapping through the argument reaches the movement prompt.
    for (var i = 0; i < 12 && game.dialogue.isActive; i++) {
      game.dialogue.advance();
      game.dialogue.advance();
      await run(tester, frames: 6);
    }
    expect(game.dialogue.isActive, isFalse);
    await run(tester, frames: 4);
    expect(game.hud.prompt.text, isNotNull);
  });

  testWidgets('the player falls onto the ground plane and stays there', (
    tester,
  ) async {
    final game = await boot(tester);
    await run(tester, frames: 120);

    final player = game.level!.player;
    expect(player.onGround, isTrue);
    expect(player.body.bottom, closeTo(GameLevel.groundY, 1.0));
  });

  testWidgets('a single jump clears the woodpile', (tester) async {
    final game = await boot(tester);
    await run(tester, frames: 120);
    final player = game.level!.player;

    // The prologue's jump prompt is only fair if the prop it points at is
    // inside a single jump's apex (98px at the doc's numbers).
    expect(
      GameLevel.groundY - YardLevel.woodpileTop,
      lessThan(90),
      reason: 'leave margin under the 98px apex',
    );

    game.dialogue.clear();
    await run(tester, frames: 2);
    game.hud.prompt.hide();

    // Run at it from the left and jump, driving the real keyboard path so
    // the platform resolution gets a say.
    player.position = Vector2(
      380 - Player.hbOffsetX,
      GameLevel.groundY - Player.hbHeight - Player.hbOffsetY,
    );
    const right = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyD,
      logicalKey: LogicalKeyboardKey.keyD,
      timeStamp: Duration.zero,
    );

    var jumped = false;
    for (var i = 0; i < 150; i++) {
      player.onKeyEvent(right, {LogicalKeyboardKey.keyD});
      // Jump once the woodpile's near edge is close enough to matter.
      if (!jumped && player.body.right > 470) {
        player.jump();
        jumped = true;
      }
      await tester.pump(const Duration(milliseconds: 16));
      if (player.body.bottom <= YardLevel.woodpileTop + 1 && player.onGround) {
        break;
      }
    }

    expect(jumped, isTrue);
    expect(
      player.body.bottom,
      closeTo(YardLevel.woodpileTop, 1.0),
      reason: 'Sakamoto should end up standing on top of the woodpile',
    );
  });

  testWidgets('every level builds', (tester) async {
    final game = await boot(tester);
    await run(tester);

    final expected = <LevelId, Matcher>{
      LevelId.road: isA<RoadLevel>(),
      LevelId.registry: isA<RegistryLevel>(),
      LevelId.gate: isA<GateLevel>(),
      LevelId.ending: isA<EndingLevel>(),
    };

    for (final entry in expected.entries) {
      await game.goToLevel(entry.key);
      await run(tester, frames: 45);

      expect(game.level, entry.value, reason: '${entry.key} should mount');
      expect(game.level!.player.isMounted, isTrue);
      expect(game.level!.platforms, isNotEmpty);
      // The HUD is rebuilt per level because each level gets a fresh camera.
      expect(game.hud.isMounted, isTrue);
      expect(game.dialogue.isMounted, isTrue);
    }
  });

  testWidgets('guard drains and refills, and a parry window opens', (
    tester,
  ) async {
    final game = await boot(tester);
    await run(tester, frames: 120);
    final player = game.level!.player;

    // Dialogue owns input at the top of the prologue; clear it first.
    game.dialogue.clear();
    await run(tester, frames: 2);

    player.guardDown();
    await run(tester, frames: 40);
    expect(player.isGuarding, isTrue);
    expect(game.state.guard, lessThan(GameState.maxGuardPips));

    player.guardUp();
    expect(player.isParrying, isTrue, reason: 'releasing opens the window');
    await run(tester, frames: 20);
    expect(player.isParrying, isFalse, reason: 'and it closes again');
  });

  testWidgets('the prologue plays through and hands the run to E1', (
    tester,
  ) async {
    final game = await boot(tester);
    await run(tester, frames: 30);

    // The whole of level 00: the argument, the first slash, guard taught by
    // refusal, the boss, the hesitation, the dying conversation, the ask.
    await autoplay(
      tester,
      game,
      frames: 6000,
      until: () => game.state.currentLevel == LevelId.road,
    );

    expect(
      game.state.currentLevel,
      LevelId.road,
      reason: 'the prologue should end by opening the portal to the road',
    );
    expect(game.level, isA<RoadLevel>());
    expect(game.level!.cameraFollows, isTrue, reason: 'E1 side-scrolls');
  });

  testWidgets('no level throws or stalls under half a minute of play', (
    tester,
  ) async {
    final game = await boot(tester);

    for (final id in [LevelId.road, LevelId.registry, LevelId.gate]) {
      await game.goToLevel(id);
      await run(tester, frames: 30);

      // Thirty seconds of button-mashing through creatures, hazards, doors
      // and boss telegraphs. Any exception in update or render fails here.
      await autoplay(tester, game, frames: 1800);

      expect(game.state.currentLevel, id);
      expect(game.level!.player.isMounted, isTrue);
      expect(game.level!.player.body.left, isNot(isNaN));
    }
  });

  testWidgets('the tally counts kills and contracts separately', (
    tester,
  ) async {
    final game = await boot(tester);
    await game.goToLevel(LevelId.road);
    await run(tester, frames: 45);

    final level = game.level! as RoadLevel;
    expect(level.creatures, isNotEmpty);

    final toad = level.creatures.first;
    toad.takeHit(1);
    await run(tester, frames: 4);
    expect(toad.dying, isTrue);
    expect(game.state.creaturesKilled, 1);
    expect(game.state.contractCount, 0);
  });
}
