/// Check if the lists start or end with the same items to trim the problem down
/// as much as possible.
_TrimResult<Item> trim<Item>(
  List<Item> oldList,
  List<Item> newList,
  bool Function(Item a, Item b) areEqual,
) {
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
  return _TrimResult(
    shortenedOldList:
        oldLen == end ? <Item>[] : oldList.sublist(start, oldLen - end),
    shortenedNewList:
        newLen == end ? <Item>[] : newList.sublist(start, newLen - end),
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
