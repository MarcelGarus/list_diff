/// Offers the [diff] function, which calculates a minimal list of [Operation]s
/// that convert one list into another.
library list_diff;

import 'dart:isolate';
import 'package:async/async.dart';

part 'operation.dart';
part 'calculate.dart';
part 'isolated.dart';

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

  // Check if the lists start or end with the same items to trim the problem
  // down as much as possible.
  final oldLen = oldList.length;
  final newLen = newList.length;
  var start = 0;
  while (start < oldLen &&
      start < newLen &&
      areEqual(oldList[start], newList[start])) {
    start++;
  }
  var end = 0;
  while (end < oldLen &&
      end < newLen &&
      areEqual(oldList[oldLen - 1 - end], newList[newLen - 1 - end])) {
    end++;
  }
  // We can now reduce the problem to two possibly smaller sublists.
  final shortenedOldList =
      oldLen == end ? <Item>[] : oldList.sublist(start, oldLen - end);
  final shortenedNewList =
      newLen == end ? <Item>[] : newList.sublist(start, newLen - end);

  // If no [spawnIsolate] is given, we try to automatically choose a value that
  // aligns with our performance goals.
  // The algorithm fills an N times M table of cells, where N and M are the
  // lengths of both lists. Because most Dart code is eventually used in
  // Flutter as AOT-compiled code, I did some performance testing on a
  // OnePlus 6T. Turns out, spawning an isolate and transmitting the necessary
  // data takes about 13 ms and filling one cell about 4 µs.
  // Let's say an app wants to achieve 90 fps (that may seem like a stretch,
  // but keep in mind that there are lots of less-performant devices, so the
  // benchmark speeds are taken with an upper-bound-ish kind of view).
  // That leaves us with about 11 ms per frame. Because there's probably a lot
  // of other stuff happening apart from calculating the differences (like,
  // actually animating stuff and building widgets), let's say we want the diff
  // to at most take up half of the time, so at most 6 ms.
  // Whether we should spawn an isolate only depends on if we can fit the
  // calculation of the N*M cells into the timeframe of 6 ms. With a cell
  // calculation time of 4 µs, we can calculate the value of
  // 6 ms / 4 µs = 1.500 cells to still be able to hit our deadline.
  spawnIsolate ??= shortenedOldList.length * shortenedNewList.length > 1500;

  // Those are sublists that reduce the problem to a smaller problem domain.
  List<Operation<Item>> operations = await (spawnIsolate
      ? _calculateDiffInSeparateIsolate(
          shortenedOldList, shortenedNewList, areEqual, getHashCode)
      : _calculateDiff(shortenedOldList, shortenedNewList, areEqual));

  // Shift operations back.
  return operations.map((op) => op._shift(start)).toList();
}
