import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/services/api_client.dart';
import '../models/delivery.dart';
import '../models/delivery_preparation.dart';
import '../models/sale_order.dart';

class DeliveryProvider extends ChangeNotifier {
  DeliveryProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;

  List<DeliveryPublic> _myDeliveries = [];
  List<DeliveryPublic> _createdDeliveries = [];
  List<DeliveryPublic> _boardDeliveries = [];
  bool _loadingMine = false;
  bool _loadingCreated = false;
  bool _loadingBoard = false;
  String? _errorMine;
  String? _errorCreated;
  String? _errorBoard;

  List<DeliveryPublic> get myDeliveries => _myDeliveries;
  List<DeliveryPublic> get createdDeliveries => _createdDeliveries;
  List<DeliveryPublic> get boardDeliveries => _boardDeliveries;
  bool get isLoadingMine => _loadingMine;
  bool get isLoadingCreated => _loadingCreated;
  bool get isLoadingBoard => _loadingBoard;
  String? get errorMine => _errorMine;
  String? get errorCreated => _errorCreated;
  String? get errorBoard => _errorBoard;

  static List<DeliveryPublic> parseListResponse(Map<String, dynamic>? data) {
    if (data == null) return [];
    final items = data['items'];
    if (items is! List) return [];
    return items
        .map((e) => DeliveryPublic.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<DeliveryPublic> _parseList(dynamic data) {
    if (data is! Map<String, dynamic>) return parseListResponse(data);
    return parseListResponse(data);
  }

  /// Đơn giao gắn với một đơn bán (backend kiểm tra quyền đọc đơn bán).
  Future<List<DeliveryPublic>> fetchForSaleOrder(String saleOrderId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/admin/deliveries',
        queryParameters: {
          'saleOrderId': saleOrderId,
          'list': 'all',
          'page': 1,
          'limit': 20,
        },
      );
      final list = parseListResponse(res.data);
      if (list.isEmpty) return list;
      // List API có thể thiếu assignedUser; fallback fetchOne để lấy tên NV giao.
      final first = list.first;
      final assigneeName = first.assignedUser?.name?.trim() ?? '';
      final needsAssignee =
          (first.assignedUserId?.isNotEmpty ?? false) && assigneeName.isEmpty;
      if (needsAssignee) {
        final full = await fetchOne(first.id);
        if (full != null) return [full, ...list.skip(1)];
      }
      return list;
    } catch (e) {
      debugPrint('fetchForSaleOrder: $e');
      return [];
    }
  }

  /// Danh sách đơn vị vận chuyển (Cài đặt hệ thống).
  Future<List<String>> fetchShippingCarriers() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/admin/deliveries/shipping-carriers',
      );
      final raw = res.data?['carriers'];
      if (raw is! List) return [];
      return raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('fetchShippingCarriers: $e');
      return [];
    }
  }

  Future<void> loadMine() async {
    _loadingMine = true;
    _errorMine = null;
    notifyListeners();
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/admin/deliveries',
        queryParameters: {'list': 'mine', 'page': 1, 'limit': 50},
      );
      _myDeliveries = _parseList(res.data);
    } on DioException catch (e) {
      _errorMine = e.response?.data?.toString() ?? e.message;
    } catch (e) {
      _errorMine = e.toString();
    } finally {
      _loadingMine = false;
      notifyListeners();
    }
  }

  Future<void> loadBoard() async {
    _loadingBoard = true;
    _errorBoard = null;
    notifyListeners();
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/admin/deliveries',
        queryParameters: {'list': 'board', 'page': 1, 'limit': 50},
      );
      _boardDeliveries = _parseList(res.data);
    } on DioException catch (e) {
      _errorBoard = e.response?.data?.toString() ?? e.message;
    } catch (e) {
      _errorBoard = e.toString();
    } finally {
      _loadingBoard = false;
      notifyListeners();
    }
  }

  Future<void> loadCreated() async {
    _loadingCreated = true;
    _errorCreated = null;
    notifyListeners();
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/admin/deliveries',
        queryParameters: {'list': 'created', 'page': 1, 'limit': 50},
      );
      _createdDeliveries = _parseList(res.data);
    } on DioException catch (e) {
      _errorCreated = e.response?.data?.toString() ?? e.message;
    } catch (e) {
      _errorCreated = e.toString();
    } finally {
      _loadingCreated = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await Future.wait([loadMine(), loadCreated(), loadBoard()]);
  }

  Future<DeliveryPublic?> fetchOne(String id) async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/admin/deliveries/$id');
      final data = res.data;
      if (data == null) return null;
      return DeliveryPublic.fromJson(data);
    } catch (e) {
      debugPrint('fetchOne delivery: $e');
      return null;
    }
  }

  /// Đơn bán đầy đủ (mã KiotViet) khi nested `saleOrder` trên phiếu giao thiếu trường.
  Future<SaleOrderPublic?> fetchLinkedSaleOrder(String saleOrderId) async {
    try {
      final res =
          await _api.get<Map<String, dynamic>>('/admin/sale-orders/$saleOrderId');
      final data = res.data;
      if (data == null) return null;
      return SaleOrderPublic.fromJson(data);
    } catch (e) {
      debugPrint('fetchLinkedSaleOrder: $e');
      return null;
    }
  }

  Future<DeliveryPublic?> create(Map<String, dynamic> body) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/deliveries',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    final d = DeliveryPublic.fromJson(data);
    await refresh();
    return d;
  }

  Future<DeliveryPublic?> patch(String id, Map<String, dynamic> body) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/deliveries/$id',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    final d = DeliveryPublic.fromJson(data);
    await refresh();
    return d;
  }

  Future<DeliveryPublic?> patchStatus(
    String id, {
    required String status,
    String? reason,
  }) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/deliveries/$id/status',
      data: {
        'status': status,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    final data = res.data;
    if (data == null) return null;
    final d = DeliveryPublic.fromJson(data);
    await refresh();
    return d;
  }

  Future<DeliveryPublic?> assignToMe(String id) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/deliveries/$id/assign',
    );
    final data = res.data;
    if (data == null) return null;
    final d = DeliveryPublic.fromJson(data);
    await refresh();
    return d;
  }

  Future<DeliveryPublic?> addCheckinImage(
    String id, {
    required String url,
    required String type,
    String? note,
    String? mediaType,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/deliveries/$id/checkin-images',
      data: {
        'url': url,
        'type': type,
        if (note != null) 'note': note,
        if (mediaType != null && mediaType.isNotEmpty) 'mediaType': mediaType,
      },
    );
    final data = res.data;
    if (data == null) return null;
    return DeliveryPublic.fromJson(data);
  }

  Future<DeliveryPublic?> removeCheckinImage(
    String id, {
    required String url,
    required String type,
  }) async {
    final res = await _api.delete<Map<String, dynamic>>(
      '/admin/deliveries/$id/checkin-images',
      data: {'url': url, 'type': type},
    );
    final data = res.data;
    if (data == null) return null;
    return DeliveryPublic.fromJson(data);
  }

  Future<DeliveryPublic?> patchLine(
    String deliveryId,
    String lineId, {
    Map<String, bool>? preparationChecklistState,
    bool? confirmPreparation,
  }) async {
    final body = <String, dynamic>{};
    if (preparationChecklistState != null) {
      body['preparationChecklistState'] = preparationChecklistState;
    }
    if (confirmPreparation != null) {
      body['confirmPreparation'] = confirmPreparation;
    }
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/deliveries/$deliveryId/lines/$lineId',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    final d = DeliveryPublic.fromJson(data);
    await refresh();
    return d;
  }

  /// Checklist gợi ý chuẩn bị giao (server).
  Future<List<DeliveryPreparationChecklistItem>>
      fetchPreparationChecklistTemplate() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/admin/deliveries/preparation-checklist',
      );
      final items = res.data?['items'];
      if (items is! List || items.isEmpty) {
        return List<DeliveryPreparationChecklistItem>.from(
          kDefaultPreparationChecklist,
        );
      }
      return items
          .map(
            (e) => DeliveryPreparationChecklistItem.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('fetchPreparationChecklistTemplate: $e');
      return List<DeliveryPreparationChecklistItem>.from(
        kDefaultPreparationChecklist,
      );
    }
  }
}
