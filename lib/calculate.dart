part of 'list_diff.dart';

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

// This algorithm works by filling out a table with the two lists at the
// axes, where a cell at position x,y represents the number of operations
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
  List<Item> oldList,
  List<Item> newList,
  bool Function(Item a, Item b) areEqual,
) async {
  var row = <_Sequence<Item>>[];

  for (var x = 0; x <= oldList.length; x++) {
    if (x == 0) {
      row.add(_Sequence.unchanged(null));
    } else {
      row.add(_Sequence.delete(row.last, oldList[x - 1]));
    }
  }

  for (var y = 0; y < newList.length; y++) {
    final nextRow = <_Sequence<Item>>[];

    for (var x = 0; x <= oldList.length; x++) {
      if (x == 0) {
        nextRow.add(_Sequence.insert(row[0], newList[y]));
      } else if (await _doItemsMatch(newList[y], oldList[x - 1], areEqual)) {
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

Future<bool> _doItemsMatch<Item>(
  Item first,
  Item second,
  bool Function(Item a, Item b) areEqual,
) async {
  if (Item == _ReferenceToItemOnOtherIsolate) {
    final firstRef = first as _ReferenceToItemOnOtherIsolate;
    final secondRef = second as _ReferenceToItemOnOtherIsolate;
    return await firstRef.equals(secondRef);
  } else {
    return areEqual(first, second);
  }
}

/// A synchronous variant of [_calculateDiff].
List<Operation<Item>> _calculateDiffSync<Item>(
  List<Item> oldList,
  List<Item> newList,
  bool Function(Item a, Item b) areEqual,
) {
  assert(Item is! _ReferenceToItemOnOtherIsolate);

  var row = <_Sequence<Item>>[];

  for (var x = 0; x <= oldList.length; x++) {
    if (x == 0) {
      row.add(_Sequence.unchanged(null));
    } else {
      row.add(_Sequence.delete(row.last, oldList[x - 1]));
    }
  }

  for (var y = 0; y < newList.length; y++) {
    final nextRow = <_Sequence<Item>>[];

    for (var x = 0; x <= oldList.length; x++) {
      if (x == 0) {
        nextRow.add(_Sequence.insert(row[0], newList[y]));
      } else if (areEqual(newList[y], oldList[x - 1])) {
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
