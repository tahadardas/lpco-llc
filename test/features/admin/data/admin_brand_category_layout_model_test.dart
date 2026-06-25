import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';

void main() {
  test('brand category layout parses map payload', () {
    final model = AdminBrandCategoryLayoutModel.fromPayload(<String, dynamic>{
      'layout': <String, dynamic>{
        'zero': <String, dynamic>{
          'category_ids': <dynamic>[3, '7'],
          'hidden_category_ids': '9,11',
        },
      },
      'available': <String, dynamic>{
        'brands': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'name': 'Zero', 'slug': 'zero'},
        ],
        'categories': <Map<String, dynamic>>[
          <String, dynamic>{'id': 3, 'name': 'أقلام', 'slug': 'pens'},
        ],
      },
    });

    expect(model.layout['zero']?.categoryIds, <int>[3, 7]);
    expect(model.layout['zero']?.hiddenCategoryIds, <int>[9, 11]);
    expect(model.availableBrands.single.slug, 'zero');
    expect(model.availableCategories.single.name, 'أقلام');
  });

  test('brand category layout parses list payload without crashing', () {
    final model = AdminBrandCategoryLayoutModel.fromPayload(<String, dynamic>{
      'layout': <Map<String, dynamic>>[
        <String, dynamic>{
          'brand_slug': 'zidny',
          'category_ids': <dynamic>['5', 6],
        },
      ],
      'brands': <Map<String, dynamic>>[
        <String, dynamic>{'id': 2, 'name': 'Zidny', 'slug': 'zidny'},
      ],
      'categories': <Map<String, dynamic>>[
        <String, dynamic>{'id': 5, 'name': 'دفاتر', 'slug': 'notebooks'},
      ],
    });

    expect(model.layout['zidny']?.categoryIds, <int>[5, 6]);
    expect(model.availableBrands.single.name, 'Zidny');
    expect(model.availableCategories.single.name, 'دفاتر');
  });
}
