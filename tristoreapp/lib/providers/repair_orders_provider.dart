import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/services/api_client.dart';
import '../models/repair_order.dart';

class RepairOrdersProvider extends ChangeNotifier {
  RepairOrdersProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;

  List<RepairOrderPublic> _items = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String _list = 'mine';
  String? _statusFilter;
  String _search = '';

  List<RepairOrderPublic> get items => _items;
  int get page => _page;
  int get totalPages => _totalPages;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  String? get error => _error;
  String get listScope => _list;

  void setScope(String list) {
    if (_list == list) return;
    _list = list;
    notifyListeners();
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSearch(String s) {
    _search = s;
    notifyListeners();
  }

  Future<void> load({required bool reset}) async {
    if (reset) {
      if (_loading) return;
    } else {
      if (_loadingMore || _loading) return;
    }
    final nextPage = reset ? 1 : _page + 1;
    if (!reset && nextPage > _totalPages) return;

    if (reset) {
      _loading = true;
    } else {
      _loadingMore = true;
    }
    _error = null;
    notifyListeners();

    final q = <String, dynamic>{
      'page': nextPage,
      'limit': 20,
      'list': _list,
    };
    if (_statusFilter != null && _statusFilter!.isNotEmpty) {
      q['status'] = _statusFilter;
    }
    final st = _search.trim();
    if (st.isNotEmpty) q['search'] = st;

    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/admin/repair-orders',
        queryParameters: q,
      );
      final data = res.data;
      if (data == null) {
        _error = 'Dữ liệu rỗng';
      } else {
        final parsed = RepairOrdersListResult.fromJson(data);
        if (reset) {
          _items = List.from(parsed.items);
        } else {
          _items.addAll(parsed.items);
        }
        _page = nextPage;
        _totalPages = parsed.totalPages;
      }
    } on DioException catch (e) {
      _error = e.response?.data?.toString() ?? e.message ?? 'Lỗi mạng';
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<RepairOrderPublic?> create(Map<String, dynamic> body) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/repair-orders',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return RepairOrderPublic.fromJson(data);
  }

  Future<RepairOrderPublic?> patchStatus(String id, String status) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/repair-orders/$id/status',
      data: {'status': status},
    );
    final data = res.data;
    if (data == null) return null;
    return RepairOrderPublic.fromJson(data);
  }

  Future<RepairOrderPublic?> patch(String id, Map<String, dynamic> body) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/repair-orders/$id',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return RepairOrderPublic.fromJson(data);
  }
}
