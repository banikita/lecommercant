import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> initDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}