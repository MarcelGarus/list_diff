import 'dart:math';

import 'package:list_diff/list_diff.dart';

Future<void> main() async {
  var random = Random();
  var first = List.generate(1000, (_) => random.nextInt(100));
  var second = List.generate(1000, (_) => random.nextInt(100));

  print('Calculating operations on other isolate.');
  var operations = await diff(first, second, spawnIsolate: true);
  print('${operations.length} operations needed.');
}
