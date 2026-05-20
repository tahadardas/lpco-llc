import 'package:flutter/material.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandAppBar(title: 'شروط الاستخدام'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'شروط وأحكام استخدام تطبيق LPCO',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                '1. طبيعة التطبيق',
                'هذا التطبيق هو منصة تجارية (B2B/B2C) مخصصة لعرض كتالوج المنتجات وتقديم طلبات الشراء لشركة LPCO LLC.',
              ),
              _buildSection(
                context,
                '2. الأسعار والمنتجات',
                'تخضع أسعار المنتجات، ومدى توفرها، والوحدات، والعروض للتغيير المستمر دون إشعار مسبق. نسعى لضمان دقة المعلومات، ولكن قد تحدث أخطاء غير مقصودة.',
              ),
              _buildSection(
                context,
                '3. الطلبات والتأكيد',
                'جميع الطلبات المرسلة عبر التطبيق تُعتبر "طلبات مبدئية" ولا تُعد نهائية أو ملزمة إلا بعد تأكيدها رسمياً من قبل الإدارة أو فريق المبيعات.',
              ),
              _buildSection(
                context,
                '4. التزامات المستخدم',
                'يجب عليك تقديم معلومات صحيحة ودقيقة (مثل بيانات الحساب والعنوان والتواصل). كما تتعهد بعدم إساءة استخدام التطبيق أو محاولة الوصول غير المصرح به أو التلاعب بالطلبات والعروض.',
              ),
              _buildSection(
                context,
                '5. حقوق الشركة',
                'تحتفظ الشركة بالحق في رفض، إلغاء، أو تعديل أي طلب في حال وجود بيانات خاطئة، أو تسعير غير صحيح، أو نفاد الكمية، أو لأي أسباب تشغيلية أخرى.',
              ),
              _buildSection(
                context,
                '6. وضع الزائر (Guest Mode)',
                'قد يوفر التطبيق ميزة التصفح كزائر والتي تتيح إمكانيات محدودة مقارنة بالحسابات المسجلة والمعتمدة.',
              ),
              _buildSection(
                context,
                '7. إخلاء المسؤولية',
                'الشركة غير مسؤولة عن أي انقطاعات في الخدمة ناتجة عن مشاكل في الإنترنت، أو الأجهزة، أو الاستضافة، أو خدمات الطرف الثالث، أو حالات القوة القاهرة.',
              ),
              _buildSection(
                context,
                '8. القبول بالشروط',
                'استمرارك في استخدام التطبيق يُعد إقراراً وقبولاً منك بهذه الشروط والأحكام.',
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
