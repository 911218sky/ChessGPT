import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ControlSectionBand extends StatelessWidget {
  const ControlSectionBand({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class CollapsibleControlSectionBand extends StatefulWidget {
  const CollapsibleControlSectionBand({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<CollapsibleControlSectionBand> createState() =>
      _CollapsibleControlSectionBandState();
}

class _CollapsibleControlSectionBandState
    extends State<CollapsibleControlSectionBand> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    const collapsedHeaderPadding = EdgeInsets.fromLTRB(16, 14, 16, 14);
    const expandedHeaderPadding = EdgeInsets.fromLTRB(16, 16, 16, 14);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded = !_expanded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: _expanded
                  ? expandedHeaderPadding
                  : collapsedHeaderPadding,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: widget.child,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class InlineCollapsibleSection extends StatefulWidget {
  const InlineCollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<InlineCollapsibleSection> createState() =>
      _InlineCollapsibleSectionState();
}

class _InlineCollapsibleSectionState extends State<InlineCollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: Colors.white70),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _expanded ? widget.child : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class SquareIconAction extends StatelessWidget {
  const SquareIconAction({
    super.key,
    required this.icon,
    required this.active,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? AppColors.primary : Colors.white10,
              width: active ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            color: onTap == null ? Colors.white30 : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class ControlDataLine extends StatelessWidget {
  const ControlDataLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class SegmentedPicker<T> extends StatelessWidget {
  const SegmentedPicker({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T item) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ControlLabel(label),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < options.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(itemLabel(options[index])),
                  selected: options[index] == value,
                  onSelected: (_) => onChanged(options[index]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class LabeledDropdown<T> extends StatelessWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = itemLabel(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ControlLabel(label),
        const SizedBox(height: 8),
        PopupMenuButton<T>(
          tooltip: label,
          color: const Color(0xFF2B302F),
          elevation: 14,
          offset: const Offset(0, 58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          onSelected: onChanged,
          itemBuilder: (context) => [
            for (final item in items)
              PopupMenuItem<T>(
                value: item,
                child: Row(
                  children: [
                    Icon(
                      item == value
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: item == value ? AppColors.primary : Colors.white38,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        itemLabel(item),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 16,
                  color: Color(0x22000000),
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedLabel,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white60,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.obscureText = false,
    this.hintText,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool obscureText;
  final String? hintText;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ControlLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
          onChanged: readOnly ? null : onChanged,
          decoration: InputDecoration(helperText: hintText),
        ),
      ],
    );
  }
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: Colors.white70),
    );
  }
}
