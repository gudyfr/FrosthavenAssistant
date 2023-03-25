import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Model/character_class.dart';
import 'package:frosthaven_assistant/Resource/stat_calculator.dart';
import 'package:frosthaven_assistant/Resource/state/character.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

final _getIt = GetIt.instance;

@GenerateNiceMocks(
    [MockSpec<GameState>(), MockSpec<Character>(), MockSpec<CharacterClass>()])
void main() {

  test('C>2 returns false for 2 characters', () {
    var characterClass = MockCharacterClass();
    when(characterClass.name).thenReturn("not escort");
    var character1 = MockCharacter();
    when(character1.characterClass).thenReturn(characterClass);
    var character2 = MockCharacter();
    when(character2.characterClass).thenReturn(characterClass);
    var character3 = MockCharacter();
    when(character3.characterClass).thenReturn(characterClass);
    var character4 = MockCharacter();
    when(character4.characterClass).thenReturn(characterClass);

    var twoCharacterList = [character1, character2];
    var threeCharacterList = [character1, character2, character3];
    var fourCharacterList = [character1, character2, character3, character4];
  //arrange
  const message = "TestMessage";
  final stubGameState = MockGameState();
  _getIt.registerFactory<GameState>(() => stubGameState);
  when(stubGameState.level).thenReturn(ValueNotifier(2));
  when(stubGameState.currentList).thenReturn(twoCharacterList);

  //act
  assert(StatCalculator.evaluateCondition("C>2"));
  });
}