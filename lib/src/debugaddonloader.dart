import 'package:dictionaries/addons.dart';
import 'package:make_root_say_banana/make_root_say_banana.dart' as make_root_say_banana;

List<DictionariesAddon> loadDebugAddons() => [
  make_root_say_banana.load(),
];