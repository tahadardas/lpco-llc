import 'package:lpco_llc/core/utils/text_sanitizer.dart';

class AppNotificationModel {
  final int id;
  final String title;
  final String body;
  final String createdAt;
  final bool isRead;
  final String deepLink;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.deepLink,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? ''}') ?? 0,
      title: TextSanitizer.fix(json['title'] ?? 'تنبيه'),
      body: TextSanitizer.fix(json['body']),
      createdAt: TextSanitizer.fix(json['created_at']),
      isRead: json['is_read'] == true,
      deepLink: TextSanitizer.fix(json['deep_link']),
    );
  }

  AppNotificationModel copyWith({bool? isRead}) {
    return AppNotificationModel(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      deepLink: deepLink,
    );
  }
}
