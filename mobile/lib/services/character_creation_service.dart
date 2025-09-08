import 'package:mobile/common/constants.dart';
import 'package:mobile/common/game.dart';

class CharacterCreationService {
  Specs assignBonus(Specs specs, String type) {
    if (type == 'life') {
      specs
        ..life = DEFAULT_HP + BONUS
        ..speed = DEFAULT_SPEED;
    } else {
      specs
        ..speed = DEFAULT_SPEED + BONUS
        ..life = DEFAULT_HP;
    }
    return specs;
  }

  Specs assignDice(Specs specs, String which) {
    if (which == 'attack') {
      specs
        ..attackBonus = Bonus.d6
        ..defenseBonus = Bonus.d4;
    } else {
      specs
        ..attackBonus = Bonus.d4
        ..defenseBonus = Bonus.d6;
    }
    return specs;
  }
}
