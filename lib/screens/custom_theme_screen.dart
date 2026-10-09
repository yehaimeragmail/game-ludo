import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/artisan_parlor.dart';
import '../theme/parlor_themes.dart';

/// PRO: custom theme creator — pick board, felt, accent and player colors.
/// Live preview, persisted per color.
class CustomThemeScreen extends StatefulWidget {
  final ParlorAudio audio;
  final ParlorSettings settings;

  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  ParlorThemeDef get _t => ParlorThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  // Curated parlor-friendly palette choices.
  static const List<Color> palette = [
    Color(0xFF3B2416), Color(0xFF5C3A21), Color(0xFF241309),
    Color(0xFF4A1F14), Color(0xFF6E2F1C), Color(0xFF2B1009),
    Color(0xFF1C2438), Color(0xFF2C3A55), Color(0xFF101624),
    Color(0xFF2E3B22), Color(0xFF4A5A34), Color(0xFF1A2312),
    Color(0xFFC9A227), Color(0xFFE8CE7A), Color(0xFF8A6D1A),
    Color(0xFFB87333), Color(0xFFE09E5A), Color(0xFF7E4F22),
    Color(0xFFC0C6D4), Color(0xFFE8ECF5), Color(0xFF7E8698),
    Color(0xFFF5EFE0), Color(0xFFFAF6EE), Color(0xFF2E2118),
    Color(0xFF1E4D3B), Color(0xFF0F3D2E), Color(0xFF3D1F2E),
    Color(0xFFA31621), Color(0xFF1D4E9E), Color(0xFF1B7A4D),
    Color(0xFFD99A2B), Color(0xFF7D3C98), Color(0xFF229954),
    Color(0xFF2471A3), Color(0xFFC0392B), Color(0xFFE67E22),
    Color(0xFFEFE3C8), Color(0xFFE4D3A8), Color(0xFF8A6A42),
  ];

  static const rows = [
    ('Wood dark', 'woodDark'),
    ('Wood mid', 'woodMid'),
    ('Wood deep', 'woodDeep'),
    ('Accent metal', 'accent'),
    ('Accent light', 'accentLight'),
    ('Accent dark', 'accentDark'),
    ('Ivory text', 'ivory'),
    ('Felt', 'felt'),
    ('Track light', 'trackLight'),
    ('Track dark', 'trackDark'),
    ('Player 1', 'pc0'),
    ('Player 2', 'pc1'),
    ('Player 3', 'pc2'),
    ('Player 4', 'pc3'),
  ];

  Future<void> _pick(String key, String label) async {
    final s = widget.settings;
    final current = Color(s.customColors[key]!);
    final chosen = await showDialog<Color>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [
              _t.woodMid,
              _t.woodDeep,
            ]),
            border: Border.all(color: _t.accent, width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pick $label', style: Parlor.display(20, theme: _t)),
              const SizedBox(height: 14),
              SizedBox(
                width: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: palette.length,
                  itemBuilder: (_, i) {
                    final c = palette[i];
                    final selected = c.value == current.value;
                    return GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        Navigator.of(context).pop(c);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                            color: selected
                                ? _t.accentLight
                                : Colors.black.withValues(alpha: 0.4),
                            width: selected ? 3 : 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              WoodButton(
                label: 'Cancel',
                width: 160,
                fontSize: 15,
                theme: _t,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && mounted) {
      widget.audio.click();
      await s.setCustomColor(key, chosen.value);
      // Selecting a custom color auto-applies the custom theme.
      await s.setTheme('custom');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final preview = s.customTheme;
    return WoodBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title:
              Text('Theme Creator', style: Parlor.display(22, theme: t)),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () async {
                widget.audio.click();
                await s.resetCustomColors();
                if (mounted) setState(() {});
              },
              child:
                  Text('Reset', style: Parlor.label(13, theme: t)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Column(
                children: [
                  // Live preview strip.
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(colors: [
                        preview.woodMid,
                        preview.woodDeep,
                      ]),
                      border: Border.all(
                          color: preview.accent, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text('Live preview',
                            style: Parlor.label(13, theme: preview)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final c in preview.playerColors)
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c,
                                  border: Border.all(
                                      color: preview.accentLight,
                                      width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.5),
                                      offset: const Offset(0, 3),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 26,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: preview.felt,
                            border: Border.all(
                                color: preview.accent
                                    .withValues(alpha: 0.6)),
                          ),
                          alignment: Alignment.center,
                          child: Text('Felt sample',
                              style: Parlor.label(11, theme: preview)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final r in rows)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 5),
                      child: GestureDetector(
                        onTap: () => _pick(r.$2, r.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: t.woodDeep.withValues(alpha: 0.6),
                            border: Border.all(
                                color: t.accent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(
                                      s.customColors[r.$2]!),
                                  border: Border.all(
                                      color: t.accentLight,
                                      width: 1.5),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(r.$1,
                                    style:
                                        Parlor.body(15, theme: t)),
                              ),
                              Icon(Icons.palette,
                                  color: t.accentLight, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  WoodButton(
                    label: 'Use This Theme',
                    width: 260,
                    theme: t,
                    onTap: () async {
                      widget.audio.click();
                      await s.setTheme('custom');
                      if (mounted) Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
