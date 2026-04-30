import 'package:dio/dio.dart';
import 'package:lpco_llc/core/network/dio_client.dart';

class JobRepository {
  final Dio _dio = DioClient().dio;

  Future<void> submitApplication({
    required String fullName,
    required String email,
    required String phone,
    required String province,
    required String education,
    required String position,
    required String experience,
    required String about,
  }) async {
    await _dio.post(
      '/dms/v1/job-application',
      data: <String, dynamic>{
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'province': province,
        'education': education,
        'position': position,
        'experience': experience,
        'about': about,
      },
    );
  }
}
