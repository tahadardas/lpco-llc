import 'package:flutter/material.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandAppBar(title: 'سياسة الخصوصية'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مرحباً بك في تطبيق LPCO',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                '1. البيانات التي نجمعها',
                'قد نقوم بجمع بعض البيانات الشخصية والتقنية لتحسين تجربتك، وتشمل:\n'
                    '• بيانات الحساب: الاسم، رقم الهاتف، البريد الإلكتروني، والعنوان.\n'
                    '• بيانات الطلبات والسلة: معلومات عن المنتجات التي تتفاعل معها أو تطلبها.\n'
                    '• بيانات تقنية: معلومات الجهاز، عنوان الـ IP، ومعرفات الإشعارات.',
              ),
              _buildSection(
                context,
                '2. الغرض من استخدام البيانات',
                'نستخدم بياناتك للأغراض التالية:\n'
                    '• إدارة حسابك وتسهيل عمليات الطلب والدفع.\n'
                    '• التنسيق لتوصيل الطلبات وتقديم الدعم الفني وخدمة العملاء.\n'
                    '• إرسال الإشعارات المتعلقة بطلباتك أو العروض الترويجية (في حال تفعيلها).\n'
                    '• تحسين خدماتنا ومنع الاحتيال وضمان أمن التطبيق.',
              ),
              _buildSection(
                context,
                '3. مشاركة البيانات',
                'نحن لا نقوم ببيع بياناتك الشخصية. قد نشارك بعض البيانات فقط مع مزودي الخدمات المعتمدين لدينا (مثل شركات الشحن) أو عند الضرورة استجابةً لمتطلبات قانونية أو تشغيلية تتعلق بتنفيذ الطلبات.',
              ),
              _buildSection(
                context,
                '4. المدفوعات والمعلومات المالية',
                'يتم عرض معلومات التحويل البنكي أو الحسابات داخل التطبيق لغرض تنسيق الدفع للطلبات. قد نقوم بحفظ بيانات تأكيد الدفع والطلبات لضمان استكمال المعاملات بشكل صحيح.',
              ),
              _buildSection(
                context,
                '5. الأمان',
                'نحن نتخذ تدابير فنية وتنظيمية معقولة لحماية بياناتك من الوصول غير المصرح به. ومع ذلك، يرجى العلم بأنه لا يوجد نظام إلكتروني آمن بنسبة 100%.',
              ),
              _buildSection(
                context,
                '6. حقوق المستخدم',
                'يحق لك طلب تصحيح أو تحديث أو حذف معلوماتك الشخصية من خلال التواصل معنا، وذلك وفقاً للقيود القانونية والمحاسبية والتشغيلية المطبقة.',
              ),
              _buildSection(
                context,
                '7. التواصل معنا',
                'إذا كانت لديك أي استفسارات حول سياسة الخصوصية، يرجى التواصل معنا عبر معلومات الاتصال المتوفرة في التطبيق.',
              ),
              const SizedBox(height: 24),
              Text(
                'آخر تحديث: 20 مايو 2026',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}
