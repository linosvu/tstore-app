import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/services/api_client.dart';
import '../models/task.dart';

class TasksProvider extends ChangeNotifier {
  TasksProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;

  List<TaskPublic> _items = [];
  List<TaskPublic> _recent = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loadingRecent = false;
  String? _error;
  String? _recentError;
  String _list = 'mine';
  String? _statusFilter;
  bool _overdueFilter = false;
  String _search = '';

  ApiClient get api => _api;

  List<TaskPublic> get items => _items;
  List<TaskPublic> get recent => _recent;
  int get page => _page;
  int get totalPages => _totalPages;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get isLoadingRecent => _loadingRecent;
  String? get error => _error;
  String? get recentError => _recentError;
  String get listScope => _list;
  String? get statusFilter => _statusFilter;
  bool get overdueFilter => _overdueFilter;

  void setScope(String list) {
    if (_list == list) return;
    _list = list;
    notifyListeners();
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    _overdueFilter = false;
    notifyListeners();
  }

  void setOverdueFilter(bool value) {
    _overdueFilter = value;
    if (value) _statusFilter = null;
    notifyListeners();
  }

  void setSearch(String s) {
    _search = s;
    notifyListeners();
  }

  Future<void> loadRecent() async {
    if (_loadingRecent) return;
    _loadingRecent = true;
    _recentError = null;
    notifyListeners();
    try {
      final res = await _api.get<Map<String, dynamic>>('/admin/tasks/recent');
      final data = res.data;
      if (data == null) {
        _recentError = 'Dữ liệu rỗng';
      } else {
        final raw = data['items'];
        _recent = raw is List
            ? raw
                .whereType<Map<String, dynamic>>()
                .map(TaskPublic.fromJson)
                .toList()
            : [];
      }
    } on DioException catch (e) {
      _recentError = e.response?.data?.toString() ?? e.message ?? 'Lỗi mạng';
    } catch (e) {
      _recentError = e.toString();
    } finally {
      _loadingRecent = false;
      notifyListeners();
    }
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
    if (_overdueFilter) q['overdue'] = true;
    final st = _search.trim();
    if (st.isNotEmpty) q['search'] = st;

    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/admin/tasks',
        queryParameters: q,
      );
      final data = res.data;
      if (data == null) {
        _error = 'Dữ liệu rỗng';
      } else {
        final parsed = TasksListResult.fromJson(data);
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

  Future<TaskPublic?> fetchOne(String id) async {
    final res = await _api.get<Map<String, dynamic>>('/admin/tasks/$id');
    final data = res.data;
    if (data == null) return null;
    return TaskPublic.fromJson(data);
  }

  Future<TaskPublic?> create(Map<String, dynamic> body) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/tasks',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return TaskPublic.fromJson(data);
  }

  Future<TaskPublic?> patch(String id, Map<String, dynamic> body) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/tasks/$id',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return TaskPublic.fromJson(data);
  }

  Future<TaskPublic?> patchStatus(String id, String status) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/tasks/$id/status',
      data: {'status': status},
    );
    final data = res.data;
    if (data == null) return null;
    return TaskPublic.fromJson(data);
  }

  Future<TaskPublic?> addCollaborator(
    String id, {
    required String userId,
    bool canEdit = false,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/tasks/$id/collaborators',
      data: {'userId': userId, 'canEdit': canEdit},
    );
    final data = res.data;
    if (data == null) return null;
    return TaskPublic.fromJson(data);
  }

  Future<TaskPublic?> removeCollaborator(String id, String userId) async {
    final res = await _api.delete<Map<String, dynamic>>(
      '/admin/tasks/$id/collaborators/$userId',
    );
    final data = res.data;
    if (data == null) return null;
    return TaskPublic.fromJson(data);
  }

  Future<TaskPublic?> addAttachment(
    String id, {
    required String url,
    String? mediaType,
    String? note,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/tasks/$id/attachments',
      data: {
        'url': url,
        if (mediaType != null) 'mediaType': mediaType,
        if (note != null) 'note': note,
      },
    );
    final data = res.data;
    if (data == null) return null;
    return TaskPublic.fromJson(data);
  }

  Future<TaskPublic?> removeAttachment(String id, {required String url}) async {
    final res = await _api.delete<Map<String, dynamic>>(
      '/admin/tasks/$id/attachments',
      data: {'url': url},
    );
    final data = res.data;
    if (data == null) return null;
    return TaskPublic.fromJson(data);
  }

  Future<TaskPublic?> addNote(String id, {required String content}) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/tasks/$id/notes',
      data: {'content': content},
    );
    final data = res.data;
    if (data == null) return null;
    return TaskPublic.fromJson(data);
  }

  static String? dioMessage(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null) return '${d['message']}';
      return e.message;
    }
    return e.toString();
  }
}
