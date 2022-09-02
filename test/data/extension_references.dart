import 'package:collection/collection.dart';

void main() {
  // firstWhereOrNull is on the extension IterableExtension.
  var foo = ['one', 'two', 'three'];
  print(foo.firstWhereOrNull((item) => item == 'four'));
}
