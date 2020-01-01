part of 'list_diff.dart';

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

  Operation<Item> _shift(int shiftAmount) => Operation._(
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
          "Tried to remove item $item at index $index, but there's a "
          "different item at that position: ${list[index]}.");
      list.removeAt(index);
    }
  }

  String toString() =>
      '${isInsertion ? 'Insertion' : 'Deletion'} of $item at $index.';
}

extension ApplyOperation<T> on List<T> {
  void apply(Operation<T> operation) => operation.applyTo(this);
}
