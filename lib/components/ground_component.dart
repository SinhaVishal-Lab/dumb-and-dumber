import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

class GroundComponent extends PositionComponent with CollisionCallbacks {
  GroundComponent({required super.position, required super.size});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }
}
