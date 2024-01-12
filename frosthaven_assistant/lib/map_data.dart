import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:frosthaven_assistant/Model/MonsterAbility.dart';
import 'package:frosthaven_assistant/Model/campaign.dart';
import 'package:frosthaven_assistant/Model/character_class.dart';
import 'package:frosthaven_assistant/Model/monster.dart';
import 'package:frosthaven_assistant/Model/scenario.dart';
import 'package:frosthaven_assistant/Model/summon.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  final output = <String, dynamic>{};
  output['monsters'] = {};
  output['decks'] = {};
  output['scenarios'] = {};
  output['characters'] = {};

  var editions = {"Solo", "Frosthaven"};
  for(var edition in editions) {
    final String response = await rootBundle
        .loadString('assets/data/editions/$edition.json', cache: false);
    final data = await json.decode(response);
    final model = CampaignModel.fromJson(data, const []);

    output['monsters'].addAll({
      for (var e in model.monsters.values.map((e) =>
          convertMonster(e))) e['internal']: e
    });

    output['decks'].addAll({
      for (var e in model.monsterAbilities.map((e) =>
          convertDeck(e))) e['name']: e
    });

    output['scenarios'].addAll(
        model.scenarios.map((k, v) => MapEntry(k, convertScenario(v))));

    output['characters'].addAll({
      for (var e in model.characters.map((e) =>
          convertCharacter(e))) e['name']: e
    });

  }

  File("D:/fhtts/docs/gameData.json").writeAsString(json.encode(output));
  var encoder = JsonEncoder.withIndent("\t");
  File("D:/fhtts/gameData.human.json").writeAsString(encoder.convert(output));
  debugPrint("Done !");
}

convertMonster(MonsterModel model) {
  var output = <String, dynamic>{};
  output["name"] = model.display;
  output["internal"] = model.name;
  output["maxInstances"] = model.count;
  output['deck'] = model.deck;
  output['levels'] = model.levels.map((e) => convertMonsterLevelModel(e)).toList();
  return output;
}

convertMonsterLevelModel(MonsterLevelModel model) {
  var output = <String,dynamic>{};
  if (model.normal != null) {
    output['normal'] = convertMonsterStatsModel(model.normal!);
  }
  if (model.elite != null) {
    output['elite'] = convertMonsterStatsModel(model.elite!);
  }
  if (model.boss != null) {
    output['boss'] = convertMonsterStatsModel(model.boss!);
  }
  output['level'] = model.level;
  return output;
}

convertMonsterStatsModel(MonsterStatsModel model) {
  var output = <String,dynamic>{};
  var hp = model.health.toString().replaceAll("x", "*");
  if (hp.endsWith("d2")) {
    hp = "floor(${hp.substring(0,hp.length-2)}/2)";
  }
  output['hp'] = hp;

  if (model.immunities.isNotEmpty) {
    output['immunities'] =
        model.immunities.map((e) => e.replaceAll("%", "")).toList();
  }
  var conditions = List<String>.empty(growable: true);
  for(var entry in model.attributes) {
    entry = entry.replaceAll("%", "");
    var candidates = ["shield", "retaliate", "pierce"];
    var found = false;
    for(var candidate in candidates) {
      if(entry.startsWith(candidate)) {
        output[candidate] = int.parse(entry.substring(candidate.length+1));
        found = true;
      }
    }
    if (!found) {
      conditions.add(entry);
    }
  }
  return output;
}

convertDeck(MonsterAbilityDeckModel model) {
  var output = <String,dynamic>{};
  output['name'] = model.name;
  output['cards'] = model.cards.map((e) => convertCard(e)).toList();
  return output;
}

convertCard(MonsterAbilityCardModel model) {
  return [model.nr, model.shuffle, model.initiative];
}

convertScenario(ScenarioModel model) {
  var output = <String, dynamic>{};
  output['name'] = model.name;
  output['monsters'] = model.monsters;
  if (model.lootDeck != null) {
    output['loot'] = convertLootDeck(model.lootDeck!);
  }
  output['specials'] = convertSpecials(model.specialRules);
  if(model.sections.isNotEmpty) {
    output['sections'] =
        {for (var s in model.sections.map((e) => convertScenario(e))) s['name'] : s};
  }
  return output;
}

convertLootDeck(LootDeckModel model) {
  return [
    model.arrowvine,
    model.axenut,
    model.coin,
    model.corpsecap,
    model.flamefruit,
    model.hide,
    model.lumber,
    model.metal,
    model.rockroot,
    model.snowthistle,
    model.treasure
  ];
}

convertSpecials(List<SpecialRule> l) {
  return l.map((e) => convertSpecial(e)).toList();
}

convertSpecial(SpecialRule e) {
  var output = <String, dynamic>{};
  output['type'] = e.type;

  if(e.list.isNotEmpty) {
    output['list'] = e.list;
  }

  if(e.type == "levelAdjust") {
    output['level'] = e.level;
  }

  if (e.condition != "") {
    output['condition'] = e.condition;
  }

  if (e.name != "") {
    output['name'] = e.name;
  }

  if (e.health != "") {
    var hp = e.health.toString().replaceAll("x", "*");
    if (hp.endsWith("d2")) {
      hp = "floor(${hp.substring(0,hp.length-2)}/2)";
    }
    output['hp'] = hp;
  }

  if(e.type == "Timer") {
    output['startOfRound'] = e.startOfRound;
  }

  if (e.note != "") {
    if(e.notes.isNotEmpty) {
      output['notes'] = e.notes.toList();
    } else {
      output['note'] = e.note;
    }
  }
  if(e.init != 99) {
    output['init'] = e.init;
  }

  return output;
}

convertCharacter(CharacterClass e) {
  var output = <String, dynamic>{};
  output['name'] = e.name;
  output['hps'] = e.healthByLevel;
  output['summons'] = e.summons.map((e) => convertSummon(e)).toList();
  return output;
}

convertSummon(SummonModel e) {
  var output = <String, dynamic>{};
  output['name'] = e.name;
  output['hp'] = e.health;
  output['maxInstances'] = e.standees;
  return output;
}