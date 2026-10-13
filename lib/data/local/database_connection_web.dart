import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:standup_app/core/app_identity.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: AppIdentity.databaseName,
      sqlite3Uri: Uri.base.resolve('sqlite3.wasm'),
      driftWorkerUri: Uri.base.resolve('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
