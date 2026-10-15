import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/ids/ares_id.dart';
import '../../../lib/domain/archive/work_archive_entry.dart';
import '../../../lib/infrastructure/archive/file_work_archive_repository.dart';
import '../../../lib/infrastructure/storage/json_file_store.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('ares_test_'));
  tearDown(() => temp.deleteSync(recursive: true));

  FileWorkArchiveRepository repo() => FileWorkArchiveRepository(JsonFileStore(directoryProvider: () async => temp));

  WorkArchiveEntry entry(String id, DateTime at) => WorkArchiveEntry(
        id: AresId(id),
        title: '06 Ekim 2026 — $id',
        summary: 'özet $id',
        completedAt: at,
        tags: const ['sohbet'],
      );

  test('kayıtlar uygulama yeniden açılınca da durur', () async {
    await repo().save(entry('a', DateTime(2026, 10, 1)));
    final reopened = await repo().search('');
    expect(reopened.map((e) => e.id.value), ['a']);
    expect(reopened.first.tags, ['sohbet']);
  });

  test('yeni kayıt üstte listelenir ve silinen kayıt kalıcı olarak kalkar', () async {
    final first = repo();
    await first.save(entry('eski', DateTime(2026, 9, 1)));
    await first.save(entry('yeni', DateTime(2026, 10, 5)));
    expect((await first.search('')).map((e) => e.id.value), ['yeni', 'eski']);

    await first.delete('eski');
    expect((await repo().search('')).map((e) => e.id.value), ['yeni']);
  });

  test('arama başlık ve özet içinde çalışır', () async {
    final r = repo();
    await r.save(entry('alfa', DateTime(2026, 10, 1)));
    await r.save(entry('beta', DateTime(2026, 10, 2)));
    expect((await r.search('alfa')).length, 1);
  });
}
