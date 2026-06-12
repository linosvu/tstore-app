import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:tstore/core/services/api_client.dart';
import 'package:tstore/models/sale_order.dart';

/// Dòng sản phẩm trong form tạo đơn (giá là bản sao tại thời điểm thêm).
class SaleOrderDraftLine {
  SaleOrderDraftLine({
    this.lineId,
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.unitPrice,
    this.fragile = false,
    this.bulky = false,
    this.needsInstallation = false,
    this.carefulPackaging = false,
    this.alreadyPaid = true,
  });

  /// ID dòng trên server (khi sửa đơn đã có — giữ FK giao/chuẩn bị).
  final String? lineId;

  final String productId;
  final String productName;
  final String productCode;
  int quantity;
  int unitPrice;
  bool fragile;
  bool bulky;
  bool needsInstallation;
  bool carefulPackaging;
  bool alreadyPaid;
}

class SaleOrderDraftProvider extends ChangeNotifier {
  SaleOrderDraftProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;

  String? orderId;
  String? customerId;
  String orderSource = 'internal';
  String orderStatus = 'draft';
  String customerName = '';
  String customerPhone = '';
  String houseNumber = '';
  String wardId = 'A';
  String provinceId = 'X';
  final List<SaleOrderDraftLine> lines = [];
  String paymentTerms = 'pay_on_delivery';
  DateTime? scheduledPaymentDate;
  int prepaidAmount = 0;
  String orderNotes = '';
  DateTime? expectedDeliveryAt;

  bool saving = false;
  String? lastError;

  Timer? _debounce;

  /// Gọi từ UI sau khi sửa [lines] trực tiếp (notifyListeners là protected).
  void bump() => notifyListeners();

  void scheduleAutosave(void Function() onSave) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), onSave);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void applyCustomer(CustomerPublic c) {
    customerId = c.id;
    customerName = c.name;
    customerPhone = c.phone ?? '';
    if (c.addresses.isNotEmpty) {
      final a = c.addresses.first;
      houseNumber = a.houseNumber;
      wardId = a.wardId;
      provinceId = a.provinceId;
    } else {
      houseNumber = '';
      wardId = 'A';
      provinceId = 'X';
    }
    notifyListeners();
  }

  /// Xóa chọn khách (đổi SĐT tìm lại / chưa chọn).
  void clearCustomerSelection() {
    customerId = null;
    customerName = '';
    customerPhone = '';
    houseNumber = '';
    wardId = 'A';
    provinceId = 'X';
    notifyListeners();
  }

  void applyLoadedOrder(SaleOrderPublic o) {
    orderId = o.id;
    orderSource = o.orderSource;
    orderStatus = o.status;
    customerId = o.customerId;
    // "scheduled" không còn trên app — map sang trả trước một phần + ngày hẹn.
    paymentTerms =
        o.paymentTerms == 'scheduled' ? 'partial_prepayment' : o.paymentTerms;
    prepaidAmount = o.prepaidAmount;
    final snap = o.deliveryAddressSnapshot;
    houseNumber = (snap['houseNumber'] as String?) ?? '';
    wardId = (snap['wardId'] as String?) ?? 'A';
    provinceId = (snap['provinceId'] as String?) ?? 'X';
    lines
      ..clear()
      ..addAll(
        o.lines.map(
          (l) => SaleOrderDraftLine(
            lineId: l.id,
            productId: l.productId,
            productName: l.productName ?? '',
            productCode: l.productCode ?? '',
            quantity: l.quantity,
            unitPrice: l.unitPrice,
            fragile: l.fragile,
            bulky: l.bulky,
            needsInstallation: l.needsInstallation,
            carefulPackaging: l.carefulPackaging,
            alreadyPaid: l.alreadyPaid,
          ),
        ),
      );
    if (o.scheduledPaymentDate != null && o.scheduledPaymentDate!.isNotEmpty) {
      scheduledPaymentDate = DateTime.tryParse(o.scheduledPaymentDate!);
    } else {
      scheduledPaymentDate = null;
    }
    final c = o.customer;
    if (c != null) {
      if (c.name.trim().isNotEmpty) customerName = c.name.trim();
      customerPhone = c.phone?.trim() ?? customerPhone;
    }
    final n = o.notes?.trim();
    orderNotes = (n == null || n.isEmpty)
        ? ''
        : (n.length > 500 ? n.substring(0, 500) : n);
    final ed = o.expectedDeliveryAt?.trim();
    expectedDeliveryAt =
        ed != null && ed.isNotEmpty ? DateTime.tryParse(ed) : null;
    notifyListeners();
  }

  void clearDraft() {
    orderId = null;
    orderSource = 'internal';
    orderStatus = 'draft';
    customerId = null;
    customerName = '';
    customerPhone = '';
    houseNumber = '';
    wardId = 'A';
    provinceId = 'X';
    lines.clear();
    paymentTerms = 'pay_on_delivery';
    scheduledPaymentDate = null;
    prepaidAmount = 0;
    orderNotes = '';
    expectedDeliveryAt = null;
    notifyListeners();
  }

  Map<String, dynamic> _draftBody() {
    return {
      if (orderId != null) 'id': orderId,
      if (customerId != null && customerId!.trim().isNotEmpty)
        'customerId': customerId,
      'deliveryAddressSnapshot': {
        'houseNumber': houseNumber.trim(),
        'wardId': wardId,
        'provinceId': provinceId,
      },
      'paymentTerms': paymentTerms,
      if (paymentTerms == 'partial_prepayment' && scheduledPaymentDate != null)
        'scheduledPaymentDate': _dateOnlyIso(scheduledPaymentDate!),
      'prepaidAmount': prepaidAmount,
      'notes': orderNotes.trim().isEmpty ? null : orderNotes.trim(),
      'expectedDeliveryAt': expectedDeliveryAt?.toUtc().toIso8601String(),
      'lines': lines
          .map(
            (l) => {
              if (l.lineId != null) 'id': l.lineId,
              'productId': l.productId,
              'quantity': l.quantity,
              'unitPrice': l.unitPrice,
              'fragile': l.fragile,
              'bulky': l.bulky,
              'needsInstallation': l.needsInstallation,
              'carefulPackaging': l.carefulPackaging,
              'alreadyPaid': l.alreadyPaid,
            },
          )
          .toList(),
    };
  }

  static String _dateOnlyIso(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// `paid_in_full`: backend cần `prepaidAmount` = phần còn nợ sau các dòng đã TT (không nhập tay trên UI).
  void alignPrepaidForPaymentTerms() {
    if (paymentTerms != 'paid_in_full') return;
    var subtotal = 0;
    var linesPrepaid = 0;
    for (final l in lines) {
      final t = l.quantity * l.unitPrice;
      subtotal += t;
      if (l.alreadyPaid) linesPrepaid += t;
    }
    final base = subtotal - linesPrepaid;
    prepaidAmount = base < 0 ? 0 : base;
  }

  /// Lỗi nếu đã chọn khách nhưng chưa có địa chỉ giao (snapshot).
  String? validateDelivery() {
    final hasCustomer = customerId != null && customerId!.trim().isNotEmpty;
    if (hasCustomer && houseNumber.trim().isEmpty) {
      return 'Cần số nhà / địa chỉ giao.';
    }
    return null;
  }

  /// Lỗi nếu chưa có dòng sản phẩm.
  String? validateLines() {
    if (lines.isEmpty) return 'Cần ít nhất một sản phẩm.';
    return null;
  }

  Future<bool> saveDraft() async {
    lastError = validateDelivery() ?? validateLines();
    if (lastError != null) {
      notifyListeners();
      return false;
    }
    alignPrepaidForPaymentTerms();
    saving = true;
    notifyListeners();
    try {
      final res = await _api.put<Map<String, dynamic>>(
        '/admin/sale-orders/draft',
        data: _draftBody(),
      );
      final data = res.data;
      if (data != null && data['id'] is String) {
        orderId = data['id'] as String;
      }
      saving = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      saving = false;
      lastError = _dioMsg(e);
      notifyListeners();
      return false;
    } catch (e) {
      saving = false;
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadOrder(String id) async {
    lastError = null;
    try {
      final res =
          await _api.get<Map<String, dynamic>>('/admin/sale-orders/$id');
      final data = res.data;
      if (data == null) return false;
      applyLoadedOrder(SaleOrderPublic.fromJson(data));
      final cid = customerId;
      if (cid != null) {
        try {
          final cr =
              await _api.get<Map<String, dynamic>>('/admin/customers/$cid');
          final cm = cr.data;
          if (cm != null) {
            customerName = (cm['name'] as String?) ?? '';
            customerPhone = (cm['phone'] as String?) ?? '';
          }
        } catch (_) {}
      }
      notifyListeners();
      return true;
    } on DioException catch (e) {
      lastError = _dioMsg(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> confirm({
    bool createPreparation = false,
    bool? preparationIsPublicBoard,
    String? preparationAssignedUserId,
  }) async {
    if (orderId == null) return false;
    lastError = null;
    saving = true;
    notifyListeners();
    try {
      final data = <String, dynamic>{
        'createPreparation': createPreparation,
      };
      if (createPreparation) {
        data['preparationIsPublicBoard'] = preparationIsPublicBoard ?? true;
        if (preparationAssignedUserId != null) {
          data['preparationAssignedUserId'] = preparationAssignedUserId;
        }
      }
      await _api.post<Map<String, dynamic>>(
        '/admin/sale-orders/$orderId/confirm',
        data: data,
      );
      saving = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      saving = false;
      lastError = _dioMsg(e);
      notifyListeners();
      return false;
    }
  }

  static String _dioMsg(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) {
      final m = d['message'];
      if (m is String) return m;
      if (m is List && m.isNotEmpty) return m.first.toString();
    }
    return e.message ?? 'Lỗi mạng';
  }
}
