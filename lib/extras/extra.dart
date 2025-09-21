// import 'package:flutter/material.dart';

// class NameInputScreen extends StatefulWidget {
//   final Function(String) onNameSubmit;
//   final VoidCallback onBack;

//   const NameInputScreen({
//     super.key,
//     required this.onNameSubmit,
//     required this.onBack,
//   });

//   @override
//   State<NameInputScreen> createState() => _NameInputScreenState();
// }

// class _NameInputScreenState extends State<NameInputScreen> {
//   final TextEditingController _nameController = TextEditingController();
//   final FocusNode _focusNode = FocusNode();

//   @override
//   void initState() {
//     super.initState();
//     // Auto-focus the text field when screen loads
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _focusNode.requestFocus();
//     });
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _focusNode.dispose();
//     super.dispose();
//   }

//   void _submitName() {
//     String name = _nameController.text.trim();
//     if (name.isNotEmpty) {
//       widget.onNameSubmit(name);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       height: double.infinity,
//       decoration: const BoxDecoration(
//         image: DecorationImage(
//           image: AssetImage('assets/images/koi_pond.gif'),
//           fit: BoxFit.cover,
//         ),
//       ),
//       child: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 100),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               // Title
//               const Text(
//                 'ENTER CHARACTER NAME',
//                 style: TextStyle(
//                   fontSize: 26,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 40),

//               // Name input field
//               TextField(
//                 controller: _nameController,
//                 focusNode: _focusNode,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 18,
//                   fontWeight: FontWeight.w500,
//                 ),
//                 textAlign: TextAlign.center,
//                 maxLength: 20,
//                 decoration: InputDecoration(
//                   hintText: 'Your Hero Name',
//                   hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
//                   filled: true,
//                   fillColor: Colors.black.withOpacity(0.5),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(15),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(15),
//                     borderSide: const BorderSide(color: Colors.blue, width: 2),
//                   ),
//                   contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 20,
//                     vertical: 15,
//                   ),
//                   counterStyle: TextStyle(color: Colors.grey[400]),
//                 ),
//                 onSubmitted: (value) => _submitName(),
//               ),

//               const SizedBox(height: 40),

//               // Buttons row
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   // Back button
//                   ElevatedButton.icon(
//                     onPressed: widget.onBack,
//                     icon: const Icon(Icons.arrow_back, size: 20),
//                     label: const Text(
//                       'BACK',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.grey[700],
//                       foregroundColor: Colors.white,
//                       minimumSize: const Size(120, 50),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(25),
//                       ),
//                     ),
//                   ),

//                   // OK button
//                   ElevatedButton.icon(
//                     onPressed: _submitName,
//                     icon: const Icon(Icons.check, size: 20),
//                     label: const Text(
//                       'OK',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color.fromARGB(255, 119, 227, 123),
//                       foregroundColor: Colors.white,
//                       minimumSize: const Size(120, 50),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(25),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

//----------------------------------------------------------------
// class PlayerNameDisplay extends PositionComponent {
//   final String playerName;

//   PlayerNameDisplay({required this.playerName});

//   @override
//   Future<void> onLoad() async {
//     final nameText = TextComponent(
//       text: 'Player: $playerName',
//       position: Vector2(20, 120),
//       textRenderer: TextPaint(
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 20,
//           fontWeight: FontWeight.w600,
//           shadows: [
//             Shadow(
//               offset: Offset(1, 1),
//               blurRadius: 3,
//               color: Colors.black.withOpacity(0.8),
//             ),
//           ],
//         ),
//       ),
//     );
//     add(nameText);
//   }
// }

  // void updatePlayerName(String name) {
  //   playerName = name;
  //   // Update the UI to show the new player name
  //   removeAll(children.whereType<PlayerNameDisplay>());
  //   add(PlayerNameDisplay(playerName: playerName));
  // }

    //   // Add player name display if name is available
    // if (playerName.isNotEmpty) {
    //   add(PlayerNameDisplay(playerName: playerName));
    // }
//----------------------------------------------------------------
// class LevelBackground extends Component {
//   @override
//   Future<void> onLoad() async {
//     // Empty screen as requested - just a solid color background
//     final background = RectangleComponent(
//       size: Vector2(1000, 1000), // Large enough to cover screen
//       paint: Paint()
//         ..color = Color(0xFF34495E), // Slightly lighter than game background
//       position: Vector2.zero(),
//     );
//     add(background);
//   }
// }
//----------------------------------------------------------------


    // // Add UI buttons (Pause and Exit)
    // gameUI = GameUI(
    //   onPause: () {
    //     pauseGame();
    //     onPauseGame();
    //   },
    //   onExit: onShowMainMenu,
    // );
    // add(gameUI);

//     class GameUI extends PositionComponent {
//   final VoidCallback onPause;
//   final VoidCallback onExit;

//   GameUI({required this.onPause, required this.onExit});

//   @override
//   Future<void> onLoad() async {
//     // Pause Button
//     final pauseButton = ButtonComponent(
//       button: RectangleComponent(
//         size: Vector2(100, 45),
//         paint: Paint()..color = Colors.amber,
//       ),
//       buttonDown: RectangleComponent(
//         size: Vector2(100, 45),
//         paint: Paint()..color = Colors.amber.withOpacity(0.7),
//       ),
//       onPressed: onPause,
//       position: Vector2(20, 20),
//     );

//     final pauseText = TextComponent(
//       text: 'PAUSE',
//       position: Vector2(35, 35),
//       textRenderer: TextPaint(
//         style: TextStyle(
//           color: Colors.black,
//           fontSize: 16,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );

//     // Exit Button
//     final exitButton = ButtonComponent(
//       button: RectangleComponent(
//         size: Vector2(100, 45),
//         paint: Paint()..color = Colors.redAccent,
//       ),
//       buttonDown: RectangleComponent(
//         size: Vector2(100, 45),
//         paint: Paint()..color = Colors.redAccent.withOpacity(0.7),
//       ),
//       onPressed: onExit,
//       position: Vector2(140, 20),
//     );

//     final exitText = TextComponent(
//       text: 'EXIT',
//       position: Vector2(165, 35),
//       textRenderer: TextPaint(
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 16,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );

//     add(pauseButton);
//     add(pauseText);
//     add(exitButton);
//     add(exitText);
//   }
// }
//---------------------------------------------------------------- 



      