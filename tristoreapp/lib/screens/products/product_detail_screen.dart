import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/auth_user.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import 'create_product_sheet.dart';
import 'product_media_widgets.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  static bool _userMayEditProduct(AuthUser? u) {
    final r = u?.role ?? '';
    return r == 'manager' || r == 'admin';
  }

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.api.get<Map<String, dynamic>>(
        '/admin/products/${widget.productId}',
      );
      final data = res.data;
      if (data == null) {
        throw Exception('empty');
      }
      final p = Product.fromJson(data);
      if (!mounted) return;
      setState(() {
        _product = p;
        _loading = false;
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openEditSheet() async {
    final p = _product;
    if (p == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => CreateProductSheet.edit(product: p),
    );
    if (!mounted) return;
    if (ok == true) {
      AppMessenger.showSnackBar(context, 
        SnackBar(
          content: Text(l10n.success),
          backgroundColor: AppColors.success,
        ),
      );
      await _load();
    }
  }

  void _openGallery(List<String> urls, int initialIndex) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().user;
    final showEdit =
        !_loading && _error == null && ProductDetailScreen._userMayEditProduct(user);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.productsDetailTitle),
        actions: [
          if (showEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.productsEdit,
              onPressed: _openEditSheet,
            ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: Text(l10n.productsRetry),
              ),
            ],
          ),
        ),
      );
    }
    final p = _product!;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.images.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: p.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) {
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openGallery(p.images, i),
                      borderRadius: BorderRadius.circular(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ProductImageUrl(
                          url: p.images[i],
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          baseUrl: ApiConfig.baseUrl,
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            p.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  p.code,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${l10n.productsQuantity}: ${p.quantity}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${l10n.productsSellingPrice}: ${NumberFormat.decimalPattern(Localizations.localeOf(context).toString()).format(p.sellingPrice)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Text(l10n.productsDetailCreatedAt, style: labelStyle),
          const SizedBox(height: 4),
          Text(
            _formatDetailDate(context, l10n, p.createdAt),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Text(l10n.productsDetailContentUpdatedAt, style: labelStyle),
          const SizedBox(height: 4),
          Text(
            _formatDetailDate(context, l10n, p.lastContentUpdatedAt),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Text(l10n.productsDetailQuantityUpdatedAt, style: labelStyle),
          const SizedBox(height: 4),
          Text(
            _formatDetailDate(context, l10n, p.lastQuantityUpdatedAt),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (p.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.productsTags, style: labelStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: p.tags
                  .map(
                    (t) => Chip(
                      label: Text(t.name),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.productsDescription, style: labelStyle),
            const SizedBox(height: 6),
            Text(
              p.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDetailDate(
    BuildContext context,
    AppLocalizations l10n,
    DateTime? dt,
  ) {
    if (dt == null) return l10n.productsDetailDatePlaceholder;
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('dd/MM/yyyy HH:mm', locale).format(dt.toLocal());
  }
}
