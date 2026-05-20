class AppRoutePaths {
  static const String home = '/';
  static const String categories = '/categories';
  static const String catalog = '/catalog';
  static const String brands = '/brands';
  static const String brandsCatalog = '/brands/catalog';
  static const String categoriesCatalog = '/categories/catalog';
  static const String saved = '/saved';
  static const String cart = '/cart';
  static const String account = '/account';
  static const String orders = '/orders';
  static const String ordersDetails = '/orders/details';
  static const String notifications = '/notifications';
  static const String jobs = '/jobs';
  static const String contact = '/contact';
  static const String security = '/security';
  static const String editProfile = '/edit-profile';
  static const String admin = '/admin';
  static const String scanner = '/scanner';
  static const String login = '/login';
  static const String register = '/register';
  static const String checkout = '/checkout';
  static const String product = '/product';
  static const String search = '/search';
  static const String categoryById = '/category';
  static const String brandBySlug = '/brand';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsOfUse = '/terms-of-use';

  static String loginRedirect(String targetPath) {
    return Uri(
      path: login,
      queryParameters: <String, String>{'redirect': targetPath},
    ).toString();
  }

  static String catalogListing({
    required String title,
    bool focus = false,
    String? entry,
    String? search,
    String? type,
    String? id,
    String? slug,
    int? curatedCategoryId,
    String? curatedCategorySlug,
    String? curatedCategoryLabel,
    String basePath = catalog,
  }) {
    return Uri(
      path: basePath,
      queryParameters: <String, String>{
        'title': title,
        if (focus) 'focus': '1',
        if (entry != null && entry.trim().isNotEmpty) 'entry': entry.trim(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
        if (id != null && id.trim().isNotEmpty) 'id': id.trim(),
        if (slug != null && slug.trim().isNotEmpty) 'slug': slug.trim(),
        if (curatedCategoryId != null && curatedCategoryId > 0)
          'curatedCategoryId': '$curatedCategoryId',
        if (curatedCategorySlug != null &&
            curatedCategorySlug.trim().isNotEmpty)
          'curatedCategorySlug': curatedCategorySlug.trim(),
        if (curatedCategoryLabel != null &&
            curatedCategoryLabel.trim().isNotEmpty)
          'curatedCategoryLabel': curatedCategoryLabel.trim(),
      },
    ).toString();
  }

  static String catalogSearchEntry({
    String title = '\u0627\u0644\u0628\u062d\u062b',
    String entry = 'nav',
    String? search,
    String? basePath,
  }) {
    return catalogListing(
      basePath: basePath ?? catalog,
      title: title,
      focus: true,
      entry: entry,
      search: search,
    );
  }

  static String scannerSearchEntry({String? basePath}) {
    return Uri(
      path: scanner,
      queryParameters: <String, String>{
        'mode': 'search',
        if (basePath != null && basePath.trim().isNotEmpty)
          'basePath': basePath.trim(),
      },
    ).toString();
  }

  static String productUrl(int id) => '/product/$id';

  @Deprecated('Use productUrl instead')
  static String productById(int id) => productUrl(id);

  static String categoryUrl(int id) => '/category/$id';

  static String brandUrl(
    String slug, {
    String? title,
    int? curatedCategoryId,
    String? curatedCategorySlug,
    String? curatedCategoryLabel,
  }) {
    return Uri(
      path: '/brand/$slug',
      queryParameters: <String, String>{
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (curatedCategoryId != null && curatedCategoryId > 0)
          'curatedCategoryId': '$curatedCategoryId',
        if (curatedCategorySlug != null &&
            curatedCategorySlug.trim().isNotEmpty)
          'curatedCategorySlug': curatedCategorySlug.trim(),
        if (curatedCategoryLabel != null &&
            curatedCategoryLabel.trim().isNotEmpty)
          'curatedCategoryLabel': curatedCategoryLabel.trim(),
      },
    ).toString();
  }

  static String searchUrl({String? query}) =>
      query == null || query.trim().isEmpty ? '/search' : '/search?q=$query';

  static String adminModule(String moduleId) => '$admin/module/$moduleId';

  static String adminOrder(int orderId) => '$admin/order/$orderId';
}
