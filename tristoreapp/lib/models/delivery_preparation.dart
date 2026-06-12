/// Một mục checklist chuẩn bị giao (từ server `GET .../preparation-checklist`).
class DeliveryPreparationChecklistItem {
  const DeliveryPreparationChecklistItem({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  factory DeliveryPreparationChecklistItem.fromJson(Map<String, dynamic> json) {
    return DeliveryPreparationChecklistItem(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

/// Dự phòng khi API checklist lỗi (đồng bộ id với backend).
const List<DeliveryPreparationChecklistItem> kDefaultPreparationChecklist = [
  DeliveryPreparationChecklistItem(id: 'fragile_glass', label: 'Thủy tinh dễ vỡ'),
  DeliveryPreparationChecklistItem(id: 'bubble_wrap', label: 'Bọc xốp'),
  DeliveryPreparationChecklistItem(id: 'moisture_guard', label: 'Chống ẩm'),
  DeliveryPreparationChecklistItem(id: 'impact_guard', label: 'Chống va đập'),
  DeliveryPreparationChecklistItem(id: 'tight_pack', label: 'Bọc hàng kĩ'),
  DeliveryPreparationChecklistItem(id: 'paint_scratch', label: 'Dễ tróc sơn'),
  DeliveryPreparationChecklistItem(id: 'bulky_item', label: 'Hàng cồng kềnh'),
  DeliveryPreparationChecklistItem(id: 'electronics', label: 'Đồ điện tử'),
];
