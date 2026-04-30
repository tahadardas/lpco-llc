enum AdminModuleKind {
  stats,
  orders,
  users,
  members,
  settings,
  diagnostics,
  notifications,
  homeBanner,
  homeLayout,
  appTheme,
  popupConfig,
  products,
  reviews,
  ordering,
}

enum AdminModuleSupport { fullControl, readOnly, partial, unavailable }

extension AdminModuleSupportX on AdminModuleSupport {
  bool get isAvailable => this != AdminModuleSupport.unavailable;
  bool get canWrite => this == AdminModuleSupport.fullControl;

  static AdminModuleSupport fromApi(String value) {
    switch (value) {
      case 'full':
      case 'full_control':
        return AdminModuleSupport.fullControl;
      case 'read_only':
      case 'readonly':
        return AdminModuleSupport.readOnly;
      case 'partial':
      case 'partially_implemented':
        return AdminModuleSupport.partial;
      default:
        return AdminModuleSupport.unavailable;
    }
  }
}

class AdminModule {
  final String id;
  final AdminModuleKind kind;
  final String title;
  final String description;
  final AdminModuleSupport support;
  final bool canRead;
  final bool canWrite;
  final String? gapMessage;

  const AdminModule({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    this.support = AdminModuleSupport.unavailable,
    this.canRead = false,
    this.canWrite = false,
    this.gapMessage,
  });

  bool get isAvailable => support.isAvailable;

  AdminModule copyWith({
    String? title,
    String? description,
    AdminModuleSupport? support,
    bool? canRead,
    bool? canWrite,
    String? gapMessage,
  }) {
    return AdminModule(
      id: id,
      kind: kind,
      title: title ?? this.title,
      description: description ?? this.description,
      support: support ?? this.support,
      canRead: canRead ?? this.canRead,
      canWrite: canWrite ?? this.canWrite,
      gapMessage: gapMessage ?? this.gapMessage,
    );
  }
}

const List<AdminModule> kAdminModuleDefinitions = <AdminModule>[
  AdminModule(
    id: 'stats',
    kind: AdminModuleKind.stats,
    title: 'لوحة التحكم',
    description: 'مؤشرات الأداء، النشاط الأخير، وصحة النظام.',
    support: AdminModuleSupport.readOnly,
    canRead: true,
  ),
  AdminModule(
    id: 'orders',
    kind: AdminModuleKind.orders,
    title: 'إدارة الطلبات',
    description: 'البحث، الفلترة، تحديث الحالة، والفاتورة.',
  ),
  AdminModule(
    id: 'users',
    kind: AdminModuleKind.users,
    title: 'إدارة المستخدمين',
    description: 'فحص حسابات المستخدمين والأدوار والمجموعات.',
  ),
  AdminModule(
    id: 'members',
    kind: AdminModuleKind.members,
    title: 'إدارة الأعضاء',
    description: 'إنشاء وتحديث وحذف حسابات الأعضاء التجارية.',
  ),
  AdminModule(
    id: 'settings',
    kind: AdminModuleKind.settings,
    title: 'إعدادات التطبيق',
    description: 'التجارة، الحماية، التكاملات، والبريد الإداري.',
  ),
  AdminModule(
    id: 'diagnostics',
    kind: AdminModuleKind.diagnostics,
    title: 'التشخيص والعمليات',
    description: 'جاهزية JWT وWooCommerce والإشعارات والفواتير.',
  ),
  AdminModule(
    id: 'notifications',
    kind: AdminModuleKind.notifications,
    title: 'مركز الإشعارات',
    description: 'إرسال الإشعارات، التاريخ، والإحصاءات.',
  ),
  AdminModule(
    id: 'home-banner',
    kind: AdminModuleKind.homeBanner,
    title: 'بانر الرئيسية',
    description: 'إدارة البانر الرئيسي المستخدم داخل التطبيق.',
  ),
  AdminModule(
    id: 'home-layout',
    kind: AdminModuleKind.homeLayout,
    title: 'تخطيط الرئيسية',
    description: 'ترتيب أقسام الصفحة الرئيسية وتكوينها.',
  ),
  AdminModule(
    id: 'app-theme',
    kind: AdminModuleKind.appTheme,
    title: 'ثيم التطبيق',
    description: 'ألوان وثيم التطبيق القادمة من اللوحة.',
  ),
  AdminModule(
    id: 'popup-config',
    kind: AdminModuleKind.popupConfig,
    title: 'النافذة المنبثقة',
    description: 'التحكم في الإعلان المنبثق وتوجيهه.',
  ),
  AdminModule(
    id: 'products',
    kind: AdminModuleKind.products,
    title: 'إدارة المنتجات',
    description: 'البحث، الفلاتر، والحقول التشغيلية الآمنة للمنتج.',
  ),
  AdminModule(
    id: 'reviews',
    kind: AdminModuleKind.reviews,
    title: 'مراجعة التقييمات',
    description: 'فحص التقييمات واعتمادها أو إيقافها.',
  ),
  AdminModule(
    id: 'ordering',
    kind: AdminModuleKind.ordering,
    title: 'ترتيب الواجهة',
    description: 'ترتيب المنتجات المميزة والتصنيفات والعلامات.',
  ),
];
