import 'dart:ui' hide TextStyle;

import 'package:dumb_and_dumber/Levels/level.dart';
import 'package:dumb_and_dumber/characters/bosses.dart';
import 'package:dumb_and_dumber/characters/enemy.dart';
import 'package:dumb_and_dumber/components/placeholder.dart';
import 'package:dumb_and_dumber/dialogue/dialogue.dart';
import 'package:dumb_and_dumber/state/game_state.dart';
import 'package:flame/components.dart';

/// H1 · THE REGISTRY — Hell · arenas.
///
/// Hell is not a journey, it is a series of rooms that lock behind you. Each
/// arena is a single screen at the build's fixed resolution: doors seal,
/// waves spawn, doors open. The whole rhythm is fight, breathe, walk twenty
/// steps, fight.
class RegistryLevel extends GameLevel {
  RegistryLevel({required super.player}) : super(id: LevelId.registry);

  static const double arenaWidth = GameLevel.viewW;
  static const List<double> arenaX = [0, 1080, 2160];
  static const double bossX = 3240;

  late final RegistrarBoss registrar;

  final List<Platform> _doors = [];
  bool _bossFightRunning = false;
  bool _questionAsked = false;

  @override
  Future<void> build() async {
    levelWidth = 4600;
    cameraFollows = true;

    add(
      PlaceholderParallax(
        sky: const Color(0xFF2A0F0C),
        mid: const Color(0xFF6B1D12),
        near: const Color(0xFF1A1110),
        size: Vector2(levelWidth, levelHeight),
        caption:
            'PARALLAX — fire ceiling / ash haze / the silhouette of the growl',
      ),
    );

    // Black sand and basalt, all the way through.
    ground(0, levelWidth, color: const Color(0xFF1E1A18));

    // Arena 2: a river of souls runs downhill through the room. Touching it
    // does not kill — it grabs Sakamoto and drops him back at the entrance.
    add(
      SoulRiver(
        position: Vector2(arenaX[1] + 380, GameLevel.groundY - 18),
        size: Vector2(360, 40),
      ),
    );
    trigger(
      arenaX[1] + 380,
      GameLevel.groundY - 30,
      360,
      120,
      onEnter: () {
        toast('THE RIVER TAKES ITS CUT');
        placePlayer(arenaX[1] + 120);
      },
    );

    // Arena 3: desks, stamps, and a queue thousands long that Sakamoto skips.
    add(
      CrowdStrip(
        position: Vector2(arenaX[2] + 60, 250),
        size: Vector2(900, 150),
        color: const Color(0xFFB9A99A),
        count: 30,
        seed: 3,
      ),
    );
    for (final dx in [180.0, 520.0, 820.0]) {
      add(
        Prop(
          position: Vector2(arenaX[2] + dx, 330),
          size: Vector2(110, 70),
          color: const Color(0xFF4A3524),
          label: 'DESK',
          lightText: true,
        ),
      );
    }

    // The boss room.
    for (final dx in [220.0, 900.0]) {
      add(
        Prop(
          position: Vector2(bossX + dx, 200),
          size: Vector2(90, 200),
          color: const Color(0xFF3A2A20),
          label: 'RECORDS',
          lightText: true,
        ),
      );
    }
    registrar = RegistrarBoss(
      position: Vector2(
        bossX + 620,
        GameLevel.groundY - RegistrarBoss.bodyHeight,
      ),
    );
    add(registrar);

    placePlayer(120);
    setCheckpoint(120);
  }

  // ── Doors ───────────────────────────────────────────────────

  Future<void> _sealDoors(double left, double right) async {
    for (final x in [left, right]) {
      final door = Platform(
        position: Vector2(x, 60),
        size: Vector2(28, GameLevel.groundY - 60),
        color: const Color(0xFF8A2F2A),
        label: 'DOOR',
      );
      _doors.add(door);
      platforms.add(door);
      add(door);
    }
    toast('THE DOORS SEAL');
  }

  void _openDoors() {
    for (final door in _doors) {
      platforms.remove(door);
      door.removeFromParent();
    }
    _doors.clear();
    toast('CLEARED');
  }

  bool get _arenaClear => creatures.every((c) => !c.active);

  @override
  void onSwing(Rect reach, bool charged) {
    super.onSwing(reach, charged);
    if (_bossFightRunning && reach.overlaps(registrar.body)) {
      registrar.takeHit(charged ? 2 : 1, charged: charged);
    }
  }

  @override
  Future<void> script() async {
    // ── 1. Arrival ────────────────────────────────────────────
    player.controlsLocked = true;
    await wait(0.8);
    await say([
      const Line('SAKAMOTO', 'Oh. Oh, this is fine. This is a normal hole.'),
    ]);
    // A growl loud enough to shake the screen. Its source is never shown,
    // here or ever — it is scenery, and it is the biggest thing in the game.
    toast('SOMETHING GROWLS', seconds: 2.2);
    await wait(1.6);
    await say([
      const Line.inHead('Do not look for it.'),
      const Line('SAKAMOTO', 'Look for what?'),
      const Line.inHead('Exactly.'),
    ]);
    player.controlsLocked = false;

    // ── 2. Arena 1 — ash shore ────────────────────────────────
    await waitUntil(() => player.body.center.dx > arenaX[0] + 260);
    await _sealDoors(arenaX[0] + 40, arenaX[0] + arenaWidth - 60);
    for (final dx in [620.0, 860.0, 980.0]) {
      spawn(
        Creature.ashHound(Vector2(arenaX[0] + dx, GameLevel.groundY - 100)),
      );
    }

    // If the two-headed dog was contracted on Earth it arrives here, fights
    // the pack on camera, and Yami is insufferable about it for a full minute.
    if (game.state.hasContract(CreatureId.twoHeadedDog)) {
      final ally = Creature.twoHeadedDog(
        Vector2(arenaX[0] + 300, GameLevel.groundY - 110),
      )..ally = true;
      spawn(ally);
      await say([
        const Line.inHead('That is your dog. You have a dog in Hell.'),
        const Line.inHead('I am going to talk about this for a while.'),
      ]);
      // An ally thins the pack on camera.
      await wait(3);
      for (final c in creatures) {
        if (c.creatureId == 'ash-hound' && c.active) {
          c.takeHit(2);
          break;
        }
      }
    }

    prompt('ROLL THROUGH THEM  —  they circle behind');
    await waitUntil(() => _arenaClear);
    prompt(null);
    _openDoors();
    setCheckpoint(arenaX[0] + 600);

    // ── 3. Arena 2 — the soul river bank ──────────────────────
    await waitUntil(() => player.body.center.dx > arenaX[1] + 160);
    await _sealDoors(arenaX[1] + 40, arenaX[1] + arenaWidth - 60);
    await say([
      const Line.inHead('There are faces in that. Do not stand in it.'),
    ]);
    for (final dx in [420.0, 600.0, 760.0]) {
      spawn(
        Creature.agonyHand(Vector2(arenaX[1] + dx, GameLevel.groundY - 90)),
      );
    }
    await waitUntil(() => _arenaClear);
    _openDoors();
    setCheckpoint(arenaX[1] + 900);

    // ── 4. Arena 3 — the queue ────────────────────────────────
    await waitUntil(() => player.body.center.dx > arenaX[2] + 160);
    await _sealDoors(arenaX[2] + 40, arenaX[2] + arenaWidth - 60);
    await say([
      const Line('SAKAMOTO', 'Is this the line? I am not doing the line.'),
      const Line.inHead('You have never done a line in your life.'),
    ]);

    prompt('HOLD ATK TO CHARGE  —  shields only open to a draw-cut');
    // Waves of four.
    for (var wave = 0; wave < 2; wave++) {
      for (var i = 0; i < 4; i++) {
        spawn(
          Creature.clerk(
            Vector2(arenaX[2] + 420 + i * 150, GameLevel.groundY - 150),
          ),
        );
      }
      await waitUntil(() => _arenaClear);
      if (wave == 0) await wait(1.2);
    }
    prompt(null);
    _openDoors();
    setCheckpoint(arenaX[2] + 900);

    // ── 5–7. The boss ─────────────────────────────────────────
    await waitUntil(() => player.body.center.dx > bossX + 120);
    await _bossFight();

    // ── 8. The check ──────────────────────────────────────────
    await say([
      const Line('SAKAMOTO', 'Oh shit!'),
      const Line('SAKAMOTO', 'Why are you being chaotic in hell?'),
      const Line(
        'REGISTRAR',
        'Chaotic? I have four arms and a filing deadline.',
      ),
      const Line.narration('He turns a page. Then another. Then back.'),
      const Line(
        'REGISTRAR',
        "Your friend isn't here. He's not even close to here.",
      ),
      const Line.narration(
        'Everyone on screen is briefly, genuinely embarrassed.',
      ),
      const Line.inHead('Bitch, why were you looking in hell? Go up!'),
    ]);

    // ── 9. The redirect ───────────────────────────────────────
    if (registrar.contractable) {
      await say([
        const Line(
          'REGISTRAR',
          'I can stamp you a pass. It will not work up there.',
        ),
      ]);
      final pick = await choose([
        const Choice('Take the pass. Leave him standing.'),
        const Choice('Finish him anyway.'),
      ]);
      if (pick == 0) {
        game.state.recordContract(CreatureId.registrar);
        toast('CONTRACT SEALED');
        await say([
          const Line('REGISTRAR', 'Good. Now get out of my Registry.'),
        ]);
      } else {
        game.state.recordKill();
        await say([
          const Line.inHead(
            'He was doing paperwork. He was just doing paperwork.',
          ),
        ]);
      }
    }

    await say([
      const Line('REGISTRAR', 'The gate above has an angel on it.'),
      const Line('REGISTRAR', 'She is not a bureaucrat. Do not try charm.'),
    ]);

    player.controlsLocked = true;
    await game.hud.flash.flash(duration: 1.2, color: const Color(0xFFFF7043));
    await finish();
  }

  Future<void> _bossFight() async {
    setCheckpoint(bossX + 200);
    await game.hud.nameCard.slam('THE REGISTRAR', sub: 'BEHIND SCHEDULE');
    game.hud.bossBar.show('THE REGISTRAR');
    registrar.fighting = true;
    _bossFightRunning = true;
    registrar.onQuestion = () => _questionAsked = true;

    await waitUntil(() => _questionAsked);
    _bossFightRunning = false;
    game.hud.bossBar.value = 0.2;

    // A dialogue in the middle of a boss fight with both bars still on screen.
    await say([
      const Line(
        'REGISTRAR',
        'Stop. Stop hitting me. What do you actually want?',
      ),
    ]);
    final pick = await choose([
      const Choice('"My friend. He died. I need him back."'),
      const Choice('"I want to speak to whoever is in charge."'),
      const Choice('"I forgot. It was important though."'),
    ]);
    await say([
      switch (pick) {
        0 => const Line(
          'REGISTRAR',
          'Names. Dates. Anything at all. No? Wonderful.',
        ),
        1 => const Line(
          'REGISTRAR',
          'I am whoever is in charge. That is the tragedy.',
        ),
        _ => const Line(
          'REGISTRAR',
          'It was important. You forgot. Both true.',
        ),
      },
    ]);
    game.hud.bossBar.hide();
  }

  @override
  void onRespawned() {
    if (_bossFightRunning) registrar.fighting = true;
  }
}

/// A river of souls with faces surfacing and going under. Eight frames of
/// animation are on the buy list; this is the stand-in.
class SoulRiver extends PositionComponent {
  SoulRiver({required super.position, required super.size})
    : super(priority: -1);

  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF2D4E63),
    );
    for (var i = 0; i < 9; i++) {
      final x = (i * 41.0 + _t * 40) % size.x;
      final lift = (i.isEven ? 1 : -1) * 4.0;
      canvas.drawCircle(
        Offset(x, size.y / 2 + lift),
        7,
        Paint()..color = const Color(0xFFBFD8E8).withValues(alpha: 0.8),
      );
    }
    PlaceholderArt.box(
      canvas
        ..save()
        ..translate(size.x / 2 - 70, -22),
      Vector2(140, 18),
      color: const Color(0xFF2D4E63),
      label: 'SOUL RIVER',
      lightText: true,
    );
    canvas.restore();
  }
}
