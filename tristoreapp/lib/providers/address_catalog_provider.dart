import 'package:flutter/foundation.dart';

import '../core/services/api_client.dart';
import '../models/address_catalog.dart';

class AddressCatalogProvider extends ChangeNotifier {
  AddressCatalogProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;

  List<AddressCatalogProvince> _provinces = [];
  bool _loading = false;
  String? _error;

  List<AddressCatalogProvince> get provinces => _provinces;
  bool get isLoading => _loading;
  String? get error => _error;

  String get defaultProvinceId =>
      _provinces.isNotEmpty
          ? _provinces.first.id
          : AddressCatalog.fallbackProvinceId;

  String get defaultWardId {
    if (_provinces.isEmpty) return AddressCatalog.fallbackWardId;
    final wards = _provinces.first.wards;
    return wards.isNotEmpty ? wards.first.id : AddressCatalog.fallbackWardId;
  }

  List<String> provinceIds() =>
      _provinces.map((p) => p.id).where((id) => id.isNotEmpty).toList();

  List<AddressCatalogWard> wardsForProvince(String provinceId) {
    for (final p in _provinces) {
      if (p.id == provinceId) return p.wards;
    }
    return const [];
  }

  List<String> wardIdsForProvince(String provinceId) =>
      wardsForProvince(provinceId).map((w) => w.id).toList();

  String provinceName(String id) {
    for (final p in _provinces) {
      if (p.id == id) return p.name;
    }
    return id;
  }

  String wardName(String provinceId, String wardId) {
    for (final w in wardsForProvince(provinceId)) {
      if (w.id == wardId) return w.name;
    }
    return wardId;
  }

  String formatAddressLine({
    required String houseNumber,
    required String wardId,
    required String provinceId,
  }) {
    final house = houseNumber.trim();
    final houseUsable =
        house.isNotEmpty && house != '—' && house != '-';

    final wardResolved = wardName(provinceId, wardId);
    final provResolved = provinceName(provinceId);

    // Fallback X/A: số nhà đã chứa địa chỉ đầy đủ từ KiotViet.
    if (provinceId == AddressCatalog.fallbackProvinceId &&
        wardId == AddressCatalog.fallbackWardId) {
      return houseUsable ? house : '—';
    }

    final parts = <String>[];
    if (houseUsable) parts.add(house);

    final wardOk = wardResolved != wardId && wardResolved.isNotEmpty;
    if (wardOk &&
        (!houseUsable || !_addressContainsPlace(house, wardResolved))) {
      parts.add(wardResolved);
    }

    final joinedForProv = parts.join(', ');
    final provOk = provResolved != provinceId && provResolved.isNotEmpty;
    if (provOk &&
        (!houseUsable ||
            !_addressContainsPlace(
              joinedForProv.isEmpty ? house : joinedForProv,
              provResolved,
            ))) {
      parts.add(provResolved);
    }

    if (parts.isEmpty) return '—';
    return parts.join(', ');
  }

  static String _normalizeAddressText(String raw) {
    var s = raw.trim().toLowerCase();
    const from = 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    final prefixRe = RegExp(
      r'^(tinh|tp\.?|thanh pho|t\.p\.|phuong|xa|thi tran|quan|huyen|thi xa|p\.|x\.|q\.|h\.|tt\.|ward)\s+',
    );
    for (var i = 0; i < 4; i++) {
      final next = s.replaceFirst(prefixRe, '').trim();
      if (next == s) break;
      s = next;
    }
    return s;
  }

  static bool _addressContainsPlace(String house, String placeName) {
    final h = _normalizeAddressText(house);
    final p = _normalizeAddressText(placeName);
    if (h.isEmpty || p.isEmpty) return false;
    return h.contains(p);
  }

  /// Nạp catalog nếu chưa có dữ liệu và không đang tải. An toàn gọi nhiều lần
  /// (vd sau khi đăng nhập / mỗi lần mở màn có địa chỉ) để tự phục hồi khi lần
  /// nạp đầu thất bại (mạng chập / gọi trước lúc có token).
  Future<void> ensureLoaded() async {
    if (_provinces.isNotEmpty || _loading) return;
    await load();
  }

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_provinces.isNotEmpty && !force) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.get<Map<String, dynamic>>('/admin/address-catalog');
      final catalog = AddressCatalog.fromJson(res.data ?? {});
      _provinces = catalog.provinces;
    } catch (e) {
      _error = e.toString();
      if (_provinces.isEmpty) _provinces = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
