Offers a `diff` method that accepts two `List`s and returns a list of
`Operation`s for turning the first list into the second one:

```dart
var operations = await diff(
  ['coconut', 'nut', 'peanut'],
  ['kiwi', 'coconut', 'maracuja', 'nut', 'banana'],
);
operations.forEach(print);

// Output:
// Insertion of kiwi at 0.
// Insertion of maracuja at 2.
// Insertion of banana at 4.
// Deletion of peanut at 5.
```

`Operation`s are either an insertion or deletion of an item at an index. You
can also directly apply them to a list:

```dart
// Let's try it out!
var fruitBowl = List<String>.from(nutMix);
print(fruitBowl);

for (var operation in operations) {
    operation.applyTo(fruitBowl);
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
```

The lists' items are compared using their `==` operator.

### A word about performance and threading

The current version of the function is not as performant as it could be.
The runtime is currently O(N*M), where N and M are the lengths of the lists.

If you're handling large data sets, better run this on a background isolate by
setting [useSeparateIsolate] to [true]:

```dart
var operations = await diff(first, second, useSeparateIsolate: true);
```

### For Flutter users

[diff] can be used to calculate updates for an [AnimatedList]:

```dart
final _listKey = GlobalKey<AnimatedListState>();
List<String> _lastFruits;
...
StreamBuilder<String>(
  stream: fruitStream,
  initialData: [],
  builder: (context, snapshot) {
    for (var operation in await diff(_lastFruits, snapshot.data)) {
      if (operation.isInsertion) {
        _listKey.insertItem(operation.index);
      } else {
        _listKey.removeItem(operation.index, (context, animation) => ...);
      }
    }
    return AnimatedList(
      key: _listKey,
      itemBuilder: (context, index, animation) => ...,
    );
  },
),
```
