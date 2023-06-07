
import 'dart:math';

import 'package:frosthaven_assistant/Model/monster.dart';

import '../../services/service_locator.dart';
import '../enums.dart';
import '../stat_calculator.dart';
import 'character.dart';
import 'figure_state.dart';
import 'game_state.dart';
import 'monster.dart';

class MonsterInstance extends FigureState {
  MonsterInstance(this.standeeNr, this.type, bool summoned, Monster monster) {
    setLevel(monster);
    gfx = monster.type.gfx;
    name = monster.type.name;
    move = 0; //only used for summons
    attack = 0;
    range = 0;
    if(summoned) {
      roundSummoned = getIt<GameState>().round.value;
    } else {
      roundSummoned = -1;
    }
  }

  MonsterInstance.summon(this.standeeNr, this.type, this.name, int summonHealth, this.move, this.attack, this.range, this.gfx, this.roundSummoned) {
    //deal with summon init
    maxHealth.value = summonHealth;
    health.value = summonHealth;
  }

  String getId(){
    return name + gfx + standeeNr.toString();
  }

  late final int standeeNr;
  late MonsterType type;
  late final String name;
  late final String gfx;

  //summon stats
  late int move;
  late int attack;
  late int range;
  int roundSummoned = -1;

  void setLevel(Monster monster) {
    var damage = maxHealth.value - health.value;
    dynamic newHealthValue = 10; //need to put something outer than 0 or the standee will die immediately causing glitch
    MonsterStatsModel? monsterStatsModel;
    switch(type) {
      case MonsterType.boss :
        monsterStatsModel = monster.type.levels[monster.level.value].boss!;
        break;
      case MonsterType.elite :
        monsterStatsModel = monster.type.levels[monster.level.value].elite!;
        break;
      case  MonsterType.normal :
        monsterStatsModel = monster.type.levels[monster.level.value].normal!;
        break;
    }
    if(monsterStatsModel != null) {
      newHealthValue = monsterStatsModel.health;
      for (var attribute in monsterStatsModel.attributes) {
        if (attribute.startsWith("%shield% ")) {
          baseShield.value = int.parse(attribute.substring("%shield% ".length));
        } else if (attribute.startsWith("%retaliate% ")) {
          baseRetaliate.value =
              int.parse(attribute.substring("%retaliate% ".length));
        }
      }
    }
    int? value = StatCalculator.calculateFormula(newHealthValue);
    if (value != null) {
      maxHealth.value = value;
    } else {
      //handle edge case
      if(newHealthValue == "Hollowpact"){
        int value = 7;
        for(var item in getIt<GameState>().currentList) {
          if(item is Character && item.id == "Hollowpact") {
            value = item.characterClass.healthByLevel[item.characterState.level.value-1];
            break;
          }
        }
        maxHealth.value = value;
      }
      if(newHealthValue == "Incarnate"){
        int value = 36; //double Incarante's level 5 health
        for(var item in getIt<GameState>().currentList) {
          if(item is Character && item.id == "Incarnate") {
            value = item.characterClass.healthByLevel[item.characterState.level.value-1] * 2;
            break;
          }
        }
        maxHealth.value = value;
      }

    }
    //maxHealth.value = StatCalculator.calculateFormula(newHealthValue)!;
    level.value = monster.level.value;
    health.value = max(1, maxHealth.value - damage);
  }

  @override
  String toString() {
    return '{'
        '"health": ${health.value}, '
        '"maxHealth": ${maxHealth.value}, '
        '"baseShield": ${baseShield.value}, '
        '"baseRetaliate": ${baseRetaliate.value}, '
        '"level": ${level.value}, '
        '"standeeNr": $standeeNr, '
        '"move": $move, '
        '"attack": $attack, '
        '"range": $range, '
        '"name": "$name", '
        '"gfx": "$gfx", '
        '"roundSummoned": $roundSummoned, '
        '"type": ${type.index}, '
        '"chill": ${chill.value}, '
        '"conditions": ${conditions.value.toString()}, '
        '"conditionsAddedThisTurn": ${conditionsAddedThisTurn.value.toList().toString()}, '
        '"conditionsAddedPreviousTurn": ${conditionsAddedPreviousTurn.value.toList().toString()} '
        '}';
  }

  MonsterInstance.fromJson(Map<String, dynamic> json) {
    standeeNr = json["standeeNr"];
    health.value = json["health"];
    level.value = json["level"];
    maxHealth.value = json["maxHealth"];
    name = json["name"];
    gfx = json["gfx"];
    type = MonsterType.values[json["type"]];
    move = json["move"];
    attack = json["attack"];
    range = json["range"];
    baseShield.value = json["baseShield"] ?? 0;
    baseRetaliate.value = json["baseRetaliate"] ?? 0;
    if(json.containsKey("roundSummoned")) {
      roundSummoned = json["roundSummoned"];
    } else {
      roundSummoned = -1;
    }
    chill.value = json["chill"];
    List<dynamic> condis = json["conditions"];
    for(int item in condis){
      conditions.value.add(Condition.values[item]);
    }

    if(json.containsKey("conditionsAddedThisTurn")) {
      List<dynamic> condis2 = json["conditionsAddedThisTurn"];
      for (int item in condis2) {
        conditionsAddedThisTurn.value.add(Condition.values[item]);
      }
    }
    if(json.containsKey("conditionsAddedPreviousTurn")) {
      List<dynamic> condis3 = json["conditionsAddedPreviousTurn"];
      for (int item in condis3) {
        conditionsAddedPreviousTurn.value.add(Condition.values[item]);
      }
    }
  }

}