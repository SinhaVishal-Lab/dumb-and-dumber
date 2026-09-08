import 'dart:math' as math;
import 'dart:ui' hide TextStyle;

import 'package:dumb_and_dumber/Levels/level.dart';
import 'package:dumb_and_dumber/characters/player.dart';
import 'package:dumb_and_dumber/characters/yami.dart';
import 'package:dumb_and_dumber/components/placeholder.dart';
import 'package:dumb_and_dumber/dialogue/dialogue.dart';
import 'package:dumb_and_dumber/state/game_state.dart';
import 'package:flame/components.dart';

/// 00 · THE YARD — Earth · prologue.
///
/// One flat screen, one background, two sprites — essentially the level the
/// build already had, dressed as a dirt yard at dusk. It is the tutorial and
/// it is also the inciting accident, and those are the same three button
/// presses. Fail state: none.
class YardLevel extends GameLevel {
  YardLevel({required super.player}) : super(id: LevelId.yard);

  late final Yami yami;

  /// Low enough to clear in one jump — see the note in [build].
  static const double woodpileTop = 330;

  /// Hits only count once the fight is actually staged.
  bool _bossActive = false;
  int _hitsLanded = 0;

  @override
  Future<void> build() async {
    levelWidth = GameLevel.viewW;
    levelHeight = GameLevel.viewH;
    cameraFollows = false;

    // The repo's one scaled backdrop, dressed for dusk.
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
        paint: Paint()..color = const Color(0x551A1230),
        priority: -99,
      ),
    );

    // §11 Earth — yard: dirt + fence tileset is still to be drawn, so the
    // ground is a flat plate at the doc's y=400.
    ground(0, GameLevel.viewW, color: const Color(0xFF473627));

    // Props the yard needs: woodpile, post, bucket.
    //
    // The woodpile has to clear a single jump: apex is jumpForce² / 2·gravity
    // = 420² / 1800 = 98px, so anything at 100 is a wall with a prompt on it.
    // 70 leaves a comfortable margin.
    add(
      Prop(
        position: Vector2(520, woodpileTop),
        size: Vector2(120, GameLevel.groundY - woodpileTop),
        color: const Color(0xFF6B4A2A),
        label: 'WOODPILE',
        lightText: true,
      ),
    );
    ledge(
      520,
      woodpileTop,
      120,
      height: GameLevel.groundY - woodpileTop,
      oneWay: false,
      color: const Color(0x00000000),
    );
    add(
      Prop(
        position: Vector2(180, 330),
        size: Vector2(36, 70),
        color: const Color(0xFF55442E),
        label: 'POST',
        lightText: true,
      ),
    );

    yami = Yami(position: Vector2(760, GameLevel.groundY - Player.feetOffset));
    add(yami);
    yami.face(false);

    placePlayer(140);
    setCheckpoint(140);
  }

  /// Yami is not a Creature — he never fights back — so the swing has to be
  /// resolved against him by hand.
  @override
  void onSwing(Rect reach, bool charged) {
    super.onSwing(reach, charged);
    if (!_bossActive) return;
    if (_hitsLanded >= 4) return;
    if (!reach.overlaps(yami.body)) return;
    _hitsLanded++;
    yami.takeHit();
    game.hud.bossBar.value = yami.health / Yami.maxHealth;
  }

  @override
  Future<void> script() async {
    // ── 1. The argument ───────────────────────────────────────
    await wait(0.8);
    await say([
      const Line('YAMI', 'Say it. Say I am the better swordsman.'),
      const Line('SAKAMOTO', 'You fall over when you sneeze.'),
      const Line('YAMI', 'That was once, and the ground was uneven.'),
      const Line('YAMI', 'Come here and settle it, then.'),
    ]);

    prompt('WALK  →   (joystick / D)');
    await waitUntil(() => player.body.center.dx > 430);

    prompt('JUMP  (SPACE / tap JUMP)');
    await waitUntil(() => player.body.center.dx > 660);
    prompt(null);

    await say([
      const Line('YAMI', 'There he is. Took you long enough.'),
      const Line('SAKAMOTO', 'I was pacing myself.'),
    ]);

    // ── 2. First slash ────────────────────────────────────────
    _bossActive = false;
    prompt('ATTACK  (Z / tap ATK)');
    await waitUntil(() => player.isAttacking);
    prompt(null);
    await wait(0.2);
    yami.takeHit();
    await wait(0.4);

    // HURT animation, no health bar on screen — the game is teaching that
    // hits land, and hiding what they cost.
    await say([
      const Line('YAMI', 'Ha! Warm-up. That was a warm-up.'),
      const Line('YAMI', 'I thought we were friends.'),
      const Line('SAKAMOTO', "We are. That's why I went easy."),
    ]);
    yami.health = Yami.maxHealth;

    // ── 3. Guard, taught by refusal ───────────────────────────
    await say([
      const Line.narration('A guard prompt appears over YAMI\'s head.'),
      const Line('YAMI', 'What, this? Blocking a friend would be rude.'),
      const Line.narration('He lowers his sword. He does not use it.'),
    ]);

    prompt('HOLD GUARD  (X / hold GUARD)');
    await waitUntil(() => player.isGuarding);
    await wait(0.6);
    prompt(null);
    await say([
      const Line('YAMI', 'See, you can do it. You just look stupid doing it.'),
      const Line('YAMI', 'Anyway! I do want you to win.'),
    ]);

    // ── 4. Boss — YAMI ────────────────────────────────────────
    await game.hud.nameCard.slam('YAMI', sub: 'THE DUMBER ONE');
    game.hud.bossBar.show('YAMI');
    _bossActive = true;
    _hitsLanded = 0;
    yami.health = Yami.maxHealth;
    game.hud.bossBar.value = 1;

    // Phase one: he dodges by accident and finds it hilarious.
    await waitUntil(() => _hitsLanded >= 1);
    yami.position.x = 840;
    yami.taunt();
    await say([
      const Line('YAMI', 'Whoa! Did you see that? I did not mean to do that.'),
    ]);

    // Phase two: he stops dodging to make a point about honour.
    await waitUntil(() => _hitsLanded >= 2);
    yami.idle();
    await say([
      const Line(
        'YAMI',
        'No more moving. Moving is for people who might lose.',
      ),
    ]);

    // Phase three: the bar is a sliver, he spreads his arms wide.
    await waitUntil(() => _hitsLanded >= 3);
    _bossActive = false;
    game.hud.bossBar.value = 0.06;
    await say([const Line.narration('He spreads his arms wide and waits.')]);

    // ── 5. The hesitation timer ───────────────────────────────
    await _hesitation();

    // ── 6. The stop ───────────────────────────────────────────
    game.hud.bossBar.hide();
    prompt(null);
    player.controlsLocked = true;
    await game.hud.flash.flash(duration: 1.1);
    // One bird noise. flame_audio is a dependency and unused (§9) — the sound
    // hook goes here.
    await wait(0.6);
    yami.position = Vector2(800, GameLevel.groundY - Player.feetOffset);
    yami.sitDown();
    await wait(1.4);
    yami.lieStill();
    await wait(1.0);

    // ── 7. The dying conversation ─────────────────────────────
    // Four to five minutes, one static shot, no music, no skip. What follows
    // is the spine of it; every beat is one more page of the same scene.
    await _dyingConversation();

    // ── 9. The last breath ────────────────────────────────────
    await say([
      const Line('YAMI', 'Bring my soul back before I die, idi—'),
      const Line.inHead('—idiot. Before I die, idiot.'),
      const Line.inHead('Huh. That is a strange place to be standing.'),
    ]);

    await wait(0.8);
    await game.hud.flash.flash(duration: 1.2);
    await finish();
  }

  /// The player should land the killing blow, so the prompt waits as long as
  /// it takes. Refusing to press the button is not a way out.
  Future<void> _hesitation() async {
    _bossActive = true;
    prompt('ATTACK  —  he is not moving');

    const taunts = [
      'What, now you are being careful?',
      "Here. I'll shut my eyes. Better?",
      'You have never won anything in your life. Swing.',
    ];

    for (final taunt in taunts) {
      final struck = await waitUntilOr(
        // Fifteen seconds for the first, then every ten.
        taunt == taunts.first ? 15 : 10,
        () => _hitsLanded >= 4,
      );
      if (struck) {
        _bossActive = false;
        return;
      }
      yami.taunt();
      await say([Line('YAMI', taunt)]);
      prompt('ATTACK  —  he is not moving');
    }

    // The last taunt hands off into a short cutscene: Yami steps into the
    // swing to make his point, and Sakamoto's arm finishes the motion.
    final struck = await waitUntilOr(8, () => _hitsLanded >= 4);
    _bossActive = false;
    if (struck) return;

    prompt(null);
    player.controlsLocked = true;
    await say([
      const Line.narration('He steps into the swing to make his point.'),
    ]);
    yami.position.x = player.facingRight
        ? player.position.x + 120
        : player.position.x - 120;
    await wait(0.4);
    yami.takeHit();
    await wait(0.5);
    player.controlsLocked = false;
    // Same slash, same frame of white, same result.
  }

  Future<void> _dyingConversation() async {
    await say([
      const Line('YAMI', 'Ow. Ow ow ow. Okay. That one counted.'),
      const Line('YAMI', 'Sit down, you are looming.'),
    ]);

    var pick = await choose([
      const Choice('"Get up."'),
      const Choice('"Do you want water?"'),
      const Choice('"That was your fault."'),
    ]);
    await say([
      switch (pick) {
        0 => const Line('YAMI', 'Working on it. Give me a minute. Or nine.'),
        1 => const Line('YAMI', 'Water. For this. Yes. Great idea.'),
        _ => const Line('YAMI', 'It absolutely was. Does not help though.'),
      },
      const Line('YAMI', 'Stop looking at me like that. You look like a dog.'),
    ]);

    await say([
      const Line.narration('A long time passes. Neither of them fills it.'),
      const Line('YAMI', 'Alright. Practical bit.'),
      const Line('YAMI', 'You are going to go and fetch my soul back.'),
    ]);

    pick = await choose([
      const Choice('"Your what?"'),
      const Choice('"Where is it kept?"'),
      const Choice('"Can I fetch it tomorrow?"'),
    ]);
    await say([
      switch (pick) {
        0 => const Line('YAMI', 'My soul. The me part. Keep up.'),
        1 => const Line('YAMI', 'One of three places. Nobody agrees which.'),
        _ => const Line('YAMI', 'Tomorrow I am scenery. Today, please.'),
      },
      const Line('SAKAMOTO', 'Win what? You are the one leaking.'),
      const Line('YAMI', 'Now go win for me.'),
    ]);

    await say([
      const Line(
        'YAMI',
        'Find someone who knows how it works. A saint. Whatever.',
      ),
      const Line('YAMI', 'You are an idiot, and idiots are famously lucky.'),
      const Line.narration('He is repeating himself now. He knows it.'),
    ]);
  }

  @override
  void onPlayerFellOut() {
    // Fail state: none. The yard simply puts him back.
    placePlayer(140);
  }
}
