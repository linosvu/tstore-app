import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/services/api_client.dart';
import '../models/support_ticket.dart';

class SupportTicketsProvider extends ChangeNotifier {
  SupportTicketsProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;

  List<SupportTicketPublic> _items = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String _list = 'mine';
  String? _statusFilter;
  String? _categoryFilter;
  bool _unassignedFilter = false;
  String _search = '';

  List<SupportTicketPublic> get items => _items;
  int get page => _page;
  int get totalPages => _totalPages;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  String? get error => _error;
  String get listScope => _list;
  String? get statusFilter => _statusFilter;
  bool get unassignedFilter => _unassignedFilter;

  void setScope(String list) {
    if (_list == list) return;
    _list = list;
    notifyListeners();
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    _unassignedFilter = false;
    notifyListeners();
  }

  void setUnassignedFilter(bool value) {
    _unassignedFilter = value;
    if (value) _statusFilter = null;
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
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
    if (_categoryFilter != null && _categoryFilter!.isNotEmpty) {
      q['category'] = _categoryFilter;
    }
    if (_unassignedFilter) q['unassigned'] = true;
    final st = _search.trim();
    if (st.isNotEmpty) q['search'] = st;

    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/admin/support-tickets',
        queryParameters: q,
      );
      final data = res.data;
      if (data == null) {
        _error = 'Dữ liệu rỗng';
      } else {
        final parsed = SupportTicketsListResult.fromJson(data);
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

  Future<SupportTicketPublic?> fetchOne(String id) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/admin/support-tickets/$id',
    );
    final data = res.data;
    if (data == null) return null;
    return SupportTicketPublic.fromJson(data);
  }

  Future<SupportTicketPublic?> create(Map<String, dynamic> body) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/support-tickets',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return SupportTicketPublic.fromJson(data);
  }

  Future<SupportTicketPublic?> patch(String id, Map<String, dynamic> body) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/support-tickets/$id',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return SupportTicketPublic.fromJson(data);
  }

  Future<SupportTicketPublic?> patchStatus(String id, String status) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/support-tickets/$id/status',
      data: {'status': status},
    );
    final data = res.data;
    if (data == null) return null;
    return SupportTicketPublic.fromJson(data);
  }

  Future<SupportTicketPublic?> addNote(String id, String content) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/support-tickets/$id/notes',
      data: {'content': content},
    );
    final data = res.data;
    if (data == null) return null;
    return SupportTicketPublic.fromJson(data);
  }

  Future<ConvertToRepairResult?> convertToRepair(
    String id, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/support-tickets/$id/convert-to-repair',
      data: body ?? {},
    );
    final data = res.data;
    if (data == null) return null;
    return ConvertToRepairResult.fromJson(data);
  }
}
