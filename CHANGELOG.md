## [1.1.0] - 2019-10-09

* BREAKING CHANGE: `diff` is now asynchronous.
* Add support for running `diff` on another isolate by simply setting
  `runOnSeparateIsolate` to `true`.
* Add `isolated.dart` example.
* Better error messages.
* Revised doc comments.
* Add readme.

## [1.0.1] - 2019-10-09

* Remove unused dependency `dart:isolate`.

## [1.0.0] - 2019-10-09

* Initial release featuring the `diff` function that takes two lists and
  returns a list of `Operation`s that turn the first into the second list if
  applied in order.
