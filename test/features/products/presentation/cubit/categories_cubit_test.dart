import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';
import 'package:lpco_llc/features/products/presentation/cubit/categories_cubit.dart';

class _FakeCategoryRepository extends ProductRepository {
  final List<CategoryModel> remoteCategories;
  final List<CategoryModel> cachedCategories = const [];

  _FakeCategoryRepository({
    required this.remoteCategories,
  });

  @override
  Future<List<CategoryModel>> getCachedCategories({bool guest = false}) async {
    return cachedCategories;
  }

  @override
  Future<List<CategoryModel>> getCategories({
    bool guest = false,
    bool forceRefresh = false,
  }) async {
    return remoteCategories;
  }
}

void main() {
  test('CategoriesCubit preserves API category order', () async {
    final cubit = CategoriesCubit(
      isGuest: true,
      repository: _FakeCategoryRepository(
        remoteCategories: const <CategoryModel>[
          CategoryModel(
            id: 30,
            name: 'Third from API',
            slug: 'third',
            count: 1,
            imageUrl: '',
          ),
          CategoryModel(
            id: 10,
            name: 'First alphabetically',
            slug: 'first',
            count: 99,
            imageUrl: '',
          ),
          CategoryModel(
            id: 20,
            name: 'Child from API',
            slug: 'child',
            parentId: 30,
            count: 5,
            imageUrl: '',
          ),
        ],
      ),
    );
    addTearDown(cubit.close);

    await cubit.initialize();

    expect(cubit.state.status, CategoriesStatus.loaded);
    expect(cubit.state.categories.map((category) => category.id), <int>[
      30,
      10,
      20,
    ]);
  });
}
