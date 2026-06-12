import 'package:flutter/material.dart';

import 'package:provider/provider.dart';



import 'package:tstore/core/localization/app_localizations.dart';

import 'package:tstore/providers/auth_provider.dart';

import 'package:tstore/widgets/ui/status_badge.dart';

import 'package:tstore/widgets/ui/ts_dropdown_field.dart';



/// Sentinel: đưa lên bảng chung.

const kAssignTargetBoard = '__board__';



/// Sentinel: giao trực tiếp, chưa chọn người.

const kAssignTargetUnassigned = '__unassigned__';



/// Kết quả map sang API (`isPublicBoard`, `assignedUserId`).

class AssignTargetApiPayload {

  const AssignTargetApiPayload({

    required this.isPublicBoard,

    this.assignedUserId,

  });



  final bool isPublicBoard;

  final String? assignedUserId;



  static AssignTargetApiPayload fromTargetValue(String? value) {

    if (value == null || value == kAssignTargetBoard) {

      return const AssignTargetApiPayload(isPublicBoard: true);

    }

    if (value == kAssignTargetUnassigned) {

      return const AssignTargetApiPayload(isPublicBoard: false);

    }

    return AssignTargetApiPayload(

      isPublicBoard: false,

      assignedUserId: value,

    );

  }

}



String assignTargetUserLabel(

  String name,

  String userId,

  String? currentUserId,

  AppLocalizations l10n,

) {

  final base = name.trim().isEmpty ? userId : name.trim();

  if (currentUserId != null && userId == currentUserId) {

    return '$base ${l10n.assignTargetMeSuffix}';

  }

  return base;

}



/// Dropdown «Giao cho:» — bảng chung / nhân viên (tùy chọn chưa gán).

class AssignTargetDropdown extends StatelessWidget {

  const AssignTargetDropdown({

    super.key,

    required this.value,

    required this.users,

    required this.onChanged,

    this.loading = false,

    this.enabled = true,

    this.showUnassigned = false,

  });



  final String value;

  final List<(String id, String name)> users;

  final ValueChanged<String> onChanged;

  final bool loading;

  final bool enabled;

  final bool showUnassigned;



  @override

  Widget build(BuildContext context) {

    final l10n = AppLocalizations.of(context);

    final currentUserId = context.read<AuthProvider>().user?.id;



    if (loading) {
      return tsDropdownWithSectionLabel(
        context,
        sectionLabel: l10n.assignTargetLabel,
        dropdown: const LinearProgressIndicator(),
      );
    }



    String effectiveValue;

    if (value == kAssignTargetBoard) {

      effectiveValue = kAssignTargetBoard;

    } else if (value == kAssignTargetUnassigned) {

      if (showUnassigned) {

        effectiveValue = kAssignTargetUnassigned;

      } else if (currentUserId != null &&

          users.any((u) => u.$1 == currentUserId)) {

        effectiveValue = currentUserId;

      } else {

        effectiveValue = kAssignTargetBoard;

      }

    } else if (users.any((u) => u.$1 == value)) {

      effectiveValue = value;

    } else {

      effectiveValue = kAssignTargetBoard;

    }



    final items = <String>[

      kAssignTargetBoard,

      if (showUnassigned) kAssignTargetUnassigned,

      ...users.map((u) => u.$1),

    ];



    String labelFor(String v) {

      if (v == kAssignTargetBoard) return l10n.fulfillmentScopeBoard;

      if (v == kAssignTargetUnassigned) return l10n.deliveryAssignUnassigned;

      final u = users.firstWhere((e) => e.$1 == v);

      return assignTargetUserLabel(u.$2, u.$1, currentUserId, l10n);

    }



    return TsDropdownField<String>(

      value: effectiveValue,

      items: items,

      itemLabel: labelFor,

      labelText: l10n.assignTargetLabel,

      enabled: enabled,

      onChanged: (v) {

        if (v != null) onChanged(v);

      },

    );

  }

}



/// Dialog chọn «Giao cho:» — dùng khi tạo phiếu CB từ chi tiết đơn.

Future<AssignTargetApiPayload?> showAssignTargetPicker(

  BuildContext context, {

  String initial = kAssignTargetBoard,

  bool showUnassigned = false,

  String? title,

}) async {

  final l10n = AppLocalizations.of(context);

  var target = initial;

  var users = <(String id, String name)>[];

  var loading = true;



  final result = await showDialog<AssignTargetApiPayload>(

    context: context,

    builder: (dialogCtx) => StatefulBuilder(

      builder: (dialogCtx, setLocal) {

        if (loading) {

          WidgetsBinding.instance.addPostFrameCallback((_) async {

            try {

              final api = dialogCtx.read<AuthProvider>().api;

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

                  if (id != null && active) {

                    list.add((id, name.isEmpty ? id : name));

                  }

                }

              }

              if (dialogCtx.mounted) {

                setLocal(() {

                  users = list;

                  loading = false;

                });

              }

            } catch (_) {

              if (dialogCtx.mounted) {

                setLocal(() => loading = false);

              }

            }

          });

        }

        return AlertDialog(

          title: Text(title ?? l10n.saleOrderCreatePreparation),

          content: AssignTargetDropdown(

            value: target,

            users: users,

            loading: loading,

            showUnassigned: showUnassigned,

            onChanged: (v) => setLocal(() => target = v),

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(dialogCtx),

              child: Text(l10n.cancel),

            ),

            FilledButton(

              onPressed: loading

                  ? null

                  : () => Navigator.pop(

                        dialogCtx,

                        AssignTargetApiPayload.fromTargetValue(target),

                      ),

              child: Text(l10n.ok),

            ),

          ],

        );

      },

    ),

  );

  return result;

}

