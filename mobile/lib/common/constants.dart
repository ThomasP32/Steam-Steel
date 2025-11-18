// ignore_for_file: constant_identifier_names : const

const int DEFAULT_HP = 4;

const int DEFAULT_SPEED = 4;

const int DEFAULT_ATTACK = 4;

const int DEFAULT_DEFENSE = 4;

const int MAXIMUM_BONUS = 6;

const int MINIMUM_BONUS = 4;

const int DEFAULT_EVASIONS = 2;

const int DEFAULT_ACTIONS = 1;

const int SWORD_ATTACK_BONUS = 2;

const int SWORD_SPEED_BONUS = 1;

const int ARMOR_DEFENSE_BONUS = 2;

const int ARMOR_SPEED_PENALTY = 1;

const int FLASK_ATTACK_BONUS = 2;

const int AMULET_LIFE_BONUS = 2;

const int ICE_ATTACK_PENALTY = 2;

const int ICE_DEFENSE_PENALTY = 2;

const int INVENTORY_SIZE = 2;

const int BONUS = 2;

const int TURN_DURATION = 30;

const int DELAY = 3;

const int MAX_CHAR = 2;

const int COUNTDOWN_NOEVASION_DURATION = 3;

const int COUNTDOWN_COMBAT_DURATION = 5;

const double EVASION_SUCCESS_RATE = 0.4;

const int DEFENDING_PLAYER_LIFE = 2;

const int ROLL_DICE_CONSTANT = 1;

const int SUFFIX_INCREMENT = 1;

const int SUFFIX_VALUE = 10;

const int BONUS_REDUCTION = 2;

const int MINIMUM_MOVES = 1;

const double CONTINUE_ODDS = 0.4;

const double HALF = 0.5;

const int N_WIN_VICTORIES = 3;

const int N_WINS_PER_LEVEL = 5;

const int N_LEVEL_BANNER = 5;
const int MAX_LEVEL = 25;

const List<String> CHAT_REACTIONS = ['👍', '❤️', '🤡', '💀'];

enum ProfileType {
  aggressive('aggressive'),
  defensive('defensive'),
  normal('');

  const ProfileType(this.value);
  final String value;
}

enum BotName {
  atlas('Atlas'),
  nova('Nova'),
  cipher('Cipher'),
  echo('Echo'),
  zephyr('Zephyr'),
  vortex('Vortex'),
  blaze('Blaze'),
  phoenix('Phoenix'),
  titan('Titan'),
  shadow('Shadow');

  const BotName(this.displayName);
  final String displayName;
}
