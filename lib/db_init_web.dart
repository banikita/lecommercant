import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_common/sqflite.dart';

Future<void> initDatabase() async {
  databaseFactory = databaseFactoryFfiWeb;
}