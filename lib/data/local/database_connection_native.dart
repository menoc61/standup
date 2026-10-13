import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:standup_app/core/app_identity.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppIdentity.databaseFileName));
    return NativeDatabase.createInBackground(file);
  });
}
