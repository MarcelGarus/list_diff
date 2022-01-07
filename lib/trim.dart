/// Check if the lists start or end with the same items to trim the problem down
/// as much as possible.
_TrimResult<Item> trim<Item>(
  List<Item> oldList,
  List<Item> newList,
  bool Function(Item a, Item b) areEqual,
) {
  var oldLen = oldList.length;
  var newLen = newList.length;

  var end = 0;
  while (end < oldLen &&
      end < newLen &&
      areEqual(oldList[oldLen - 1 - end], newList[newLen - 1 - end])) {
    end++;
  }
  oldList = oldList.sublist(0, oldLen - end);
  newList = newList.sublist(0, newLen - end);
  oldLen -= end;
  newLen -= end;

  var start = 0;
  while (start < oldLen &&
      start < newLen &&
      areEqual(oldList[start], newList[start])) {
    start++;
  }

  // We can now reduce the problem to two possibly smaller sublists.
  return _TrimResult(
    shortenedOldList: oldList.sublist(start),
    shortenedNewList: newList.sublist(start),
    start: start,
  );
}

class _TrimResult<Item> {
  const _TrimResult({
    required this.shortenedOldList,
    required this.shortenedNewList,
    required this.start,
  });

  final List<Item> shortenedOldList;
  final List<Item> shortenedNewList;
  final int start;
}
