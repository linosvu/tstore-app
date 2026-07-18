import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/services/api_client.dart';
import '../models/service_request.dart';

class ServiceRequestsProvider extends ChangeNotifier {
  ServiceRequestsProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;

  List<ServiceRequestPublic> _items = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String _tab = 'support';
  String? _statusFilter;
  bool _overdueOnly = false;
  String _search = '';

  List<ServiceRequestPublic> get items {
    if (!_overdueOnly) return _items;
    return _items.where((r) => r.hasOverdueTicket).toList();
  }

  int get page => _page;
  int get totalPages => _totalPages;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  String? get error => _error;
  String get tab => _tab;
  String? get statusFilter => _statusFilter;
  bool get overdueOnly => _overdueOnly;
  String get search => _search;

  void setTab(String tab) {
    if (_tab == tab) return;
    _tab = tab;
    notifyListeners();
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    _overdueOnly = false;
    notifyListeners();
  }

  void setOverdueOnly(bool value) {
    _overdueOnly = value;
    if (value) _statusFilter = null;
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
      'tab': _tab,
    };
    if (_statusFilter != null && _statusFilter!.isNotEmpty) {
      q['status'] = _statusFilter;
    }
    final st = _search.trim();
    if (st.isNotEmpty) q['search'] = st;

    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/admin/service-requests',
        queryParameters: q,
      );
      final data = res.data;
      if (data == null) {
        _error = 'Dữ liệu rỗng';
      } else {
        final parsed = ServiceRequestsListResult.fromJson(data);
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

  Future<ServiceRequestPublic?> fetchRequest(String id) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/admin/service-requests/$id',
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceRequestPublic.fromJson(data);
  }

  Future<ServiceTicketPublic?> fetchTicket(String id) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/admin/service-tickets/$id',
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<ServiceRequestPublic?> createRequest(Map<String, dynamic> body) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/service-requests',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceRequestPublic.fromJson(data);
  }

  Future<ServiceRequestPublic?> patchRequest(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/service-requests/$id',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceRequestPublic.fromJson(data);
  }

  Future<ServiceRequestPublic?> completeRequest(String id) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/service-requests/$id/complete',
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceRequestPublic.fromJson(data);
  }

  Future<ServiceRequestPublic?> cancelRequest(String id, String reason) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/service-requests/$id/cancel',
      data: {'reason': reason},
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceRequestPublic.fromJson(data);
  }

  Future<ServiceTicketPublic?> createChildTicket(
    String requestId,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/service-requests/$requestId/tickets',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<ServiceTicketPublic?> patchFeeAppointment(
    String ticketId,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/fee-appointment',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<TicketEvidencePublic?> addEvidence(
    String ticketId,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/evidences',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return TicketEvidencePublic.fromJson(data);
  }

  Future<TicketSignaturePublic?> addSignature(
    String ticketId,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/signatures',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return TicketSignaturePublic.fromJson(data);
  }

  Future<ServiceTicketPublic?> ticketAction(
    String ticketId,
    String action, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/$action',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<TakeDeviceResult?> takeDevice(
    String ticketId,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/take-device',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return TakeDeviceResult.fromJson(data);
  }

  Future<RepairSupportStats?> fetchStats() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/admin/dashboard/repair-support',
    );
    final data = res.data;
    if (data == null) return null;
    return RepairSupportStats.fromJson(data);
  }
}
