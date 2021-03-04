import 'calculate.dart';
import 'isolated.dart';
import 'operation.dart';
import 'trim.dart';

export 'operation.dart';

typedef EqualityChecker<Item> = bool Function(Item a, Item b);
typedef HashCodeGetter<Item> = int Function(Item a);

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
///
/// See also:
/// - [diffSync], if your lists are very small.
Future<List<Operation<Item>>> diff<Item>(
  List<Item> oldList,
  List<Item> newList, {
  bool? spawnIsolate,
  EqualityChecker<Item>? areEqual,
  HashCodeGetter<Item>? getHashCode,
}) async {
  assert(
    (areEqual == null) == (getHashCode == null),
    'You have to either provide both an areEqual and a getHashCode function or '
    'none at all. For more information, see the documentation of hashCode: '
    'https://api.dart.dev/stable/2.9.2/dart-core/Object/hashCode.html',
  );

  // Use == operator and item hash code as default comparison functions
  final areEqualCheck = areEqual ?? (a, b) => a == b;
  final getHashCodeCheck = getHashCode ?? (item) => item.hashCode;

  final trimResult = trim(oldList, newList, areEqualCheck);

  final spawnIsolate_ = spawnIsolate ??
      shouldSpawnIsolate(
        trimResult.shortenedOldList,
        trimResult.shortenedNewList,
      );

  // Those are sublists that reduce the problem to a smaller problem domain.
  List<Operation<Item>> operations = spawnIsolate_
      ? await calculateDiffInSeparateIsolate(
          trimResult.shortenedOldList,
          trimResult.shortenedNewList,
          areEqualCheck,
          getHashCodeCheck,
        )
      : diffSync(
          trimResult.shortenedOldList,
          trimResult.shortenedNewList,
          areEqual: areEqualCheck,
        );

  // Shift operations back.
  return operations.map((op) => op.shift(trimResult.start)).toList();
}

/// Calculates a minimal list of [Operation]s that convert the [oldList] into
/// the [newList].
///
/// Unlike [diff], this function works synchronously (i.e., without using
/// [Future]s).
///
/// See also:
/// - [diff], for a detailed explanation or if you have very long lists.
List<Operation<Item>> diffSync<Item>(
  List<Item> oldList,
  List<Item> newList, {
  EqualityChecker<Item>? areEqual,
}) {
  // Use == operator and item hash code as default comparison functions
  final areEqualCheck = areEqual ?? (a, b) => a == b;

  final trimResult = trim(oldList, newList, areEqualCheck);

  // Those are sublists that reduce the problem to a smaller problem domain.
  List<Operation<Item>> operations = calculateDiffSync(
    trimResult.shortenedOldList,
    trimResult.shortenedNewList,
    areEqualCheck,
  );

  // Shift operations back.
  return operations.map((op) => op.shift(trimResult.start)).toList();
}
