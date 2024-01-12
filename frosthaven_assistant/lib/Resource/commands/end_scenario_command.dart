import '../../services/service_locator.dart';
import '../action_handler.dart';
import '../state/game_state.dart';

class EndScenarioCommand extends Command {
  final GameState _gameState = getIt<GameState>();

  EndScenarioCommand();

  @override
  void execute() {
    GameMethods.resetGameState();
    _gameState.updateList.value++;
  }

  @override
  void undo() {
    _gameState.updateList.value++;
  }

  @override
  String describe() {
    return "End Scenario";
  }
}