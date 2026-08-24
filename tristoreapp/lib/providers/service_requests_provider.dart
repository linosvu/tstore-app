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
  String? _supportStaffUserId;
  String? _ticketStaffUserId;
  String? _ticketCostMode;
  String? _ticketStatus;
  bool _overdueOnly = false;
  bool _dueSoonOnly = false;
  String? _subStatusIn;
  String? _repairType;
  String? _vendorId;
  String? _technicianId;
  bool _repairOverdue = false;
  int? _dueWithinHours;
  String? _receivedFrom;
  String? _receivedTo;
  String _search = '';

  List<ServiceRequestPublic> get items {
    if (_tab == 'repair') {
      return _items;
    }
    if (_overdueOnly) {
      return _items.where((r) => r.hasOverdueTicket).toList();
    }
    if (_dueSoonOnly) {
      return _items.where((r) => r.hasDueSoonTicket).toList();
    }
    return _items;
  }

  int get page => _page;
  int get totalPages => _totalPages;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  String? get error => _error;
  String get tab => _tab;
  String? get statusFilter => _statusFilter;
  String? get supportStaffUserId => _supportStaffUserId;
  String? get ticketStaffUserId => _ticketStaffUserId;
  String? get ticketCostMode => _ticketCostMode;
  String? get ticketStatus => _ticketStatus;
  bool get overdueOnly => _overdueOnly;
  bool get dueSoonOnly => _dueSoonOnly;
  String get search => _search;

  void setTab(String tab) {
    if (_tab == tab) return;
    _tab = tab;
    notifyListeners();
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    _ticketStatus = null;
    _overdueOnly = false;
    _dueSoonOnly = false;
    notifyListeners();
  }

  void setSupportStaffUserId(String? userId) {
    _supportStaffUserId = userId;
    notifyListeners();
  }

  void setTicketStaffUserId(String? userId) {
    _ticketStaffUserId = userId;
    notifyListeners();
  }

  void setTicketCostMode(String? mode) {
    _ticketCostMode = mode;
    notifyListeners();
  }

  void setTicketStatus(String? status) {
    _ticketStatus = status;
    _statusFilter = null;
    _overdueOnly = false;
    _dueSoonOnly = false;
    notifyListeners();
  }

  void setOverdueOnly(bool value) {
    _overdueOnly = value;
    if (value) {
      _statusFilter = null;
      _ticketStatus = null;
      _dueSoonOnly = false;
      if (_tab == 'repair') _repairOverdue = true;
    } else if (_tab == 'repair') {
      _repairOverdue = false;
    }
    notifyListeners();
  }

  void setDueSoonOnly(bool value) {
    _dueSoonOnly = value;
    if (value) {
      _statusFilter = null;
      _ticketStatus = null;
      _overdueOnly = false;
      if (_tab == 'repair') _dueWithinHours = 12;
    } else if (_tab == 'repair') {
      _dueWithinHours = null;
    }
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
    if (_supportStaffUserId != null && _supportStaffUserId!.isNotEmpty) {
      q['supportStaffUserId'] = _supportStaffUserId;
    }
    if (_ticketStaffUserId != null && _ticketStaffUserId!.isNotEmpty) {
      q['ticketStaffUserId'] = _ticketStaffUserId;
    }
    if (_ticketCostMode != null && _ticketCostMode!.isNotEmpty) {
      q['ticketCostMode'] = _ticketCostMode;
    }
    if (_ticketStatus != null && _ticketStatus!.isNotEmpty) {
      q['ticketStatus'] = _ticketStatus;
    }
    if (_subStatusIn != null && _subStatusIn!.isNotEmpty) {
      q['subStatusIn'] = _subStatusIn;
    }
    if (_repairType != null) q['repairType'] = _repairType;
    if (_vendorId != null) q['vendorId'] = _vendorId;
    if (_technicianId != null) q['technicianId'] = _technicianId;
    if (_repairOverdue) q['overdue'] = 'true';
    if (_dueWithinHours != null) q['dueWithinHours'] = _dueWithinHours;
    if (_tab == 'repair') {
      if (_overdueOnly) q['overdue'] = 'true';
      if (_dueSoonOnly) q['dueWithinHours'] = 12;
    }
    if (_receivedFrom != null && _receivedFrom!.isNotEmpty) {
      q['receivedFrom'] = _receivedFrom;
    }
    if (_receivedTo != null && _receivedTo!.isNotEmpty) {
      q['receivedTo'] = _receivedTo;
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

  Future<ServiceTicketPublic?> fetchTicket(
    String id, {
    bool includeDeleted = false,
  }) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/admin/service-tickets/$id',
      queryParameters: includeDeleted ? {'includeDeleted': 'true'} : null,
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

  Future<ServiceTicketPublic?> patchTicketRequestInfo(
    String ticketId,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/request-info',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<ServiceTicketPublic?> patchTicketAssignee(
    String ticketId,
    String staffUserId,
  ) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/assignee',
      data: {'staffUserId': staffUserId},
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<ServiceTicketPublic?> patchTicketAppointment(
    String ticketId, {
    required String appointmentDate,
    required String appointmentSlot,
  }) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/appointment',
      data: {
        'appointmentDate': appointmentDate,
        'appointmentSlot': appointmentSlot,
      },
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<ServiceTicketPublic?> patchTicketHandlingNote(
    String ticketId,
    String? note,
  ) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/handling-note',
      data: {'note': note},
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<ServiceTicketPublic?> patchTicketCost(
    String ticketId,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/cost',
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

  Future<ServiceTicketPublic?> removeSignature(
    String ticketId,
    String signatureId,
  ) async {
    final res = await _api.delete<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/signatures/$signatureId',
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<ServiceTicketPublic?> removeEvidence(
    String ticketId,
    String evidenceId,
  ) async {
    final res = await _api.delete<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/evidences/$evidenceId',
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<ServiceTicketPublic?> softDeleteTicket(String ticketId) async {
    final res = await _api.delete<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId',
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<ServiceTicketPublic?> restoreTicket(String ticketId) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/restore',
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<ServiceTicketPublic?> createOnsitePaymentProposal(
    String ticketId,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/payment-proposals',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<ServiceTicketPublic?> confirmOnsitePaymentProposal(
    String proposalId,
  ) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/service-tickets/payment-proposals/$proposalId/confirm',
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
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

  Future<ServiceTicketPublic?> patchTicket(
    String ticketId,
    String action, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/service-tickets/$ticketId/$action',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    return ServiceTicketPublic.fromJson(data);
  }

  Future<List<RepairVendorPublic>> fetchRepairVendors() async {
    final res = await _api.get<Map<String, dynamic>>('/admin/repair-vendors');
    final raw = res.data?['items'];
    if (raw is! List) return [];
    return raw
        .map((e) => RepairVendorPublic.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RepairTechnicianPublic>> fetchRepairTechnicians() async {
    final res =
        await _api.get<Map<String, dynamic>>('/admin/repair-technicians');
    final raw = res.data?['items'];
    if (raw is! List) return [];
    return raw
        .map((e) => RepairTechnicianPublic.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, int>> fetchRepairStats() async {
    final res =
        await _api.get<Map<String, dynamic>>('/admin/service-requests/repair-stats');
    final counts = res.data?['counts'];
    if (counts is! Map) return {};
    return counts.map((k, v) => MapEntry('$k', (v as num?)?.toInt() ?? 0));
  }

  void setRepairListFilters({
    String? subStatusIn,
    String? repairType,
    String? vendorId,
    String? technicianId,
    bool? repairOverdue,
    int? dueWithinHours,
    String? receivedFrom,
    String? receivedTo,
    bool clearSubStatus = false,
    bool clearRepairType = false,
    bool clearVendor = false,
    bool clearTechnician = false,
    bool clearReceivedDates = false,
  }) {
    if (clearSubStatus) _subStatusIn = null;
    else if (subStatusIn != null) _subStatusIn = subStatusIn;
    if (clearRepairType) _repairType = null;
    else if (repairType != null) _repairType = repairType;
    if (clearVendor) _vendorId = null;
    else if (vendorId != null) _vendorId = vendorId;
    if (clearTechnician) _technicianId = null;
    else if (technicianId != null) _technicianId = technicianId;
    if (repairOverdue != null) _repairOverdue = repairOverdue;
    if (dueWithinHours != null) _dueWithinHours = dueWithinHours;
    if (clearReceivedDates) {
      _receivedFrom = null;
      _receivedTo = null;
    } else {
      if (receivedFrom != null) {
        _receivedFrom = receivedFrom.isEmpty ? null : receivedFrom;
      }
      if (receivedTo != null) {
        _receivedTo = receivedTo.isEmpty ? null : receivedTo;
      }
    }
    notifyListeners();
  }

  String? get subStatusIn => _subStatusIn;
  String? get repairTypeFilter => _repairType;
  String? get vendorIdFilter => _vendorId;
  String? get technicianIdFilter => _technicianId;
  String? get receivedFromFilter => _receivedFrom;
  String? get receivedToFilter => _receivedTo;

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

  static String dioMessage(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null) {
        final m = d['message'];
        if (m is List) return m.map((x) => '$x').join('\n');
        return '$m';
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }
}
