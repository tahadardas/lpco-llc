import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/network/dio_client.dart';

abstract class AccountDeletionGateway {
  Future<void> deleteCurrentAccount({required String password});
}

class AccountRepository implements AccountDeletionGateway {
  final Dio _dio;
  final DioClient _client;

  AccountRepository({Dio? dio, DioClient? client})
    : _client = client ?? DioClient(),
      _dio = dio ?? (client ?? DioClient()).dio;

  @override
  Future<void> deleteCurrentAccount({required String password}) async {
    try {
      final response = await _dio.delete(
        '/dms/v1/account',
        data: <String, dynamic>{'password': password},
        options: _client.buildOptions(cachePolicy: CachePolicy.noCache),
      );
      final payload = ApiContract.expectMap(
        response.data,
        endpoint: '/dms/v1/account',
      );
      if (payload['success'] != true) {
        throw const AccountDeletionException('تعذر حذف الحساب.');
      }
    } on DioException catch (error) {
      throw AccountDeletionException(
        ApiContract.safeMessageFromException(
          error,
          fallback: 'تعذر حذف الحساب حالياً. يرجى إعادة المحاولة.',
        ),
      );
    }
  }
}

class AccountDeletionException implements Exception {
  final String message;

  const AccountDeletionException(this.message);

  @override
  String toString() => message;
}
