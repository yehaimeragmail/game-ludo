import 'package:flutter/material.dart';

/// Artisan Parlor — the Stitch-derived design system for Ludo.
/// Heirloom parlor luxury: dark walnut, brass, ivory, mother-of-pearl.
/// No neon, no cyberpunk, no generic Material look.
class Parlor {
  // Palette (from DESIGN.md)
  static const walnutDark = Color(0xFF3B2416);
  static const walnutMid = Color(0xFF5C3A21);
  static const walnutDeep = Color(0xFF241309);
  static const walnutLight = Color(0xFF7A5230);
  static const brass = Color(0xFFC9A227);
  static const brassLight = Color(0xFFE8CE7A);
  static const brassDark = Color(0xFF8A6D1A);
  static const ivory = Color(0xFFF5EFE0);
  static const ivoryDim = Color(0xFFD9CDAE);
  static const feltGreen = Color(0xFF1E4D3B);
  static const feltDark = Color(0xFF143526);
  static const ruby = Color(0xFFA31621);
  static const sapphire = Color(0xFF1D4E9E);
  static const emerald = Color(0xFF1B7A4D);
  static const amber = Color(0xFFD99A2B);
  static const shadow = Color(0xFF1A0F08);

  /// Player colors in seat order: Red, Blue, Green, Yellow.
  static const playerColors = [ruby, sapphire, emerald, amber];
  static const playerNames = ['Ruby', 'Sapphire', 'Emerald', 'Amber'];

  // Typography: carved serif for display, humanist sans for body.
  static const displayFont = 'serif';

  static TextStyle display(double size, {Color color = brassLight}) => TextStyle(
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.2,
        shadows: const [
          Shadow(color: shadow, offset: Offset(0, 2), blurRadius: 4),
        ],
      );

  static TextStyle body(double size, {Color color = ivory}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.35,
      );

  static TextStyle label(double size, {Color color = ivoryDim}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.8,
      );

  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: walnutDark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: brass,
        onPrimary: walnutDeep,
        secondary: brassLight,
        onSecondary: walnutDeep,
        surface: walnutMid,
        onSurface: ivory,
        error: ruby,
        onError: ivory,
      ),
      textTheme: TextTheme(
        displayLarge: display(34),
        displayMedium: display(26),
        titleLarge: display(22),
        bodyLarge: body(16),
        bodyMedium: body(14),
        labelLarge: label(14),
      ),
    );
  }
}

/// Subtle walnut wood-grain background with a warm vignette.
class WoodBackdrop extends StatelessWidget {
  final Widget child;
  const WoodBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Parlor.walnutDark),
      child: CustomPaint(
        painter: _WoodGrainPainter(),
        child: child,
      ),
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Warm vignette: darker at edges, warm center glow.
    final vignette = RadialGradient(
      center: const Alignment(0, -0.25),
      radius: 1.15,
      colors: [
        const Color(0xFF4A2E1B).withValues(alpha: 0.55),
        Parlor.walnutDark.withValues(alpha: 0.0),
        Parlor.shadow.withValues(alpha: 0.55),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = vignette.createShader(Offset.zero & size),
    );
    // Faint vertical grain streaks.
    final grain = Paint()
      ..color = Parlor.walnutDeep.withValues(alpha: 0.16)
      ..strokeWidth = 2.5;
    for (int i = 0; i < 14; i++) {
      final x = size.width * (i + 0.5) / 14;
      final wobble = (i % 3 - 1) * 8.0;
      canvas.drawLine(
        Offset(x + wobble, 0),
        Offset(x - wobble, size.height),
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A chunky wooden button with brass trim — looks physically pressable.
class WoodButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double width;
  final double fontSize;
  final bool brassTrim;

  const WoodButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 240,
    this.fontSize = 19,
    this.brassTrim = true,
  });

  @override
  State<WoodButton> createState() => _WoodButtonState();
}

class _WoodButtonState extends State<WoodButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 15),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? [Parlor.walnutLight, Parlor.walnutMid, Parlor.walnutDeep]
                : [const Color(0xFF4A3A2C), const Color(0xFF3A2C20)],
          ),
          border: widget.brassTrim
              ? Border.all(color: Parlor.brass, width: 2.5)
              : null,
          boxShadow: [
            // top bevel highlight
            BoxShadow(
              color: Parlor.brassLight.withValues(alpha: _pressed ? 0.05 : 0.22),
              offset: const Offset(0, -2),
              blurRadius: 2,
            ),
            // body shadow (shrinks when pressed)
            BoxShadow(
              color: Parlor.shadow.withValues(alpha: 0.75),
              offset: Offset(0, _pressed ? 2 : 6),
              blurRadius: _pressed ? 4 : 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: Parlor.display(widget.fontSize,
              color: enabled ? Parlor.ivory : Parlor.ivoryDim.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

/// An engraved brass plaque for titles.
class BrassPlaque extends StatelessWidget {
  final String title;
  final String? subtitle;
  const BrassPlaque({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Parlor.walnutDeep, Color(0xFF2E1A0E)],
        ),
        border: Border.all(color: Parlor.brass, width: 3),
        boxShadow: const [
          BoxShadow(color: Parlor.shadow, offset: Offset(0, 6), blurRadius: 12),
          BoxShadow(
              color: Color(0xFFE8CE7A),
              offset: Offset(0, -1),
              blurRadius: 1,
              spreadRadius: 0),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Parlor.display(30), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: Parlor.body(14, color: Parlor.ivoryDim),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// A brass lever toggle for settings.
class ParlorToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const ParlorToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 64,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: value ? Parlor.brassDark : Parlor.walnutDeep,
          border: Border.all(color: Parlor.brass, width: 2),
          boxShadow: const [
            BoxShadow(
                color: Parlor.shadow, offset: Offset(0, 3), blurRadius: 5),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Parlor.brassLight, Parlor.brass, Parlor.brassDark],
              ),
              boxShadow: const [
                BoxShadow(
                    color: Parlor.shadow,
                    offset: Offset(0, 2),
                    blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A wooden-bead volume slider on a brass rail.
class BeadSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const BeadSlider({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: Parlor.brass,
        inactiveTrackColor: Parlor.walnutDeep,
        thumbShape: const _BeadThumb(),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

class _BeadThumb extends SliderComponentShape {
  const _BeadThumb();
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(26, 26);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    canvas.drawCircle(
        center + const Offset(0, 2),
        12,
        Paint()..color = Parlor.shadow.withValues(alpha: 0.6));
    canvas.drawCircle(
        center,
        11,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            radius: 1.0,
            colors: [Parlor.brassLight, Parlor.brass, Parlor.brassDark],
          ).createShader(Rect.fromCircle(center: center, radius: 11)));
  }
}

/// Small helper: a labeled settings row.
class SettingRow extends StatelessWidget {
  final String label;
  final Widget control;
  const SettingRow({super.key, required this.label, required this.control});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: Parlor.walnutDeep.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Parlor.brass.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Parlor.body(16))),
          control,
        ],
      ),
    );
  }
}
