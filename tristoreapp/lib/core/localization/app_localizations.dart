import 'package:flutter/material.dart';

import '../config/app_template_config.dart';

/// Từ điển chuỗi hiển thị tiếng Việt của ứng dụng.
///
/// Ứng dụng chỉ hỗ trợ tiếng Việt; class này được giữ lại dưới dạng
/// singleton để các màn hình tiếp tục gọi `AppLocalizations.of(context)`
/// mà không cần đổi API sử dụng.
class AppLocalizations {
  const AppLocalizations._();

  static const AppLocalizations _instance = AppLocalizations._();

  static AppLocalizations of(BuildContext context) => _instance;

  // Common
  String get appName => AppTemplateConfig.appDisplayName;
  String get searchClear => 'Xóa';
  String get managementHubTitle => 'Quản lý';
  String get managementOpen => 'Quản lý vận hành';
  String get managementCardOrders => 'Đơn hàng';
  String get managementCardDeliveries => 'Giao hàng';
  String get managementCardPreparations => 'Phiếu chuẩn bị';
  String get managementCardTasks => 'Nhiệm vụ';
  String get managementFilterTitle => 'Bộ lọc';
  String get managementApplyFilter => 'Áp dụng';
  String get managementClearFilter => 'Xóa bộ lọc';
  String get managementResultsTitle => 'Kết quả lọc';
  String get managementTotal => 'Tổng';
  String get managementDateToday => 'Hôm nay';
  String get managementDateYesterday => 'Hôm qua';
  String get managementDateLast7 => '7 ngày';
  String get managementDateThisMonth => 'Tháng này';
  String get managementDateAll => 'Tất cả';
  String get managementDateCustom => 'Chọn khoảng ngày';
  String get managementCreatorAll => 'Tất cả người tạo';
  String get managementCreatorMe => 'Tôi tạo';
  String get managementCreatorPick => 'Chọn nhân viên';
  String get managementAssigneeAll => 'Tất cả người giao';
  String get managementAssigneePick => 'Chọn người thực hiện';
  String get managementPaymentPaid => 'Đã thanh toán';
  String get managementPaymentUnpaid => 'Chưa thanh toán';
  String get managementPaymentScheduled => 'Hẹn thanh toán';
  String get managementScheduledDelivery => 'Hẹn giao';
  String get managementPriorityNormal => 'Ưu tiên thường';
  String get managementPriorityHigh => 'Ưu tiên cao';
  String get managementPriorityUrgent => 'Khẩn';
  String get managementPriorityLow => 'Thấp';
  String get managementSectionDate => 'Thời gian';
  String get managementSectionCreator => 'Người tạo';
  String get managementSectionAssignee => 'Người thực hiện';
  String get managementSectionPayment => 'Thanh toán';
  String get managementSectionExpectedDelivery => 'Dự kiến giao hàng';
  String get managementSectionPrepInProgress => 'Đang chuẩn bị';
  String get managementSectionDeliveryPending => 'Chờ giao';
  String get managementAssigneeUnassigned => 'Chưa gán';
  String get managementPrepNoAssignee => 'Chưa có NV nhận';
  String get managementDeliveryNoAssignee => 'Chưa có NV nhận';
  String get managementExpectedDueSoon => 'Cần xử lý (24h tới)';
  String get managementExpectedOverdue => 'Trễ hẹn';
  String get managementPaymentPendingConfirm => 'Cần xác nhận thu tiền';
  String get managementQuickAccessTitle => 'Truy cập nhanh';
  String get managementQuickAccessEmpty =>
      'Chưa có mục nào. Mở Kết quả lọc và chọn Lưu lại.';
  String get managementSaveQuickAccessButton => 'Lưu lại';
  String get managementSaveQuickAccessTitle => 'Lưu truy cập nhanh';
  String get managementSaveQuickAccessHint => 'Đặt tên (tối đa 40 ký tự)';
  String get managementSaveQuickAccessSuccess => 'Đã lưu vào Truy cập nhanh';
  String get managementQuickAccessDeleteTitle => 'Xóa truy cập nhanh?';
  String managementQuickAccessDeleteBody(String name) =>
      'Xóa "$name" khỏi danh sách Truy cập nhanh.';
  String get ok => 'Đồng ý';
  String get cancel => 'Hủy';
  String get save => 'Lưu';
  String get delete => 'Xóa';
  String get edit => 'Chỉnh sửa';
  String get loading => 'Đang tải...';
  String get error => 'Lỗi';
  String get success => 'Thành công';
  String get yes => 'Có';
  String get no => 'Không';

  // Navigation
  String get homeNav => 'Trang chủ';
  String get diary => 'Nhật Ký';
  String get timeTracker => 'Thời Gian';
  String get finance => 'Tài Chính';
  String get deliveryNav => 'Giao Hàng';
  String get prepNav => 'Chuẩn bị';
  String get points => 'Điểm';
  String get settings => 'Cài Đặt';
  String get profile => 'Hồ sơ';
  String get profileTitle => 'Hồ sơ';
  String get profileEmail => 'Email';
  String get profileChangePassword => 'Đổi mật khẩu';
  String get profileCurrentPassword => 'Mật khẩu hiện tại';
  String get profileNewPassword => 'Mật khẩu mới';
  String get profileConfirmNewPassword => 'Nhập lại mật khẩu mới';
  String get profilePasswordsDoNotMatch =>
      'Mật khẩu mới và xác nhận không khớp.';
  String get profilePasswordMinLength => 'Mật khẩu mới cần ít nhất 6 ký tự.';
  String get profilePhone => 'Điện thoại';
  String get profileBio => 'Giới thiệu';
  String get profileTemplateId => 'Mã template';
  String get openAppSettings => 'Cài đặt ứng dụng';
  String get profileShortcutTitle => 'Hồ sơ của bạn';
  String get profileShortcutSubtitle => 'Ảnh đại diện, tên và thẻ thông tin';
  String get profileStatsComingSoonTitle => 'Thống kê của bạn';
  String get profileStatsComingSoonBody =>
      'Tổng hợp hoạt động và hiệu suất sẽ hiển thị tại đây sau.';
  String get settingsAccountSection => 'Tài khoản';
  String get profileLogoutTitle => 'Đăng xuất';
  String get profileLogoutMessage => 'Bạn có chắc muốn đăng xuất?';

  // Products (tab trước đây là Nhật ký)
  String get productsNav => 'Sản phẩm';
  String get productsTitle => 'Sản phẩm';
  String get productsSearchHint => 'Tìm mã, tên, mô tả, số lượng, thẻ…';
  String get productsCreate => 'Tạo mới';
  String get productsEdit => 'Sửa sản phẩm';
  String get productsCode => 'Mã';
  String get productsName => 'Tên';
  String get productsQuantity => 'Số lượng';
  String get productsSellingPrice => 'Giá bán (đồng)';
  String get productsDescription => 'Mô tả';
  String get productsImageUrls => 'Ảnh (URL, mỗi dòng một)';
  String get productsImageUrlsHint =>
      'Ít nhất một URL (http/https hoặc data URL). Có thể nhiều dòng.';
  String get productsForbidden => 'Tài khoản không có quyền xem sản phẩm.';
  String get productsEmpty => 'Chưa có sản phẩm.';
  String get productsLoadMore => 'Tải thêm';
  String get productsEnd => 'Đã hiển thị hết.';
  String get productsTags => 'Thẻ';
  String get productsFillRequired => 'Nhập mã và tên sản phẩm.';
  String get productsCodeReadOnly => 'Mã sản phẩm không được đổi.';
  String get productsImagesOptional =>
      'Ảnh là tùy chọn (tối đa 10). Khi chưa có ảnh sẽ hiển thị hình mặc định.';
  String get productsCreateFailed => 'Không tạo được sản phẩm.';
  String get productsEditFailed => 'Không cập nhật được sản phẩm.';
  String get productsOutOfStock => 'Hết hàng';
  String get productsTagFilterMax => 'Chọn tối đa 10 thẻ lọc.';
  String get productsDetailTitle => 'Chi tiết sản phẩm';
  String get productsRetry => 'Thử lại';
  String productsPrepareOrderWithCount(int count) => 'Chuẩn bị đơn ($count)';
  String get productsPrepSelect => 'Chọn';
  String get productsPrepDeselect => 'Bỏ chọn';
  String get productsDetailCreatedAt => 'Ngày tạo';
  String get productsDetailContentUpdatedAt => 'Ngày cập nhật thông tin';
  String get productsDetailQuantityUpdatedAt => 'Ngày cập nhật số lượng';
  String get productsDetailDatePlaceholder => '—';
  String get productsImagesLabel => 'Ảnh sản phẩm';
  String get productsImagesEmpty => 'Chưa có ảnh nào.';
  String get productsImagesMax => 'Tối đa 10 ảnh.';
  String get productsAddImage => 'Thêm ảnh';
  String get productsImageFromCamera => 'Chụp ảnh';
  String get productsImageFromGallery => 'Thư viện';
  String get mediaPickTitle => 'Thêm ảnh hoặc video';
  String get mediaRecordVideo => 'Quay video';
  String get mediaPickVideoFromGallery => 'Chọn video';
  String get mediaAddMedia => 'Thêm ảnh/video';
  String get mediaUploadFailed => 'Không tải lên được file.';
  String get mediaVideoTooLong => 'Video vượt thời lượng cho phép.';
  String get mediaVideoTooLarge => 'Video vượt dung lượng cho phép.';
  String mediaLimitsHint(int maxImageBytes, int maxVideoBytes, int maxVideoSec) {
    final imgMb = (maxImageBytes / (1024 * 1024)).round();
    final vidMb = (maxVideoBytes / (1024 * 1024)).round();
    return 'Ảnh tối đa ${imgMb}MB · Video tối đa ${vidMb}MB · Thời lượng video tối đa ${maxVideoSec}s';
  }
  String get productsImageFromUrl => 'Dán URL ảnh';
  String get productsImageUrlPasteTitle => 'Thêm ảnh bằng URL';
  String get productsImageUrlPasteHint => 'http(s) hoặc data:image…';
  String get productsImageInvalidUrl => 'URL không hợp lệ.';
  String get productsImageProcessing => 'Đang xử lý ảnh…';
  String get productsImagePickFailed => 'Không xử lý được ảnh.';
  String get productsRemoveImageTooltip => 'Xóa ảnh';
  String get productsTagsLabel => 'Thẻ';
  String get productsTagsHint => 'Nhập để tìm hoặc tạo thẻ';
  String get productsTagsMax => 'Tối đa 10 thẻ.';
  String get productsTagsSuggestionLabel => 'Gợi ý';
  String productsTagsCreateNew(String name) => 'Tạo thẻ "$name"';

  // Diary
  String get diaryTitle => 'Nhật Ký Cá Nhân';
  String get writeDiary => 'Viết Nhật Ký';
  String get saveDiary => 'Lưu Nhật Ký';
  String get diaryPlaceholder => 'Hôm nay của bạn thế nào?';
  String get recentEntries => 'Các Mục Gần Đây';

  // Time Tracker
  String get timeTrackerTitle => 'Theo Dõi Thời Gian';
  String get currentTask => 'Công Việc Hiện Tại';
  String get startTracking => 'Bắt Đầu';
  String get stopTracking => 'Dừng Lại';
  String get taskPlaceholder => 'Bạn đang làm gì?';
  String get timeHistory => 'Lịch Sử Thời Gian';

  // Delivery (giao hàng)
  String get deliveryTitle => 'Giao hàng';
  String get fulfillmentHubTitle => 'Giao Hàng';
  String get fulfillmentScopeLabel => 'Phạm vi';
  String get fulfillmentScopeMine => 'Của tôi';
  String get fulfillmentScopeCreated => 'Do tôi tạo';
  String get fulfillmentScopeCreatedShort => 'Tôi tạo';
  String get fulfillmentScopeBoard => 'Bảng chung';
  String get fulfillmentScopeMineHint =>
      'Chỉ hiển thị đơn liên quan đến bạn (theo quyền nhân viên).';
  String get fulfillmentLegUnassigned => 'Chưa gán';
  String get fulfillmentFilterOpen => 'Chưa xong';
  String get fulfillmentFilterCompleted => 'Hoàn thành';
  String get fulfillmentFilterCancelled => 'Hủy';
  String get fulfillmentNoPrepYet => 'Chưa có phiếu chuẩn bị cho đơn này.';
  String get fulfillmentNoDeliveryYet => 'Chưa có đơn giao cho đơn bán này.';
  String get deliveryTabMine => 'Đơn của tôi';
  String get deliveryTabCreated => 'Đã tạo';
  String get deliveryTabBoard => 'Bảng chung';
  String get deliveryEmpty => 'Chưa có đơn giao hàng.';
  String get deliveryCreatedEmpty => 'Bạn chưa tạo đơn giao hàng nào.';
  String get deliveryBoardEmpty => 'Không có đơn trên bảng chung.';
  String get deliveryRetry => 'Thử lại';
  String get deliveryCustomer => 'Khách hàng';
  String get deliveryAddress => 'Địa chỉ giao';
  String get deliveryAssignee => 'Người giao';
  String get assignTargetLabel => 'Giao cho:';
  String get assignTargetMeSuffix => '(Tôi)';
  String get deliveryScheduled => 'Hẹn giao';
  String get deliveryPriority => 'Ưu tiên';
  String get deliveryScheduleAndPrioritySection => 'Hẹn giao & Ưu tiên';
  String get deliveryShippingCarrier => 'Đơn vị vận chuyển';
  String get deliveryCarrierNotChosen => 'Chưa chọn';
  String get deliveryClearSchedule => 'Xóa lịch';
  String get deliveryCopyPhoneTooltip => 'Sao chép SĐT';
  String get deliveryCopyAddressTooltip => 'Sao chép địa chỉ';
  String get deliveryPhoneCopied => 'Đã sao chép SĐT';
  String get deliveryAddressCopied => 'Đã sao chép địa chỉ';
  String get deliveryNote => 'Ghi chú giao hàng';
  String get deliveryPaymentCollected => 'Đã thu tiền';
  String get deliveryRemoveImage => 'Xóa ảnh';
  String get deliveryPrepPhotos => 'Ảnh chuẩn bị';
  String get deliveryProducts => 'Sản phẩm';
  String get deliveryPrepTapHint => 'Chạm để checklist chuẩn bị';
  String get deliveryLinePreparationTitle => 'Chuẩn bị giao';
  String get deliveryPreparationSaveClose => 'Lưu và đóng';
  String get deliveryPreparationDone => 'Xong';
  String get deliveryPreparationReadonlyHint =>
      'Dòng này đã xác nhận chuẩn bị xong.';
  String get deliveryPreparationEmptyTemplate =>
      'Chưa có mục checklist từ máy chủ.';
  String get deliveryStatus => 'Trạng thái';
  String get deliveryNextStatus => 'Bước tiếp';
  String get deliverySetStatus => 'Đổi trạng thái';
  String get deliveryReason => 'Lý do';
  String get deliveryImages => 'Ảnh check-in';
  String get deliveryAddImage => 'Thêm ảnh';
  String get deliveryCheckinTabEmpty => 'Chưa có ảnh trong mục này.';
  String get deliveryAssignMe => 'Nhận đơn';
  String get deliveryCreateFromOrder => 'Tạo đơn giao hàng';
  String get deliveryViewOrder => 'Xem đơn giao hàng';
  String get deliveryCreateTitle => 'Tạo đơn giao';
  String get deliveryPublicBoard => 'Đưa lên bảng chung';
  String get deliveryDirectAssign => 'Giao trực tiếp (chọn người)';
  String get deliverySelectLines => 'Chọn sản phẩm giao';
  String get deliverySubmit => 'Tạo đơn';
  String get deliveryCreateSuccess => 'Đã tạo đơn giao hàng.';
  String get deliveryCreateFailed => 'Không tạo được đơn giao.';
  String get deliveryAssignUnassigned => 'Chưa gán';
  String get deliveryCheckinType => 'Loại ảnh';
  String get deliveryTypeCheckin => 'Check-in';
  String get deliveryTypeReceived => 'Nhận hàng';
  String get deliveryTypeInstall => 'Lắp đặt';
  String get deliveryStatusPending => 'Chờ giao';
  String get deliveryStatusPreparing => 'Đang chuẩn bị';
  String get deliveryStatusReady => 'Sẵn sàng';
  String get deliveryStatusDelivering => 'Đang giao';
  String get deliveryStatusCompleted => 'Hoàn thành';
  String get deliveryStatusFailed => 'Thất bại';
  String get deliveryStatusCancelled => 'Đã hủy';
  String get deliveryStatusAwaitingConfirm => 'Chờ xác nhận';
  String get deliveryStartPreparation => 'Bắt đầu chuẩn bị';
  String get deliveryCancelShipment => 'Hủy giao hàng';
  String get deliveryDeliveryCode => 'Mã GH';
  String get deliveryAmountDueLabel => 'Cần thu';
  String deliveryCountdownHrsMin(int h, int m) => 'Còn ${h}g ${m}ph';
  String deliveryCountdownMinutes(int m) => 'Còn $m phút';
  String get deliveryCountdownSoon => 'Sắp tới';
  String deliveryCountdownDays(int n) => 'Còn $n ngày';
  String get deliveryCountdownOneDay => 'Còn 1 ngày';
  String deliveryCountdownOverDays(int n) => 'Quá $n ngày';
  String get deliveryCountdownOverOneDay => 'Quá 1 ngày';
  String deliveryCountdownOverHrsMin(int h, int m) => 'Quá ${h}g ${m}ph';
  String deliveryCountdownOverMinutes(int m) => 'Quá $m phút';
  String get deliveryPriorityLow => 'Thấp';
  String get deliveryPriorityNormal => 'Bình thường';
  String get deliveryPriorityHigh => 'Cao';
  String get deliveryPriorityUrgent => 'Khẩn cấp';
  String get deliveryFilterAll => 'Tất cả';
  String get deliveryFilterEmpty =>
      'Không có đơn ở trạng thái này. Chọn bộ lọc khác.';
  String get prepTitle => 'Chuẩn bị hàng';
  String get prepTabMine => 'Của tôi';
  String get prepTabCreated => 'Đã tạo';
  String get prepTabBoard => 'Bảng chung';
  String get prepStatusPending => 'Chờ chuẩn bị';
  String get prepStatusInProgress => 'Đang chuẩn bị';
  String get prepStatusReady => 'Chuẩn bị xong';
  String get prepStatusDone => 'Chuẩn bị xong';
  String get prepStatusCancelled => 'Đã hủy';
  String get prepViewOrder => 'Xem chuẩn bị';
  String get prepBoardEmpty => 'Không có phiếu trên bảng chung.';
  String get prepMineEmpty => 'Chưa có phiếu chuẩn bị.';
  String get prepCreatedEmpty => 'Bạn chưa tạo phiếu chuẩn bị nào.';
  String get prepAssignMe => 'Nhận phiếu';
  String get prepAssignee => 'Người chuẩn bị';
  String get prepMarkReady => 'Chuẩn bị xong';
  String get prepMarkDone => 'Chuẩn bị xong';
  String get prepMarkCancelled => 'Hủy phiếu chuẩn bị';
  String get prepCancelReasonTitle => 'Hủy phiếu chuẩn bị';
  String get prepCancelReasonHint => 'Nhập lý do hủy (không bắt buộc)';
  String get prepStartPreparing => 'Bắt đầu chuẩn bị';
  String get prepNotes => 'Ghi chú';
  String get prepPhotos => 'Ảnh xác nhận';
  String get prepProducts => 'Danh sách sản phẩm';
  String get prepDeliveryBlocked =>
      'Phiếu chuẩn bị đã hủy, không thể tạo đơn giao.';

  // Finance
  String get financeTitle => 'Quản Lý Tài Chính';
  String get addTransaction => 'Thêm Giao Dịch';
  String get income => 'Thu nhập';
  String get expense => 'Chi tiêu';
  String get amount => 'Số tiền';
  String get description => 'Mô tả';
  String get category => 'Danh mục';
  String get balance => 'Số dư';
  String get transactionHistory => 'Lịch Sử Giao Dịch';

  // Points
  String get pointsTitle => 'Điểm & Cửa Hàng';
  String get availablePoints => 'Điểm Khả Dụng';
  String get earnPoints => 'Kiếm Điểm';
  String get premiumFeatures => 'Tính Năng Premium';
  String get pointsHistory => 'Lịch Sử Điểm';
  String get dailyCheckIn => 'Điểm danh hàng ngày';
  String get completeDiaryEntry => 'Hoàn thành nhật ký';
  String get completeTimeTracking => 'Kết thúc theo dõi thời gian';
  String get addFinancialTransaction => 'Thêm giao dịch tài chính';

  // Categories
  String get food => '🍽️ Ăn uống';
  String get transport => '🚗 Di chuyển';
  String get shopping => '🛒 Mua sắm';
  String get entertainment => '🎬 Giải trí';
  String get health => '⚕️ Sức khỏe';
  String get education => '📚 Học tập';
  String get work => '💼 Công việc';
  String get other => '📦 Khác';

  // Premium Features
  String get exportData => 'Xuất Dữ Liệu';
  String get advancedStats => 'Thống Kê Nâng Cao';
  String get themeCustomization => 'Tùy Chỉnh Giao Diện';
  String get exportDataDesc => 'Xuất tất cả dữ liệu ra CSV/PDF';
  String get advancedStatsDesc => 'Biểu đồ và thông tin chi tiết';
  String get themeCustomizationDesc => 'Tùy chỉnh màu sắc và giao diện';

  // Messages
  String get notEnoughPoints => 'Không đủ điểm!';
  String get featureUnlocked => 'Tính năng đã được mở khóa!';

  String get quickActions => 'Thao Tác Nhanh';
  String get todaysSummary => 'Tóm Tắt Hôm Nay';
  String get recentActivity => 'Hoạt Động Gần Đây';
  String get entry => 'mục';
  String get tracked => 'đã theo dõi';
  String get transactions => 'giao dịch';
  String get earned => 'đã kiếm';
  String get loadingPersonalSpace => 'Đang tải không gian cá nhân của bạn...';

  String get diaryEntryCompleted => 'Đã hoàn thành nhật ký';
  String get timeTrackingSessionEnded => 'Phiên theo dõi thời gian đã kết thúc';
  String get addedExpense => 'Đã thêm chi tiêu';
  String get minutesAgo => 'phút trước';
  String get hourAgo => 'giờ trước';
  String get hoursAgo => 'giờ trước';
  String get time => 'Thời gian';

  String get tracking => 'Đang theo dõi';
  String get readyToTrack => 'Sẵn sàng theo dõi';
  String get timeStatistics => 'Thống Kê Thời Gian';
  String get today => 'Hôm nay';
  String groupTodayCount(int count) => 'Hôm nay ($count đơn)';
  String get groupNext => 'Tiếp theo';
  String get thisWeek => 'Tuần này';
  String get totalSessions => 'Tổng Phiên';
  String get average => 'Trung bình';
  String get noTimeEntriesYet => 'Chưa có bản ghi thời gian nào';
  String get startTrackingToSeeHistory =>
      'Bắt đầu theo dõi thời gian để xem lịch sử tại đây';
  String get entries => 'mục';
  String get viewAllEntries => 'Xem tất cả {} mục';
  String get timeTrackingCompleted =>
      'Hoàn thành theo dõi thời gian! +3 điểm đã kiếm';
  String get deleteTimeEntry => 'Xóa Bản Ghi Thời Gian';
  String get deleteTimeEntryConfirmation =>
      'Bạn có chắc chắn muốn xóa bản ghi thời gian này? Hành động này không thể hoàn tác.';
  String get timeEntryDeletedSuccessfully =>
      'Đã xóa bản ghi thời gian thành công';
  String get yesterday => 'Hôm qua';

  String get updateAvatar => 'Cập Nhật Avatar';
  String get camera => 'Camera';
  String get gallery => 'Thư viện';
  String get editYourName => 'Chỉnh Sửa Tên';
  String get yourName => 'Tên của bạn';
  String get enterYourName => 'Nhập tên của bạn';
  String get avatarUpdatedSuccessfully => 'Cập nhật avatar thành công! ✨';
  String get failedToUpdateAvatar => 'Không thể cập nhật avatar 😞';
  String get failedToAccessCamera => 'Không thể truy cập camera 📷';
  String get failedToAccessGallery => 'Không thể truy cập thư viện 🖼️';
  String get nameUpdatedSuccessfully => 'Cập nhật tên thành công! 👋';
  String get appearance => 'Giao Diện';
  String get settingsLegacySectionTitle => 'Công cụ bổ sung';
  String get settingsLegacySectionSubtitle =>
      'Nhật ký, chấm công, điểm (màn hình template)';
  String get money => 'Tiền';

  String get pointsAndStore => 'Điểm & Cửa Hàng';
  String get finishTimeTracking => 'Kết thúc theo dõi thời gian';
  String get exportDiaryEntries => 'Xuất Nhật Ký';
  String get exportTimeReports => 'Xuất Báo Cáo Thời Gian';
  String get exportFinancialReports => 'Xuất Báo Cáo Tài Chính';
  String get downloadDiaryEntriesDesc =>
      'Tải về tất cả nhật ký dưới dạng PDF/CSV';
  String get downloadTimeReportsDesc =>
      'Tải về báo cáo theo dõi thời gian chi tiết';
  String get downloadFinancialReportsDesc =>
      'Tải về báo cáo tài chính hoàn chỉnh';
  String get allDiaryEntriesWithDates => 'Tất cả nhật ký kèm ngày tháng';
  String get exportPdfCsvFormat => 'Xuất dưới dạng PDF hoặc CSV';
  String get passwordProtectedFiles => 'File được bảo vệ bằng mật khẩu';
  String get directDownloadDevice => 'Tải trực tiếp về thiết bị';
  String get completeTimeTrackingHistory =>
      'Lịch sử theo dõi thời gian hoàn chỉnh';
  String get productivityChartsGraphs => 'Biểu đồ và đồ thị năng suất';
  String get dailyWeeklyMonthlyReports => 'Báo cáo hàng ngày, tuần, tháng';
  String get professionalPdfFormat => 'Định dạng PDF chuyên nghiệp';
  String get incomeExpenseBreakdown => 'Phân tích thu chi';
  String get financialChartsAnalytics => 'Biểu đồ và phân tích tài chính';
  String get bankStyleStatements => 'Báo cáo kiểu ngân hàng';
  String get taxReadyCsvExports => 'Xuất CSV sẵn sàng cho thuế';
  String get unlockFor => 'Mở khóa với {} điểm';
  String get need => 'Cần {} điểm';
  String get exportFeatureUnlocked =>
      'Tính năng xuất {} đã được mở khóa thành công!';
  String get canExportAnytime => 'Bạn có thể xuất dữ liệu bất cứ lúc nào!';
  String get awesome => 'Tuyệt vời!';
  String get dontHaveEnoughPoints =>
      'Bạn không có đủ điểm để mở khóa tính năng này.';
  String get waysToEarnPoints => 'Cách kiếm điểm:';
  String get dailyCheckInPoints => 'Điểm danh hàng ngày (+5 điểm)';
  String get writeDiaryPoints => 'Viết nhật ký (+2 điểm)';
  String get trackTimePoints => 'Theo dõi thời gian (+3 điểm)';
  String get addTransactionPoints => 'Thêm giao dịch (+1 điểm)';
  String get gotIt => 'Đã hiểu!';
  String get timeReports => 'Báo cáo thời gian';
  String get financialReports => 'Báo cáo tài chính';
  String get diaryEntries => 'Mục nhật ký';

  String get currentBalance => 'Số Dư Hiện Tại';
  String get positiveBalance => 'Số dư dương';
  String get negativeBalance => 'Số dư âm';
  String get monthlyOverview => 'Tổng Quan Tháng';
  String get expenses => 'Chi tiêu';
  String get saved => 'Tiết kiệm';
  String get enterTransactionDescription => 'Nhập mô tả giao dịch';
  String get pleaseEnterAmount => 'Vui lòng nhập số tiền';
  String get pleaseEnterValidAmount => 'Vui lòng nhập số tiền hợp lệ';
  String get pleaseEnterDescription => 'Vui lòng nhập mô tả';
  String get addExpense => 'Thêm Chi Tiêu';
  String get addIncome => 'Thêm Thu Nhập';
  String get noTransactionsYet => 'Chưa có giao dịch nào';
  String get addFirstTransactionToStart =>
      'Thêm giao dịch đầu tiên để bắt đầu theo dõi';
  String get filter => 'Lọc';
  String get viewAllTransactions => 'Xem tất cả {} giao dịch';
  String get deleteTransaction => 'Xóa Giao Dịch';
  String get areYouSureDeleteTransaction =>
      'Bạn có chắc chắn muốn xóa giao dịch này?';
  String get thisActionCannotBeUndone => 'Hành động này không thể hoàn tác';
  String get transactionDeletedSuccessfully => 'Xóa giao dịch thành công';
  String get yourFinancialRecordRemoved =>
      'Bản ghi tài chính của bạn đã được xóa';
  String get transactionAddedSuccessfully =>
      'Thêm giao dịch thành công! +1 điểm đã kiếm';
  String get add => 'Thêm';
  String get transactionDeleted => 'Giao dịch đã bị xóa';

  String get financeAnalytics => 'Phân Tích Tài Chính';
  String get expenseByCategory => 'Chi Tiêu Theo Danh Mục';
  String get allTransactions => 'Tất Cả Giao Dịch';

  String get selectDate => 'Chọn Ngày';
  String get change => 'Thay Đổi';
  String get noDiaryEntriesYet => 'Chưa có nhật ký nào';
  String get chars => 'ký tự';
  String get diarySavedSuccessfully =>
      'Lưu nhật ký thành công! +2 điểm đã kiếm';

  String get noDiaryEntriesFound => 'Không tìm thấy nhật ký nào';
  String get noTimeEntriesFound => 'Không tìm thấy bản ghi thời gian nào';
  String get noFinancialTransactionsFound =>
      'Không tìm thấy giao dịch tài chính nào';
  String get noData => 'Không Có Dữ Liệu';
  String get diaryEntriesExport => 'Xuất Nhật Ký';
  String get totalEntries => 'Tổng Số Mục';
  String get dateRange => 'Khoảng Thời Gian';
  String get copyText => 'Sao Chép';
  String get viewAll => 'Xem Tất Cả';
  String get previewLatest3Entries => 'Xem trước (3 mục gần nhất):';
  String get timeReportsExport => 'Xuất Báo Cáo Thời Gian';
  String get totalTime => 'Tổng Thời Gian';
  String get previewLatest5Sessions => 'Xem trước (5 phiên gần nhất):';
  String get financialReportsExport => 'Xuất Báo Cáo Tài Chính';
  String get previewLatest5Transactions => 'Xem trước (5 giao dịch gần nhất):';
  String get allDiaryEntries => 'Tất Cả Nhật Ký';
  String get allTimeEntries => 'Tất Cả Bản Ghi Thời Gian';
  String get generated => 'Tạo lúc';
  String get task => 'Nhiệm vụ';
  String get date => 'Ngày';
  String get start => 'Bắt đầu';
  String get end => 'Kết thúc';
  String get duration => 'Thời lượng';
  String get type => 'Loại';
  String get summary => 'Tóm tắt';
  String get diaryCopiedToClipboard => 'Đã sao chép nhật ký vào clipboard!';
  String get timeReportsCopiedToClipboard =>
      'Đã sao chép báo cáo thời gian vào clipboard!';
  String get financialReportCopiedToClipboard =>
      'Đã sao chép báo cáo tài chính vào clipboard!';

  String get dailyCheckInActivity => 'Điểm danh hàng ngày';
  String get timeTrackingSession => 'Phiên theo dõi thời gian';
  String get financialTransactionAdded => 'Thêm giao dịch tài chính';
  String get exportDiaryEntriesFeature => 'Tính năng xuất nhật ký';
  String get exportTimeReportsFeature => 'Tính năng xuất báo cáo thời gian';
  String get exportFinancialReportsFeature =>
      'Tính năng xuất báo cáo tài chính';
  String get exportBundleAllFeatures => 'Gói xuất dữ liệu - tất cả tính năng';
  String get exportDataFeature => 'Tính năng xuất dữ liệu';
  String get advancedStatistics => 'Thống kê nâng cao';

  // Sale orders
  String get ordersTitle => 'Đơn bán hàng';
  String get ordersCreate => 'Tạo đơn';
  String get ordersListEmpty => 'Chưa có đơn hàng.';
  String get ordersListSearchEmpty => 'Không tìm thấy đơn phù hợp.';
  String get ordersSearchHint => 'Mã đơn, tên khách, tên sản phẩm trong đơn…';
  String get ordersFilterAll => 'Tất cả';
  String get ordersFilterPaymentUnpaid => 'Chưa TT Xong';
  String get ordersFilterShowMore => 'Xem thêm';
  String get ordersFilterShowLess => 'Thu gọn';
  String get ordersOrderShort => 'Đơn';

  /// Tiền tố badge trạng thái đơn giao trên thẻ đơn hàng (danh sách).
  String get ordersDeliveryGHPrefix => 'GH: ';
  String get ordersDetailTitle => 'Chi tiết đơn';
  String get ordersSubtotal => 'Tạm tính';
  String get ordersAmountDue => 'Còn phải thu';
  String get ordersOrderIdCopied => 'Đã sao chép mã đơn';
  String get saleOrderNotesSectionTitle => 'Ghi chú đơn hàng';
  String get saleOrderNotesHint => 'Tối đa 500 ký tự';
  String get saleOrderExpectedDeliveryTitle => 'Thời gian dự kiến giao hàng';
  String get saleOrderExpectedDeliveryHint =>
      'Chọn ngày giờ (tuỳ chọn). Để trống nếu chưa hẹn.';
  String get saleOrderExpectedDeliveryClear => 'Bỏ hẹn';
  String get saleOrderExpectedDeliveryUpdated => 'Đã cập nhật hẹn giao';
  String get saleOrderExpectedDeliveryTapToSet =>
      'Chưa hẹn — nhấn để chọn ngày giờ';
  String get prepOrderExpectedFromSale => 'Dự kiến giao (đơn hàng)';
  String get prepOrderNotesFromSale => 'Ghi chú đơn hàng';
  String get saleOrderDetailAuditTitle => 'Thông tin đơn';
  String get saleOrderCreatedBy => 'Người tạo';
  String get saleOrderUpdatedBy => 'Cập nhật bởi:';
  String get saleOrderWorkerLabel => 'Người làm';
  String get saleOrderCreatedAtLabel => 'Ngày tạo';
  String get saleOrderLastUpdatedLabel => 'Cập nhật lần cuối';
  String get ordersDetailRefresh => 'Làm mới';
  String get saleOrderDetailEditOrder => 'Chỉnh sửa đơn hàng';
  String get saleOrderDetailRefresh => 'Tải lại / đồng bộ';
  String get saleOrderDetailRefreshDone => 'Đã đồng bộ dữ liệu mới nhất';
  String get saleOrderChangeStatus => 'Đổi trạng thái';
  String get saleOrderChangeStatusTitle => 'Chuyển trạng thái đơn hàng';
  String get saleOrderChangeStatusSuccess => 'Đã cập nhật trạng thái đơn hàng';
  String get saleOrderChangeStatusNoOptions =>
      'Đơn này không có bước chuyển trạng thái tiếp theo.';
  String saleOrderChangeStatusConfirm(String from, String to) =>
      'Chuyển từ «$from» sang «$to»?';
  String get saleOrderKiotSyncOverwriteTitle => 'Đồng bộ từ KiotViet';
  String get saleOrderKiotSyncOverwriteMessage =>
      'Dữ liệu đơn hàng trên hệ thống sẽ bị ghi đè bởi dữ liệu mới nhất từ KiotViet. Tiếp tục?';
  String get saleOrderKiotPaymentsTitle => 'Chi tiết thanh toán (KiotViet)';
  String get saleOrderRecordPaymentPendingShort => 'Chờ duyệt';
  String get saleOrderRecordPaymentButton => 'Ghi nhận thanh toán';
  String get saleOrderRecordPaymentTitle => 'Ghi nhận thanh toán';
  String get saleOrderRecordPaymentTotalOrder => 'Tổng số tiền đơn hàng';
  String get saleOrderRecordPaymentCollected => 'Đã thu';
  String get saleOrderRecordPaymentRemaining => 'Còn phải thu';
  String get saleOrderRecordPaymentThisTime => 'Số tiền thu lần này';
  String get saleOrderRecordPaymentMethod => 'Hình thức';
  String get saleOrderRecordPaymentMethodCash => 'Tiền mặt';
  String get saleOrderRecordPaymentMethodTransfer => 'Chuyển khoản';
  String get saleOrderRecordPaymentMethodCard => 'Quẹt thẻ';
  String get saleOrderRecordPaymentMethodOther => 'Thanh toán khác';
  String get saleOrderRecordPaymentNote => 'Ghi chú thanh toán';
  String get saleOrderRecordPaymentSchedule => 'Hẹn thanh toán';
  String get saleOrderRecordPaymentSchedulePick => 'Chọn ngày hẹn';
  String get saleOrderRecordPaymentScheduleRequired =>
      'Bật hẹn thanh toán cần chọn ngày trong tương lai.';
  String get saleOrderRecordPaymentScheduleAmountLabel => 'Số hẹn thu';
  String get saleOrderRecordPaymentPreviousSchedule => 'Lần hẹn thu trước';
  String get saleOrderRecordPaymentScheduleModeHint =>
      'Chỉ đặt lịch nhắc thu — chưa ghi nhận tiền thực tế.';
  String get saleOrderRecordPaymentScheduleSubmit => 'Ghi nhận hẹn';
  String get saleOrderPaymentScheduleReminderLabel => 'Hẹn thu';
  String get saleOrderRecordPaymentSubmit => 'Ghi nhận';
  String get saleOrderRecordPaymentConfirm => 'Xác nhận';
  String get saleOrderRecordPaymentPendingTitle =>
      'Ghi nhận chờ quản lý xác nhận';
  String get saleOrderRecordPaymentSuccess => 'Đã gửi ghi nhận.';
  String get saleOrderRecordPaymentConfirmSuccess =>
      'Đã xác nhận thanh toán.';
  String get saleOrderRecordPaymentInvalidAmount =>
      'Nhập số tiền hợp lệ (đồng).';
  String get saleOrderRecordPaymentAmountTooHigh =>
      'Số tiền không được vượt quá số còn phải thu.';
  String get saleOrderRecordPaymentTransferProofTitle =>
      'Ảnh xác nhận chuyển khoản';
  String get saleOrderRecordPaymentTransferProofHint =>
      'Tuỳ chọn: chụp hoặc chọn ảnh bill / screenshot giao dịch.';
  String get saleOrderRecordPaymentTransferProofRemove => 'Xóa ảnh';
  String get saleOrderRecordPaymentTransferProofView => 'Xem ảnh CK';
  String get saleOrderRecordPaymentTransferProofUploadFailed =>
      'Không tải được ảnh lên. Thử lại.';
  String get saleOrderPrepButtonLabel => 'Tạo phiếu Chuẩn bị hàng';
  String get saleOrderDetailCancelOrder => 'Hủy đơn hàng';
  String get saleOrderDetailCancelConfirm =>
      'Bạn có chắc muốn hủy đơn hàng này?';
  String get saleOrderDetailCancelled => 'Đã hủy đơn hàng';
  String get ordersLinesPrepaid => 'Đã TT (theo dòng SP)';
  String get ordersLinesTitle => 'Sản phẩm';
  String get ordersStatusLabel => 'Trạng thái';
  String get ordersStatusDraft => 'Nháp';
  String get ordersStatusConfirmed => 'Phiếu tạm';
  String get ordersStatusDelivery => 'Đang giao';
  String get ordersStatusCompleted => 'Hoàn thành';
  String get ordersStatusCancelled => 'Đã hủy';
  String get ordersStatusRefund => 'Hoàn tiền';
  String get ordersDashboardList => 'Quản lý đơn';
  String get ordersDashboardCreate => 'Tạo đơn mới';
  String get ordersSubTabOrders => 'Đơn hàng';
  String get ordersSubTabRepair => 'Sửa chữa';
  String get ordersScopeAll => 'Đơn hàng';
  String get ordersScopeMine => 'Của tôi';
  String get ordersScopeBoard => 'Bảng chung';
  String get ordersDateFilterTitle => 'Lọc theo ngày tạo';
  String get ordersDatePreset1Day => '1 ngày';
  String get ordersDatePreset1Week => '1 tuần';
  String get ordersDatePreset1Month => '1 tháng';
  String get ordersDatePreset3Months => '3 tháng';
  String get ordersDatePresetCustom => 'Tùy chọn';
  String get ordersDateFilterClear => 'Bỏ lọc ngày';
  String get ordersManagedBy => 'Người quản lý';
  String get ordersAssignToMe => 'Nhận đơn';
  String get ordersAssignToMeSuccess => 'Đã nhận đơn để quản lý';
  String get ordersFinish => 'Xong';
  String get ordersFinishSuccess => 'Đã hoàn tất đơn hàng';
  String get ordersCompleteDelivery => 'Hoàn thành';
  String get ordersCompleteDeliverySuccess => 'Đã hoàn thành giao hàng';
  String get ordersFinishBlockedPayment =>
      'Cần ghi nhận đủ thanh toán trước khi bấm Xong.';
  String get ordersFinishBlockedPrep =>
      'Phiếu chuẩn bị phải ở trạng thái Chuẩn bị xong.';
  String get ordersFinishBlockedDelivery =>
      'Phiếu giao hàng phải ở trạng thái Hủy hoặc Hoàn thành trước khi kết thúc đơn.';
  String get saleOrderDetailCompleteOrder => 'Hoàn thành';
  String get ordersBoardEmpty => 'Không có đơn trên bảng chung.';

  String get repairFormTitle => 'Tạo đơn sửa chữa';
  String get repairCustomerName => 'Khách hàng';
  String get repairCustomerPhone => 'Số điện thoại';
  String get repairItemDescription => 'Sản phẩm / thiết bị';
  String get repairIssueDescription => 'Nội dung sửa chữa';
  String get repairReceivedDate => 'Ngày nhận';
  String get repairPromisedDate => 'Ngày hẹn trả';
  String get repairNotes => 'Ghi chú';
  String get repairPriority => 'Ưu tiên';
  String get repairStatus => 'Trạng thái';
  String get repairSubmit => 'Tạo đơn';
  String get repairListEmpty => 'Chưa có đơn sửa chữa.';
  String get repairLoadFailed => 'Không tải được danh sách sửa chữa.';
  String get repairCreated => 'Đã tạo đơn sửa chữa.';

  // Tasks
  String get tasksDashboardSection => 'Nhiệm vụ của tôi';
  String get tasksViewAll => 'Xem tất cả';
  String get tasksCreateNew => 'Thêm nhiệm vụ mới';
  String get tasksListTitle => 'Nhiệm vụ';
  String get tasksListEmpty => 'Chưa có nhiệm vụ.';
  String get tasksCreateTitle => 'Tạo nhiệm vụ';
  String get tasksDetailTitle => 'Chi tiết nhiệm vụ';
  String get tasksTitleLabel => 'Tiêu đề';
  String get tasksContentLabel => 'Nội dung';
  String get tasksDueLabel => 'Hạn';
  String get tasksDuePick => 'Chọn thời hạn';
  String get tasksPriorityHigh => 'Ưu tiên cao';
  String get tasksPriorityNormal => 'Ưu tiên thường';
  String get tasksPrioritySection => 'Ưu tiên';
  String get tasksAssigneeSection => 'Người thực hiện';
  String get tasksAssigneeMain => 'Người chính';
  String get tasksAssigneeMe => 'Tôi';
  String get tasksCollaboratorsSection => 'Người phụ';
  String get tasksCollaboratorsEmpty => 'Chưa có người phụ.';
  String get tasksAddCollaborator => 'Thêm người phụ';
  String get tasksSubmit => 'Tạo nhiệm vụ';
  String get tasksTitleRequired => 'Vui lòng nhập tiêu đề.';
  String get tasksCreateFailed => 'Không tạo được nhiệm vụ.';
  String get tasksCreated => 'Đã tạo nhiệm vụ.';
  String get tasksFilterAll => 'Tất cả';
  String get tasksStatusPending => 'Chưa làm';
  String get tasksStatusInProgress => 'Đang làm';
  String get tasksStatusOverdue => 'Quá hạn';
  String get tasksStatusCompleted => 'Hoàn thành';
  String get tasksStatusCancelled => 'Đã hủy';
  String get tasksScopeMine => 'Của tôi';
  String get tasksScopeAll => 'Toàn bộ';
  String get tasksRoleMain => 'Chính';
  String get tasksRoleCollaborator => 'Phụ';
  String get tasksPerformersSection => 'Người thực hiện';
  String get tasksEditPerformers => 'Cập nhật người thực hiện';
  String get tasksAttachmentsSection => 'Đính kèm';
  String get tasksAttachmentsEmpty => 'Chưa có đính kèm.';
  String get tasksAddAttachment => 'Thêm ảnh / video';
  String get tasksNotesSection => 'Ghi chú nhóm';
  String get tasksNotesEmpty => 'Chưa có ghi chú.';
  String get tasksNoteHint => 'Viết ghi chú…';
  String get tasksAddNote => 'Gửi';
  String get tasksCompleteAction => 'Hoàn thành';
  String get tasksCompletedSuccess => 'Đã hoàn thành nhiệm vụ.';
  String get tasksEditTitle => 'Sửa nhiệm vụ';
  String get tasksCancelTitle => 'Hủy nhiệm vụ';
  String get tasksCancelConfirm => 'Bạn có chắc muốn hủy nhiệm vụ này?';
  String get tasksCancelAction => 'Hủy';
  String get tasksDashboardEmpty => 'Không có nhiệm vụ phù hợp.';

  String get dashboardTodayTitle => 'Tổng quan hôm nay';
  String get dashboardScopeAll => 'Toàn hệ thống';
  String get dashboardScopeMine => 'Công việc của tôi';
  String get dashboardStatOrdersToday => 'Đơn hàng hôm nay';
  String get dashboardStatOrdersTodayHint => 'Đơn được tạo trong ngày';
  String get dashboardStatPrepToday => 'Chuẩn bị';
  String get dashboardStatPrepTodayHint => 'Phiếu CB tạo hôm nay';
  String get dashboardStatDeliveryToday => 'Giao hàng';
  String get dashboardStatDeliveryTodayHint => 'Đơn giao tạo hôm nay';
  String get dashboardReminders => 'Nhắc nhở';
  String get dashboardReminderDraft => 'Phiếu tạm / nháp cần xử lý';
  String get dashboardReminderPrep => 'Phiếu chuẩn bị đang chờ';
  String get dashboardReminderDelivery => 'Đơn giao chưa hoàn tất';
  String get dashboardReminderScheduledPayment => 'Đơn đang hẹn thanh toán';
  String get dashboardReminderOpsTitle => 'Đơn hàng · Chuẩn bị · Giao hàng';
  String get dashboardReminderOverdue => 'Trễ hẹn giao';
  String get dashboardReminderDueWithin24h => 'Phải giao trong 24h';
  String get dashboardReminderScheduledDelivery24h => 'Hẹn giao trong 24h';
  String get dashboardReminderNoPrepAssignee =>
      'Đã nhận đơn, chưa có người chuẩn bị';
  String get dashboardReminderNoDeliveryAssignee => 'Chưa có người giao hàng';
  String get dashboardLoadFailed => 'Không tải được tổng quan.';

  /// Nhãn tab bottom nav: Đơn hàng.
  String get ordersNav => 'Đơn hàng';
  String get saleOrderFlowTitle => 'Tạo đơn bán hàng';
  String get saleOrderStep1Title => 'Khách hàng & giao hàng';
  String get saleOrderPhoneHint => 'Số điện thoại';
  String get saleOrderLookupResults => 'Kết quả tìm';
  String get saleOrderNewCustomerBlock => 'Tạo khách mới';
  String get saleOrderNameHint => 'Tên khách';
  String get saleOrderHouseHint => 'Số nhà / đường';
  String get saleOrderConfiguredAddresses => 'Địa chỉ đã cấu hình (hệ thống)';
  String get saleOrderWard => 'Phường/xã (mã)';
  String get saleOrderProvince => 'Tỉnh/TP (mã)';
  String get saleOrderCreateCustomer => 'Lưu khách mới';
  String get saleOrderSelected => 'Đã chọn';

  /// Sau khi tra SĐT: không có khách khớp (đủ số).
  String get saleOrderPhoneNotInSystem => 'Chưa có trên hệ thống';
  String get saleOrderAddAddress => 'Thêm địa chỉ';
  String get saleOrderSelectAddress => 'Chọn địa chỉ giao';

  /// Xác nhận xóa một địa chỉ giao hàng (Step 1).
  String saleOrderDeleteAddressConfirm(String summary) =>
      'Xóa địa chỉ này?\n$summary';

  /// Tiêu đề nhóm chip tuỳ chọn dòng đơn (popup sửa SP).
  String get saleOrderLineEditOptionsTitle => 'Tuỳ chọn';

  /// Gợi ý nhập giá theo phân cách nghìn (khớp app).
  String get saleOrderIntegerThousandsHint =>
      'Dùng dấu chấm (.) phân cách hàng nghìn.';

  String get saleOrderCustomerNewBanner => 'Khách hàng mới';
  String get saleOrderNeedPhone => 'Nhập số điện thoại để tìm (ít nhất 9 số).';
  String get saleOrderPickCustomer => 'Chọn hoặc tạo khách hàng trước.';
  String get saleOrderNeedName => 'Nhập tên khách.';
  String get saleOrderNeedAddress => 'Nhập địa chỉ (số nhà).';
  String get saleOrderNeedNameOrPhone =>
      'Nhập tên khách hoặc số điện thoại (ít nhất một trong hai).';
  String get saleOrderOptionalSuffix => ' (tùy chọn)';
  String get saleOrderStep3Title => 'Thanh toán';
  String get saleOrderBaseOwed => 'Tiền hàng chưa TT';
  String get saleOrderPayFull => 'Đã thanh toán đủ';
  String get saleOrderPayPartial => 'Trả trước một phần';
  String get saleOrderPayScheduled => 'Hẹn thanh toán';
  String get saleOrderPayOnDelivery => 'Thanh toán khi giao hàng';
  String get saleOrderScheduledDate => 'Ngày hẹn thanh toán';

  /// Ngày hẹn trả phần còn lại (kèm trả trước một phần).
  String get saleOrderRemainderDueDate => 'Hẹn ngày trả';
  String get saleOrderRemainderDateRequired =>
      'Vui lòng chọn ngày trả phần còn lại.';
  String get saleOrderPartialPrepaidInvalid =>
      'Số trả trước phải lớn hơn 0 và nhỏ hơn số còn phải thu.';
  String get saleOrderReviewSectionCustomer => 'Khách hàng';
  String get saleOrderCopyName => 'Sao chép tên';
  String get saleOrderCopyPhone => 'Sao chép SĐT';
  String get saleOrderCopyAddress => 'Sao chép địa chỉ';
  String get saleOrderCopiedName => 'Đã sao chép tên khách hàng';
  String get saleOrderCopiedPhone => 'Đã sao chép số điện thoại';
  String get saleOrderCopiedAddress => 'Đã sao chép địa chỉ';
  String get saleOrderReviewMissingCustomerWarning =>
      'Đơn hàng thiếu thông tin khách hàng.';
  String get saleOrderReviewSectionPayment => 'Thanh toán';
  String get saleOrderReviewSectionProducts => 'Sản phẩm';
  String get saleOrderPrepaidAmount => 'Số tiền trả trước (đồng)';
  String get saleOrderPrepaidHint =>
      'Nhập số, có thể dùng dấu . ngăn cách nghìn';
  String get saleOrderStep4Title => 'Xem lại & xác nhận';
  String get saleOrderOperationSection => 'Vận hành';
  String get saleOrderCreatePreparation => 'Tạo phiếu Chuẩn bị hàng';
  String get saleOrderCreatePreparationHint =>
      'Sau khi xác nhận, phiếu sẽ được đưa lên bảng chung trong tab Chuẩn bị hàng.';
  String get saleOrderPrepDeliveryAlreadyExists => 'Đã tồn tại đơn giao hàng';
  String get saleOrderPreparationCreated =>
      'Đã tạo phiếu Chuẩn bị hàng trên bảng chung.';
  String get saleOrderPaymentTerms => 'Điều khoản thanh toán';
  String get saleOrderNext => 'Tiếp theo';
  String get saleOrderBack => 'Quay lại';
  String get saleOrderConfirm => 'Xác nhận đơn';
  String get saleOrderKiotVietSave => 'Lưu đơn';
  String get saleOrderKiotVietSaved => 'Đã lưu đơn hàng.';
  String get saleOrderConfirmed => 'Đã tạo đơn thành công.';
  String get saleOrderHomeDelivery => 'Giao hàng';
  String get saleOrderHomeDeliveryReview => 'Có giao hàng';
  String get saleOrderCreateDeliveryNowTitle => 'Tạo đơn giao hàng?';
  String get saleOrderCreateDeliveryNowMsg =>
      'Đơn đã chọn giao hàng. Bạn có muốn tạo đơn giao hàng ngay bây giờ không?';
  String get saleOrderPrepaidPaidShort => 'Đã trả trước';
  String get saleOrderAddProduct => 'Thêm sản phẩm';
  String get saleOrderNoLines => 'Chưa có sản phẩm. Nhấn nút Thêm sản phẩm.';
  String get saleOrderQty => 'Số lượng';

  /// Nhãn ngắn (vd. chi tiết đơn: cùng hàng với mã SP).
  String get saleOrderPriceShort => 'Giá:';

  /// Chi tiết đơn — dòng SP: nhãn trước số tiền dòng.
  String get saleOrderLineTotalLabel => 'Thành tiền:';

  /// Chi tiết đơn — dòng SP: nhãn giá đơn vị.
  String get saleOrderSellingPriceLabel => 'Giá bán:';
  String get saleOrderUnitPrice => 'Giá bán (đơn vị)';
  String get saleOrderFlagFragile => 'Dễ vỡ';
  String get saleOrderFlagBulky => 'Cồng kềnh';
  String get saleOrderFlagInstall => 'Cần lắp đặt';
  String get saleOrderFlagPack => 'Đóng gói cẩn thận';
  String get saleOrderFlagPaid => 'Đã thanh toán';

  /// Chip sửa dòng SP: bật = thanh toán sau (chưa thu theo dòng).
  String get saleOrderLinePayLaterChip => 'Thanh toán sau';
}
