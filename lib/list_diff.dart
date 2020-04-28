/// Offers the [diff] function, which calculates a minimal list of [Operation]s
/// that convert one list into another.
library list_diff;

import 'dart:isolate';

import 'package:async/async.dart';
import 'package:meta/meta.dart';

part 'calculate.dart';
part 'isolated.dart';
part 'operation.dart';
part 'trim.dart';

/// Calculates a minimal list of [Operation]s that convert the [oldList] into
/// the [newList].
///
/// ```
/// var operations = await diff(
///   ['coconut', 'nut', 'peanut'],
///   ['kiwi', 'coconut', 'maracuja', 'nut', 'banana'],
/// );
///
/// // Operations:
/// // Insertion of kiwi at 0.
/// // Insertion of maracuja at 2.
/// // Insertion of banana at 4.
/// // Deletion of peanut at 5.
/// ```
///
/// [Items] are compared using [areEqual] and [getHashCode] functions or the
/// [Item]'s [==] operator if parameters aren't specified.
///
/// This function uses a variant of the Levenshtein algorithm to find the
/// minimum number of operations. This is a simple solution. If you need a more
/// performant solution, such as Myers' algorith, your're welcome to contribute
/// to this library at https://github.com/marcelgarus/list_diff.
///
/// If the lists are large, this operation may take some time so if you're
/// handling large data sets, better run this on a background isolate by
/// setting [spawnIsolate] to [true]:
///
/// ```
/// var operations = await diff(first, second, useSeparateIsolate: true);
/// ```
///
/// **For Flutter users**: [diff] can be used to calculate updates for an
/// [AnimatedList]:
///
/// ```
/// final _listKey = GlobalKey<AnimatedListState>();
/// List<String> _lastFruits;
/// ...
///
/// StreamBuilder<String>(
///   stream: fruitStream,
///   initialData: [],
///   builder: (context, snapshot) {
///     for (var operation in await diff(_lastFruits, snapshot.data)) {
///       if (operation.isInsertion) {
///         _listKey.insertItem(operation.index);
///       } else {
///         _listKey.removeItem(operation.index, (context, animation) => ...);
///       }
///     }
///
///     return AnimatedList(
///       key: _listKey,
///       itemBuilder: (context, index, animation) => ...,
///     );
///   },
/// ),
/// ```
Future<List<Operation<Item>>> diff<Item>(
  List<Item> oldList,
  List<Item> newList, {
  bool spawnIsolate,
  bool Function(Item a, Item b) areEqual,
  int Function(Item item) getHashCode,
}) async {
  assert((areEqual != null) == (getHashCode != null),
      'Both areEqual and getHashCode or neither of them have specified.');

  // Use == operator and item hash code as default comparison functions
  areEqual ??= (a, b) => a == b;
  getHashCode ??= (item) => item.hashCode;

  final trimResult = _trim(oldList, newList, areEqual);

  spawnIsolate ??= _shouldSpawnIsolate(
    trimResult.shortenedOldList,
    trimResult.shortenedNewList,
  );

  // Those are sublists that reduce the problem to a smaller problem domain.
  List<Operation<Item>> operations = await (spawnIsolate
      ? _calculateDiffInSeparateIsolate(
          trimResult.shortenedOldList,
          trimResult.shortenedNewList,
          areEqual,
          getHashCode,
        )
      : _calculateDiff(
          trimResult.shortenedOldList,
          trimResult.shortenedNewList,
          areEqual,
        ));

  // Shift operations back.
  return operations.map((op) => op._shift(trimResult.start)).toList();
}
