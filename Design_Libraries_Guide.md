# 📚 دليل مكتبات التصميم الموصى بها
## للتطوير الحديث لتطبيق LPCO LLC

---

## 🎨 مكتبات الأيقونات (Icons)

### 1️⃣ **Phosphor Icons** ⭐⭐⭐⭐⭐
```yaml
phosphor_flutter: ^2.1.0
```

**لماذا نوصي بها:**
- ✅ أكثر من 6,000 أيقونة
- ✅ تصميم عصري ومتناسق
- ✅ 6 أوزان مختلفة (Thin, Light, Regular, Bold, Fill, Duotone)
- ✅ مثالية للتطبيقات التجارية
- ✅ تحديثات مستمرة

**مثال الاستخدام:**
```dart
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Regular
Icon(PhosphorIcons.shoppingCart())
Icon(PhosphorIcons.heart())
Icon(PhosphorIcons.magnifyingGlass())

// Bold
Icon(PhosphorIcons.shoppingCart(PhosphorIconsStyle.bold))

// Fill
Icon(PhosphorIcons.shoppingCart(PhosphorIconsStyle.fill))

// Duotone (مميزة جداً!)
Icon(PhosphorIcons.shoppingCart(PhosphorIconsStyle.duotone))
```

**حالات الاستخدام في التطبيق:**
- Bottom Navigation: `PhosphorIcons.house()`, `PhosphorIcons.gridFour()`, `PhosphorIcons.shoppingCart()`
- App Drawer: `PhosphorIcons.user()`, `PhosphorIcons.bell()`, `PhosphorIcons.package()`
- Product Actions: `PhosphorIcons.heart()`, `PhosphorIcons.share()`, `PhosphorIcons.eye()`
- Search: `PhosphorIcons.magnifyingGlass()`

---

### 2️⃣ **Lucide Icons** ⭐⭐⭐⭐⭐
```yaml
lucide_icons_flutter: ^1.0.0
```

**لماذا نوصي بها:**
- ✅ أكثر من 1,400 أيقونة
- ✅ تصميم نظيف وبسيط
- ✅ مفتوحة المصدر
- ✅ متوافقة مع Material Design
- ✅ حجم صغير

**مثال الاستخدام:**
```dart
import 'package:lucide_icons_flutter/lucide_icons.dart';

Icon(LucideIcons.shopping_cart)
Icon(LucideIcons.heart)
Icon(LucideIcons.search)
Icon(LucideIcons.user)
Icon(LucideIcons.package)
```

**الفرق بين Phosphor و Lucide:**
- **Phosphor**: أوزان متعددة، أكثر تنوعاً، duotone مميزة
- **Lucide**: بسيطة، نظيفة، أخف في الحجم

**التوصية:** استخدم Phosphor للتطبيق الأساسي + Lucide كاحتياطي

---

### 3️⃣ **Iconify Flutter** (آلاف الأيقونات!)
```yaml
iconify_flutter: ^0.0.5
```

**المميزات:**
- ✅ الوصول لـ 200,000+ أيقونة
- ✅ كل مكتبات الأيقونات الشهيرة (Material, Font Awesome, Bootstrap Icons, etc.)
- ✅ حمل حسب الطلب (on-demand)

**مثال:**
```dart
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/mdi.dart';
import 'package:iconify_flutter/icons/fa6_solid.dart';

Iconify(Mdi.cart)
Iconify(Fa6Solid.heart)
```

**التحذير:** قد يزيد حجم التطبيق إذا استخدمت الكثير من الأيقونات

---

## 🎬 مكتبات الحركة والتحريك (Animations)

### 1️⃣ **Animate Do** ⭐⭐⭐⭐⭐ (الأسهل)
```yaml
animate_do: ^3.3.4
```

**المميزات:**
- ✅ تحريكات جاهزة (Fade, Slide, Bounce, etc.)
- ✅ سهلة الاستخدام جداً
- ✅ لا تحتاج AnimationControllers
- ✅ مثالية للمبتدئين

**الأمثلة:**
```dart
import 'package:animate_do/animate_do.dart';

// Fade In
FadeIn(
  duration: Duration(milliseconds: 500),
  child: YourWidget(),
)

// Slide In من اليمين (RTL مناسب)
SlideInRight(
  duration: Duration(milliseconds: 300),
  child: YourWidget(),
)

// Bounce In
BounceInDown(
  delay: Duration(milliseconds: 200),
  child: YourWidget(),
)

// Pulse (للأزرار المهمة)
Pulse(
  infinite: true,
  child: AddToCartButton(),
)

// Flash (للإشعارات)
Flash(
  child: NotificationBadge(),
)

// Shake (للأخطاء)
Shake(
  child: ErrorMessage(),
)
```

**حالات الاستخدام في التطبيق:**
```dart
// Hero Banner - Slide + Fade
SlideInDown(
  duration: Duration(milliseconds: 600),
  child: FadeIn(
    child: HeroBanner(),
  ),
)

// Product Cards - Staggered Animation
ListView.builder(
  itemBuilder: (context, index) {
    return FadeInUp(
      delay: Duration(milliseconds: 50 * index),
      child: ProductCard(),
    );
  },
)

// Add to Cart Button Success
void onAddToCart() {
  setState(() => _added = true);
  // Animation triggers automatically
}

_added ? BounceInDown(child: CheckIcon()) : AddIcon()

// Category Cards - Elastic Effect
ElasticIn(
  child: CategoryCard(),
)
```

---

### 2️⃣ **Flutter Animate** ⭐⭐⭐⭐⭐ (الأقوى)
```yaml
flutter_animate: ^4.5.0
```

**المميزات:**
- ✅ API حديثة ومرنة
- ✅ تحريكات معقدة بسهولة
- ✅ تسلسل التحريكات (chaining)
- ✅ تأثيرات متقدمة

**الأمثلة:**
```dart
import 'package:flutter_animate/flutter_animate.dart';

// بسيطة
Text("مرحباً")
  .animate()
  .fadeIn(duration: 600.ms)
  .scale();

// متقدمة - تسلسل
ProductCard()
  .animate()
  .fadeIn(duration: 300.ms)
  .then(delay: 100.ms)
  .slideY(begin: 0.2, end: 0)
  .then()
  .shimmer(duration: 1200.ms);

// مع Loop
AddToCartButton()
  .animate(onPlay: (controller) => controller.repeat())
  .shimmer(duration: 2.seconds)
  .shake(duration: 0.5.seconds, delay: 2.seconds);

// Conditional Animation
productCard
  .animate(
    target: isHovered ? 1 : 0,
  )
  .scale(end: 1.05)
  .elevation(end: 8);
```

**أمثلة متقدمة للتطبيق:**
```dart
// Loading Shimmer للبطاقات
Container()
  .animate(onPlay: (c) => c.repeat(reverse: true))
  .shimmer(
    duration: 1500.ms,
    color: Colors.white.withValues(alpha: 0.5),
  );

// Success Checkmark Animation
Icon(Icons.check_circle)
  .animate()
  .scale(
    begin: Offset(0, 0),
    end: Offset(1, 1),
    curve: Curves.elasticOut,
    duration: 600.ms,
  )
  .then()
  .shake();

// Product Card Entrance
ProductCard()
  .animate()
  .fadeIn(duration: 400.ms, curve: Curves.easeOut)
  .slideY(begin: 0.3, end: 0)
  .then(delay: 100.ms)
  .shimmer(duration: 800.ms);

// Price Update Animation
Text("$newPrice")
  .animate(key: ValueKey(newPrice))
  .fadeIn(duration: 200.ms)
  .scaleXY(begin: 0.8, end: 1.0)
  .then()
  .shimmer(duration: 400.ms, color: Colors.green);
```

---

### 3️⃣ **Shimmer** (للتحميل) ⭐⭐⭐⭐⭐
```yaml
shimmer: ^3.0.0
```

**الاستخدام:**
```dart
import 'package:shimmer/shimmer.dart';

Shimmer.fromColors(
  baseColor: Colors.grey[300]!,
  highlightColor: Colors.grey[100]!,
  child: Container(
    width: double.infinity,
    height: 200,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
  ),
)

// للنصوص
Shimmer.fromColors(
  baseColor: Colors.grey[300]!,
  highlightColor: Colors.grey[100]!,
  child: Column(
    children: [
      Container(width: 200, height: 20, color: Colors.white),
      SizedBox(height: 8),
      Container(width: 150, height: 16, color: Colors.white),
    ],
  ),
)
```

**Widget جاهز للاستخدام:**
```dart
class ProductCardShimmer extends StatelessWidget {
  const ProductCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.neutral200,
      highlightColor: AppColors.neutral100,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.imageRadius,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            // Title
            Container(
              width: double.infinity,
              height: 20,
              color: Colors.white,
            ),
            SizedBox(height: AppSpacing.sm),
            // Subtitle
            Container(
              width: 150,
              height: 16,
              color: Colors.white,
            ),
            SizedBox(height: AppSpacing.md),
            // Price
            Container(
              width: 100,
              height: 24,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### 4️⃣ **Flutter SpinKit** (Loading Indicators) ⭐⭐⭐⭐
```yaml
flutter_spinkit: ^5.2.1
```

**مجموعة ضخمة من مؤشرات التحميل:**
```dart
import 'package:flutter_spinkit/flutter_spinkit.dart';

// للتحميل العام
SpinKitFadingCircle(
  color: AppColors.primaryRed,
  size: 50.0,
)

// للأزرار
SpinKitThreeBounce(
  color: Colors.white,
  size: 20.0,
)

// للشاشات الكاملة
SpinKitFoldingCube(
  color: AppColors.primaryRed,
  size: 50.0,
)

// Wave (جميل للتطبيقات العربية)
SpinKitWave(
  color: AppColors.primaryRed,
  type: SpinKitWaveType.center,
)

// Pulse Ring
SpinKitPulseRing(
  color: AppColors.primaryRed,
  size: 80.0,
)
```

**Widget Loading للتطبيق:**
```dart
class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const AppLoadingIndicator({
    super.key,
    this.size = 50.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SpinKitFadingCircle(
      color: color ?? AppColors.primaryRed,
      size: size,
    );
  }
}

// في الزر
ElevatedButton(
  onPressed: _isLoading ? null : _submit,
  child: _isLoading
      ? SpinKitThreeBounce(
          color: Colors.white,
          size: 20,
        )
      : Text('إرسال'),
)
```

---

## 🎯 مكتبات UI Components

### 1️⃣ **Salomon Bottom Bar** ⭐⭐⭐⭐⭐
```yaml
salomon_bottom_bar: ^3.3.2
```

**مميزات:**
- ✅ تصميم عصري جداً
- ✅ تحريكات سلسة
- ✅ تخصيص سهل

**الاستخدام:**
```dart
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

SalomonBottomBar(
  currentIndex: _currentIndex,
  onTap: (i) => setState(() => _currentIndex = i),
  items: [
    SalomonBottomBarItem(
      icon: Icon(Icons.home),
      title: Text("الرئيسية"),
      selectedColor: AppColors.primaryRed,
    ),
    SalomonBottomBarItem(
      icon: Icon(Icons.grid_view),
      title: Text("الكتالوج"),
      selectedColor: AppColors.primaryRed,
    ),
    SalomonBottomBarItem(
      icon: Icon(Icons.shopping_cart),
      title: Text("السلة"),
      selectedColor: AppColors.primaryRed,
    ),
    SalomonBottomBarItem(
      icon: Icon(Icons.person),
      title: Text("حسابي"),
      selectedColor: AppColors.primaryRed,
    ),
  ],
)
```

---

### 2️⃣ **Flutter Slidable** ⭐⭐⭐⭐⭐
```yaml
flutter_slidable: ^3.1.1
```

**مثالي لـ:**
- قائمة السلة (حذف العناصر)
- قائمة المفضلات
- الإشعارات

**الاستخدام:**
```dart
import 'package:flutter_slidable/flutter_slidable.dart';

Slidable(
  key: ValueKey(cartItem.id),
  endActionPane: ActionPane(
    motion: const ScrollMotion(),
    children: [
      SlidableAction(
        onPressed: (context) => _removeItem(cartItem),
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        icon: Icons.delete,
        label: 'حذف',
        borderRadius: AppRadius.lgRadius,
      ),
      SlidableAction(
        onPressed: (context) => _saveForLater(cartItem),
        backgroundColor: AppColors.info,
        foregroundColor: Colors.white,
        icon: Icons.bookmark,
        label: 'حفظ',
        borderRadius: AppRadius.lgRadius,
      ),
    ],
  ),
  child: CartItemCard(item: cartItem),
)
```

---

### 3️⃣ **Card Swiper** ⭐⭐⭐⭐⭐
```yaml
card_swiper: ^3.0.1
```

**مثالي للـ Hero Banner:**
```dart
import 'package:card_swiper/card_swiper.dart';

Swiper(
  itemBuilder: (BuildContext context, int index) {
    return HeroBannerCard(banner: banners[index]);
  },
  itemCount: banners.length,
  pagination: SwiperPagination(
    builder: DotSwiperPaginationBuilder(
      activeColor: AppColors.primaryRed,
      color: Colors.white.withValues(alpha: 0.5),
    ),
  ),
  control: SwiperControl(
    color: AppColors.primaryRed,
  ),
  autoplay: true,
  autoplayDelay: 5000,
  duration: 800,
  curve: Curves.easeInOut,
  viewportFraction: 0.9,
  scale: 0.95,
)
```

---

### 4️⃣ **Awesome Dialog** ⭐⭐⭐⭐
```yaml
awesome_dialog: ^3.2.1
```

**Dialogs جميلة وجاهزة:**
```dart
import 'package:awesome_dialog/awesome_dialog.dart';

AwesomeDialog(
  context: context,
  dialogType: DialogType.success,
  animType: AnimType.bottomSlide,
  title: 'نجحت العملية',
  desc: 'تم إضافة المنتج إلى السلة',
  btnOkText: 'موافق',
  btnOkOnPress: () {},
  btnOkColor: AppColors.success,
).show();

// للتأكيد
AwesomeDialog(
  context: context,
  dialogType: DialogType.warning,
  animType: AnimType.scale,
  title: 'تأكيد الحذف',
  desc: 'هل أنت متأكد من حذف هذا المنتج؟',
  btnCancelText: 'إلغاء',
  btnCancelOnPress: () {},
  btnOkText: 'حذف',
  btnOkOnPress: () => _deleteProduct(),
  btnOkColor: AppColors.error,
).show();

// للأخطاء
AwesomeDialog(
  context: context,
  dialogType: DialogType.error,
  animType: AnimType.topSlide,
  title: 'خطأ',
  desc: 'حدث خطأ في الاتصال بالخادم',
  btnOkText: 'حسناً',
  btnOkOnPress: () {},
).show();
```

---

### 5️⃣ **Flutter EasyLoading** ⭐⭐⭐⭐⭐
```yaml
flutter_easyloading: ^3.0.5
```

**Loading overlay سهل:**
```dart
import 'package:flutter_easyloading/flutter_easyloading.dart';

// في main.dart
MaterialApp(
  builder: EasyLoading.init(),
)

// الاستخدام
void _addToCart() async {
  EasyLoading.show(
    status: 'جاري الإضافة...',
    maskType: EasyLoadingMaskType.black,
  );
  
  await cartService.addItem(item);
  
  EasyLoading.dismiss();
  
  EasyLoading.showSuccess(
    'تمت الإضافة بنجاح!',
    duration: Duration(seconds: 2),
  );
}

// تخصيص
void configureLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.custom
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = AppColors.primaryRed
    ..backgroundColor = Colors.white
    ..indicatorColor = AppColors.primaryRed
    ..textColor = AppColors.textPrimary
    ..maskColor = Colors.black.withValues(alpha: 0.5)
    ..userInteractions = false
    ..dismissOnTap = false;
}
```

---

## 📜 مكتبات التمرير والصفحات (Scrolling & Pagination)

### 1️⃣ **Pull to Refresh** ⭐⭐⭐⭐⭐
```yaml
pull_to_refresh: ^2.0.0
```

**الاستخدام:**
```dart
import 'package:pull_to_refresh/pull_to_refresh.dart';

final RefreshController _refreshController = RefreshController();

SmartRefresher(
  controller: _refreshController,
  enablePullDown: true,
  enablePullUp: true,
  header: WaterDropMaterialHeader(
    backgroundColor: AppColors.primaryRed,
    color: Colors.white,
  ),
  footer: CustomFooter(
    builder: (BuildContext context, LoadStatus? mode) {
      Widget body;
      if (mode == LoadStatus.idle) {
        body = Text("اسحب لتحميل المزيد");
      } else if (mode == LoadStatus.loading) {
        body = SpinKitThreeBounce(
          color: AppColors.primaryRed,
          size: 20,
        );
      } else if (mode == LoadStatus.failed) {
        body = Text("فشل التحميل!");
      } else if (mode == LoadStatus.canLoading) {
        body = Text("اسحب لتحميل المزيد");
      } else {
        body = Text("لا توجد بيانات إضافية");
      }
      return Container(
        height: 55.0,
        child: Center(child: body),
      );
    },
  ),
  onRefresh: _onRefresh,
  onLoading: _onLoading,
  child: ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) {
      return ProductCard(product: items[index]);
    },
  ),
);

void _onRefresh() async {
  await Future.delayed(Duration(milliseconds: 1000));
  await _loadData();
  _refreshController.refreshCompleted();
}

void _onLoading() async {
  await Future.delayed(Duration(milliseconds: 1000));
  await _loadMore();
  _refreshController.loadComplete();
}
```

---

### 2️⃣ **Infinite Scroll Pagination** ⭐⭐⭐⭐⭐
```yaml
infinite_scroll_pagination: ^4.0.0
```

**الأفضل للصفحات الكبيرة:**
```dart
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

final PagingController<int, ProductModel> _pagingController = 
    PagingController(firstPageKey: 1);

@override
void initState() {
  super.initState();
  _pagingController.addPageRequestListener((pageKey) {
    _fetchPage(pageKey);
  });
}

Future<void> _fetchPage(int pageKey) async {
  try {
    final newItems = await productRepository.getProducts(
      page: pageKey,
      pageSize: 20,
    );
    
    final isLastPage = newItems.length < 20;
    
    if (isLastPage) {
      _pagingController.appendLastPage(newItems);
    } else {
      final nextPageKey = pageKey + 1;
      _pagingController.appendPage(newItems, nextPageKey);
    }
  } catch (error) {
    _pagingController.error = error;
  }
}

// في build:
PagedGridView<int, ProductModel>(
  pagingController: _pagingController,
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: AppSpacing.md,
    crossAxisSpacing: AppSpacing.md,
    childAspectRatio: 0.7,
  ),
  builderDelegate: PagedChildBuilderDelegate<ProductModel>(
    itemBuilder: (context, item, index) => ProductCard(
      product: item,
    ),
    firstPageErrorIndicatorBuilder: (context) => ErrorView(),
    newPageErrorIndicatorBuilder: (context) => ErrorView(),
    firstPageProgressIndicatorBuilder: (context) => LoadingGrid(),
    newPageProgressIndicatorBuilder: (context) => LoadingIndicator(),
    noItemsFoundIndicatorBuilder: (context) => EmptyView(),
  ),
);

@override
void dispose() {
  _pagingController.dispose();
  super.dispose();
}
```

---

### 3️⃣ **Smooth Page Indicator** ⭐⭐⭐⭐⭐
```yaml
smooth_page_indicator: ^1.2.0
```

**للـ Carousel Indicators:**
```dart
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

final PageController _pageController = PageController();

Column(
  children: [
    SizedBox(
      height: 200,
      child: PageView.builder(
        controller: _pageController,
        itemCount: banners.length,
        itemBuilder: (context, index) {
          return BannerCard(banner: banners[index]);
        },
      ),
    ),
    SizedBox(height: AppSpacing.md),
    SmoothPageIndicator(
      controller: _pageController,
      count: banners.length,
      effect: WormEffect(
        dotColor: AppColors.neutral300,
        activeDotColor: AppColors.primaryRed,
        dotHeight: 8,
        dotWidth: 8,
        spacing: 8,
      ),
    ),
  ],
)

// تأثيرات أخرى:
// JumpingDotEffect
// ExpandingDotsEffect
// ScaleEffect
// ScrollingDotsEffect
// SlideEffect
// ColorTransitionEffect
```

---

## 🎯 توصيات التثبيت النهائية

### **المكتبات الأساسية (Must Have):**
```yaml
dependencies:
  # Icons
  phosphor_flutter: ^2.1.0
  
  # Animations - أساسية
  animate_do: ^3.3.4
  flutter_animate: ^4.5.0
  shimmer: ^3.0.0
  flutter_spinkit: ^5.2.1
  
  # UI Components
  salomon_bottom_bar: ^3.3.2
  flutter_slidable: ^3.1.1
  awesome_dialog: ^3.2.1
  flutter_easyloading: ^3.0.5
  
  # Scrolling
  pull_to_refresh: ^2.0.0
  infinite_scroll_pagination: ^4.0.0
  smooth_page_indicator: ^1.2.0
  
  # الموجود بالفعل (احتفظ بها)
  flutter_staggered_animations: ^1.1.1
  animations: ^2.1.1
  lottie: ^3.3.2
```

### **المكتبات الاختيارية (Nice to Have):**
```yaml
dependencies:
  # Icons - إضافية
  lucide_icons_flutter: ^1.0.0
  
  # UI Components - إضافية
  card_swiper: ^3.0.1
  flutter_sticky_header: ^0.6.5
  
  # Better Forms
  flutter_form_builder: ^9.4.2
  
  # Backdrop effects
  backdrop: ^0.9.1
```

---

## 💡 نصائح الاستخدام

### **1. لا تفرط في التحريكات:**
- استخدم التحريكات بذكاء
- التحريكات الكثيرة = تجربة مزعجة
- ركز على التحريكات المهمة فقط

### **2. الأداء أولاً:**
- استخدم `const` constructors
- Lazy load للصور
- Cache بذكاء

### **3. التناسق:**
- استخدم نفس نوع التحريكات في كل التطبيق
- نفس المدة الزمنية للتحريكات المتشابهة
- نفس الـ curves

### **4. RTL Support:**
- اختبر كل التحريكات في RTL
- بعض التحريكات قد تحتاج تعديل للعربية

---

## 📊 مصفوفة الاختيار

| الاحتياج | المكتبة الموصى بها | البديل |
|---------|-------------------|---------|
| أيقونات عامة | Phosphor Icons | Lucide Icons |
| تحريكات بسيطة | Animate Do | Flutter Animate |
| تحريكات معقدة | Flutter Animate | Lottie |
| Loading indicators | Flutter SpinKit | Custom |
| Shimmer loading | Shimmer | Skeletonizer |
| Bottom Nav | Salomon Bottom Bar | Custom |
| Dialogs | Awesome Dialog | Custom |
| Loading overlay | EasyLoading | Custom |
| Pull to refresh | Pull to Refresh | Custom |
| Pagination | Infinite Scroll | Custom |
| Page indicators | Smooth Page Indicator | Custom |
| Swiper/Carousel | Card Swiper | PageView |
| Slidable lists | Flutter Slidable | Dismissible |

---

**🎯 التوصية النهائية:** ابدأ بالمكتبات الأساسية، ثم أضف الاختيارية حسب الحاجة. لا تضف مكتبة إلا إذا كنت متأكداً أنك ستستخدمها!
