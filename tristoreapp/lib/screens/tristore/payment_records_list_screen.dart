import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/models/dashboard_payment_record.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/screens/tristore/dashboard_payment_section.dart';
import 'package:tstore/widgets/ui/branded_app_bar.dart';

class PaymentRecordsListScreen extends StatefulWidget {
  const PaymentRecordsListScreen({super.key});

  @override
  State<PaymentRecordsListScreen> createState() =>
      _PaymentRecordsListScreenState();
}

class _PaymentRecordsListScreenState extends State<PaymentRecordsListScreen> {
  final _items = <DashboardPaymentRecord>[];
  final _scroll = ScrollController();
  int _page = 1;
  int _total = 0;
  int _todayPending = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _err;

  static const _limit = 20;

  bool get _hasMore => _items.length < _total;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _err = null;
        _page = 1;
        _items.clear();
      });
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }

    final auth = context.read<AuthProvider>();
    final page = reset ? 1 : _page + 1;
    final res = await fetchDashboardPaymentRecords(
      auth,
      page: page,
      limit: _limit,
    );
    if (!mounted) return;
    if (res == null) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _err = 'Không tải được danh sách thanh toán.';
      });
      return;
    }
    setState(() {
      _page = page;
      _total = res.total;
      _todayPending = res.todayPendingCount;
      if (reset) {
        _items
          ..clear()
          ..addAll(res.items);
      } else {
        _items.addAll(res.items);
      }
      _loading = false;
      _loadingMore = false;
      _err = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final showManager = user?.role == 'admin' || user?.role == 'manager';

    return Scaffold(
      appBar: BrandedAppBar(
        title: const Text(
          'Thanh toán',
          style: TextStyle(
            color: AppColors.onPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.space3,
              AppSpacing.screenHorizontal,
              AppSpacing.space1,
            ),
            child: Text(
              'hôm nay: $_todayPending chưa duyệt · tổng $_total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _loading && _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : _err != null && _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(
                            AppSpacing.screenHorizontal,
                          ),
                          children: [
                            const SizedBox(height: 48),
                            Text(_err!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            Center(
                              child: FilledButton(
                                onPressed: () => _load(reset: true),
                                child: const Text('Thử lại'),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenHorizontal,
                            AppSpacing.space2,
                            AppSpacing.screenHorizontal,
                            AppSpacing.space6,
                          ),
                          itemCount: _items.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            if (i >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final item = _items[i];
                            return DashboardPaymentRecordTile(
                              item: item,
                              showManager: showManager,
                              dense: false,
                              onTap: () =>
                                  openPaymentRecordParent(context, item),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
