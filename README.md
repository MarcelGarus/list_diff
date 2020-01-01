Offers a `diff` method that accepts two `List`s and returns a list of
`Operation`s for turning the first list into the second one:

```dart
var operations = await diff(
  ['coconut', 'nut', 'peanut'],
  ['kiwi', 'coconut', 'maracuja', 'nut', 'banana'],
);
operations.forEach(print);

// Operations:
// Insertion of kiwi at 0.
// Insertion of maracuja at 2.
// Insertion of banana at 4.
// Deletion of peanut at 5.
```

`Operation`s are either an insertion or deletion of an item at an index. You
can also directly apply them to a list:

```dart
// Let's try it out!
var fruitBowl = ['coconut', 'nut', 'peanut'];

for (var operation in operations) {
  fruitBowl.apply(operation);
}

// Transforming:
// [coconut, nut, peanut]
// [kiwi, coconut, nut, peanut]
// [kiwi, coconut, maracuja, nut, peanut]
// [kiwi, coconut, maracuja, nut, banana, peanut]
// [kiwi, coconut, maracuja, nut, banana]
```

The lists' items are compared using their `==` operator and `hashCode` by default.
But you can specify a custom comparison method and hash code:

```dart
var operations = await diff(
  first,
  second,
  areEqual: (a, b) => ...,
  getHashCode: (a) => ...,
);
```

### A word about performance and threading

I'm not sure the current version is as performant as it could be.
The runtime is currently O(N*M), where N and M are the lengths of the lists.
If you know a better algorithm, feel welcome to open an issue or file a pull request.

If the data sets are large, the `diff` function automatically spawns an
isolate. If you want more control on whether an isolate should be
spawned, you can also explicitly set the `spawnIsolate` parameter:

```dart
var operations = await diff(first, second, spawnIsolate: true);
```

### For Flutter users

`diff` can be used to calculate updates for an `AnimatedList`.
The [implicitly_animated_list](https://pub.dev/packages/implicitly_animated_list) package does that for you.
