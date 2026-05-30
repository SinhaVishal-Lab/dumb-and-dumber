import 'package:dumb_and_dumber/components/menu_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MainMenuScreen extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback? onResume;

  const MainMenuScreen({super.key, required this.onPlay, this.onResume});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/autumn_city.gif'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'バカとアホ',
                style: GoogleFonts.gamjaFlower(
                  fontSize: 52,
                  fontWeight: FontWeight.normal,
                  color: const Color.fromARGB(
                    255,
                    254,
                    158,
                    143,
                  ).withValues(alpha: 0.8),
                ),
              ),
              SizedBox(height: 80),
              MenuButton(
                text: 'PLAY',
                onPressed: onPlay,
                color: const Color.fromARGB(255, 169, 34, 7),
                icon: Icons.play_arrow,
              ),

              SizedBox(height: 20),
              if (onResume != null)
                MenuButton(
                  text: 'RESUME',
                  onPressed: onResume!,
                  color: const Color.fromARGB(255, 194, 117, 2),
                  icon: Icons.play_circle_outline,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
