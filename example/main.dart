import 'package:list_diff/list_diff.dart';

void main() async {
  var nutMix = ['coconut', 'nut', 'peanut'];
  var tropic = ['kiwi', 'coconut', 'maracuja', 'nut', 'banana'];

  // Now, let's turn the nut mix into the tropical mix.
  var recipe = await diff(nutMix, tropic);

  // Let's try it out!
  var bowl = List<String>.from(nutMix);
  print(bowl);

  for (var operation in recipe) {
    operation.applyTo(bowl);
    print('$operation\n$bowl');
  }

  // Output:
  // [coconut, nut, peanut]
  // Insertion of kiwi at 0.
  // [kiwi, coconut, nut, peanut]
  // Insertion of maracuja at 2.
  // [kiwi, coconut, maracuja, nut, peanut]
  // Insertion of banana at 4.
  // [kiwi, coconut, maracuja, nut, banana, peanut]
  // Deletion of peanut at 5.
  // [kiwi, coconut, maracuja, nut, banana]
}
