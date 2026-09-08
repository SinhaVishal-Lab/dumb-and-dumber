import 'package:dumb_and_dumber/Screens/main_menu_screen.dart';
import 'package:dumb_and_dumber/Screens/name_input_screen.dart';
import 'package:dumb_and_dumber/Screens/pause_screen.dart';
import 'package:dumb_and_dumber/dumb_and_dumber.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class GameWrapper extends StatefulWidget {
  const GameWrapper({super.key});

  @override
  State<GameWrapper> createState() => _GameWrapperState();
}

class _GameWrapperState extends State<GameWrapper> {
  late DumbandDumber game;
  bool showMainMenu = true;
  bool showNameInput = false;
  bool gameStarted = false;
  bool gamePaused = false;
  String playerName = 'Sakamoto';

  @override
  void initState() {
    super.initState();
    game = DumbandDumber(
      onShowMainMenu: () {
        setState(() {
          showMainMenu = true;
          showNameInput = false;
          gameStarted = false;
          gamePaused = false;
        });
      },
      onPauseGame: () {
        setState(() {
          gamePaused = true;
        });
      },
      onResumeGame: () {
        setState(() {
          gamePaused = false;
        });
      },
      playerName: playerName,
    );
  }

  void showNameInputScreen() {
    setState(() {
      showMainMenu = false;
      showNameInput = true;
    });
  }

  void startGameWithName(String name) {
    setState(() {
      playerName = name;
      showNameInput = false;
      gameStarted = true;
      gamePaused = false;
    });
    // A fresh run: the tally, the contracts and the level all reset. Before
    // the game has finished loading this only records the name, and onLoad
    // picks the prologue up from there.
    game.startNewRun(name);
  }

  void resumeGame() {
    setState(() {
      showMainMenu = false;
      gamePaused = false;
    });
    game.resumeGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (gameStarted) GameWidget(game: game),
          if (showMainMenu)
            MainMenuScreen(
              onPlay: showNameInputScreen,
              onResume: gameStarted ? resumeGame : null,
            ),
          if (showNameInput)
            NameInputScreen(
              onNameSubmit: startGameWithName,
              onBack: () {
                setState(() {
                  showMainMenu = true;
                  showNameInput = false;
                });
              },
            ),
          if (gamePaused && !showMainMenu && !showNameInput)
            PauseMenuScreen(
              onResume: () {
                setState(() {
                  gamePaused = false;
                });
                game.resumeGame();
              },
              onMainMenu: () {
                setState(() {
                  showMainMenu = true;
                  gamePaused = false;
                });
              },
            ),
        ],
      ),
    );
  }
}
