import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../Resource/state/game_state.dart';
import '../Resource/settings.dart';
import '../services/service_locator.dart';

class PlayButton extends StatefulWidget {
  final String icon;
  final double width = 40;
  final double borderWidth = 2;

  const PlayButton({Key? key, required this.icon}) : super(key: key);

  @override
  AnimatedContainerButtonState createState() => AnimatedContainerButtonState();
}

class AnimatedContainerButtonState extends State<PlayButton> {
  // Define the various properties with default values. Update these properties
  // when the user taps a FloatingActionButton.
  final GameState _gameState = getIt<GameState>();
  final Settings settings = getIt<Settings>();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: EdgeInsets.only(right: 2 * settings.userScalingBars.value),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InkWell(
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              focusColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTapDown: (TapDownDetails details) {
                _gameState.pauseAudio();
              },
              child: StreamBuilder<PlayerState>(
                stream: _gameState.getPlayerStateStream(),
                  builder: (context, asyncSnapshot) {
                    Color? color;
                    if (asyncSnapshot.data == PlayerState.playing) {
                      color = Colors.black;
                    } else {
                      color = Colors.grey;
                    }

                    return Image(
                      //fit: BoxFit.contain,
                      height:
                          widget.width * settings.userScalingBars.value * 0.65,
                      image: AssetImage(widget.icon),
                      color: color,
                      width:
                          widget.width * settings.userScalingBars.value * 0.65,
                    );
                  }),
            ),
            SizedBox(width: 100),
          ],
        ));
  }
}
