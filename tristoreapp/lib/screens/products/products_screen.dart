import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/routes.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/auth_user.dart';
import 'package:tstore/models/product.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui/app_search_bar.dart';
import '../../widgets/ui/empty_state.dart';
import '../../widgets/ui/error_banner.dart';
import '../../core/theme/app_ui_extension.dart';
import '../../widgets/ui/app_surface_card.dart';
import '../../widgets/ui/list_skeleton.dart';
import '../main_shell.dart';
import '../orders/sale_order_flow_screen.dart';
import 'create_product_sheet.dart';
import 'product_detail_screen.dart';
import 'product_media_widgets.dart';

/// Sau này bật `true` để cho phép nhân viên tạo sản phẩm (cần đồng bộ backend).
const bool kStaffMayCreateProducts = false;

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  final List<Product> _items = [];
  final List<ProductTag> _filterTags = [];
  int _page = 0;
  int _totalPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  static const _limit = 20;
  static const _maxTagFilters = 10;

  final Map<String, Product> _prepSelected = {};
  final List<String> _prepOrder = [];
  void _onSearchTextChanged() {
    if (mounted) setState(() {});
  }

  void _togglePrepSelection(Product product) {
    if (product.quantity == 0) return;
    setState(() {
      if (_prepSelected.containsKey(product.id)) {
        _prepSelected.remove(product.id);
        _prepOrder.remove(product.id);
      } else {
        _prepSelected[product.id] = product;
        _prepOrder.add(product.id);
      }
    });
  }

  List<Product> _prepProductsOrdered() =>
      _prepOrder.map((id) => _prepSelected[id]!).toList();

  Future<void> _openPrepareOrderFlow() async {
    if (_prepOrder.isEmpty) return;
    final ordered = _prepProductsOrdered();
    setState(() {
      _prepSelected.clear();
      _prepOrder.clear();
    });
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SaleOrderFlowScreen(
          initialPageIndex: 1,
          initialPrepProducts: ordered,
        ),
      ),
    );
  }

  static bool _canManageProducts(AuthUser? u) {
    final r = u?.role ?? '';
    return r == 'manager' || r == 'admin';
  }

  static bool _canCreateProduct(AuthUser? u) {
    if (_canManageProducts(u)) return true;
    if (!kStaffMayCreateProducts) return false;
    return u?.role == 'staff';
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchTextChanged);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _loading || _error != null) return;
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    if (_scroll.position.pixels > max - 240) {
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
    if (_loading || _loadingMore) return;
    final nextPage = reset ? 1 : _page + 1;
    if (!reset && (nextPage > _totalPages || _page >= _totalPages)) return;

    setState(() {
      _error = null;
      if (reset) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });

    final auth = context.read<AuthProvider>();
    try {
      final trimmed = _searchCtrl.text.trim();
      final q = <String, dynamic>{'page': nextPage, 'limit': _limit};
      if (trimmed.isNotEmpty) {
        q['search'] = trimmed;
      }
      if (_filterTags.isNotEmpty) {
        q['tagIds'] = _filterTags.map((t) => t.id).toList();
      }
      final res = await auth.api.get<Map<String, dynamic>>(
        '/admin/products',
        queryParameters: q,
      );
      final data = res.data;
      if (data == null) {
        throw Exception('empty');
      }
      final list = (data['items'] as List<dynamic>? ?? [])
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
      final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(list);
        } else {
          _items.addAll(list);
        }
        _page = nextPage;
        _totalPages = totalPages;
        _loading = false;
        _loadingMore = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      var msg = e.message ?? 'Error';
      if (e.response?.statusCode == 403) {
        msg = AppLocalizations.of(context).productsForbidden;
      } else if (e.response?.data is Map) {
        final m = (e.response!.data as Map)['message'];
        if (m is String) {
          msg = m;
        } else if (m is List && m.isNotEmpty) {
          msg = m.first.toString();
        }
      }
      setState(() {
        _error = msg;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _load(reset: true);
      }
    });
  }

  Set<String> get _filterTagIds => _filterTags.map((t) => t.id).toSet();

  void _toggleFilterTag(ProductTag tag) {
    final l10n = AppLocalizations.of(context);
    final i = _filterTags.indexWhere((t) => t.id == tag.id);
    if (i >= 0) {
      setState(() => _filterTags.removeAt(i));
    } else {
      if (_filterTags.length >= _maxTagFilters) {
        AppMessenger.showSnackBar(context, 
          SnackBar(content: Text(l10n.productsTagFilterMax)),
        );
        return;
      }
      setState(() => _filterTags.add(ProductTag(id: tag.id, name: tag.name)));
    }
    _load(reset: true);
  }

  void _removeFilterTag(String id) {
    setState(() => _filterTags.removeWhere((t) => t.id == id));
    _load(reset: true);
  }

  void _openImageViewer(List<String> urls, int initialIndex) {
    if (urls.isEmpty || !mounted) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      useSafeArea: false,
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.sizeOf(ctx).width,
          height: MediaQuery.sizeOf(ctx).height,
          child: ProductImageGalleryDialog(
            urls: urls,
            initialIndex: initialIndex,
            baseUrl: ApiConfig.baseUrl,
          ),
        ),
      ),
    );
  }

  Future<void> _openCreate() async {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthProvider>();
    String code = '';
    try {
      final res =
          await auth.api.get<Map<String, dynamic>>('/admin/products/code/next');
      code = (res.data?['code'] as String?) ?? '';
    } catch (_) {}

    if (!mounted) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => CreateProductSheet.create(suggestedCode: code),
    );
    if (!mounted) return;
    if (created == true) {
      AppMessenger.showSnackBar(context, 
        SnackBar(
          content: Text(l10n.success),
          backgroundColor: AppColors.success,
        ),
      );
      await _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final canCreate = _canCreateProduct(user);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            8,
            AppSpacing.screenHorizontal,
            10,
          ),
          child: FilledButton(
            onPressed:
                _prepOrder.isEmpty ? null : () => _openPrepareOrderFlow(),
            child: Text(
              l10n.productsPrepareOrderWithCount(_prepOrder.length),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space1,
                AppSpacing.space1,
                AppSpacing.space1,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.homeNav,
                    icon: const Icon(Icons.home_rounded),
                    onPressed: () {
                      final shell = MainShellController.maybeOf(context);
                      if (shell != null) {
                        shell.goHome();
                      } else {
                        Navigator.pushReplacementNamed(context, AppRoutes.home);
                      }
                    },
                  ),
                  Expanded(
                    child: Text(
                      l10n.productsTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (canCreate)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 148),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _openCreate(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_circle_outline_rounded, size: 22),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                l10n.productsCreate,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.space2,
                AppSpacing.screenHorizontal,
                AppSpacing.space2,
              ),
              child: AppSearchBar(
                controller: _searchCtrl,
                hintText: l10n.productsSearchHint,
                onChanged: (_) => _onSearchChanged(),
                onClear: () => _onSearchChanged(),
              ),
            ),
              if (_filterTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    0,
                    AppSpacing.screenHorizontal,
                    AppSpacing.space2,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in _filterTags)
                          Padding(
                            padding: const EdgeInsets.only(
                                right: 8, top: 4, bottom: 2),
                            child: _FilterTagPill(
                              label: t.name,
                              onRemove: () => _removeFilterTag(t.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: _buildBody(l10n),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading && _items.isEmpty) {
      return const ListSkeleton(
        rows: 8,
        variant: ListSkeletonVariant.compact,
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ErrorBanner(
            message: _error!,
            retryLabel: l10n.productsRetry,
            onRetry: () => _load(reset: true),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyState(message: l10n.productsEmpty),
        ],
      );
    }
    var extra = 0;
    if (_loadingMore) {
      extra = 1;
    } else if (_page >= _totalPages && _items.isNotEmpty) {
      extra = 1;
    }
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        AppSpacing.space6,
      ),
      itemCount: _items.length + extra,
      itemBuilder: (context, i) {
        if (i < _items.length) {
          final product = _items[i];
          return _ProductTile(
            product: product,
            l10n: l10n,
            selectedTagIds: _filterTagIds,
            onTagTap: _toggleFilterTag,
            prepSelected: _prepSelected.containsKey(product.id),
            onPrepToggle: () => _togglePrepSelection(product),
            onOpenDetail: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (ctx) =>
                      ProductDetailScreen(productId: product.id),
                ),
              );
            },
            onImageTap: product.images.isEmpty
                ? null
                : () => _openImageViewer(product.images, 0),
          );
        }
        if (_loadingMore) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              l10n.productsEnd,
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
        );
      },
    );
  }
}

class _FilterTagPill extends StatelessWidget {
  const _FilterTagPill({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outline),
        ),
        padding: const EdgeInsets.only(left: 12, right: 2, top: 6, bottom: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(18),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductListTagPill extends StatelessWidget {
  const _ProductListTagPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.outline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.l10n,
    required this.selectedTagIds,
    required this.onTagTap,
    required this.onOpenDetail,
    this.prepSelected = false,
    this.onPrepToggle,
    this.onImageTap,
  });

  final Product product;
  final AppLocalizations l10n;
  final Set<String> selectedTagIds;
  final ValueChanged<ProductTag> onTagTap;
  final VoidCallback onOpenDetail;
  final bool prepSelected;
  final VoidCallback? onPrepToggle;
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context) {
    final thumb = product.images.isNotEmpty ? product.images.first : null;
    final outOfStock = product.quantity == 0;

    final prepSlot = onPrepToggle != null;
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(
            url: thumb,
            onTap: onImageTap,
            hasGallery: product.images.isNotEmpty,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: prepSlot ? 84 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: onOpenDetail,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            product.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: onOpenDetail,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  product.code,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${l10n.productsQuantity}: ${product.quantity}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                      if (product.tags.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          l10n.productsTags,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 5,
                          runSpacing: 3,
                          children: product.tags.map((t) {
                            final selected = selectedTagIds.contains(t.id);
                            return _ProductListTagPill(
                              label: t.name,
                              selected: selected,
                              onTap: () => onTagTap(t),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                if (prepSlot)
                  Positioned(
                    top: outOfStock ? 4 : 0,
                    right: 0,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: outOfStock ? null : onPrepToggle,
                      child: Text(
                        prepSelected
                            ? l10n.productsPrepDeselect
                            : l10n.productsPrepSelect,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (outOfStock) {
      content = Banner(
        message: l10n.productsOutOfStock,
        location: BannerLocation.topEnd,
        color: const Color(0xFFEA580C),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: content,
      );
    }

    final ui = context.appUi;
    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardOuter),
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui.radiusLg),
          border: prepSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ui.radiusLg),
          child: content,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    this.url,
    this.onTap,
    this.hasGallery = false,
  });

  final String? url;
  final VoidCallback? onTap;
  final bool hasGallery;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    Widget core;
    if (url == null || url!.isEmpty) {
      core = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.inventory_2_outlined,
            color: AppColors.primary.withValues(alpha: 0.6)),
      );
    } else {
      core = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ProductImageUrl(
          url: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          baseUrl: ApiConfig.baseUrl,
        ),
      );
    }

    if (onTap != null && hasGallery) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: core,
        ),
      );
    }
    return core;
  }
}
