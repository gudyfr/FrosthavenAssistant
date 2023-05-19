import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:frosthaven_assistant/Model/MonsterAbility.dart';
import 'package:frosthaven_assistant/Model/campaign.dart';
import 'package:frosthaven_assistant/Model/monster.dart';
import 'package:frosthaven_assistant/Model/scenario.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final String response = await rootBundle
      .loadString('assets/data/editions/Frosthaven.json', cache: false);
  final data = await json.decode(response);
  final model = CampaignModel.fromJson(data, const []);
  final output = <String, dynamic>{};

  output['monsters'] = model.monsters.values.map((e) => convertMonster(e)).toList();
  output['decks'] = model.monsterAbilities.map((e) => convertDeck(e)).toList();
  output['scenarios'] = model.scenarios.map((k,v) => MapEntry(k, convertScenario(v)));
  File("out.json").writeAsString(json.encode(output));
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
  output['hp'] = model.health;
  if (model.immunities.length > 0) {
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
  var output = <String,dynamic>{};
  output['monsters'] = model.monsters;
  if (model.lootDeck != null) {
    output['loot'] = convertLootDeck(model.lootDeck!);
  }
  return output;
}

convertLootDeck(LootDeckModel model) {
  return [model.arrowvine, model.axenut, model.coin, model.corpsecap, model.flamefruit, model.hide, model.lumber, model.metal, model.rockroot, model.snowthistle, model.treasure];
}