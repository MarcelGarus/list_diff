import 'package:list_diff/list_diff.dart';
import 'package:test/test.dart';

late List<Item> list, newList;

class Item {
  Item(this.id, this.value);

  int id;
  int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

void main() {
  group('Diff tests', () {
    setUp(() {
      list = [
        Item(0, 0),
        Item(1, 1),
        Item(2, 2),
        Item(3, 3),
      ];
      newList = List.from(list);
    });

    group('Default equals function tests', () {
      test('Identical list diff returns empty list', () async {
        final operations = await diff(list, newList);

        expect(operations, isEmpty);
      });

      test('List with one removed element returns one deletion', () async {
        newList.removeAt(1);

        final operations = await diff(list, newList);

        expect(operations, hasLength(1));
        expect(operations.first.type, OperationType.deletion);
        expect(operations.first.item, list[1]);
        expect(operations.first.index, 1);
      });

      test('List with one added element returns one insertion', () async {
        newList.add(Item(4, 4));

        final operations = await diff(list, newList);

        expect(operations, hasLength(1));
        expect(operations.first.type, OperationType.insertion);
        expect(operations.first.item, newList[4]);
        expect(operations.first.index, 4);
      });

      test(
          'List with two neighboring switched elements returns insertion and deletion',
          () async {
        final temp = newList.first;
        newList.first = newList[1];
        newList[1] = temp;

        final operations = await diff(list, newList);

        expect(operations, hasLength(2));

        expect(operations.first.type, OperationType.insertion);
        expect(operations.first.item, newList[0]);
        expect(operations.first.index, 0);

        expect(operations[1].type, OperationType.deletion);
        expect(operations[1].item, list[1]);
        expect(operations[1].index, 2);
      });

      test(
          'List with two not neighboring switched elements returns correct operations',
          () async {
        final temp = newList.first;
        newList.first = newList[2];
        newList[2] = temp;

        final operations = await diff(list, newList);

        expect(operations, hasLength(4));

        expect(operations.first.type, OperationType.insertion);
        expect(operations.first.item, newList.first);
        expect(operations.first.index, 0);

        expect(operations[1].type, OperationType.insertion);
        expect(operations[1].item, newList[1]);
        expect(operations[1].index, 1);

        expect(operations[2].type, OperationType.deletion);
        expect(operations[2].item, list[1]);
        expect(operations[2].index, 3);

        expect(operations[3].type, OperationType.deletion);
        expect(operations[3].item, list[2]);
        expect(operations[3].index, 3);
      });
    });

    group('Custom equals function tests', () {
      final areEqual = (a, b) => a.value == b.value;
      final getHashCode = (item) => item.hashCode;

      test('Identical list diff returns empty list', () async {
        final operations = await diff(
          list,
          newList,
          areEqual: areEqual,
          getHashCode: getHashCode,
        );

        expect(operations, isEmpty);
      });

      test('List with one removed element returns one deletion', () async {
        newList.removeAt(1);

        final operations = await diff(
          list,
          newList,
          areEqual: areEqual,
          getHashCode: getHashCode,
        );

        expect(operations, hasLength(1));
        expect(operations.first.type, OperationType.deletion);
        expect(operations.first.item, list[1]);
        expect(operations.first.index, 1);
      });

      test('List with one added element returns one insertion', () async {
        newList.add(Item(4, 4));

        final operations = await diff(
          list,
          newList,
          areEqual: areEqual,
          getHashCode: getHashCode,
        );

        expect(operations, hasLength(1));
        expect(operations.first.type, OperationType.insertion);
        expect(operations.first.item, newList[4]);
        expect(operations.first.index, 4);
      });

      test(
          'List with two neighboring switched elements returns insertion and deletion',
          () async {
        final temp = newList.first;
        newList.first = newList[1];
        newList[1] = temp;

        final operations = await diff(
          list,
          newList,
          areEqual: areEqual,
          getHashCode: getHashCode,
        );

        expect(operations, hasLength(2));

        expect(operations.first.type, OperationType.insertion);
        expect(operations.first.item, newList[0]);
        expect(operations.first.index, 0);

        expect(operations[1].type, OperationType.deletion);
        expect(operations[1].item, list[1]);
        expect(operations[1].index, 2);
      });

      test(
          'List with two not neighboring switched elements returns correct operations',
          () async {
        final temp = newList.first;
        newList.first = newList[2];
        newList[2] = temp;

        final operations = await diff(
          list,
          newList,
          areEqual: areEqual,
          getHashCode: getHashCode,
        );

        expect(operations, hasLength(4));

        expect(operations.first.type, OperationType.insertion);
        expect(operations.first.item, newList.first);
        expect(operations.first.index, 0);

        expect(operations[1].type, OperationType.insertion);
        expect(operations[1].item, newList[1]);
        expect(operations[1].index, 1);

        expect(operations[2].type, OperationType.deletion);
        expect(operations[2].item, list[1]);
        expect(operations[2].index, 3);

        expect(operations[3].type, OperationType.deletion);
        expect(operations[3].item, list[2]);
        expect(operations[3].index, 3);
      });

      test('List with item replaced with equal one return empty list',
          () async {
        newList.first = Item(4, 0);

        final operations = await diff(
          list,
          newList,
          areEqual: areEqual,
          getHashCode: getHashCode,
        );

        expect(operations, isEmpty);
      });
    });
  });
}
