import 'package:dio/dio.dart';

import '../core/services/api_client.dart';
import '../models/delivery.dart';
import '../models/management_entity.dart';
import '../models/management_filters.dart';
import '../models/management_stats.dart';
import '../models/preparation_order.dart';
import '../models/sale_order.dart';
import '../models/task.dart';

class ManagementProvider {
  ManagementProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<ManagementStatsResponse> fetchStats({
    required ManagementEntity entity,
    required ManagementFilters filters,
  }) async {
    final q = <String, dynamic>{
      'entity': entity.apiValue,
      ...filters.toQueryParams(includeStatus: true),
    };
    final res = await _api.get<Map<String, dynamic>>(
      '/admin/management/stats',
      queryParameters: q,
    );
    final data = res.data;
    if (data == null) throw Exception('Dữ liệu rỗng');
    return ManagementStatsResponse.fromJson(data);
  }

  Future<({List<SaleOrderPublic> items, int totalPages})> fetchSaleOrdersPage({
    required ManagementFilters filters,
    required int page,
    int limit = 20,
    String listScope = 'all',
  }) async {
    final q = <String, dynamic>{
      'page': page,
      'limit': limit,
      'list': listScope,
      ...filters.toQueryParams(),
    };
    final res = await _api.get<Map<String, dynamic>>(
      '/admin/sale-orders',
      queryParameters: q,
    );
    return _parseSaleOrders(res.data);
  }

  Future<({List<PreparationOrderPublic> items, int totalPages})>
      fetchPreparationsPage({
    required ManagementFilters filters,
    required int page,
    int limit = 20,
    String listScope = 'all',
  }) async {
    final q = <String, dynamic>{
      'page': page,
      'limit': limit,
      'list': listScope,
      ...filters.toQueryParams(),
    };
    if (filters.createdByUserId != null) {
      q['saleOrderCreatedByUserId'] = filters.createdByUserId;
    }
    final res = await _api.get<Map<String, dynamic>>(
      '/admin/preparations',
      queryParameters: q,
    );
    return _parsePreparations(res.data);
  }

  Future<({List<TaskPublic> items, int totalPages})> fetchTasksPage({
    required ManagementFilters filters,
    required int page,
    int limit = 20,
  }) async {
    final q = <String, dynamic>{
      'page': page,
      'limit': limit,
      'list': 'all',
      ...filters.toQueryParams(),
    };
    final res = await _api.get<Map<String, dynamic>>(
      '/admin/tasks',
      queryParameters: q,
    );
    return _parseTasks(res.data);
  }

  Future<({List<DeliveryPublic> items, int totalPages})> fetchDeliveriesPage({
    required ManagementFilters filters,
    required int page,
    int limit = 20,
    String listScope = 'all',
  }) async {
    final q = <String, dynamic>{
      'page': page,
      'limit': limit,
      'list': listScope,
      ...filters.toQueryParams(),
    };
    final res = await _api.get<Map<String, dynamic>>(
      '/admin/deliveries',
      queryParameters: q,
    );
    return _parseDeliveries(res.data);
  }

  Future<List<({String id, String name, String email})>> fetchStaffUsers() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/admin/users',
      queryParameters: {'page': 1, 'limit': 100},
    );
    final data = res.data;
    final items = data?['items'];
    if (items is! List) return [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((u) {
          final id = u['id'] as String? ?? '';
          final name = (u['fullName'] as String? ?? u['email'] as String? ?? '')
              .trim();
          final email = u['email'] as String? ?? '';
          return (id: id, name: name.isEmpty ? email : name, email: email);
        })
        .where((u) => u.id.isNotEmpty)
        .toList();
  }

  ({List<SaleOrderPublic> items, int totalPages}) _parseSaleOrders(
    Map<String, dynamic>? data,
  ) {
    if (data == null) return (items: <SaleOrderPublic>[], totalPages: 1);
    final raw = data['items'];
    final items = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(SaleOrderPublic.fromJson)
            .toList()
        : <SaleOrderPublic>[];
    final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
    return (items: items, totalPages: totalPages);
  }

  ({List<PreparationOrderPublic> items, int totalPages}) _parsePreparations(
    Map<String, dynamic>? data,
  ) {
    if (data == null) return (items: <PreparationOrderPublic>[], totalPages: 1);
    final raw = data['items'];
    final items = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(PreparationOrderPublic.fromJson)
            .toList()
        : <PreparationOrderPublic>[];
    final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
    return (items: items, totalPages: totalPages);
  }

  ({List<TaskPublic> items, int totalPages}) _parseTasks(
    Map<String, dynamic>? data,
  ) {
    if (data == null) return (items: <TaskPublic>[], totalPages: 1);
    final raw = data['items'];
    final items = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(TaskPublic.fromJson)
            .toList()
        : <TaskPublic>[];
    final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
    return (items: items, totalPages: totalPages);
  }

  ({List<DeliveryPublic> items, int totalPages}) _parseDeliveries(
    Map<String, dynamic>? data,
  ) {
    if (data == null) return (items: <DeliveryPublic>[], totalPages: 1);
    final raw = data['items'];
    final items = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(DeliveryPublic.fromJson)
            .toList()
        : <DeliveryPublic>[];
    final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
    return (items: items, totalPages: totalPages);
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
