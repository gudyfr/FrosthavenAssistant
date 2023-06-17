import 'dart:collection';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/assertions.dart';
import 'package:frosthaven_assistant/Layout/monster_ability_card.dart';
import 'package:frosthaven_assistant/Layout/monster_stat_card.dart';
import 'package:frosthaven_assistant/Layout/monster_widget.dart';
import 'package:frosthaven_assistant/Model/MonsterAbility.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/Resource/state/monster.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path/path.dart' as p;

import '../Resource/color_matrices.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ScreenshotController screenshotController = ScreenshotController();
  setupGetIt();
  var gameState = getIt<GameState>();
  gameState.modelData.addListener(() async {
    var documentsPath = await getApplicationDocumentsDirectory();
    var abilityCardsOutputFolder =
    p.join(documentsPath.path, "frosthaven", "abilityCards");
    var statsCardsOutputFolder =
    p.join(documentsPath.path, "frosthaven", "statsCards");
    await Directory(abilityCardsOutputFolder).create(recursive: true);
    await Directory(statsCardsOutputFolder).create(recursive: true);
    var editions = ['Frosthaven', 'Solo'];
    Map<String, List<MonsterAbilityCardModel>> abilityCards = HashMap();
    for(var edition in editions) {
      var model = gameState.modelData.value[edition];
      if (model != null) {
        for (var deck in model.monsterAbilities) {
          abilityCards[deck.name] = deck.cards;
        }
      }
    }

    for(var edition in editions) {
      var model = gameState.modelData.value[edition];
      if (model != null) {
        var monsters = model.monsters;
        for (var name in monsters.keys) {
          var monster = monsters[name];
          if (monster != null) {
            debugPrint("$name -> ${monster.name} (Deck : ${monster.deck})");
            var monsterAbilityCards = abilityCards[monster.deck];
            if (monsterAbilityCards != null) {
              for (var level in monster.levels) {
                var monsterInstance =
                GameMethods.createMonster(monster.name, level.level, false);
                if (monsterInstance != null) {
                  for (var monsterAbilityCard in monsterAbilityCards) {
                    var outputPath = p.join(abilityCardsOutputFolder,
                        "${monster.name}_${level.level}_${monsterAbilityCard
                            .nr}.png");
                    if (!await File(outputPath).exists()) {
                      var content = await screenshotController
                          .captureFromWidget(
                          MonsterAbilityCardWidget.buildFront(
                              monsterAbilityCard, monsterInstance, 1.0, true),
                          pixelRatio: 4.0);

                      File(outputPath).writeAsBytes(content);
                    } else {
                      debugPrint(
                          "Skipping ${monster.name}_${level
                              .level}_${monsterAbilityCard.nr}");
                    }
                  }

                  // Stats Card
                  var outputPath = p.join(statsCardsOutputFolder,
                      "${monster.name}_${level.level}.png");
                  if (!await File(outputPath).exists()) {
                    var content = await screenshotController.captureFromWidget(
                        MonsterStatCardWidget(data: monsterInstance),
                        pixelRatio: 2.0);

                    File(outputPath).writeAsBytes(content);
                  } else {
                    debugPrint("Skipping ${monster.name}_${level.level}");
                  }

                  // Monster image
                  outputPath =
                      p.join(statsCardsOutputFolder, "${monster.name}.png");
                  if (!await File(outputPath).exists()) {
                    var content = await screenshotController.captureFromWidget(
                        buildImagePart(monsterInstance, 120, 2.0, false),
                        pixelRatio: 2.0);

                    File(outputPath).writeAsBytes(content);
                  }

                  outputPath =
                      p.join(
                          statsCardsOutputFolder, "${monster.name}.grey.png");
                  if (!await File(outputPath).exists()) {
                    var content = await screenshotController.captureFromWidget(
                        buildImagePart(monsterInstance, 120, 2.0, true),
                        pixelRatio: 2.0);

                    File(outputPath).writeAsBytes(content);
                  }
                }
              }
            }
          }
        }
      }
    }
  });
}

Widget buildImagePart(Monster data, double height, double scale, bool grey) {
  bool frosthavenStyle = GameMethods.isFrosthavenStyle(data.type);
  return ColorFiltered(
      colorFilter:
          grey ? ColorFilter.matrix(grayScale) : ColorFilter.matrix(identity),
      child: Stack(alignment: Alignment.bottomCenter, children: [
        Container(
            height: height,
            margin: EdgeInsets.only(bottom: 4 * scale, top: 4 * scale),
            child: PhysicalShape(
              color: Colors.transparent,
              //or bleu if current
              shadowColor: Colors.black,
              elevation: 8,
              clipper: const ShapeBorderClipper(shape: CircleBorder()),
              child: Container(
                margin: EdgeInsets.only(bottom: 0 * scale, top: 2 * scale),
                child: Image(
                  fit: BoxFit.contain,
                  height: height,
                  width: height,
                  image:
                      AssetImage("assets/images/monsters/${data.type.gfx}.png"),
                  //width: widget.height*0.8,
                ),
              ),
            )),
        Container(
            width: height * 0.95,
            height: height,
            alignment: Alignment.bottomCenter,
            margin: EdgeInsets.only(bottom: frosthavenStyle ? 2 * scale : 0),
            child: Text(
              textAlign: TextAlign.center,
              data.type.display,
              style: TextStyle(
                  fontFamily: frosthavenStyle ? "GermaniaOne" : 'Pirata',
                  color: Colors.white,
                  fontSize: 10 * scale,
                  shadows: [
                    Shadow(
                      offset: Offset(1 * scale, 1 * scale),
                      color: Colors.black87,
                      blurRadius: 1 * scale,
                    )
                  ]),
            ))
      ]));
}
