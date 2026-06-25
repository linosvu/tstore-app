import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import 'package:tstore/core/utils/amount_input.dart';
import 'package:tstore/core/utils/product_image_compress.dart' show uploadProductImageFromPath;
import 'package:tstore/models/product.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/integer_thousands_input_formatter.dart';
import 'product_media_widgets.dart';

class CreateProductSheet extends StatefulWidget {
  const CreateProductSheet._({
    super.key,
    this.suggestedCode,
    this.productToEdit,
  });

  /// Tạo mới (mã gợi ý từ API).
  factory CreateProductSheet.create({
    Key? key,
    required String suggestedCode,
  }) {
    return CreateProductSheet._(key: key, suggestedCode: suggestedCode);
  }

  /// Sửa sản phẩm hiện có (`PATCH /admin/products/:id`).
  factory CreateProductSheet.edit({Key? key, required Product product}) {
    return CreateProductSheet._(key: key, productToEdit: product);
  }

  final String? suggestedCode;
  final Product? productToEdit;

  bool get _isEdit => productToEdit != null;

  @override
  State<CreateProductSheet> createState() => _CreateProductSheetState();
}

class _CreateProductSheetState extends State<CreateProductSheet> {
  static const _maxImages = 10;
  static const _maxTags = 10;
  static const _thousandsSep = kAppDefaultThousandsSeparator;

  late final TextEditingController _codeCtrl;
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '0');
  final _priceCtrl = TextEditingController(text: '0');
  final _descCtrl = TextEditingController();
  final _tagInputCtrl = TextEditingController();

  final List<String> _images = [];
  final List<String> _tags = [];
  final List<String> _tagSuggestions = [];

  Timer? _suggestDebounce;
  bool _saving = false;
  bool _imageBusy = false;
  bool _suggestLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    if (p != null) {
      _codeCtrl = TextEditingController(text: p.code);
      _nameCtrl.text = p.name;
      _qtyCtrl.text = formatIntegerWithSeparator(p.quantity, _thousandsSep);
      _priceCtrl.text = formatIntegerWithSeparator(p.sellingPrice, _thousandsSep);
      _descCtrl.text = p.description;
      _images.addAll(List<String>.from(p.images));
      _tags.addAll(p.tags.map((t) => t.name));
    } else {
      _codeCtrl = TextEditingController(text: widget.suggestedCode ?? '');
    }
    _tagInputCtrl.addListener(_onTagInputChanged);
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _tagInputCtrl.removeListener(_onTagInputChanged);
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _tagInputCtrl.dispose();
    super.dispose();
  }

  void _onTagInputChanged() {
    setState(() {});
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(const Duration(milliseconds: 280), _fetchSuggest);
  }

  Future<void> _fetchSuggest() async {
    if (!mounted) return;
    final q = _tagInputCtrl.text.trim();
    setState(() => _suggestLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.api.get<Map<String, dynamic>>(
        '/admin/tags/suggest',
        queryParameters: {
          if (q.isNotEmpty) 'q': q,
          'limit': 12,
        },
      );
      final items = (res.data?['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((m) => (m['name'] as String?) ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _tagSuggestions
          ..clear()
          ..addAll(items);
        _suggestLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _suggestLoading = false);
    }
  }

  bool _hasTag(String name) {
    final n = name.trim().toLowerCase();
    return _tags.any((t) => t.toLowerCase() == n);
  }

  void _addTag(String name, {AppLocalizations? l10n}) {
    final v = name.trim();
    if (v.isEmpty) return;
    if (_hasTag(v)) {
      _tagInputCtrl.clear();
      return;
    }
    if (_tags.length >= _maxTags) {
      if (l10n != null && mounted) {
        AppMessenger.showSnackBar(context, 
          SnackBar(content: Text(l10n.productsTagsMax)),
        );
      }
      return;
    }
    setState(() {
      _tags.add(v);
      _tagInputCtrl.clear();
    });
  }

  void _removeTag(String name) {
    setState(() => _tags.removeWhere((t) => t == name));
  }

  void _removeImage(int i) {
    setState(() => _images.removeAt(i));
  }

  Future<void> _pickFromSource(ImageSource src, AppLocalizations l10n) async {
    if (_images.length >= _maxImages) {
      if (mounted) {
        AppMessenger.showSnackBar(context, SnackBar(content: Text(l10n.productsImagesMax)));
      }
      return;
    }
    final picker = ImagePicker();
    try {
      setState(() => _imageBusy = true);
      final x = await picker.pickImage(source: src);
      if (x == null) {
        if (mounted) setState(() => _imageBusy = false);
        return;
      }
      final imageUrl = await uploadProductImageFromPath(
        x.path,
        context.read<AuthProvider>().api,
      );
      if (!mounted) return;
      if (imageUrl == null) {
        setState(() => _imageBusy = false);
        AppMessenger.showSnackBar(context, 
          SnackBar(content: Text(l10n.productsImagePickFailed)),
        );
        return;
      }
      setState(() {
        _images.add(imageUrl);
        _imageBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _imageBusy = false);
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text('${l10n.productsImagePickFailed} ($e)')),
      );
    }
  }

  Future<void> _addImageFromUrl(AppLocalizations l10n) async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.productsImageUrlPasteTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.productsImageUrlPasteHint),
          maxLength: 3500000,
          maxLines: 1,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;
    final ok = url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('data:image');
    if (!ok) {
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(l10n.productsImageInvalidUrl)),
      );
      return;
    }
    if (_images.length >= _maxImages) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(l10n.productsImagesMax)));
      return;
    }
    setState(() => _images.add(url));
  }

  Future<void> _showImageSourceSheet(AppLocalizations l10n) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.productsImageFromCamera),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromSource(ImageSource.camera, l10n);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.productsImageFromGallery),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromSource(ImageSource.gallery, l10n);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: Text(l10n.productsImageFromUrl),
              onTap: () {
                Navigator.pop(ctx);
                _addImageFromUrl(l10n);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(AppLocalizations l10n) async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final qty = parseIntegerLoose(_qtyCtrl.text, _thousandsSep) ?? 0;
    final sellingPrice = parseIntegerLoose(_priceCtrl.text, _thousandsSep) ?? 0;
    final pendingTag = _tagInputCtrl.text.trim();
    if (pendingTag.isNotEmpty && !_hasTag(pendingTag) && _tags.length < _maxTags) {
      _tags.add(pendingTag);
      _tagInputCtrl.clear();
    }
    if (code.isEmpty || name.isEmpty) {
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(l10n.productsFillRequired)),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      final body = <String, dynamic>{
        if (!widget._isEdit) 'code': code,
        'name': name,
        'description': _descCtrl.text.trim(),
        'quantity': qty,
        'sellingPrice': sellingPrice,
        if (_images.isNotEmpty) 'images': List<String>.from(_images),
        'tags': _tags,
      };
      if (widget._isEdit) {
        await auth.api.patch<Map<String, dynamic>>(
          '/admin/products/${widget.productToEdit!.id}',
          data: body,
        );
      } else {
        final data = Map<String, dynamic>.from(body);
        if (_tags.isEmpty) {
          data.remove('tags');
        }
        await auth.api.post<Map<String, dynamic>>(
          '/admin/products',
          data: data,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      var msg =
          widget._isEdit ? l10n.productsEditFailed : l10n.productsCreateFailed;
      final d = e.response?.data;
      if (d is Map && d['message'] != null) {
        final m = d['message'];
        if (m is String) {
          msg = m;
        } else if (m is List && m.isNotEmpty) {
          msg = m.first.toString();
        }
      }
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppMessenger.showSnackBar(context, SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget._isEdit ? l10n.productsEdit : l10n.productsCreate,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    readOnly: widget._isEdit,
                    enableInteractiveSelection: !widget._isEdit,
                    decoration: InputDecoration(
                      labelText: l10n.productsCode,
                      helperText:
                          widget._isEdit ? l10n.productsCodeReadOnly : null,
                      helperMaxLines: 2,
                      suffixIcon: widget._isEdit
                          ? const Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                              color: AppColors.onSurfaceVariant,
                            )
                          : null,
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _qtyCtrl,
                    decoration:
                        InputDecoration(labelText: l10n.productsQuantity),
                    keyboardType:
                        integerThousandsKeyboardType(_thousandsSep),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        integerThousandsInputAllowPattern(_thousandsSep),
                      ),
                      IntegerThousandsInputFormatter(
                        separatorKey: _thousandsSep,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              decoration: InputDecoration(
                labelText: l10n.productsSellingPrice,
                hintText: '0',
              ),
              keyboardType: integerThousandsKeyboardType(_thousandsSep),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  integerThousandsInputAllowPattern(_thousandsSep),
                ),
                IntegerThousandsInputFormatter(
                  separatorKey: _thousandsSep,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l10n.productsName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: l10n.productsDescription,
                alignLabelWithHint: true,
              ),
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            _buildImagesSection(l10n, theme),
            const SizedBox(height: 16),
            _buildTagsSection(l10n, theme),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : () => _save(l10n),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesSection(AppLocalizations l10n, ThemeData theme) {
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: AppColors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.productsImagesLabel, style: labelStyle)),
            Text(
              '${_images.length}/$_maxImages',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.productsImagesOptional,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: (_images.isEmpty ? 1 : 0) + _images.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final placeholderCount = _images.isEmpty ? 1 : 0;
              if (_images.isEmpty && i == 0) {
                return const _ProductImagePlaceholderTile();
              }
              final imgIndex = i - placeholderCount;
              if (imgIndex < _images.length) {
                return _ImageThumbTile(
                  url: _images[imgIndex],
                  tooltip: l10n.productsRemoveImageTooltip,
                  onRemove: () => _removeImage(imgIndex),
                );
              }
              final disabled = _images.length >= _maxImages || _imageBusy;
              return _AddImageTile(
                busy: _imageBusy,
                disabled: disabled,
                label: l10n.productsAddImage,
                onTap: disabled ? null : () => _showImageSourceSheet(l10n),
              );
            },
          ),
        ),
        if (_imageBusy)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(l10n.productsImageProcessing,
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTagsSection(AppLocalizations l10n, ThemeData theme) {
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: AppColors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final pending = _tagInputCtrl.text.trim();
    final filteredSuggest = _tagSuggestions
        .where((s) => !_hasTag(s))
        .take(20)
        .toList();
    final canCreatePending = pending.isNotEmpty &&
        !_hasTag(pending) &&
        !filteredSuggest.any((s) => s.toLowerCase() == pending.toLowerCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.productsTagsLabel, style: labelStyle)),
            Text(
              '${_tags.length}/$_maxTags',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _tags)
                  InputChip(
                    label: Text(t, style: const TextStyle(fontSize: 13)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onDeleted: () => _removeTag(t),
                  ),
              ],
            ),
          ),
        TextField(
          controller: _tagInputCtrl,
          decoration: InputDecoration(
            labelText: l10n.productsTagsLabel,
            hintText: l10n.productsTagsHint,
            suffixIcon: _suggestLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (pending.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.add_rounded),
                        tooltip: l10n.productsAddImage,
                        onPressed: () => _addTag(pending, l10n: l10n),
                      )
                    : null),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => _addTag(v, l10n: l10n),
          onChanged: (v) {
            if (v.endsWith(',') || v.endsWith('\n')) {
              _addTag(v.replaceAll(RegExp(r'[,\n]'), ''), l10n: l10n);
            }
          },
          maxLength: 64,
        ),
        if (canCreatePending)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.productsTagsCreateNew(pending)),
              onPressed: () => _addTag(pending, l10n: l10n),
            ),
          ),
        if (filteredSuggest.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            l10n.productsTagsSuggestionLabel,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in filteredSuggest)
                ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () => _addTag(s, l10n: l10n),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Thumbnail mặc định khi chưa có ảnh (cùng kích thước ô thêm ảnh).
class _ProductImagePlaceholderTile extends StatelessWidget {
  const _ProductImagePlaceholderTile();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: AppColors.primary.withValues(alpha: 0.08),
          child: Icon(
            Icons.inventory_2_outlined,
            size: 40,
            color: AppColors.primary.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _ImageThumbTile extends StatelessWidget {
  const _ImageThumbTile({
    required this.url,
    required this.tooltip,
    required this.onRemove,
  });

  final String url;
  final String tooltip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ProductImageUrl(
            url: url,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            baseUrl: ApiConfig.baseUrl,
          ),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: Material(
            color: Colors.black.withValues(alpha: 0.7),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Tooltip(
                message: tooltip,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({
    required this.busy,
    required this.disabled,
    required this.label,
    required this.onTap,
  });

  final bool busy;
  final bool disabled;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = disabled ? AppColors.outline : AppColors.primary;
    return SizedBox(
      width: 96,
      height: 96,
      child: Material(
        color: AppColors.primary.withValues(alpha: disabled ? 0.04 : 0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: DottedRoundedBorder(
            color: color,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  busy
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        )
                      : Icon(Icons.add_a_photo_outlined, color: color),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vẽ viền đứt nét bao quanh con. Dùng [CustomPaint] để khỏi thêm dependency.
class DottedRoundedBorder extends StatelessWidget {
  const DottedRoundedBorder({
    super.key,
    required this.color,
    required this.child,
    this.radius = 10,
    this.strokeWidth = 1.2,
    this.dashLength = 4,
    this.gapLength = 3,
  });

  final Color color;
  final Widget child;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        gapLength: gapLength,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, next.toDouble()),
          paint,
        );
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) {
    return old.color != color ||
        old.radius != radius ||
        old.strokeWidth != strokeWidth ||
        old.dashLength != dashLength ||
        old.gapLength != gapLength;
  }
}
