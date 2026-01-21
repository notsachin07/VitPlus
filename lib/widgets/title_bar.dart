import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 40,
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Text(
              'VitPlus',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const Expanded(child: SizedBox()),
            _WindowButton(
              icon: Icons.remove,
              onPressed: () => windowManager.minimize(),
              hoverColor: isDark ? Colors.white10 : Colors.black12,
            ),
            _WindowButton(
              icon: Icons.close,
              onPressed: () => windowManager.close(),
              hoverColor: AppTheme.errorRed,
              iconHoverColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color hoverColor;
  final Color? iconHoverColor;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    required this.hoverColor,
    this.iconHoverColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 40,
          color: _isHovered ? widget.hoverColor : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 18,
            color: _isHovered && widget.iconHoverColor != null
                ? widget.iconHoverColor
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }
}
