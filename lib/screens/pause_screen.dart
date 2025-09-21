import 'package:dumb_and_dumber/components/menu_button.dart';
import 'package:flutter/material.dart';

class PauseMenuScreen extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onMainMenu;

  const PauseMenuScreen({
    super.key,
    required this.onResume,
    required this.onMainMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/city_night.gif'),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 40),
            MenuButton(
              text: 'RESUME',
              onPressed: onResume,
              color: Colors.green,
              icon: Icons.play_arrow,
            ),
            SizedBox(height: 15),
            MenuButton(
              text: 'MAIN MENU',
              onPressed: onMainMenu,
              color: Colors.red,
              icon: Icons.home,
            ),
          ],
        ),
      ),
    );
  }
}
