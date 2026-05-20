import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/core/network/api_contract.dart';

import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';

enum CategoriesStatus { initial, loading, loaded, error }

class CategoriesState {
  final CategoriesStatus status;
  final List<CategoryModel> categories;
  final String errorMessage;

  const CategoriesState({
    this.status = CategoriesStatus.initial,
    this.categories = const <CategoryModel>[],
    this.errorMessage = '',
  });

  CategoriesState copyWith({
    CategoriesStatus? status,
    List<CategoryModel>? categories,
    String? errorMessage,
  }) {
    return CategoriesState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class CategoriesCubit extends Cubit<CategoriesState> {
  final ProductRepository _repository;
  final bool _isGuest;

  CategoriesCubit({ProductRepository? repository, required bool isGuest})
    : _repository = repository ?? ProductRepository(),
      _isGuest = isGuest,
      super(const CategoriesState());

  Future<void> initialize({bool forceRefresh = false}) async {
    emit(state.copyWith(status: CategoriesStatus.loading, errorMessage: ''));

    var emittedFromCache = false;
    try {
      final cached = await _repository.getCachedCategories(guest: _isGuest);
      if (isClosed) return;
      if (cached.isNotEmpty) {
        emittedFromCache = true;
        emit(
          state.copyWith(
            status: CategoriesStatus.loaded,
            categories: cached,
            errorMessage: '',
          ),
        );
      }
    } catch (_) {}

    try {
      final categories = await _repository.getCategories(guest: _isGuest, forceRefresh: forceRefresh);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CategoriesStatus.loaded,
          categories: categories,
          errorMessage: '',
        ),
      );
    } catch (error) {
      if (emittedFromCache) {
        emit(state.copyWith(status: CategoriesStatus.loaded, errorMessage: ''));
        return;
      }

      emit(
        state.copyWith(
          status: CategoriesStatus.error,
          errorMessage: ApiContract.safeMessageFromException(error),
        ),
      );
    }
  }

  Future<void> refresh() => initialize(forceRefresh: true);
}
