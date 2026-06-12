# TStore Design System (DMX-inspired)

Reference UX: Thợ Điện Máy Xanh (layout patterns only — no copied assets/logos).

## Color tokens

| Token | Hex | Usage |
|-------|-----|--------|
| `primary` | `#288AD6` | Chips, tabs, links, icons |
| `primaryDark` | `#0D2B57` | Primary CTA (Xác nhận) |
| `primaryTint` | `#E8F4FC` | Badges, selected chip fill |
| `accent` | `#FFC107` | Tab underline, bottom-nav indicator |
| `background` | `#F5F7FA` | Scaffold |
| `surface` | `#FFFFFF` | Cards |

Defined in `lib/core/constants/app_colors.dart`.

## Rules

1. Do not use `Color(0x...)` outside `app_colors.dart`.
2. Prefer `Theme.of(context).colorScheme` and `context.appUi` for spacing/shadows.
3. Use widgets under `lib/design_system/` for new UI.
4. Business status colors stay in `delivery_ui.dart` / `preparation_ui.dart`.

## Components

See `lib/design_system/design_system.dart` and debug gallery route `AppRoutes.designSystemGallery` (debug builds).

## Dropdowns (chip/badge aligned)

- `TsDropdownField` / `TsDropdownFieldNullable` — `lib/widgets/ui/ts_dropdown_field.dart`
- `TsStatusDropdownField` — status changes with badge tones in field and menu
- Decoration: `ts_dropdown_decorations.dart` (border/radius matches chips)

## Reference screenshots

Stored in project assets from DMX app samples (Activity, Profile, Address picker).
