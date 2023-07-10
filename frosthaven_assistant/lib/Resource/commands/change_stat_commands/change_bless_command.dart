import '../../../services/service_locator.dart';
import '../../state/game_state.dart';
import '../../state/modifier_deck_state.dart';
import '../../state/monster.dart';
import 'change_stat_command.dart';

class ChangeBlessCommand extends ChangeStatCommand {
  ModifierDeck? deck;
  ChangeBlessCommand(super.change, super.figureId, super.ownerId);
  ChangeBlessCommand.deck(this.deck) : super(0, '', '');

  @override
  void execute() {
    //Figure figure = getFigure(ownerId, figureId)!;
    if (deck == null) {
      deck = getIt<GameState>().modifierDeck;
      for (var item in getIt<GameState>().currentList) {
        if (item.id == ownerId) {
          if (item is Monster && item.isAlly) {
            deck = getIt<GameState>().modifierDeckAllies;
          }
        }
      }
    }

    deck!.blesses.value += change;
  }

  @override
  void undo() {
    //stat.value -= change;
    getIt<GameState>().updateList.value++;
  }

  @override
  String describe() {
    if (change > 0) {
      return "Add a Bless";
    }
    return "Remove a Bless";
  }
}
