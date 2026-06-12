import 'dart:convert';
import 'dart:math';

import 'package:tstore/core/services/storage_service.dart';
import 'package:tstore/models/management_entity.dart';
import 'package:tstore/models/management_filters.dart';
import 'package:tstore/models/management_quick_access.dart';

class ManagementQuickAccessStore {
  ManagementQuickAccessStore._();
  static final ManagementQuickAccessStore instance = ManagementQuickAccessStore._();

  static const String storageKey = 'management_quick_access_v1';

  Future<List<ManagementQuickAccess>> loadAll() async {
    final raw = await StorageService.instance.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final items = <ManagementQuickAccess>[];
      for (final e in decoded) {
        if (e is Map<String, dynamic>) {
          try {
            items.add(ManagementQuickAccess.fromJson(e));
          } catch (_) {
            // bỏ mục hỏng
          }
        } else if (e is Map) {
          try {
            items.add(
              ManagementQuickAccess.fromJson(Map<String, dynamic>.from(e)),
            );
          } catch (_) {}
        }
      }
      return _sorted(items);
    } catch (_) {
      return [];
    }
  }

  Future<ManagementQuickAccess> save({
    required String name,
    required ManagementEntity entity,
    required ManagementFilters filters,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tên truy cập nhanh không được để trống');
    }
    final safeName = trimmed.length > ManagementQuickAccess.maxNameLength
        ? trimmed.substring(0, ManagementQuickAccess.maxNameLength)
        : trimmed;

    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = ManagementQuickAccess(
      id: _newId(),
      name: safeName,
      entity: entity,
      filters: filters,
      lastUsedAtMs: now,
    );

    final list = await loadAll();
    list.insert(0, entry);
    final trimmedList = _sorted(list).take(ManagementQuickAccess.maxSaved).toList();
    await _persist(trimmedList);
    return entry;
  }

  Future<void> recordUse(String id) async {
    final list = await loadAll();
    final i = list.indexWhere((e) => e.id == id);
    if (i < 0) return;
    list[i] = list[i].copyWith(
      lastUsedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persist(_sorted(list));
  }

  Future<void> remove(String id) async {
    final list = await loadAll();
    list.removeWhere((e) => e.id == id);
    await _persist(list);
  }

  List<ManagementQuickAccess> _sorted(List<ManagementQuickAccess> items) {
    final copy = List<ManagementQuickAccess>.from(items);
    copy.sort((a, b) => b.lastUsedAtMs.compareTo(a.lastUsedAtMs));
    return copy;
  }

  Future<void> _persist(List<ManagementQuickAccess> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await StorageService.instance.saveString(storageKey, encoded);
  }

  String _newId() {
    final r = Random();
    return '${DateTime.now().millisecondsSinceEpoch}_${r.nextInt(1 << 32)}';
  }
}
