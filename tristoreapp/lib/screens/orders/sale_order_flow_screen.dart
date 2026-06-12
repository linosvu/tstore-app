import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/theme/app_text_styles.dart';
import 'package:tstore/core/theme/app_ui_extension.dart';
import 'package:tstore/core/utils/amount_input.dart';
import 'package:tstore/models/address_book_entry.dart';
import 'package:tstore/models/product.dart';
import 'package:tstore/models/sale_order.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/preparation_provider.dart';
import 'package:tstore/providers/sale_order_draft_provider.dart';
import 'package:tstore/screens/delivery/create_delivery_sheet.dart';
import 'package:tstore/widgets/assign_target_dropdown.dart';
import 'package:tstore/widgets/integer_thousands_input_formatter.dart';
import 'package:tstore/design_system/design_system.dart';
import 'package:tstore/widgets/ui/status_badge.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';
import 'package:intl/intl.dart';

const _wardIds = ['A', 'B', 'C'];
const _provinceIds = ['X', 'Y', 'Z'];

/// Cùng nhịp với [CreateProductSheet]: lề ngang form, khoảng cách field.
const _orderFormHPadding = 20.0;
const _orderFormFieldGap = 12.0;
const _orderFormSectionGap = 16.0;

List<(String, StatusBadgeTone)> lineOptionBadges(
  SaleOrderDraftLine line,
  AppLocalizations l10n,
) {
  return [
    if (line.fragile) (l10n.saleOrderFlagFragile, StatusBadgeTone.warning),
    if (line.bulky) (l10n.saleOrderFlagBulky, StatusBadgeTone.neutral),
    if (line.needsInstallation)
      (l10n.saleOrderFlagInstall, StatusBadgeTone.info),
    if (line.carefulPackaging)
      (l10n.saleOrderFlagPack, StatusBadgeTone.neutral),
    if (!line.alreadyPaid)
      (l10n.saleOrderLinePayLaterChip, StatusBadgeTone.warning),
  ];
}

class SaleOrderFlowScreen extends StatelessWidget {
  const SaleOrderFlowScreen({
    super.key,
    this.initialOrderId,
    this.initialPageIndex = 0,
    this.initialPrepProducts,
  });

  final String? initialOrderId;

  /// Index trang trong [PageView] (0=khách, 1=sản phẩm, 2=thanh toán, 3=xem lại).
  final int initialPageIndex;

  /// Khi không có [initialOrderId]: đổ vào nháp rồi [saveDraft] (bỏ qua nếu có id nháp).
  final List<Product>? initialPrepProducts;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          SaleOrderDraftProvider(api: ctx.read<AuthProvider>().api),
      child: _SaleOrderFlowScaffold(
        initialOrderId: initialOrderId,
        initialPageIndex: initialPageIndex,
        initialPrepProducts: initialPrepProducts,
      ),
    );
  }
}

class _SaleOrderFlowScaffold extends StatefulWidget {
  const _SaleOrderFlowScaffold({
    this.initialOrderId,
    this.initialPageIndex = 0,
    this.initialPrepProducts,
  });

  final String? initialOrderId;
  final int initialPageIndex;
  final List<Product>? initialPrepProducts;

  @override
  State<_SaleOrderFlowScaffold> createState() => _SaleOrderFlowScaffoldState();
}

class _SaleOrderFlowScaffoldState extends State<_SaleOrderFlowScaffold> {
  late final PageController _page;
  late int _step;

  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _houseCtrl = TextEditingController();
  final _prepaidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<CustomerPublic> _lookupHits = [];
  bool _lookupBusy = false;
  bool _suggestNotInSystem = false;
  bool _isNewCustomer = false;
  List<CustomerAddress> _customerAddresses = [];
  int _selectedAddressIdx = 0;
  List<AddressBookEntry> _addressBookEntries = [];
  Timer? _phoneDebounce;
  static const _thousandsSep = ThousandsGroupSeparatorKey.dot;

  /// Cờ UI-only: khách yêu cầu giao hàng tận nơi.
  /// Không lưu backend — chỉ dùng để hỏi tạo đơn giao sau khi xác nhận.
  bool _homeDelivery = false;
  bool _createPreparation = true;
  String _prepAssignTarget = kAssignTargetBoard;
  bool _loadingPrepUsers = false;
  List<(String id, String name)> _prepUsers = [];

  @override
  void initState() {
    super.initState();
    final start = widget.initialPageIndex.clamp(0, 3);
    _step = start;
    _page = PageController(initialPage: start);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAddressBook();
      _loadPrepAssignUsers();
    });

    final id = widget.initialOrderId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final p = context.read<SaleOrderDraftProvider>();
        final ok = await p.loadOrder(id);
        if (!mounted) return;
        if (!ok && p.lastError != null) {
          AppMessenger.showSnackBar(context, SnackBar(content: Text(p.lastError!)));
          return;
        }
        _phoneCtrl.text = p.customerPhone;
        _nameCtrl.text = p.customerName;
        _houseCtrl.text = p.houseNumber;
        _isNewCustomer = false;
        final cid = p.customerId;
        if (cid != null) {
          try {
            final api = context.read<AuthProvider>().api;
            final cr =
                await api.get<Map<String, dynamic>>('/admin/customers/$cid');
            final cm = cr.data;
            if (cm != null && mounted) {
              final c = CustomerPublic.fromJson(cm);
              _customerAddresses = List<CustomerAddress>.from(c.addresses);
              _selectedAddressIdx = _indexOfSnapshotAddress(c.addresses, p);
            }
          } catch (_) {
            if (mounted) {
              _customerAddresses = [];
              _selectedAddressIdx = 0;
            }
          }
        }
        if (p.paymentTerms == 'partial_prepayment' && p.prepaidAmount > 0) {
          _prepaidCtrl.text =
              formatIntegerWithSeparator(p.prepaidAmount, _thousandsSep);
        } else {
          _prepaidCtrl.clear();
        }
        _notesCtrl.text = p.orderNotes;
        _reconcilePaymentTermsIfPayLaterLines(p);
        _reconcilePaymentTermsWhenBaseZero(p, _computeBaseOwed(p));
        if (mounted) setState(() {});
      });
    } else {
      final prep = widget.initialPrepProducts;
      if (prep != null && prep.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final p = context.read<SaleOrderDraftProvider>();
          final l10n = AppLocalizations.of(context);
          p.lines.clear();
          for (final product in prep) {
            p.lines.add(
              SaleOrderDraftLine(
                productId: product.id,
                productName: product.name,
                productCode: product.code,
                quantity: 1,
                unitPrice: product.sellingPrice,
              ),
            );
          }
          p.bump();
          if (!await p.saveDraft()) {
            if (!mounted) return;
            AppMessenger.showSnackBar(context, 
              SnackBar(content: Text(p.lastError ?? l10n.error)),
            );
          }
          if (mounted) setState(() {});
        });
      }
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _houseCtrl.dispose();
    _prepaidCtrl.dispose();
    _notesCtrl.dispose();
    _phoneDebounce?.cancel();
    super.dispose();
  }

  TextStyle? _orderFormSectionLabelStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          );

  void _syncNotesToDraft(SaleOrderDraftProvider p) {
    var t = _notesCtrl.text;
    if (t.length > 500) {
      t = t.substring(0, 500);
      _notesCtrl.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    }
    p.orderNotes = t;
  }

  Future<void> _pickExpectedDelivery(SaleOrderDraftProvider p) async {
    final now = DateTime.now();
    final initial = p.expectedDeliveryAt ?? now.add(const Duration(days: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (t == null || !mounted) return;
    p.expectedDeliveryAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    p.bump();
    setState(() {});
  }

  void _syncDeliveryFromSelectedAddress(SaleOrderDraftProvider p) {
    if (_customerAddresses.isEmpty) {
      final next = _houseCtrl.text.trim();
      if (p.houseNumber != next) {
        p.houseNumber = next;
        p.bump();
      }
      return;
    }
    final i = _selectedAddressIdx.clamp(0, _customerAddresses.length - 1);
    final a = _customerAddresses[i];
    final changed = p.houseNumber != a.houseNumber ||
        p.wardId != a.wardId ||
        p.provinceId != a.provinceId;
    if (changed) {
      p.houseNumber = a.houseNumber;
      p.wardId = a.wardId;
      p.provinceId = a.provinceId;
      p.bump();
    }
    if (_houseCtrl.text != a.houseNumber) {
      _houseCtrl.text = a.houseNumber;
    }
  }

  void _applyConfiguredAddress(
    SaleOrderDraftProvider p,
    AddressBookEntry e,
  ) {
    p.houseNumber = e.houseNumber;
    p.wardId = e.wardId;
    p.provinceId = e.provinceId;
    _houseCtrl.text = e.houseNumber;
    p.bump();
    setState(() {});
  }

  Future<void> _loadAddressBook() async {
    try {
      final api = context.read<AuthProvider>().api;
      final r = await api.get<Map<String, dynamic>>('/admin/address-book');
      final raw = r.data?['entries'] as List<dynamic>?;
      if (!mounted) return;
      final list = raw == null
          ? <AddressBookEntry>[]
          : raw
              .whereType<Map<String, dynamic>>()
              .map(AddressBookEntry.fromJson)
              .where((e) => e.id.isNotEmpty && e.houseNumber.isNotEmpty)
              .toList();
      setState(() => _addressBookEntries = list);
    } catch (_) {
      if (mounted) setState(() => _addressBookEntries = []);
    }
  }

  Future<void> _loadPrepAssignUsers() async {
    setState(() => _loadingPrepUsers = true);
    try {
      final api = context.read<AuthProvider>().api;
      final res = await api.get<Map<String, dynamic>>(
        '/admin/users',
        queryParameters: {'page': 1, 'limit': 100},
      );
      final items = res.data?['items'];
      final list = <(String, String)>[];
      if (items is List) {
        for (final e in items) {
          if (e is! Map<String, dynamic>) continue;
          final id = e['id'] as String?;
          final name = e['fullName'] as String? ?? '';
          final active = e['isActive'] as bool? ?? true;
          if (id != null && active) list.add((id, name.isEmpty ? id : name));
        }
      }
      if (mounted) setState(() => _prepUsers = list);
    } catch (_) {
      if (mounted) setState(() => _prepUsers = []);
    } finally {
      if (mounted) setState(() => _loadingPrepUsers = false);
    }
  }

  void _selectCustomerFromPublic(CustomerPublic c) {
    final p = context.read<SaleOrderDraftProvider>();
    p.applyCustomer(c);
    if (!mounted) return;
    setState(() {
      _isNewCustomer = false;
      _nameCtrl.text = c.name;
      _customerAddresses = List<CustomerAddress>.from(c.addresses);
      _selectedAddressIdx = 0;
      _houseCtrl.text = p.houseNumber;
    });
    _syncDeliveryFromSelectedAddress(p);
  }

  int _indexOfSnapshotAddress(
    List<CustomerAddress> addrs,
    SaleOrderDraftProvider p,
  ) {
    for (var i = 0; i < addrs.length; i++) {
      final a = addrs[i];
      if (a.houseNumber == p.houseNumber.trim() &&
          a.wardId == p.wardId &&
          a.provinceId == p.provinceId) {
        return i;
      }
    }
    return 0;
  }

  void _schedulePhoneLookup() {
    _phoneDebounce?.cancel();
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) {
      if (mounted) {
        context.read<SaleOrderDraftProvider>().clearCustomerSelection();
        setState(() {
          _lookupHits = [];
          _suggestNotInSystem = false;
          _lookupBusy = false;
          _isNewCustomer = false;
          _customerAddresses = [];
          _selectedAddressIdx = 0;
          _nameCtrl.clear();
          _houseCtrl.clear();
        });
      }
      return;
    }
    _phoneDebounce = Timer(const Duration(milliseconds: 420), () {
      if (mounted) _lookupPhone();
    });
  }

  Future<void> _lookupPhone() async {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) {
      if (mounted) {
        context.read<SaleOrderDraftProvider>().clearCustomerSelection();
        setState(() {
          _lookupHits = [];
          _lookupBusy = false;
          _suggestNotInSystem = false;
          _isNewCustomer = false;
          _customerAddresses = [];
          _selectedAddressIdx = 0;
          _nameCtrl.clear();
          _houseCtrl.clear();
        });
      }
      return;
    }
    setState(() {
      _lookupBusy = true;
      _lookupHits = [];
      _suggestNotInSystem = false;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final res = await api.get<Map<String, dynamic>>(
        '/admin/customers/by-phone',
        queryParameters: {'phone': digits},
      );
      final items = res.data?['items'] as List? ?? [];
      if (!mounted) return;
      final hits = items
          .map((e) => CustomerPublic.fromJson(e as Map<String, dynamic>))
          .toList();
      final p = context.read<SaleOrderDraftProvider>();
      if (hits.length == 1) {
        final c = hits.single;
        _selectCustomerFromPublic(c);
        if (!mounted) return;
        setState(() {
          _lookupHits = hits;
          _lookupBusy = false;
          _suggestNotInSystem = false;
        });
      } else if (hits.isEmpty) {
        p.clearCustomerSelection();
        setState(() {
          _lookupHits = [];
          _lookupBusy = false;
          _suggestNotInSystem = true;
          _isNewCustomer = true;
          _nameCtrl.clear();
          _customerAddresses = [];
          _selectedAddressIdx = 0;
          _houseCtrl.clear();
        });
      } else {
        p.clearCustomerSelection();
        setState(() {
          _lookupHits = hits;
          _lookupBusy = false;
          _suggestNotInSystem = false;
          _isNewCustomer = false;
          _nameCtrl.clear();
          _customerAddresses = [];
          _selectedAddressIdx = 0;
          _houseCtrl.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _lookupBusy = false;
          _suggestNotInSystem = false;
        });
      }
    }
  }

  Future<bool> _patchCustomerAddressesOnServer(
    List<CustomerAddress> addresses,
  ) async {
    final p = context.read<SaleOrderDraftProvider>();
    final id = p.customerId;
    if (id == null) return false;
    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.patch<Map<String, dynamic>>(
        '/admin/customers/$id',
        data: {'addresses': addresses.map((a) => a.toJson()).toList()},
      );
      final data = res.data;
      if (data == null || !mounted) return false;
      final c = CustomerPublic.fromJson(data);
      p.applyCustomer(c);
      var shouldSyncDelivery = false;
      setState(() {
        _customerAddresses = List<CustomerAddress>.from(c.addresses);
        if (_selectedAddressIdx >= _customerAddresses.length) {
          _selectedAddressIdx =
              _customerAddresses.isEmpty ? 0 : _customerAddresses.length - 1;
        }
        _houseCtrl.text = p.houseNumber;
        shouldSyncDelivery = true;
      });
      if (shouldSyncDelivery) _syncDeliveryFromSelectedAddress(p);
      return true;
    } on DioException catch (e) {
      if (!mounted) return false;
      final msg = e.response?.data is Map
          ? '${(e.response!.data as Map)['message'] ?? e.message}'
          : '${e.message}';
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
      return false;
    }
  }

  Future<void> _removeAddressAt(int index) async {
    if (index < 0 || index >= _customerAddresses.length) return;
    final l10n = AppLocalizations.of(context);
    final a = _customerAddresses[index];
    final summary = '${a.houseNumber} · ${a.wardId}/${a.provinceId}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_off_outlined, size: 28),
        title: Text(l10n.delete),
        content: Text(l10n.saleOrderDeleteAddressConfirm(summary)),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.appUi.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final next = List<CustomerAddress>.from(_customerAddresses)
      ..removeAt(index);
    await _patchCustomerAddressesOnServer(next);
  }

  Future<void> _showAddAddressSheet() async {
    final l10n = AppLocalizations.of(context);
    final p = context.read<SaleOrderDraftProvider>();
    if (p.customerId == null) return;
    final newAddr = await showModalBottomSheet<CustomerAddress>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AddressFormSheet(
        l10n: l10n,
        initialWardId: p.wardId,
        initialProvinceId: p.provinceId,
      ),
    );
    if (newAddr == null || !mounted) return;
    final merged = [..._customerAddresses, newAddr];
    final nextSelectedIdx = merged.length - 1;
    _selectedAddressIdx = nextSelectedIdx;
    await _patchCustomerAddressesOnServer(merged);
    if (mounted) {
      setState(() {
        _selectedAddressIdx = _customerAddresses.isEmpty
            ? 0
            : nextSelectedIdx.clamp(0, _customerAddresses.length - 1);
      });
      _syncDeliveryFromSelectedAddress(context.read<SaleOrderDraftProvider>());
    }
  }

  List<Map<String, dynamic>>? _optionalAddressPayload(
    SaleOrderDraftProvider p,
  ) {
    final house = _houseCtrl.text.trim();
    if (house.isEmpty) return null;
    return [
      {
        'houseNumber': house,
        'wardId': p.wardId,
        'provinceId': p.provinceId,
      },
    ];
  }

  Future<bool> _createCustomerOnServer({
    String? name,
    String? phone,
    List<Map<String, dynamic>>? addresses,
  }) async {
    final l10n = AppLocalizations.of(context);
    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.post<Map<String, dynamic>>(
        '/admin/customers',
        data: {
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (addresses != null && addresses.isNotEmpty) 'addresses': addresses,
        },
      );
      final data = res.data;
      if (data == null || !mounted) return false;
      final c = CustomerPublic.fromJson(data);
      _selectCustomerFromPublic(c);
      if (!mounted) return false;
      AppMessenger.showSnackBar(
        context,
        SnackBar(
          content: Text(l10n.success),
          backgroundColor: AppColors.success,
        ),
      );
      return true;
    } on DioException catch (e) {
      if (!mounted) return false;
      final msg = e.response?.data is Map
          ? '${(e.response!.data as Map)['message'] ?? e.message}'
          : '${e.message}';
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
      return false;
    }
  }

  Future<bool> _handleCustomerStep() async {
    final l10n = AppLocalizations.of(context);
    final p = context.read<SaleOrderDraftProvider>();
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final name = _nameCtrl.text.trim();
    final hasPhone = digits.length >= 9;
    final hasName = name.isNotEmpty;

    if (!hasPhone && !hasName) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.saleOrderNeedNameOrPhone)),
      );
      return false;
    }

    final addresses = _optionalAddressPayload(p);

    if (hasPhone) {
      if (p.customerId == null) {
        if (_lookupHits.length > 1) {
          AppMessenger.showSnackBar(
            context,
            SnackBar(content: Text(l10n.saleOrderPickCustomer)),
          );
          return false;
        }
        if (_isNewCustomer || _lookupHits.isEmpty) {
          if (!await _createCustomerOnServer(
            name: hasName ? name : null,
            phone: _phoneCtrl.text.trim(),
            addresses: addresses,
          )) {
            return false;
          }
        } else {
          AppMessenger.showSnackBar(
            context,
            SnackBar(content: Text(l10n.saleOrderPickCustomer)),
          );
          return false;
        }
      }
    } else {
      if (p.customerId == null) {
        if (!await _createCustomerOnServer(
          name: name,
          addresses: addresses,
        )) {
          return false;
        }
      }
    }

    _syncDeliveryFromSelectedAddress(p);
    if (p.customerId != null &&
        _customerAddresses.isEmpty &&
        addresses != null) {
      final ok = await _patchCustomerAddressesOnServer(
        addresses
            .map(
              (a) => CustomerAddress(
                houseNumber: a['houseNumber'] as String,
                wardId: a['wardId'] as String,
                provinceId: a['provinceId'] as String,
              ),
            )
            .toList(),
      );
      if (!ok) return false;
      _syncDeliveryFromSelectedAddress(p);
    }
    final deliveryErr = p.validateDelivery();
    if (deliveryErr != null) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(deliveryErr)),
      );
      return false;
    }
    if (hasName) {
      p.customerName = name;
    }
    p.bump();
    return true;
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context);
    final p = context.read<SaleOrderDraftProvider>();
    if (_step == 0) {
      final okCustomer = await _handleCustomerStep();
      if (!okCustomer) return;
    } else if (_step == 1 || _step == 2) {
      if (_step == 2) {
        if (!_validatePaymentBeforeReview(l10n, p)) return;
      }
      _syncDeliveryFromSelectedAddress(p);
      _syncNotesToDraft(p);
      final preSaveErr = p.validateDelivery() ?? p.validateLines();
      if (preSaveErr != null) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(preSaveErr)),
        );
        return;
      }
      final ok = await p.saveDraft();
      if (!ok) {
        if (!mounted) return;
        AppMessenger.showSnackBar(context, 
          SnackBar(content: Text(p.lastError ?? l10n.error)),
        );
        return;
      }
    }
    if (_step < 3) {
      if (_step == 1) {
        _applyPaymentStepReconcile(p);
      }
      final target = _step + 1;
      setState(() => _step = target);
      _animatePageToStep(target);
    }
  }

  void _prev() {
    if (_step > 0) {
      final target = _step - 1;
      setState(() => _step = target);
      _animatePageToStep(target);
    }
  }

  /// Animate PageView **sau** khi setState đã rebuild (post-frame).
  /// Tránh chạy `markNeedsLayout` của Viewport song song với rebuild parent
  /// (gây assert `_owner != null` ở rendering/object.dart).
  void _animatePageToStep(int target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_page.hasClients) return;
      _page.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatMoney(int v) =>
      '${formatIntegerWithSeparator(v, _thousandsSep)} đ';

  int _computeBaseOwed(SaleOrderDraftProvider p) {
    var subtotal = 0;
    var prepaidLines = 0;
    for (final l in p.lines) {
      final t = l.quantity * l.unitPrice;
      subtotal += t;
      if (l.alreadyPaid) prepaidLines += t;
    }
    return subtotal - prepaidLines;
  }

  /// Có dòng «thanh toán sau» thì không cho `paid_in_full`.
  void _reconcilePaymentTermsIfPayLaterLines(SaleOrderDraftProvider p) {
    final hasPayLater = p.lines.any((l) => !l.alreadyPaid);
    if (!hasPayLater || p.paymentTerms != 'paid_in_full') return;
    p.paymentTerms = 'pay_on_delivery';
    p.prepaidAmount = 0;
    _prepaidCtrl.clear();
    p.bump();
  }

  /// Tiền hàng chưa TT = 0 → mặc định «Đã thanh toán đủ».
  void _reconcilePaymentTermsWhenBaseZero(SaleOrderDraftProvider p, int base) {
    if (base != 0) return;
    if (p.paymentTerms == 'paid_in_full') return;
    p.paymentTerms = 'paid_in_full';
    p.scheduledPaymentDate = null;
    p.alignPrepaidForPaymentTerms();
    _prepaidCtrl.clear();
  }

  /// Gọi trước khi vào bước Thanh toán (không dùng post-frame trong build PageView).
  void _applyPaymentStepReconcile(SaleOrderDraftProvider p) {
    _reconcilePaymentTermsIfPayLaterLines(p);
    _reconcilePaymentTermsWhenBaseZero(p, _computeBaseOwed(p));
  }

  String _paymentTermsLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'paid_in_full':
        return l10n.saleOrderPayFull;
      case 'partial_prepayment':
        return l10n.saleOrderPayPartial;
      case 'pay_on_delivery':
        return l10n.saleOrderPayOnDelivery;
      case 'scheduled':
        return l10n.saleOrderPayScheduled;
      default:
        return code;
    }
  }

  bool _isKiotVietEdit(SaleOrderDraftProvider p) =>
      p.orderSource == 'kiotviet' && p.orderStatus != 'draft';

  Future<void> _saveKiotVietOrder() async {
    final l10n = AppLocalizations.of(context);
    final p = context.read<SaleOrderDraftProvider>();
    _syncNotesToDraft(p);
    if (!await p.saveDraft()) {
      if (!mounted) return;
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(p.lastError ?? l10n.error)),
      );
      return;
    }
    if (!mounted) return;
    AppMessenger.showSnackBar(context, 
      SnackBar(
        content: Text(l10n.saleOrderKiotVietSaved),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context, true);
  }

  bool _validatePaymentBeforeReview(
    AppLocalizations l10n,
    SaleOrderDraftProvider p,
  ) {
    if (p.paymentTerms == 'partial_prepayment') {
      if (p.scheduledPaymentDate == null) {
        AppMessenger.showSnackBar(context, 
          SnackBar(content: Text(l10n.saleOrderRemainderDateRequired)),
        );
        return false;
      }
      var subtotal = 0;
      var prepaidLines = 0;
      for (final l in p.lines) {
        final t = l.quantity * l.unitPrice;
        subtotal += t;
        if (l.alreadyPaid) prepaidLines += t;
      }
      final base = subtotal - prepaidLines;
      if (p.prepaidAmount <= 0 || p.prepaidAmount >= base) {
        AppMessenger.showSnackBar(context, 
          SnackBar(content: Text(l10n.saleOrderPartialPrepaidInvalid)),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final p = context.read<SaleOrderDraftProvider>();
    _syncNotesToDraft(p);
    if (!await p.saveDraft()) {
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(p.lastError ?? l10n.error)),
      );
      return;
    }
    final prepAssign = AssignTargetApiPayload.fromTargetValue(_prepAssignTarget);
    if (!await p.confirm(
      createPreparation: _createPreparation,
      preparationIsPublicBoard: prepAssign.isPublicBoard,
      preparationAssignedUserId: prepAssign.assignedUserId,
    )) {
      if (!mounted) return;
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(p.lastError ?? l10n.error)),
      );
      return;
    }
    if (!mounted) return;
    AppMessenger.showSnackBar(context, 
      SnackBar(
          content: Text(l10n.saleOrderConfirmed),
          backgroundColor: AppColors.success),
    );

    if (_createPreparation) {
      // Làm mới danh sách chuẩn bị hàng để đơn vừa tạo hiện ngay trên bảng chung
      context.read<PreparationProvider>().refresh();
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(l10n.saleOrderPreparationCreated)),
      );
    }

    // Nếu chọn giao hàng: tải lại đơn vừa xác nhận rồi mở sheet tạo giao hàng
    if (_homeDelivery && p.orderId != null) {
      try {
        final api = context.read<AuthProvider>().api;
        final res = await api.get<Map<String, dynamic>>(
          '/admin/sale-orders/${p.orderId}',
        );
        if (!mounted) return;
        final confirmedOrder = SaleOrderPublic.fromJson(
          res.data as Map<String, dynamic>,
        );
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => CreateDeliverySheet(order: confirmedOrder),
        );
      } catch (_) {
        // Nếu không tải được đơn thì bỏ qua, user có thể tạo giao hàng từ màn chi tiết
      }
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _openProductPicker() async {
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _ProductSearchSheet(),
    );
    if (picked == null || !mounted) return;
    final p = context.read<SaleOrderDraftProvider>();
    p.lines.add(
      SaleOrderDraftLine(
        productId: picked.id,
        productName: picked.name,
        productCode: picked.code,
        quantity: 1,
        unitPrice: picked.sellingPrice,
      ),
    );
    p.bump();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draft = context.watch<SaleOrderDraftProvider>();

    final scheme = Theme.of(context).colorScheme;
    final stepLabels = [
      l10n.saleOrderStep1Title,
      l10n.saleOrderAddProduct,
      l10n.saleOrderStep3Title,
      l10n.saleOrderStep4Title,
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isKiotVietEdit(draft)
              ? l10n.saleOrderDetailEditOrder
              : l10n.saleOrderFlowTitle,
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // ── Step indicator ──────────────────────────────────────────────
          _StepIndicator(
            step: _step,
            labels: stepLabels,
            horizontalPadding: _orderFormHPadding,
          ),
          // ── Page content ────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _step1Customer(context, draft, l10n),
                _step2Products(context, draft, l10n),
                _step3Payment(context, draft, l10n),
                _step4Review(context, draft, l10n),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          elevation: 0,
          color: scheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(height: 1, color: scheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _orderFormHPadding,
                  12,
                  _orderFormHPadding,
                  14,
                ),
                child: Row(
                  children: [
                    if (_step > 0)
                      Flexible(
                        flex: 0,
                        child: OutlinedButton.icon(
                          onPressed: draft.saving ? null : _prev,
                          icon: const Icon(Icons.chevron_left_rounded,
                              size: 20),
                          label: Text(l10n.saleOrderBack),
                        ),
                      ),
                    if (_step > 0)
                      const SizedBox(width: _orderFormFieldGap),
                    if (_step < 3)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: draft.saving ? null : _next,
                          icon: draft.saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.chevron_right_rounded,
                                  size: 20),
                          label: Text(l10n.saleOrderNext),
                        ),
                      ),
                    if (_step == 3 && _isKiotVietEdit(draft)) ...[
                      Flexible(
                        flex: 0,
                        child: OutlinedButton(
                          onPressed: draft.saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: _orderFormFieldGap),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              draft.saving ? null : _saveKiotVietOrder,
                          icon: draft.saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 20),
                          label: Text(l10n.saleOrderKiotVietSave),
                        ),
                      ),
                    ],
                    if (_step == 3 && !_isKiotVietEdit(draft))
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: draft.saving ? null : _confirm,
                          icon: draft.saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 20),
                          label: Text(l10n.saleOrderConfirm),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editLine(int index) async {
    final p = context.read<SaleOrderDraftProvider>();
    final l10n = AppLocalizations.of(context);
    final l = p.lines[index];
    final result = await showDialog<_LineEditResult>(
      context: context,
      builder: (ctx) => _LineEditDialog(
        line: l,
        l10n: l10n,
        thousandsSep: _thousandsSep,
      ),
    );

    if (result != null) {
      final q = int.tryParse(result.quantityText.trim()) ?? l.quantity;
      final price =
          parseIntegerLoose(result.priceText, _thousandsSep) ?? l.unitPrice;
      l.quantity = q > 0 ? q : 1;
      l.unitPrice = price < 0 ? 0 : price;
      l.fragile = result.fragile;
      l.bulky = result.bulky;
      l.needsInstallation = result.needsInstallation;
      l.carefulPackaging = result.carefulPackaging;
      l.alreadyPaid = result.alreadyPaid;
      p.bump();
      _reconcilePaymentTermsIfPayLaterLines(p);
      _reconcilePaymentTermsWhenBaseZero(p, _computeBaseOwed(p));
      setState(() {});
    }
  }

  Widget _step1Customer(
    BuildContext context,
    SaleOrderDraftProvider p,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final sectionLabel = _orderFormSectionLabelStyle(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        _orderFormHPadding,
        8,
        _orderFormHPadding,
        24,
      ),
      children: [
        Text(
          l10n.saleOrderStep1Title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: _orderFormSectionGap),
        Text(
          l10n.saleOrderPhoneHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: _orderFormFieldGap),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          onChanged: (_) => _schedulePhoneLookup(),
          decoration: InputDecoration(
            labelText: l10n.saleOrderPhoneHint,
            suffixIcon: IconButton(
              tooltip: l10n.saleOrderLookupResults,
              icon: _lookupBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.search_rounded, color: scheme.primary),
              onPressed: _lookupBusy ? null : _lookupPhone,
            ),
          ),
        ),
        if (_lookupBusy) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (_lookupHits.isNotEmpty) ...[
          const SizedBox(height: _orderFormFieldGap),
          Text(l10n.saleOrderLookupResults, style: sectionLabel),
          const SizedBox(height: 8),
          ..._lookupHits.map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  Icon(Icons.person_outline_rounded, color: scheme.primary),
              title: Text(c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(c.phone ?? '—'),
              trailing:
                  Icon(Icons.chevron_right_rounded, color: scheme.primary),
              onTap: () => _selectCustomerFromPublic(c),
            ),
          ),
        ],
        if (_suggestNotInSystem && !_lookupBusy) ...[
          const SizedBox(height: _orderFormFieldGap),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.person_add_alt_1_outlined,
                  color: AppColors.primary.withValues(alpha: 0.75),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${l10n.saleOrderPhoneNotInSystem} — ${l10n.saleOrderCustomerNewBanner}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: _orderFormSectionGap),
        TextField(
          controller: _nameCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.saleOrderNameHint,
            helperText: l10n.saleOrderNeedNameOrPhone,
            helperMaxLines: 2,
          ),
        ),
        if (p.customerId != null ||
            _isNewCustomer ||
            _nameCtrl.text.trim().isNotEmpty ||
            _phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length >= 9) ...[
          if (p.customerId != null &&
              !_isNewCustomer &&
              _customerAddresses.isNotEmpty) ...[
            const SizedBox(height: _orderFormSectionGap),
            Text(l10n.saleOrderSelectAddress, style: sectionLabel),
            const SizedBox(height: 8),
            ...List.generate(_customerAddresses.length, (i) {
              final a = _customerAddresses[i];
              final contactName = _nameCtrl.text.trim().isNotEmpty
                  ? _nameCtrl.text.trim()
                  : p.customerName;
              final phone = _phoneCtrl.text.trim();
              final contactLine = phone.isNotEmpty
                  ? '$contactName ($phone)'
                  : contactName;
              return TsAddressRadioTile(
                value: i,
                groupValue: _selectedAddressIdx,
                contactLine: contactLine,
                addressLine: '${a.houseNumber}, ${a.wardId} / ${a.provinceId}',
                isDefault: i == 0,
                editLabel: l10n.delete,
                onSelect: () {
                  setState(() {
                    _selectedAddressIdx = i;
                    _syncDeliveryFromSelectedAddress(p);
                  });
                },
                onEdit: () => _removeAddressAt(i),
              );
            }),
            TsAddLinkRow(
              label: l10n.saleOrderAddAddress,
              onTap: () => _showAddAddressSheet(),
            ),
          ] else ...[
            if (_addressBookEntries.isNotEmpty) ...[
              const SizedBox(height: _orderFormFieldGap),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.saleOrderConfiguredAddresses,
                  style: sectionLabel,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _addressBookEntries.map((e) {
                  return ActionChip(
                    label: Text(
                      e.label.isNotEmpty
                          ? '${e.label}: ${e.houseNumber}'
                          : e.houseNumber,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _applyConfiguredAddress(p, e),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: _orderFormFieldGap),
            TextField(
              controller: _houseCtrl,
              decoration: InputDecoration(
                labelText: p.customerId != null
                    ? l10n.saleOrderHouseHint
                    : '${l10n.saleOrderHouseHint}${l10n.saleOrderOptionalSuffix}',
              ),
              onChanged: (v) => p.houseNumber = v.trim(),
            ),
            const SizedBox(height: _orderFormFieldGap),
            Row(
              children: [
                Expanded(
                  child: TsDropdownField<String>(
                    value: p.wardId,
                    labelText: l10n.saleOrderWard,
                    items: _wardIds,
                    itemLabel: (w) => w,
                    onChanged: (v) {
                      if (v != null) {
                        p.wardId = v;
                        setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: _orderFormFieldGap),
                Expanded(
                  child: TsDropdownField<String>(
                    value: p.provinceId,
                    labelText: l10n.saleOrderProvince,
                    items: _provinceIds,
                    itemLabel: (x) => x,
                    onChanged: (v) {
                      if (v != null) {
                        p.provinceId = v;
                        setState(() {});
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _confirmDeleteLine(
    SaleOrderDraftProvider p,
    AppLocalizations l10n,
    int index,
  ) async {
    final name = p.lines[index].productName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, size: 32),
        title: Text(l10n.delete),
        content: Text(
          '${l10n.delete} "$name"?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.appUi.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      p.lines.removeAt(index);
      p.bump();
      setState(() {});
    }
  }

  Widget _step2Products(
    BuildContext context,
    SaleOrderDraftProvider p,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _orderFormHPadding,
            8,
            _orderFormHPadding,
            _orderFormFieldGap,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.ordersLinesTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: _orderFormSectionGap),
              FilledButton.icon(
                onPressed: _openProductPicker,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.saleOrderAddProduct),
              ),
            ],
          ),
        ),
        if (p.lines.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _orderFormHPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 48,
                      color: AppColors.primary.withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: _orderFormSectionGap),
                    Text(
                      l10n.saleOrderNoLines,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                _orderFormHPadding,
                0,
                _orderFormHPadding,
                24,
              ),
              itemCount: p.lines.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.35),
              ),
              itemBuilder: (ctx, i) {
                final l = p.lines[i];
                return _ProductLineCard(
                  line: l,
                  thousandsSep: _thousandsSep,
                  onEdit: () => _editLine(i),
                  onDelete: () => _confirmDeleteLine(p, l10n, i),
                  l10n: l10n,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _step3Payment(
    BuildContext context,
    SaleOrderDraftProvider p,
    AppLocalizations l10n,
  ) {
    final sectionLabel = _orderFormSectionLabelStyle(context);
    int subtotal = 0;
    int prepaidLines = 0;
    for (final l in p.lines) {
      final t = l.quantity * l.unitPrice;
      subtotal += t;
      if (l.alreadyPaid) prepaidLines += t;
    }
    final base = subtotal - prepaidLines;
    final hasPayLater = p.lines.any((l) => !l.alreadyPaid);

    Widget moneyLine(String label, int value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                _formatMoney(value),
                style: AppTextStyles.amount(context),
              ),
            ],
          ),
        );

    Future<void> pickRemainderDate() async {
      final d = await showDatePicker(
        context: context,
        initialDate: p.scheduledPaymentDate ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      );
      if (d != null) {
        p.scheduledPaymentDate = d;
        p.bump();
        setState(() {});
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        _orderFormHPadding,
        8,
        _orderFormHPadding,
        24,
      ),
      children: [
        Text(
          l10n.saleOrderStep3Title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: _orderFormSectionGap),
        moneyLine(l10n.ordersSubtotal, subtotal),
        moneyLine(l10n.ordersLinesPrepaid, prepaidLines),
        moneyLine(l10n.saleOrderBaseOwed, base),
        const Divider(height: 28),
        Text(l10n.saleOrderPaymentTerms, style: sectionLabel),
        const SizedBox(height: 8),
        ...[
          if (!hasPayLater) ('paid_in_full', l10n.saleOrderPayFull),
          ('partial_prepayment', l10n.saleOrderPayPartial),
          ('pay_on_delivery', l10n.saleOrderPayOnDelivery),
        ].map(
          (e) => RadioListTile<String>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: Text(e.$2),
            value: e.$1,
            groupValue: p.paymentTerms,
            onChanged: (v) {
              if (v == null) return;
              p.paymentTerms = v;
              if (v != 'partial_prepayment') {
                p.scheduledPaymentDate = null;
              }
              if (v == 'pay_on_delivery') {
                p.prepaidAmount = 0;
                _prepaidCtrl.clear();
              } else if (v == 'paid_in_full') {
                var st = 0;
                var pl = 0;
                for (final l in p.lines) {
                  final t = l.quantity * l.unitPrice;
                  st += t;
                  if (l.alreadyPaid) pl += t;
                }
                final b = st - pl;
                p.prepaidAmount = b < 0 ? 0 : b;
                _prepaidCtrl.clear();
              } else if (v == 'partial_prepayment') {
                p.prepaidAmount = 0;
                _prepaidCtrl.clear();
              }
              p.bump();
              setState(() {});
            },
          ),
        ),
        if (p.paymentTerms == 'partial_prepayment') ...[
          const SizedBox(height: _orderFormFieldGap),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.saleOrderRemainderDueDate),
            subtitle: Text(
              p.scheduledPaymentDate == null
                  ? '—'
                  : '${p.scheduledPaymentDate!.day.toString().padLeft(2, '0')}/'
                      '${p.scheduledPaymentDate!.month.toString().padLeft(2, '0')}/'
                      '${p.scheduledPaymentDate!.year}',
            ),
            trailing: const Icon(Icons.calendar_month_rounded),
            onTap: pickRemainderDate,
          ),
        ],
        if (p.paymentTerms == 'partial_prepayment') ...[
          const SizedBox(height: _orderFormFieldGap),
          TextField(
            controller: _prepaidCtrl,
            keyboardType: integerThousandsKeyboardType(_thousandsSep),
            inputFormatters: [
              IntegerThousandsInputFormatter(separatorKey: _thousandsSep),
            ],
            decoration: InputDecoration(
              labelText: l10n.saleOrderPrepaidAmount,
              hintText: l10n.saleOrderPrepaidHint,
            ),
            onChanged: (v) {
              p.prepaidAmount = parseIntegerLoose(v, _thousandsSep) ?? 0;
            },
          ),
        ],
        if (!_isKiotVietEdit(p)) ...[
        const Divider(height: 28),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () =>
                    setState(() => _createPreparation = !_createPreparation),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _createPreparation,
                      onChanged: (v) =>
                          setState(() => _createPreparation = v ?? true),
                    ),
                    Expanded(
                      child: Text(
                        l10n.prepNav,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _homeDelivery = !_homeDelivery),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _homeDelivery,
                      onChanged: (v) =>
                          setState(() => _homeDelivery = v ?? false),
                    ),
                    Expanded(
                      child: Text(
                        l10n.saleOrderHomeDelivery,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_createPreparation) ...[
          const SizedBox(height: _orderFormFieldGap),
          AssignTargetDropdown(
            value: _prepAssignTarget,
            users: _prepUsers,
            loading: _loadingPrepUsers,
            enabled: true,
            showUnassigned: false,
            onChanged: (v) => setState(() => _prepAssignTarget = v),
          ),
        ],
        ],
        const Divider(height: 28),
        Text(l10n.saleOrderExpectedDeliveryTitle, style: sectionLabel),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickExpectedDelivery(p),
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text(
                  p.expectedDeliveryAt == null
                      ? '—'
                      : DateFormat('dd/MM/yyyy HH:mm').format(p.expectedDeliveryAt!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (p.expectedDeliveryAt != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: l10n.saleOrderExpectedDeliveryClear,
                onPressed: () {
                  p.expectedDeliveryAt = null;
                  p.bump();
                  setState(() {});
                },
                icon: const Icon(Icons.clear),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.saleOrderExpectedDeliveryHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: _orderFormFieldGap),
        Text(l10n.saleOrderNotesSectionTitle, style: sectionLabel),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          maxLength: 500,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: l10n.saleOrderNotesSectionTitle,
            hintText: l10n.saleOrderNotesHint,
            alignLabelWithHint: true,
          ),
          onChanged: (_) => _syncNotesToDraft(p),
        ),
      ],
    );
  }

  Widget _step4Review(
    BuildContext context,
    SaleOrderDraftProvider p,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final sectionLabel = _orderFormSectionLabelStyle(context);
    int subtotal = 0;
    int prepaidLines = 0;
    for (final l in p.lines) {
      final t = l.quantity * l.unitPrice;
      subtotal += t;
      if (l.alreadyPaid) prepaidLines += t;
    }
    final base = subtotal - prepaidLines - p.prepaidAmount;

    String fmtDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    Widget moneyLine(String label, int value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                _formatMoney(value),
                style: AppTextStyles.amount(context),
              ),
            ],
          ),
        );

    final lineWidgets = <Widget>[];
    for (var i = 0; i < p.lines.length; i++) {
      final l = p.lines[i];
      final badges = lineOptionBadges(l, l10n);
      final lineTotal = l.quantity * l.unitPrice;
      if (i > 0) {
        lineWidgets.add(Divider(
          height: 20,
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ));
      }
      lineWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.productCode,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              l.productName,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '${l10n.saleOrderQty} ×${l.quantity} · ${l10n.saleOrderUnitPrice} '
              '${_formatMoney(l.unitPrice)} · ${_formatMoney(lineTotal)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: badges
                    .map(
                      (b) => StatusBadge(label: b.$1, tone: b.$2),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        _orderFormHPadding,
        8,
        _orderFormHPadding,
        24,
      ),
      children: [
        Text(
          l10n.saleOrderStep4Title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: _orderFormSectionGap),
        Text(l10n.saleOrderReviewSectionCustomer, style: sectionLabel),
        const SizedBox(height: 8),
        if (p.customerId == null || p.customerId!.trim().isEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.55),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.saleOrderReviewMissingCustomerWarning,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Text(
            p.customerName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${l10n.saleOrderPhoneHint}: ${p.customerPhone}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.saleOrderHouseHint}: ${p.houseNumber} (${p.wardId}/${p.provinceId})',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          if (_homeDelivery) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.saleOrderHomeDeliveryReview,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            l10n.saleOrderExpectedDeliveryTitle,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            p.expectedDeliveryAt == null
                ? '—'
                : DateFormat('dd/MM/yyyy HH:mm').format(p.expectedDeliveryAt!),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
        const SizedBox(height: _orderFormSectionGap),
        Text(l10n.saleOrderReviewSectionPayment, style: sectionLabel),
        const SizedBox(height: 8),
        moneyLine(l10n.ordersSubtotal, subtotal),
        moneyLine(l10n.ordersLinesPrepaid, prepaidLines),
        if (p.prepaidAmount > 0)
          moneyLine(l10n.saleOrderPrepaidPaidShort, p.prepaidAmount),
        moneyLine(l10n.saleOrderBaseOwed, base),
        const Divider(height: 22),
        Text(
          '${l10n.saleOrderPaymentTerms}: '
          '${_paymentTermsLabel(l10n, p.paymentTerms)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (p.paymentTerms == 'partial_prepayment') ...[
          if (p.scheduledPaymentDate != null) ...[
            const SizedBox(height: 10),
            Text(
              l10n.saleOrderRemainderDueDate,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              fmtDate(p.scheduledPaymentDate!),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
        if (p.orderNotes.trim().isNotEmpty) ...[
          const SizedBox(height: _orderFormSectionGap),
          Text(l10n.saleOrderNotesSectionTitle, style: sectionLabel),
          const SizedBox(height: 8),
          Text(
            p.orderNotes.trim(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: _orderFormSectionGap),
        Text(l10n.saleOrderReviewSectionProducts, style: sectionLabel),
        const SizedBox(height: 8),
        ...lineWidgets,
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.step,
    required this.labels,
    this.horizontalPadding = 16,
  });

  final int step;
  final List<String> labels;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = labels.length;
    return Padding(
      padding:
          EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 10),
      child: Row(
        children: List.generate(total * 2 - 1, (idx) {
          if (idx.isOdd) {
            // Connector line
            final filled = idx ~/ 2 < step;
            return Expanded(
              child: Container(
                height: 2,
                color: filled ? scheme.primary : scheme.surfaceContainerHighest,
              ),
            );
          }
          final i = idx ~/ 2;
          final done = i < step;
          final active = i == step;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: (done || active)
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: done
                      ? Icon(Icons.check_rounded,
                          size: 16, color: scheme.onPrimary)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i].length > 8
                    ? '${labels[i].substring(0, 8)}…'
                    : labels[i],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: (done || active)
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                    ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _ProductLineCard extends StatelessWidget {
  const _ProductLineCard({
    required this.line,
    required this.thousandsSep,
    required this.onEdit,
    required this.onDelete,
    required this.l10n,
  });

  final SaleOrderDraftLine line;
  final ThousandsGroupSeparatorKey thousandsSep;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final activeBadges = lineOptionBadges(line, l10n);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.productName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${line.productCode} · '
                      '${formatIntegerWithSeparator(line.unitPrice, thousandsSep)}đ · '
                      '×${line.quantity}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: scheme.primary,
                tooltip: l10n.edit,
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: scheme.error,
                tooltip: l10n.delete,
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
              ),
            ],
          ),
          if (activeBadges.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: activeBadges
                  .map(
                    (b) => StatusBadge(
                      label: b.$1,
                      tone: b.$2,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  const _AddressFormSheet({
    required this.l10n,
    required this.initialWardId,
    required this.initialProvinceId,
  });

  final AppLocalizations l10n;
  final String initialWardId;
  final String initialProvinceId;

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _houseCtrl = TextEditingController();
  late String _wardId = widget.initialWardId;
  late String _provinceId = widget.initialProvinceId;

  @override
  void dispose() {
    _houseCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final house = _houseCtrl.text.trim();
    if (house.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      CustomerAddress(
        houseNumber: house,
        wardId: _wardId,
        provinceId: _provinceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.saleOrderAddAddress,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _houseCtrl,
            decoration: InputDecoration(
              labelText: l10n.saleOrderHouseHint,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TsDropdownField<String>(
                  value: _wardId,
                  labelText: l10n.saleOrderWard,
                  items: _wardIds,
                  itemLabel: (w) => w,
                  onChanged: (v) {
                    if (v != null) setState(() => _wardId = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TsDropdownField<String>(
                  value: _provinceId,
                  labelText: l10n.saleOrderProvince,
                  items: _provinceIds,
                  itemLabel: (x) => x,
                  onChanged: (v) {
                    if (v != null) setState(() => _provinceId = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineEditResult {
  const _LineEditResult({
    required this.quantityText,
    required this.priceText,
    required this.fragile,
    required this.bulky,
    required this.needsInstallation,
    required this.carefulPackaging,
    required this.alreadyPaid,
  });

  final String quantityText;
  final String priceText;
  final bool fragile;
  final bool bulky;
  final bool needsInstallation;
  final bool carefulPackaging;
  final bool alreadyPaid;
}

class _LineEditDialog extends StatefulWidget {
  const _LineEditDialog({
    required this.line,
    required this.l10n,
    required this.thousandsSep,
  });

  final SaleOrderDraftLine line;
  final AppLocalizations l10n;
  final ThousandsGroupSeparatorKey thousandsSep;

  @override
  State<_LineEditDialog> createState() => _LineEditDialogState();
}

class _LineEditDialogState extends State<_LineEditDialog> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late bool _fragile = widget.line.fragile;
  late bool _bulky = widget.line.bulky;
  late bool _needsInstallation = widget.line.needsInstallation;
  late bool _carefulPackaging = widget.line.carefulPackaging;
  late bool _alreadyPaid = widget.line.alreadyPaid;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '${widget.line.quantity}');
    _priceCtrl = TextEditingController(
      text: formatIntegerWithSeparator(
          widget.line.unitPrice, widget.thousandsSep),
    );
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _LineEditResult(
        quantityText: _qtyCtrl.text,
        priceText: _priceCtrl.text,
        fragile: _fragile,
        bulky: _bulky,
        needsInstallation: _needsInstallation,
        carefulPackaging: _carefulPackaging,
        alreadyPaid: _alreadyPaid,
      ),
    );
  }

  void _bumpQty(int delta) {
    final raw = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    final next = (raw + delta).clamp(1, 999999);
    _qtyCtrl.text = '$next';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;
    final qtyParsed = int.tryParse(_qtyCtrl.text.trim()) ?? 1;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      actionsPadding: EdgeInsets.zero,
      title: Text(
        widget.line.productName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.saleOrderQty,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: qtyParsed > 1 ? () => _bumpQty(-1) : null,
                  icon: const Icon(Icons.remove_rounded, size: 22),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    maximumSize: const Size(44, 44),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: qtyParsed < 999999 ? () => _bumpQty(1) : null,
                  icon: const Icon(Icons.add_rounded, size: 22),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    maximumSize: const Size(44, 44),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 14),
            Text(
              l10n.saleOrderUnitPrice,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _priceCtrl,
              keyboardType: integerThousandsKeyboardType(widget.thousandsSep),
              inputFormatters: [
                IntegerThousandsInputFormatter(
                  separatorKey: widget.thousandsSep,
                ),
              ],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                helperText: l10n.saleOrderIntegerThousandsHint,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.saleOrderLineEditOptionsTitle,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.start,
              children: [
                FilterChip(
                  label: Text(l10n.saleOrderFlagFragile),
                  selected: _fragile,
                  onSelected: (v) => setState(() => _fragile = v),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  showCheckmark: false,
                ),
                FilterChip(
                  label: Text(l10n.saleOrderFlagBulky),
                  selected: _bulky,
                  onSelected: (v) => setState(() => _bulky = v),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  showCheckmark: false,
                ),
                FilterChip(
                  label: Text(l10n.saleOrderFlagInstall),
                  selected: _needsInstallation,
                  onSelected: (v) => setState(() => _needsInstallation = v),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  showCheckmark: false,
                ),
                FilterChip(
                  label: Text(l10n.saleOrderFlagPack),
                  selected: _carefulPackaging,
                  onSelected: (v) => setState(() => _carefulPackaging = v),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  showCheckmark: false,
                ),
                FilterChip(
                  label: Text(
                    l10n.saleOrderLinePayLaterChip,
                    style: TextStyle(
                      color:
                          !_alreadyPaid ? AppColors.warning : scheme.onSurface,
                      fontWeight:
                          !_alreadyPaid ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: !_alreadyPaid,
                  onSelected: (v) => setState(() => _alreadyPaid = !v),
                  selectedColor: AppColors.warning.withValues(alpha: 0.18),
                  checkmarkColor: AppColors.warning,
                  side: BorderSide(
                    color: !_alreadyPaid
                        ? AppColors.warning
                        : scheme.outlineVariant,
                    width: !_alreadyPaid ? 1.5 : 1,
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  showCheckmark: false,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductSearchSheet extends StatefulWidget {
  const _ProductSearchSheet();

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  final List<Product> _items = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _searchNow() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api;
      final res = await api.get<Map<String, dynamic>>(
        '/admin/products',
        queryParameters: {
          'page': 1,
          'limit': 20,
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        },
      );
      final data = res.data;
      final raw = data?['items'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(
            raw.map((e) => Product.fromJson(e as Map<String, dynamic>)),
          );
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchNow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = MediaQuery.sizeOf(context).height * 0.88;
    return SizedBox(
      height: h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Chọn sản phẩm',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Tìm mã / tên sản phẩm',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _search.clear();
                          _searchNow();
                        },
                      )
                    : null,
                filled: true,
                fillColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: scheme.outlineVariant, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: scheme.outlineVariant, width: 1),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce =
                    Timer(const Duration(milliseconds: 350), _searchNow);
                // force rebuild for clear button
                (context as Element).markNeedsBuild();
              },
            ),
          ),
          const SizedBox(height: 4),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _items.isEmpty && !_loading
                ? Center(
                    child: Text(
                      'Không tìm thấy sản phẩm',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.4)),
                    itemBuilder: (ctx, i) {
                      final p = _items[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                            '${p.code} · ${formatIntegerWithSeparator(p.sellingPrice, ThousandsGroupSeparatorKey.dot)}đ · còn ${p.quantity}'),
                        trailing: const Icon(Icons.add_circle_outline_rounded),
                        onTap: () {
                          FocusScope.of(ctx).unfocus();
                          Navigator.of(ctx).pop(p);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
