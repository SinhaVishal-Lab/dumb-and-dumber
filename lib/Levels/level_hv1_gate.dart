import 'dart:ui' hide TextStyle;

import 'package:dumb_and_dumber/Levels/level.dart';
import 'package:dumb_and_dumber/characters/bosses.dart';
import 'package:dumb_and_dumber/characters/enemy.dart';
import 'package:dumb_and_dumber/characters/player.dart';
import 'package:dumb_and_dumber/characters/yami.dart';
import 'package:dumb_and_dumber/components/placeholder.dart';
import 'package:dumb_and_dumber/dialogue/dialogue.dart';
import 'package:dumb_and_dumber/state/game_state.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors, TextStyle;

/// HV1 · THE GATE AND THE CHOIR — Heaven · stealth.
///
/// The sword still works here, and it bleeds him. Every swing costs one
/// health pip; there are no shrines. The Gate Angel takes zero damage from
/// anything he owns, so the sword is never the answer — only ever the
/// expensive shortcut.
class GateLevel extends GameLevel {
  GateLevel({required super.player}) : super(id: LevelId.gate);

  static const double gateScreen = 0;
  static const List<double> terraceX = [1200, 2300, 3400];
  static const double chaseStart = 4500;
  static const double drainX = 6500;

  late final GateAngelBoss angel;
  late final Yami yami;

  final List<SingingCue> _singers = [];
  final List<Creature> _wardens = [];

  bool _caught = false;
  int _terrace = 0;

  @override
  Future<void> build() async {
    levelWidth = 6900;
    cameraFollows = true;

    // Heaven only: the meter goes one way.
    game.state.bloodPrice = true;

    add(
      PlaceholderParallax(
        sky: const Color(0xFFBFD3F2),
        mid: const Color(0xFFE8EEF8),
        near: const Color(0xFFD6DEEA),
        size: Vector2(levelWidth, levelHeight),
        caption: 'PARALLAX — cloud floor / light shafts / distant terraces',
      ),
    );
    ground(0, levelWidth, color: const Color(0xFFE3E7EF));

    // Part one: a well of light, one angel in front of it.
    add(
      Prop(
        position: Vector2(760, 120),
        size: Vector2(200, 280),
        color: const Color(0xFFF6EFCE),
        label: 'THE GATE WELL',
      ),
    );
    add(
      CrowdStrip(
        position: Vector2(220, 250),
        size: Vector2(420, 150),
        count: 14,
        seed: 11,
      ),
    );
    angel = GateAngelBoss(
      position: Vector2(620, GameLevel.groundY - GateAngelBoss.bodyHeight),
    );
    angel.onCaught = _onCaught;
    add(angel);

    // Part two: three bright terraces of identical white souls.
    for (var i = 0; i < terraceX.length; i++) {
      add(
        CrowdStrip(
          position: Vector2(terraceX[i], 240),
          size: Vector2(820, 160),
          count: 34,
          seed: 5 + i,
        ),
      );
      add(
        Prop(
          position: Vector2(terraceX[i] - 90, 300),
          size: Vector2(70, 100),
          color: const Color(0xFFCBD4E4),
          label: 'TERRACE ${i + 1}',
        ),
      );
      // Three decoys elsewhere on the terraces also sing badly.
      final cue = SingingCue(
        atX: terraceX[i] + (i == 2 ? 640 : 280),
        isYami: i == 2,
        level: this,
      );
      _singers.add(cue);
      add(cue);

      final warden = Creature.warden(
        Vector2(terraceX[i] + 400, GameLevel.groundY - 160),
      )..passive = true;
      _wardens.add(warden);
      spawn(warden);
    }

    // The chase corridor and the service drain.
    add(
      Prop(
        position: Vector2(drainX, 280),
        size: Vector2(160, 120),
        color: const Color(0xFF8E9AAE),
        label: 'SERVICE DRAIN',
      ),
    );

    yami = Yami(
      position: Vector2(
        terraceX[2] + 600,
        GameLevel.groundY - Player.feetOffset,
      ),
      soulForm: true,
    );
    add(yami);

    placePlayer(140);
    setCheckpoint(140);
  }

  // ── Being seen ──────────────────────────────────────────────

  void _onCaught() {
    if (_caught) return;
    _caught = true;
  }

  /// Running is louder than walking, and being seen sends you back a terrace
  /// and adds a warden — so rushing the search makes the search harder.
  void _seen() {
    game.state.gateCatches++;
    toast('SEEN');
    final back = (_terrace - 1).clamp(0, terraceX.length - 1);
    _terrace = back;
    placePlayer(terraceX[back] + 60);
    final extra = Creature.warden(
      Vector2(terraceX[back] + 700, GameLevel.groundY - 160),
    )..passive = true;
    _wardens.add(extra);
    spawn(extra);
  }

  @override
  void onBloodPriceCollapse() {
    // Not a game over: the wardens carry him out of the gate and the whole
    // approach restarts.
    toast('THE WARDENS CARRY YOU OUT', seconds: 2.0);
    game.state.health = GameState.maxHealthPips;
    game.hud.sync();
    player.revive(checkpoint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Wardens sweep fixed routes.
    if (_terrace > 0 && !player.dead) {
      for (final warden in _wardens) {
        if (!warden.isMounted) continue;
        final d = (warden.body.center.dx - player.body.center.dx).abs();
        final moving = player.velocity.x.abs() > 20;
        if (d < 230 && moving && !_hiddenInChoir) {
          _seen();
          break;
        }
      }
    }
  }

  bool get _hiddenInChoir {
    if (player.velocity.x.abs() > 5) return false;
    for (final x in terraceX) {
      if (player.body.center.dx > x && player.body.center.dx < x + 820) {
        return true;
      }
    }
    return false;
  }

  // ── Director ────────────────────────────────────────────────

  @override
  Future<void> script() async {
    await wait(0.6);
    await say([
      const Line('ANGEL', "You're breathing. You can't be here."),
      const Line('SAKAMOTO', "I'll stop if that helps."),
      const Line('ANGEL', 'It does not.'),
      const Line.inHead(
        'Every time you swing that thing up here it costs you.',
      ),
    ]);

    await _bypassTheGuard();
    await _findTheBestie();
    await _theRefusal();
    await _theChase();

    player.controlsLocked = true;
    await game.hud.flash.flash(duration: 1.4);
    await finish();
  }

  /// Three solutions, and taking one closes the others.
  Future<void> _bypassTheGuard() async {
    final routes = <Choice>[
      const Choice('Join the queue and look dead.'),
      Choice(
        'Let the moths eat her light.',
        requiresContract: game.state.hasContract(CreatureId.mouthMoth)
            ? null
            : CreatureId.mouthMoth,
      ),
      const Choice('Tell her the truth.'),
    ];

    // Three catches welds the drain shut and leaves only the queue.
    final pick = game.state.gateCatches >= 3 ? 0 : await choose(routes);

    switch (pick) {
      case 0:
        game.state.gateRoute = 'queue';
        await _deadMansRoute();
      case 1:
        game.state.gateRoute = 'contract';
        await _contractRoute();
      default:
        game.state.gateRoute = 'honest';
        await _honestRoute();
    }
    _terrace = 1;
  }

  /// The only time the game asks you to do nothing, and it comes right after
  /// the loudest level in the game.
  Future<void> _deadMansRoute() async {
    await say([
      const Line.narration('Sword stowed. Lantern out. Stand in the line.'),
    ]);
    placePlayer(320);

    var failed = false;
    player.mustStandStill = true;
    player.onInputWhileStill = () => failed = true;

    for (var remaining = 40; remaining > 0; remaining--) {
      prompt('DO NOTHING  —  $remaining');
      await wait(1);
      if (failed) break;
    }

    player.mustStandStill = false;
    player.onInputWhileStill = null;
    prompt(null);

    if (failed) {
      await say([const Line('ANGEL', 'Dead men do not fidget.')]);
      _onCaught();
      game.state.gateCatches++;
      await _deadMansRoute();
      return;
    }
    await say([
      const Line('ANGEL', 'Next.'),
      const Line.inHead('You held still for forty seconds. I am stunned.'),
    ]);
    placePlayer(terraceX[0] + 60);
  }

  Future<void> _contractRoute() async {
    await say([
      const Line.narration('The moths came all this way. They were owed.'),
    ]);
    toast('THE LIGHT GOES OUT — 11 SECONDS', seconds: 2.0);
    final dark = Prop(
      position: Vector2(0, 0),
      size: Vector2(1200, GameLevel.viewH),
      color: const Color(0xE6000000),
      label: 'GATE LIGHT EATEN',
      lightText: true,
    );
    add(dark);
    prompt('RUN  →');
    final made = await waitUntilOr(11, () => player.body.center.dx > 1100);
    prompt(null);
    dark.removeFromParent();
    if (!made) {
      game.state.gateCatches++;
      _onCaught();
      await say([const Line('ANGEL', 'Slow. And moth-eaten.')]);
      await _contractRoute();
      return;
    }
    placePlayer(terraceX[0] + 60);
  }

  /// She listens, believes him, refuses anyway — then mentions the service
  /// drain and turns her back so she can honestly say she saw nothing.
  Future<void> _honestRoute() async {
    await say([
      const Line(
        'SAKAMOTO',
        'I killed my friend and I am here to take him home.',
      ),
      const Line('ANGEL', '...'),
      const Line('ANGEL', 'I believe you. The answer is still no.'),
      const Line.narration('She looks at the floor for a long moment.'),
      const Line('ANGEL', 'The terraces get washed. There is a drain for it.'),
      const Line('ANGEL', 'I am going to look at that wall now.'),
      const Line.inHead('She just told you how. Say thank you.'),
      const Line('SAKAMOTO', 'Thank you, wall.'),
    ]);
    placePlayer(terraceX[0] + 60);
  }

  /// No marker of any kind. Yami is found by ear.
  Future<void> _findTheBestie() async {
    await say([
      const Line.inHead('I am singing. Follow the singing.'),
      const Line.inHead('Ignore the other three. They are worse than me.'),
    ]);
    prompt('FIND HIM BY EAR  —  walk, do not run');

    _terrace = 1;
    await waitUntil(
      () => (player.body.center.dx - yami.body.center.dx).abs() < 200,
    );
    prompt(null);
    for (final s in _singers) {
      s.found = true;
    }
  }

  Future<void> _theRefusal() async {
    await say([
      const Line('YAMI', 'You came all the way up here.'),
      const Line('SAKAMOTO', 'You told me to.'),
      const Line('YAMI', 'I say a lot of things. I am dumb. So are you.'),
      const Line('YAMI', 'Sit down a second.'),
      const Line.narration(
        'This is the first time in the game he wants something for himself.',
      ),
      const Line('YAMI', 'No. I am not coming.'),
    ]);

    // Every creature spared is a line available in this conversation, and a
    // player who killed everything has almost nothing to say.
    var attempts = 0;
    var convinced = false;
    while (!convinced && attempts < 4) {
      attempts++;
      final pick = await choose([
        const Choice(
          '"The toad is still singing on its post."',
          requiresContract: CreatureId.bellToad,
        ),
        const Choice(
          '"She carried me across. She asked about you."',
          requiresContract: CreatureId.stiltWidow,
        ),
        const Choice(
          '"Your dog turned up in Hell. On my side."',
          requiresContract: CreatureId.twoHeadedDog,
        ),
        const Choice('"Get up. We are going."'),
      ]);

      if (pick < 3) {
        convinced = true;
        await say([
          const Line('YAMI', '...you let it live.'),
          const Line('YAMI', 'You never let anything live.'),
          const Line(
            'YAMI',
            'Fine. Fine! Carry me, then. My legs are conceptual.',
          ),
        ]);
      } else {
        await say([
          Line(
            'YAMI',
            attempts >= 3
                ? 'You are going to keep saying that until I move, are you not.'
                : 'That is not an argument, that is a schedule.',
          ),
        ]);
        if (attempts >= 3) {
          convinced = true;
          await say([
            const Line('YAMI', 'Alright. Not because you were right.'),
            const Line('YAMI', 'Because you are too stupid to stop asking.'),
          ]);
        }
      }
    }

    // Carrying him: no attack, no roll, 20% slower. Every skill the game
    // taught is gone for the last five minutes, on purpose.
    yami.removeFromParent();
    player.carrying = true;
    toast('CARRYING YAMI  —  no attack, no roll', seconds: 2.2);
  }

  Future<void> _theChase() async {
    await game.hud.nameCard.slam(
      'THE GATE ANGEL',
      sub: 'SHE HAS STOPPED BEING POLITE',
    );
    game.hud.bossBar.show(
      'DISTANCE TO THE DRAIN',
      barColor: const Color(0xFFD8A44A),
    );
    game.hud.bossBar.value = 0;

    angel.fighting = true;
    angel.position = Vector2(
      chaseStart - 400,
      GameLevel.groundY - GateAngelBoss.bodyHeight,
    );

    // Phase one — the terrace. Light beams; the only tool left is the roll,
    // and carrying means the roll is gone, so it costs distance to put him
    // down. Sakamoto sets him down to dodge.
    angel.mode = AngelMode.beams;
    prompt('RUN  →   the beams sweep');
    await _runPhase(chaseStart + 700);

    // Phase two — the colonnade. Stand still inside the choir.
    angel.mode = AngelMode.colonnade;
    prompt('STAND STILL INSIDE THE CHOIR');
    var hidden = false;
    while (!hidden) {
      final ok = await waitUntilOr(6, () {
        angel.playerHidden = player.velocity.x.abs() < 5;
        return angel.playerHidden &&
            (angel.body.center.dx - player.body.center.dx).abs() < 240;
      });
      hidden = ok;
      if (!ok && _caught) {
        _caught = false;
        placePlayer(chaseStart + 700);
      }
    }
    await say([
      const Line.narration('She walks past close enough to move his hair.'),
    ]);

    // Phase three — the drain. Three grab attempts on a clear wind-up, each
    // dodged by throwing Yami ahead and catching up to him.
    angel.mode = AngelMode.drain;
    angel.grabsDodged = 0;
    prompt('THROW YAMI AHEAD  (ATK)  to dodge the grab');
    game.hud.onAttackDown = _throwYami;
    await _runPhase(drainX);
    game.hud.onAttackDown = player.attackDown;
    prompt(null);
    game.hud.bossBar.hide();
    angel.fighting = false;

    await say([
      const Line.inHead('Down. Go down. That is the whole plan, go down.'),
    ]);
  }

  /// Throwing him ahead is the only dodge left: it buys invulnerability
  /// frames and costs you the twenty steps it takes to catch up.
  void _throwYami() {
    if (!player.carrying) return;
    player.carrying = false;
    player.takeHit(0); // Burns the invulnerability window, deals nothing.
    toast('THROWN AHEAD');
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (isMounted) player.carrying = true;
    });
  }

  Future<void> _runPhase(double targetX) async {
    while (player.body.center.dx < targetX) {
      await waitUntilOr(0.2, () => player.body.center.dx >= targetX);
      final start = angel.mode == AngelMode.drain ? chaseStart : gateScreen;
      game.hud.bossBar.value =
          ((player.body.center.dx - start) / (targetX - start)).clamp(0.0, 1.0);
      if (_caught) {
        _caught = false;
        toast('CAUGHT — BACK TO THE PHASE START');
        placePlayer(
          angel.mode == AngelMode.drain ? chaseStart + 700 : chaseStart,
        );
        angel.position.x = player.body.center.dx - 500;
      }
    }
  }
}

/// Yami is found by ear: his off-key line gets louder as Sakamoto gets
/// closer. Without the VO recorded, the cue is drawn instead of heard —
/// same information, same lack of a map marker.
class SingingCue extends PositionComponent {
  SingingCue({required this.atX, required this.isYami, required this.level})
    : super(priority: 20);

  final double atX;
  final bool isYami;
  final GameLevel level;

  bool found = false;

  static final _painter = TextPaint(
    style: const TextStyle(
      color: Color(0xFF4A5468),
      fontSize: 16,
      fontStyle: FontStyle.italic,
      fontFamily: 'monospace',
    ),
  );

  @override
  void render(Canvas canvas) {
    if (found) return;
    final distance = (level.player.body.center.dx - atX).abs();
    if (distance > 700) return;
    final loudness = (1 - distance / 700).clamp(0.0, 1.0);
    final glyphs = '♪' * (1 + (loudness * 4).round());
    canvas.saveLayer(
      Rect.fromLTWH(atX - 200, 120, 400, 80),
      Paint()..color = Colors.white.withValues(alpha: loudness),
    );
    _painter.render(
      canvas,
      isYami ? '$glyphs  (badly, and in the wrong key)' : '$glyphs  (badly)',
      Vector2(atX, 150),
      anchor: Anchor.center,
    );
    canvas.restore();
  }
}
