// lib/features/dashboard/presentation/widgets/stat_card.dart

import 'package:flutter/material.dart';

class StatCard extends StatefulWidget {
  const StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  Offset _mousePos = Offset.zero;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleHover(PointerEvent event, BoxConstraints constraints) {
    if (!mounted) return;
    setState(() {
      _isHovered = true;
      // Calculate normalized mouse position from -1.0 to 1.0
      final x = (event.localPosition.dx / constraints.maxWidth) * 2 - 1;
      final y = (event.localPosition.dy / constraints.maxHeight) * 2 - 1;
      _mousePos = Offset(x, y);
    });
    _animController.forward();
  }

  void _handleHoverExit(PointerEvent event) {
    if (!mounted) return;
    setState(() {
      _isHovered = false;
      _mousePos = Offset.zero;
    });
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate light background from color
    final bgColor = widget.color.withValues(alpha: isDark ? 0.15 : 0.12);
    // final iconBoxColor = widget.color.withValues(alpha: isDark ? 0.3 : 0.1); // Unused

    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          onEnter: (e) => _handleHover(e, constraints),
          onHover: (e) => _handleHover(e, constraints),
          onExit: _handleHoverExit,
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                // Apply 3D Perspective Tilt
                final tiltX = _mousePos.dy * 0.1;
                final tiltY = -_mousePos.dx * 0.1;

                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // perspective
                    ..rotateX(_isHovered ? tiltX : 0)
                    ..rotateY(_isHovered ? tiltY : 0),
                  alignment: FractionalOffset.center,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Card(
                elevation: _isHovered ? 12 : 4,
                shadowColor: widget.color.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: widget.color.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  height: 120, // Maintain a consistent height
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    gradient: LinearGradient(
                      colors: [
                        bgColor,
                        bgColor.withValues(alpha: isDark ? 0.05 : 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Diagonal Background Band (From Image)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _DiagonalPainter(
                              widget.color.withValues(alpha: 0.05)),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // LEFT: Icon and Label
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Icon Box
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? widget.color.withValues(alpha: 0.2)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: widget.color
                                              .withValues(alpha: 0.1),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      widget.icon,
                                      color: widget.color,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Label
                                  Text(
                                    widget.title.toUpperCase(),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // RIGHT: Value
                            // RIGHT: Value
                            TweenAnimationBuilder<int>(
                              duration: const Duration(seconds: 1),
                              tween: IntTween(
                                  begin: 0,
                                  end: int.tryParse(widget.value) ?? 0),
                              builder: (context, val, _) {
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    int.tryParse(widget.value) != null
                                        ? '$val'
                                        : widget.value,
                                    style: TextStyle(
                                      color: widget.color
                                          .withValues(alpha: 0.9),
                                      fontSize: 32,
                                      fontWeight: FontWeight.w600,
                                      height: 1,
                                      shadows: [
                                        Shadow(
                                          color: widget.color
                                              .withValues(alpha: 0.2),
                                          offset: const Offset(2, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DiagonalPainter extends CustomPainter {
  final Color color;
  _DiagonalPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.4
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.3, 0)
      ..lineTo(size.width * 0.7, 0)
      ..lineTo(size.width, size.height * 0.7)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.7, size.height)
      ..lineTo(0, size.height * 0.3)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
