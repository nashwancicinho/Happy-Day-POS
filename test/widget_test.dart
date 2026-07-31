import 'package:flutter_test/flutter_test.dart';
import 'package:happy_day_pos/models/product.dart';

void main() {
  test('ProductModel default stock tracking is enabled', () {
    const product = ProductModel(
      id: 1,
      name: 'مادة اختبارية',
      price: 1000,
    );

    expect(product.trackStock, isTrue);
    expect(product.stockQuantity, equals(100.0));
  });
}
