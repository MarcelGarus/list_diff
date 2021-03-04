enum OperationType { insertion, deletion }

/// A single operation on a list – either an insertion or deletion of an [item]
/// at an [index].
///
/// Can be applied to a [List] by calling [applyTo].
class Operation<Item> {
  final OperationType type;
  bool get isInsertion => type == OperationType.insertion;
  bool get isDeletion => type == OperationType.deletion;

  final int index;
  final Item item;

  Operation({required this.type, required this.index, required this.item});

  Operation<Item> shift(int shiftAmount) => Operation(
        type: type,
        index: index + shiftAmount,
        item: item,
      );

  /// Actually applies this operation on the [list] by mutating it.
  void applyTo(List<Item> list) {
    if (isInsertion) {
      list.insert(index, item);
    } else {
      assert(
        list[index] == item,
        "Tried to remove item $item at index $index, but there's a different "
        'item at that position: ${list[index]}.',
      );
      list.removeAt(index);
    }
  }

  String toString() => '<${isInsertion ? 'Insert' : 'Delete'} $item at $index>';
}

extension ApplyOperation<T> on List<T> {
  void apply(Operation<T> operation) => operation.applyTo(this);
}
