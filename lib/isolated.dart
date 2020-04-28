part of 'list_diff.dart';

bool _shouldSpawnIsolate<Item>(List<Item> oldList, List<Item> newList) {
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
  return oldList.length * newList.length > 1500;
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
Future<List<Operation<Item>>> _calculateDiffInSeparateIsolate<Item>(
  List<Item> oldList,
  List<Item> newList,
  bool Function(Item a, Item b) areEqual,
  int Function(Item item) getHashCode,
) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_calculationInIsolate, receivePort.sendPort);
  final port = StreamQueue(receivePort);
  final SendPort sendPort = await port.next;

  _sendItemList(sendPort, oldList, getHashCode);
  _sendItemList(sendPort, newList, getHashCode);

  while (!await port.next) {
    // Two items' hashCodes match. Let's find out if they're really the same.
    final first = oldList[await port.next];
    final second = newList[await port.next];
    sendPort.send(areEqual(first, second));
  }

  final operations = await _receiveOperationsList(port, oldList, newList);
  receivePort.close();
  return operations;
}

Future<void> _calculationInIsolate(dynamic message) async {
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

// Used in the worker isolate to refer to an item in the main isolate.
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

void _sendItemList(SendPort sendPort, List<dynamic> list,
    int Function(dynamic item) getHashCode) {
  sendPort.send(list.length);
  for (var item in list) {
    sendPort.send(getHashCode(item));
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
