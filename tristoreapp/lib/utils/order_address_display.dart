import '../models/address_catalog.dart';
import '../models/sale_order.dart';
import '../providers/address_catalog_provider.dart';

bool houseNumberUsable(String raw) {
  final t = raw.trim();
  return t.isNotEmpty && t != '—' && t != '-';
}

bool isFallbackAddressPair(String provinceId, String wardId) =>
    provinceId == AddressCatalog.fallbackProvinceId &&
    wardId == AddressCatalog.fallbackWardId;

/// Địa chỉ từ snapshot đơn (không fallback sang khách hàng).
String formatSnapshotAddress(
  Map<String, dynamic> snap,
  AddressCatalogProvider catalog,
) {
  final house = snap['houseNumber']?.toString().trim() ?? '';
  final wardId = snap['wardId']?.toString().trim() ?? '';
  final provinceId = snap['provinceId']?.toString().trim() ?? '';

  if (!houseNumberUsable(house) && isFallbackAddressPair(provinceId, wardId)) {
    return '—';
  }

  return catalog.formatAddressLine(
    houseNumber: house,
    wardId: wardId,
    provinceId: provinceId,
  );
}

/// Snapshot đơn → nếu rỗng thì lấy địa chỉ đầu tiên của khách (nếu API trả về).
String resolveOrderDeliveryAddress(
  SaleOrderPublic order,
  AddressCatalogProvider catalog,
) {
  final snapLine = formatSnapshotAddress(
    order.deliveryAddressSnapshot,
    catalog,
  );
  if (snapLine != '—') return snapLine;

  final customer = order.customer;
  if (customer != null && customer.addresses.isNotEmpty) {
    final a = customer.addresses.first;
    return catalog.formatAddressLine(
      houseNumber: a.houseNumber,
      wardId: a.wardId,
      provinceId: a.provinceId,
    );
  }
  return '—';
}
