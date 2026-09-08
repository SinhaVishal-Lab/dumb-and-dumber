import 'package:dumb_and_dumber/Levels/level.dart';
import 'package:dumb_and_dumber/Levels/level_00_yard.dart';
import 'package:dumb_and_dumber/Levels/level_e1_road.dart';
import 'package:dumb_and_dumber/Levels/level_ending.dart';
import 'package:dumb_and_dumber/Levels/level_h1_registry.dart';
import 'package:dumb_and_dumber/Levels/level_hv1_gate.dart';
import 'package:dumb_and_dumber/characters/player.dart';
import 'package:dumb_and_dumber/dialogue/dialogue_box.dart';
import 'package:dumb_and_dumber/hud/game_hud.dart';
import 'package:dumb_and_dumber/state/game_state.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';

/// バカとアホ — DUMB AND DUMBER.
///
/// One camera (1080×500 fixed), one player, one level at a time. The game
/// object owns everything that outlives a level: the run state, the camera,
/// the HUD and the dialogue box.
class DumbandDumber extends FlameGame with HasKeyboardHandlerComponents {
  DumbandDumber({
    required this.onShowMainMenu,
    required this.onPauseGame,
    required this.onResumeGame,
    required String playerName,
  }) : state = GameState(playerName: playerName);

  final VoidCallback onShowMainMenu;
  final VoidCallback onPauseGame;
  final VoidCallback onResumeGame;

  final GameState state;

  static final Vector2 viewSize = Vector2(1080, 500);

  late CameraComponent cam;
  late JoystickComponent joystick;
  late DialogueBox dialogue;
  late GameHud hud;

  GameLevel? level;
  bool isGamePaused = false;
  bool _booted = false;

  String get playerName => state.playerName;

  @override
  Color backgroundColor() => const Color(0xFF12100E);

  /// Exactly what Flame needs in its cache. The menu gifs are drawn by
  /// Flutter widgets, not by the game loop, so they stay out of it — loading
  /// the whole images directory pulled six animated gifs into video memory
  /// for nothing.
  static const List<String> spriteAssets = [
    'level-01.jpg',
    'Characters/Samurai/IDLE.png',
    'Characters/Samurai/RUN.png',
    'Characters/Samurai/ATTACK.png',
    'Characters/Samurai/HURT.png',
  ];

  @override
  Future<void> onLoad() async {
    await images.loadAll(spriteAssets);
    await goToLevel(state.currentLevel);
    _booted = true;
  }

  // ── Level flow ──────────────────────────────────────────────
  // §10 "Multi-level loading — Level.levelName is already a parameter and is
  // currently ignored". It is not ignored any more.

  GameLevel _createLevel(LevelId id, Player player) => switch (id) {
    LevelId.yard => YardLevel(player: player),
    LevelId.road => RoadLevel(player: player),
    LevelId.registry => RegistryLevel(player: player),
    LevelId.gate => GateLevel(player: player),
    LevelId.ending => EndingLevel(player: player),
  };

  Future<void> goToLevel(LevelId id) async {
    state.currentLevel = id;

    // Tear the old world down. The level's own script aborts on removal.
    level?.removeFromParent();
    if (_booted) cam.removeFromParent();
    level = null;

    final player = Player();
    final next = _createLevel(id, player);

    cam = CameraComponent.withFixedResolution(
      world: next,
      width: viewSize.x,
      height: viewSize.y,
    )..viewfinder.anchor = Anchor.topLeft;

    level = next;
    // Deliberately not awaited: these futures resolve when the components
    // mount, and mounting cannot happen until onLoad returns.
    addAll([next, cam]);
    _mountViewportUi(player);
  }

  /// The viewport furniture is rebuilt per level because each level gets a
  /// fresh camera, and a component can only have one parent.
  void _mountViewportUi(Player player) {
    dialogue = DialogueBox(viewSize: viewSize)..hasContract = state.hasContract;

    hud = GameHud(viewSize: viewSize, state: state)
      ..onJump = player.jump
      ..onAttackDown = player.attackDown
      ..onAttackUp = player.attackUp
      ..onGuardDown = player.guardDown
      ..onGuardUp = player.guardUp
      ..onContract = tryContract;

    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 20,
        paint: BasicPalette.red.withAlpha(140).paint(),
      ),
      background: CircleComponent(
        radius: 58,
        paint: BasicPalette.darkGray.withAlpha(110).paint(),
      ),
      margin: const EdgeInsets.only(left: 40, bottom: 20),
      priority: 800,
    );

    cam.viewport.addAll([joystick, hud, ..._systemButtons(), dialogue]);
  }

  List<Component> _systemButtons() {
    Component label(String text, Vector2 at, Color color) => TextComponent(
      text: text,
      position: at,
      anchor: Anchor.center,
      priority: 811,
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );

    final pauseButton = ButtonComponent(
      button: RectangleComponent(
        size: Vector2(92, 38),
        paint: Paint()..color = Colors.amber,
      ),
      buttonDown: RectangleComponent(
        size: Vector2(92, 38),
        paint: Paint()..color = Colors.amber.withValues(alpha: 0.7),
      ),
      onPressed: () {
        pauseGame();
        onPauseGame();
      },
      position: Vector2(20, 20),
      priority: 810,
    );

    final exitButton = ButtonComponent(
      button: RectangleComponent(
        size: Vector2(92, 38),
        paint: Paint()..color = Colors.redAccent,
      ),
      buttonDown: RectangleComponent(
        size: Vector2(92, 38),
        paint: Paint()..color = Colors.redAccent.withValues(alpha: 0.7),
      ),
      onPressed: onShowMainMenu,
      position: Vector2(124, 20),
      priority: 810,
    );

    return [
      pauseButton,
      exitButton,
      label('PAUSE', Vector2(66, 39), Colors.black),
      label('EXIT', Vector2(170, 39), Colors.white),
    ];
  }

  // ── Session control (called by GameWrapper) ─────────────────

  void applyPlayerName(String name) {
    state.playerName = name;
  }

  /// Fresh run from the prologue.
  Future<void> startNewRun(String name) async {
    state.resetRun();
    state.playerName = name;
    resumeEngine();
    isGamePaused = false;
    if (_booted) await goToLevel(LevelId.yard);
  }

  void startLevel() {
    resumeEngine();
    isGamePaused = false;
  }

  void pauseGame() {
    pauseEngine();
    isGamePaused = true;
  }

  void resumeGame() {
    resumeEngine();
    isGamePaused = false;
  }

  // ── Systems the player and creatures call back into ─────────

  /// §5 Blood price, Heaven only: every swing costs one health pip.
  void damagePlayerFromOwnSword() {
    state.health = (state.health - 1).clamp(0, GameState.maxHealthPips);
    hud.sync();
    hud.toast.show('THE PLACE TAKES THE DIFFERENCE', seconds: 1.0);
    if (state.health <= 0) level?.onBloodPriceCollapse();
  }

  void tryContract() {
    final current = level;
    if (current == null) return;
    final target = current.nearestOffer();
    if (target == null) return;
    current.offerContract(target);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_booted) return;
    // §5 Touch rules: buttons never overlap the dialogue box.
    final player = level?.player;
    hud.setControlsVisible(
      !dialogue.isActive &&
          player != null &&
          !player.dead &&
          !player.controlsLocked,
    );
  }
}
