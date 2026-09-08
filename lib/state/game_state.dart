/// Persistent run state — the two hidden counters, the contracts, and where
/// in the story we are. Nothing here is ever drawn on the HUD (see §5 "The
/// tally": the game never explains this and never should).
library;

enum LevelId { yard, road, registry, gate, ending }

extension LevelIdInfo on LevelId {
  String get code => switch (this) {
    LevelId.yard => '00',
    LevelId.road => 'E1',
    LevelId.registry => 'H1',
    LevelId.gate => 'HV1',
    LevelId.ending => '--',
  };

  String get title => switch (this) {
    LevelId.yard => 'THE YARD',
    LevelId.road => 'THE ROAD TO THE SAINT',
    LevelId.registry => 'THE REGISTRY',
    LevelId.gate => 'THE GATE AND THE CHOIR',
    LevelId.ending => 'THE YARD, AGAIN',
  };

  LevelId? get next => switch (this) {
    LevelId.yard => LevelId.road,
    LevelId.road => LevelId.registry,
    LevelId.registry => LevelId.gate,
    LevelId.gate => LevelId.ending,
    LevelId.ending => null,
  };
}

/// Creature ids that can be contracted. Contracts are the only thing that
/// carries between worlds.
class CreatureId {
  static const bellToad = 'bell-toad';
  static const stiltWidow = 'stilt-widow';
  static const mouthMoth = 'mouth-moth';
  static const twoHeadedDog = 'two-headed-dog';
  static const registrar = 'registrar';
}

class GameState {
  GameState({this.playerName = 'Sakamoto'});

  String playerName;

  // ── The tally (hidden) ──────────────────────────────────────
  int creaturesKilled = 0;
  final Set<String> contracted = <String>{};

  int get contractCount => contracted.length;
  bool hasContract(String id) => contracted.contains(id);

  void recordKill() => creaturesKilled++;
  void recordContract(String id) => contracted.add(id);

  /// Yami talks less the more Sakamoto kills. 1.0 = chatty, 0.0 = silent.
  double get yamiTalkativeness =>
      (1.0 - creaturesKilled * 0.12).clamp(0.25, 1.0);

  // ── Health / guard ──────────────────────────────────────────
  static const int maxHealthPips = 5;
  static const int maxGuardPips = 5;

  int health = maxHealthPips;
  double guard = maxGuardPips.toDouble();

  /// Heaven only: every swing costs a pip and there are no shrines.
  bool bloodPrice = false;

  void refillAtShrine() {
    health = maxHealthPips;
    guard = maxGuardPips.toDouble();
  }

  // ── Progression ─────────────────────────────────────────────
  LevelId currentLevel = LevelId.yard;

  /// Which of HV1's three gate routes the player took, if any.
  String? gateRoute;

  /// How many times the gate angel caught Sakamoto. Three welds the drain.
  int gateCatches = 0;

  void resetRun() {
    creaturesKilled = 0;
    contracted.clear();
    health = maxHealthPips;
    guard = maxGuardPips.toDouble();
    bloodPrice = false;
    currentLevel = LevelId.yard;
    gateRoute = null;
    gateCatches = 0;
  }
}
