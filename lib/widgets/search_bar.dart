import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Rounded search field used on Home, Marketplace and Store.
class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    super.key,
    this.hintText = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onFilterTap,
    this.onClear,
    this.readOnly = false,
    this.onTap,
    this.autofocus = false,
    this.filterCount = 0,
    this.trailing,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterTap;
  final VoidCallback? onClear;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool autofocus;
  final int filterCount;
  final Widget? trailing;

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didUpdateWidget(AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field in sync when the screen clears the query externally.
    if (widget.onChanged != null && _controller.text.isNotEmpty) {
      // no-op: controlled by the parent
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            onTap: widget.onTap,
            onChanged: (v) {
              widget.onChanged?.call(v);
              setState(() {});
            },
            onSubmitted: widget.onSubmitted,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5),
            decoration: InputDecoration(
              hintText: widget.hintText,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
              prefixIcon: const Icon(Icons.search_rounded, size: 21),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 19),
                      onPressed: () {
                        _controller.clear();
                        widget.onClear?.call();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm + 4),
                borderSide: BorderSide(color: scheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm + 4),
                borderSide: BorderSide(color: scheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm + 4),
                borderSide: BorderSide(color: scheme.primary, width: 1.5),
              ),
            ),
          ),
        ),
        if (widget.onFilterTap != null) ...[
          Gap.w10,
          _FilterButton(onTap: widget.onFilterTap!, count: widget.filterCount),
        ],
        if (widget.trailing != null) ...[Gap.w10, widget.trailing!],
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onTap, required this.count});

  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = count > 0;

    return Material(
      color: active ? scheme.primary : scheme.surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusSm + 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 50,
          width: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusSm + 4),
            border: Border.all(color: active ? scheme.primary : scheme.outline),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 21,
                color: active ? Colors.white : scheme.onSurface,
              ),
              if (active)
                Positioned(
                  top: -2,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.error,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: scheme.surface, width: 1.4),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal, filterable chip row.
class AppChipRow extends StatelessWidget {
  const AppChipRow({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.onToggle,
    this.allLabel = 'All',
    this.showAll = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<String> items;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final String allLabel;
  final bool showAll;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedIds.isNotEmpty;

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: [
          if (showAll) ...[
            FilterChip(
              label: Text(allLabel),
              selected: !hasSelection,
              onSelected: (_) {},
              showCheckmark: false,
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: !hasSelection
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Gap.w8,
          ],
          for (final item in items) ...[
            FilterChip(
              label: Text(item),
              selected: selectedIds.contains(item),
              onSelected: (_) => onToggle(item),
              showCheckmark: false,
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selectedIds.contains(item)
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Gap.w8,
          ],
        ],
      ),
    );
  }
}
