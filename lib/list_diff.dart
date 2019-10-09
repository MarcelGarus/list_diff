enum OperationType { insertion, deletion }

/// A single operation on a list, either an insertion of an item at an index or
/// the deletion of an item at an index.
class Operation<Item> {
  final OperationType type;
  bool get isInsertion => type == OperationType.insertion;
  bool get isDeletion => type == OperationType.deletion;

  final int index;
  final Item item;

  Operation._({this.type, this.index, this.item});

  void applyTo(List<Item> list) {
    if (isInsertion) {
      list.insert(index, item);
    } else {
      assert(
          list[index] == item,
          'According to the operation, the item at index $index should be '
          '$item, but is actually ${list[index]}.');
      list.removeAt(index);
    }
  }

  String toString() =>
      '${isInsertion ? 'Insertion' : 'Deletion'} of $item at $index.';
}

/// A sequence of operations applied onto the old list.
class _Sequence<Item> {
  /// The operation chosen, either [OperationType.insertion] or
  /// [OperationType.deletion] or [null], indicating that nothing changed.
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

  /// Turns this operation and its parent into a list of operations, where
  /// [null] stands for not changing any item.
  List<Operation<Item>> toOperations() {
    var operations = parent?.toOperations() ?? [];
    operations.add(type == null
        ? null
        : Operation._(
            type: type,
            index:
                operations.where((op) => op == null || op.isInsertion).length -
                    1,
            item: item,
          ));
    return operations;
  }
}

/// Calculates a minimal list of [Operation]s that convert the [oldList] into
/// the [newList].
///
/// {@tool snippet}
/// ```dart
/// diff(
///   ['coconut', 'nut', 'peanut'],
///   ['kiwi', 'coconut', 'maracuja', 'nut', 'banana'],
/// ).forEach(print);
/// ```
/// {@end-tool}
///
/// The [Item]'s [==] operator is used to compare items.
///
/// This function uses a variant of the Levenshtein algorithm to find the
/// minimum number of operations. This is a simple solution. If you need a more
/// performant solution, such as Myers' algorith, your're welcome to contribute
/// to this library at https://github.com/marcelgarus/list_diff.
///
/// If the lists are large, this operation may take significant time so if you
/// are handling large data sets, better run this on a background isolate.
///
/// {@tool snippet}
/// For Flutter users: [diff] can be used to calculate updates for an
/// [AnimatedList].
///
/// ```dart
/// final _listKey = GlobalKey<AnimatedListState>();
/// List<String> _lastFruits;
/// ...
///
/// StreamBuilder<String>(
///   stream: fruitStream,
///   initialData: [],
///   builder: (context, snapshot) {
///     for (var operation in diff(_lastFruits, snapshot.data)) {
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
/// {@end-tool}
// This algorithm works by filling out a table made up by the two lists at the
// axis, where a cell at position x,y represents the number of operations
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
// For each other cell, there are several rules to fill them out:
// * If the item in the old and the new list are equal, no operation is needed.
//   That means, the value of the cell left above the current one can just be
//   copied. (If it takes n operations to get from oldList to newList, it takes
//   the same n operations to get from [...oldList, item] to [...newList, item]).
// * Otherwise, we can either insert an item coming from the cell above or
//   delete an item coming from the cell on the left. That translates in taking
//   either the cell above or on the left and adding one operation. Obviously,
//   the smaller one of those both should be chosen.
// Implementation details: For storage efficiency, only the active row of the
// table is actually saved. Then, the new row is calculated and the original
// row is replaced with the new one.
// Also, instead of storing just the number of moves, we store the sequence of
// operations so that we can later retrace the path we took.
List<Operation<Item>> diff<Item>(List<Item> oldList, List<Item> newList) {
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
      nextRow.add(() {
        if (x == 0) {
          return _Sequence.insert(row[0], newList[y]);
        }
        if (newList[y] == oldList[x - 1]) {
          return _Sequence.unchanged(row[x - 1]);
        }
        if (row[x].isBetterThan(nextRow[x - 1])) {
          return _Sequence.insert(row[x], newList[y]);
        } else {
          return _Sequence.delete(nextRow[x - 1], oldList[x - 1]);
        }
      }());
    }

    row = nextRow;
  }

  return row.last.toOperations().where((op) => op != null).toList();
}
