/// Dialogue data model. Scripts are plain Dart lists so a level reads close
/// to the design doc's DIALOGUE blocks.
library;

class Line {
  const Line(this.speaker, this.text, {this.inHead = false});

  /// A line with no name plate — stage direction, or the world talking.
  const Line.narration(this.text) : speaker = null, inHead = false;

  /// Yami after the last breath: same voice, different mix.
  const Line.inHead(this.text) : speaker = 'YAMI', inHead = true;

  final String? speaker;
  final String text;
  final bool inHead;
}

class Choice {
  const Choice(this.text, {this.requiresContract});

  final String text;

  /// Heaven's refusal argument: every creature spared is a line available
  /// here, and a player who killed everything has almost nothing to say.
  final String? requiresContract;
}
