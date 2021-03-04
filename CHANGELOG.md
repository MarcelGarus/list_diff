## 2.0.0

* Migrate to null-safety.

## 1.3.2

* Relax dependency on async.

## 1.3.1

* Fix the assert message.

## 1.3.0

* Add `diffSync` method.

## 1.2.1

* Add extension method for more intuitive `list.apply(operation)` instead of `operation.applyTo(list)`.
* Revised readme.

## 1.2.0

* Add option to provide `areEqual` and `getHashCode` functions.

## 1.1.3

* Important fix: Fixed error in the algorithm that made it crash when the two lists are the same.

## 1.1.2

* Important fix: Fixed error in the algorithm that produced wrong results that you can't apply.

## 1.1.1

* BREAKING CHANGE: `runOnSeparateIsolate` renamed to `spawnIsolate`.
* By default, the `diff` function intelligently tries to choose whether or not to spawn an isolate based on the lengths on the lists.
* Revised readme.

## 1.1.0

* BREAKING CHANGE: `diff` is now asynchronous.
* Add support for running `diff` on another isolate by setting `runOnSeparateIsolate` to `true`.
* Add `isolated.dart` example.
* Better error messages.
* Revised doc comments.
* Add readme.

## 1.0.1

* Remove unused dependency `dart:isolate`.

## 1.0.0

* This Initial release features the `diff` function that takes two lists and returns a list of `Operation`s that turn the first into the second list if applied in order.
