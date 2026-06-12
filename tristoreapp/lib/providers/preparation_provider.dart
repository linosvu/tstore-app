import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/services/api_client.dart';
import '../models/preparation_order.dart';
import '../models/sale_order.dart';

class PreparationProvider extends ChangeNotifier {
  PreparationProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;
  ApiClient get api => _api;

  List<PreparationOrderPublic> _mine = [];
  List<PreparationOrderPublic> _created = [];
  List<PreparationOrderPublic> _board = [];
  bool _loadingMine = false;
  bool _loadingCreated = false;
  bool _loadingBoard = false;
  String? _errorMine;
  String? _errorCreated;
  String? _errorBoard;

  List<PreparationOrderPublic> get myItems => _mine;
  List<PreparationOrderPublic> get createdItems => _created;
  List<PreparationOrderPublic> get boardItems => _board;
  bool get isLoadingMine => _loadingMine;
  bool get isLoadingCreated => _loadingCreated;
  bool get isLoadingBoard => _loadingBoard;
  String? get errorMine => _errorMine;
  String? get errorCreated => _errorCreated;
  String? get errorBoard => _errorBoard;

  static List<PreparationOrderPublic> parseListResponse(Map<String, dynamic>? data) {
    if (data == null) return [];
    final items = data['items'];
    if (items is! List) return [];
    return items
        .map((e) => PreparationOrderPublic.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> loadMine() async {
    _loadingMine = true;
    _errorMine = null;
    notifyListeners();
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/admin/preparations',
        queryParameters: {'list': 'mine', 'page': 1, 'limit': 50},
      );
      _mine = parseListResponse(res.data);
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
        '/admin/preparations',
        queryParameters: {'list': 'board', 'page': 1, 'limit': 50},
      );
      _board = parseListResponse(res.data);
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
        '/admin/preparations',
        queryParameters: {'list': 'created', 'page': 1, 'limit': 50},
      );
      _created = parseListResponse(res.data);
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

  Future<PreparationOrderPublic?> fetchOne(String id) async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/admin/preparations/$id');
      final data = res.data;
      if (data == null) return null;
      return PreparationOrderPublic.fromJson(data);
    } catch (e) {
      debugPrint('fetchOne preparation: $e');
      return null;
    }
  }

  /// Đơn bán đầy đủ (mã KiotViet) khi nested `saleOrder` trên phiếu CB/GH thiếu trường.
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

  Future<PreparationOrderPublic?> fetchForSaleOrder(String saleOrderId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/admin/preparations/by-sale-order/$saleOrderId',
      );
      final data = res.data;
      if (data == null) return null;
      return PreparationOrderPublic.fromJson(data);
    } catch (e) {
      debugPrint('fetchForSaleOrder preparation: $e');
      return null;
    }
  }

  Future<PreparationOrderPublic?> assignToMe(String id) async {
    final res = await _api.post<Map<String, dynamic>>('/admin/preparations/$id/assign');
    final data = res.data;
    if (data == null) return null;
    final d = PreparationOrderPublic.fromJson(data);
    await refresh();
    return d;
  }

  Future<PreparationOrderPublic?> patchStatus(String id, String status) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/preparations/$id/status',
      data: {'status': status},
    );
    final data = res.data;
    if (data == null) return null;
    final d = PreparationOrderPublic.fromJson(data);
    await refresh();
    return d;
  }

  Future<PreparationOrderPublic?> patchNotes(String id, String? notes) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/preparations/$id',
      data: {'notes': notes},
    );
    final data = res.data;
    if (data == null) return null;
    final d = PreparationOrderPublic.fromJson(data);
    await refresh();
    return d;
  }

  Future<PreparationOrderPublic?> patch(String id, Map<String, dynamic> body) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/preparations/$id',
      data: body,
    );
    final data = res.data;
    if (data == null) return null;
    final d = PreparationOrderPublic.fromJson(data);
    await refresh();
    return d;
  }

  Future<PreparationOrderPublic?> patchLine(
    String preparationId,
    String lineId, {
    required bool isChecked,
  }) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/admin/preparations/$preparationId/lines/$lineId',
      data: {'isChecked': isChecked},
    );
    final data = res.data;
    if (data == null) return null;
    final d = PreparationOrderPublic.fromJson(data);
    await refresh();
    return d;
  }

  Future<PreparationOrderPublic?> addImage(
    String id, {
    required String url,
    String? note,
    String? mediaType,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/admin/preparations/$id/images',
      data: {
        'url': url,
        if (note != null && note.isNotEmpty) 'note': note,
        if (mediaType != null && mediaType.isNotEmpty) 'mediaType': mediaType,
      },
    );
    final data = res.data;
    if (data == null) return null;
    final d = PreparationOrderPublic.fromJson(data);
    await refresh();
    return d;
  }

  Future<PreparationOrderPublic?> removeImage(
    String id, {
    required String url,
  }) async {
    final res = await _api.delete<Map<String, dynamic>>(
      '/admin/preparations/$id/images',
      data: {'url': url},
    );
    final data = res.data;
    if (data == null) return null;
    final d = PreparationOrderPublic.fromJson(data);
    await refresh();
    return d;
  }
}
