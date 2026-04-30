import 'package:flutter/widgets.dart';
import 'package:lpco_llc/app/app.dart';
import 'package:lpco_llc/app/bootstrap/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  runApp(const LpcoWholesaleApp());
}
