import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NameInputScreen extends StatelessWidget {
  final Function(String) onNameSubmit;
  final VoidCallback onBack;

  const NameInputScreen({
    super.key,
    required this.onNameSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/koi_pond.gif'),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              Text(
                'Sakamoto san, Let\'s begin our adventure.\n坂本さん、冒険を始めましょう。',
                style: GoogleFonts.gamjaFlower(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color.fromARGB(255, 203, 255, 206),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const SizedBox(height: 40),

              // Buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Back button
                  ElevatedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, size: 20),
                    label: const Text(
                      'BACK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),

                  // OK button
                  ElevatedButton.icon(
                    onPressed: () {
                      onNameSubmit('Sakamoto');
                    },
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 119, 227, 123),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
