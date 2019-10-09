/// Offers the [diff] function, which calculates a minimal list of [Operation]s
/// that convert one list into another.
library list_diff;

import 'dart:isolate';

import 'package:async/async.dart';

enum OperationType { insertion, deletion }

/// A single operation on a list. Either [isInsertion] of an [item] at an
/// [index] or [isDeletion] of an [item] at an [index].
///
/// Can actually be applied to a [List] by calling [applyTo].
class Operation<Item> {
  final OperationType type;
  bool get isInsertion => type == OperationType.insertion;
  bool get isDeletion => type == OperationType.deletion;

  final int index;
  final Item item;

  Operation._({this.type, this.index, this.item});

  /// Actually applies this operation on the [list] by mutating it.
  void applyTo(List<Item> list) {
    if (isInsertion) {
      list.insert(index, item);
    } else {
      assert(
          list[index] == item,
          "Tried to remove item $item at index $index, but there's a "
          "different item at that position: ${list[index]}.");
      list.removeAt(index);
    }
  }

  String toString() =>
      '${isInsertion ? 'Insertion' : 'Deletion'} of $item at $index.';
}

/// A sequence of operations applied onto the old list. In contrast to the
/// [Operation] above, this sequence is not index-aware and also supports a
/// [type] of [null], indicating that nothing changed.
/// The index is derived from context from how many [_Sequence]s were applied
/// before. The cursor model works quite well: An insertion sequence and an
/// unchanged sequence both advance the cursor by 1, a deletion sequence
/// doesn't change the cursor.
///
/// **Example**: The sequence
/// `_Sequence.delete(_Sequence.unchanged(_Sequence.insert(null, a), b), c)`
/// means that given the original list, insert a at the beginning (cursor 0).
/// Then the cursor advances to index 1. Leave that unchanged. The cursor
/// advances. Remove the item at index 2.
class _Sequence<Item> {
  final OperationType type;
  final _Sequence<Item> parent;
  final Item item;
  final int length;

  const _Sequence.insert(this.parent, this.item)
      : type = OperationType.insertion,
        length = (parent?.length ?? 0) + 1;
  const _Sequence.delete(this.parent, this.item)
      : type = OperationType.deletion,
        length = (parent?.length ?? 0) + 1;
  const _Sequence.unchanged(this.parent)
      : type = null,
        item = null,
        length = parent?.length ?? 0;

  bool isBetterThan(_Sequence other) => length < other.length;

  /// Turns this operation and its anchestors into a list of [Operation]s.
  /// If [includeNullForChanged], sequences that don't change anything, create
  /// a [null] value in the resulting list.
  List<Operation<Item>> toOperations([includeNullForChanged = false]) {
    var operations = parent?.toOperations(true) ?? [];
    operations.add(type == null
        ? null
        : Operation._(
            type: type,
            index:
                operations.where((op) => op == null || op.isInsertion).length -
                    1,
            item: item,
          ));
    return includeNullForChanged
        ? operations
        : operations.where((op) => op != null).toList();
  }
}

/// Calculates a minimal list of [Operation]s that convert the [oldList] into
/// the [newList].
///
/// ```
/// var operations = await diff(
///   ['coconut', 'nut', 'peanut'],
///   ['kiwi', 'coconut', 'maracuja', 'nut', 'banana'],
/// );
/// operations.forEach(print);
///
/// // Output:
/// // Insertion of kiwi at 0.
/// // Insertion of maracuja at 2.
/// // Insertion of banana at 4.
/// // Deletion of peanut at 5.
/// ```
///
/// The [Item]'s [==] operator is used to compare items.
///
/// This function uses a variant of the Levenshtein algorithm to find the
/// minimum number of operations. This is a simple solution. If you need a more
/// performant solution, such as Myers' algorith, your're welcome to contribute
/// to this library at https://github.com/marcelgarus/list_diff.
///
/// If the lists are large, this operation may take some time so if you're
/// handling large data sets, better run this on a background isolate by
/// setting [useSeparateIsolate] to [true]:
///
/// ```
///
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
  bool useSeparateIsolate = false,
}) async {
  return await useSeparateIsolate
      ? _isolatedDiff(oldList, newList)
      : _calculateDiff(oldList, newList);
}

// This algorithm works by filling out a table with the two lists at the
// axises, where a cell at position x,y represents the number of operations
// needed to get from the first x items of the first list to the first y items
// of the second one.
// Let's say, the old list is [a, b] and the new one is [a, c]. The following
// table is created:
//     a b
//   0 1 2
// a 1 0 1
// c 2 1 2
// As you see, the first row and column are just a sequence of numbers. That's
// because for each new character, it takes one more deletion to get to the
// empty list and one more insertion to get from the empty list to the new one.
// All the other cells are filled out using these rules:
// * If the item at index x in the old list and the item at index y in the new
//   list are equal, no operation is needed.
//   That means, the value of the cell left above the current one can just be
//   copied. (If it takes N operations to get from `oldList` to `newList`, it
//   takes the same N operations to get from `[...oldList, item]` to
//   `[...newList, item]`).
// * Otherwise, we can either _insert_ an item coming from the cell above or
//   _delete_ an item coming from the cell on the left. That translates in
//   aking either the cell above or on the left and adding one operation.
//   Obviously, the smaller one of those both should be chosen for the shortest
//   possible path.
// Implementation details: For storage efficiency, only the active row of the
// table is actually saved. Then, the new row is calculated and the original
// row is replaced with the new one.
// Also, instead of storing just the number of moves, we store the [_Sequence]
// of operations so that we can later retrace the path we took.
Future<List<Operation<Item>>> _calculateDiff<Item>(
    List<Item> oldList, List<Item> newList) async {
  var row = <_Sequence<Item>>[];

  for (var x = 0; x <= oldList.length; x++) {
    if (x == 0) {
      row.add(_Sequence.unchanged(null));
    } else {
      row.add(_Sequence.insert(row.last, oldList[x - 1]));
    }
  }

  for (var y = 0; y < newList.length; y++) {
    final nextRow = <_Sequence<Item>>[];

    for (var x = 0; x <= oldList.length; x++) {
      if (x == 0) {
        nextRow.add(_Sequence.insert(row[0], newList[y]));
      } else if (await _doItemsMatch(newList[y], oldList[x - 1])) {
        nextRow.add(_Sequence.unchanged(row[x - 1]));
      } else if (row[x].isBetterThan(nextRow[x - 1])) {
        nextRow.add(_Sequence.insert(row[x], newList[y]));
      } else {
        nextRow.add(_Sequence.delete(nextRow[x - 1], oldList[x - 1]));
      }
    }

    row = nextRow;
  }

  return row.last.toOperations();
}

Future<bool> _doItemsMatch<Item>(Item first, Item second) async {
  if (Item == _ReferenceToItemOnOtherIsolate) {
    final firstRef = first as _ReferenceToItemOnOtherIsolate;
    final secondRef = second as _ReferenceToItemOnOtherIsolate;
    return await firstRef.equals(secondRef);
  } else {
    return first == second;
  }
}

// Isolates do not share memory and only communicate using ports which can only
// send some primitive types. That means, the items can't be copied to the
// other isolate.
// Rather, we create the hashCode of each item and send those to the other
// isolate. When two items' hashCodes match, the second isolate asks the first
// isolate if the items at the indexes are equal to avoid false positives.
// Here's how the communication between the isolates looks:
// * The main isolate spawns the worker isolate with a SendPort.
// * The worker isolate sends another SendPort back to the main isolate.
//   Now, the two isolates can communicate.
// * For both the old and the new list, the main isolate sends:
//   * The size of the list.
//   * The hashCodes of the items.
// * The worker isolate starts calculating the diff and when encountering a
//   possible item match, asks the main isolate if the items really match by
//   * sending false to indicate it's not done calculating the diff,
//   * sending the index of the item in the first list,
//   * sending the index of the item in the second list.
//   * Then, the main isolate responds with a bool, indicating whether the
//     items really match.
// * Once the worker isolate is done, it sends true to indicate so. Then, for
//   each operation, it sends
//   * whether it's an insertion (true for insertion, false for deletion)
//   * the index operation
//   * the index of the item in the old list if this is a deletion or the index
//     in the new list if this is an insertion.
// * The main isolate can then reconstruct the operations by looking up the
//   original items.
Future<List<Operation<Item>>> _isolatedDiff<Item>(
  List<Item> oldList,
  List<Item> newList,
) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_calculateIsolatedDiff, receivePort.sendPort);
  final port = StreamQueue(receivePort);
  final SendPort sendPort = await port.next;

  _sendItemList(sendPort, oldList);
  _sendItemList(sendPort, newList);

  while (!await port.next) {
    // Two items' hashCodes match. Let's find out if they're really the same.
    final first = oldList[await port.next];
    final second = newList[await port.next];
    sendPort.send(first == second);
  }

  final operations = await _receiveOperationsList(port, oldList, newList);
  receivePort.close();
  return operations;
}

Future<void> _calculateIsolatedDiff(dynamic message) async {
  final sendPort = message as SendPort;
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);
  final port = StreamQueue(receivePort);

  final oldList = await _receiveItemList(port, sendPort, isOldList: true);
  final newList = await _receiveItemList(port, sendPort, isOldList: false);

  var operations = await diff(oldList, newList);

  _sendOperationsList(sendPort, operations);
  receivePort.close();
}

// Used on the worker isolate to refer to an item on the main isolate.
class _ReferenceToItemOnOtherIsolate {
  final StreamQueue port;
  final SendPort sendPort;

  final bool isFromOldList;
  final int index;
  final int hashCode;

  _ReferenceToItemOnOtherIsolate({
    this.port,
    this.sendPort,
    this.isFromOldList,
    this.index,
    this.hashCode,
  });

  Future<bool> equals(_ReferenceToItemOnOtherIsolate other) async {
    assert(isFromOldList != other.isFromOldList,
        "We shouldn't need to compare items of the same list.");
    if (hashCode != other.hashCode) {
      return false;
    }
    final itemFromOldList = isFromOldList ? this : other;
    final itemFromNewList = isFromOldList ? other : this;
    sendPort
      ..send(false)
      ..send(itemFromOldList.index)
      ..send(itemFromNewList.index);
    return await port.next;
  }
}

void _sendItemList(SendPort sendPort, List<dynamic> list) {
  sendPort.send(list.length);
  for (var item in list) {
    sendPort.send(item.hashCode);
  }
}

Future<List<_ReferenceToItemOnOtherIsolate>> _receiveItemList(
    StreamQueue port, SendPort sendPort,
    {bool isOldList}) async {
  final length = await port.next;
  final list = <_ReferenceToItemOnOtherIsolate>[];

  for (var i = 0; i < length; i++) {
    list.add(_ReferenceToItemOnOtherIsolate(
      port: port,
      sendPort: sendPort,
      isFromOldList: isOldList,
      index: i,
      hashCode: await port.next,
    ));
  }
  return list;
}

void _sendOperationsList(SendPort sendPort,
    List<Operation<_ReferenceToItemOnOtherIsolate>> operations) {
  sendPort..send(true)..send(operations.length);
  for (final op in operations) {
    sendPort..send(op.isInsertion)..send(op.index)..send(op.item.index);
  }
}

Future<List<Operation<Item>>> _receiveOperationsList<Item>(
  StreamQueue port,
  List<Item> oldList,
  List<Item> newList,
) async {
  Future<Operation<Item>> _receiveOperation() async {
    final bool isInsertion = await port.next;
    return Operation<Item>._(
      type: isInsertion ? OperationType.insertion : OperationType.deletion,
      index: await port.next,
      item: isInsertion ? newList[await port.next] : oldList[await port.next],
    );
  }

  return [
    for (var i = await port.next; i > 0; i--) await _receiveOperation(),
  ];
}
