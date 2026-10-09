import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/artisan_parlor.dart';
import '../theme/parlor_themes.dart';

/// Settings — walnut drawer metaphor, theme-aware.
class SettingsScreen extends StatefulWidget {
  final ParlorAudio audio;
  final ParlorSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TipJar _tipJar = TipJar();

  ParlorThemeDef get _t => ParlorThemes.byId(widget.settings.themeId);

  @override
  void initState() {
    super.initState();
    _tipJar.init().then((_) {
      if (mounted) setState(() {});
    });
    _tipJar.lastThanks.addListener(_onThanks);
  }

  void _onThanks() {
    final msg = _tipJar.lastThanks.value;
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Parlor.body(15, theme: _t)),
        backgroundColor: _t.woodDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _tipJar.lastThanks.value = null;
  }

  @override
  void dispose() {
    _tipJar.lastThanks.removeListener(_onThanks);
    _tipJar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final audio = widget.audio;
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
              audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: Parlor.display(22, theme: t)),
          centerTitle: true,
        ),
        body: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Sound', t),
                SettingRow(
                  theme: t,
                  label: 'Music',
                  control: ParlorToggle(
                    theme: t,
                    value: s.musicOn,
                    onChanged: (v) async {
                      audio.click();
                      await s.setMusic(v);
                      audio.configure(
                          musicOn: s.musicOn,
                          sfxOn: s.sfxOn,
                          volume: s.volume);
                      if (v) {
                        audio.startMenuMusic();
                      } else {
                        audio.stopMusic();
                      }
                    },
                  ),
                ),
                SettingRow(
                  theme: t,
                  label: 'Sound effects',
                  control: ParlorToggle(
                    theme: t,
                    value: s.sfxOn,
                    onChanged: (v) async {
                      await s.setSfx(v);
                      audio.configure(
                          musicOn: s.musicOn,
                          sfxOn: s.sfxOn,
                          volume: s.volume);
                      if (v) audio.click();
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Text('Volume', style: Parlor.body(16, theme: t)),
                BeadSlider(
                  theme: t,
                  value: s.volume,
                  onChanged: (v) async {
                    await s.setVolume(v);
                    audio.configure(
                        musicOn: s.musicOn,
                        sfxOn: s.sfxOn,
                        volume: s.volume);
                  },
                ),
                const SizedBox(height: 10),
                _SectionTitle('Appearance', t),
                SettingRow(
                  theme: t,
                  label: 'Theme',
                  control: Text(
                    ParlorThemes.byId(s.themeId).name,
                    style: Parlor.label(14, theme: t),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final th in ParlorThemes.all)
                      GestureDetector(
                        onTap: () async {
                          audio.click();
                          await s.setTheme(th.id);
                        },
                        child: Container(
                          width: 64,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(colors: [
                              th.woodMid,
                              th.accent,
                            ]),
                            border: Border.all(
                              color: s.themeId == th.id
                                  ? th.accentLight
                                  : th.accent.withValues(alpha: 0.3),
                              width: s.themeId == th.id ? 3 : 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (int i = 0; i < 2; i++)
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 1.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: th.playerColors[i],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Token style', style: Parlor.body(16, theme: t)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0;
                        i < TokenShapes.names.length;
                        i++)
                      _MiniChip(
                        theme: t,
                        label: TokenShapes.names[i],
                        selected: s.tokenShape == i,
                        onTap: () async {
                          audio.click();
                          await s.setTokenShape(i);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Dice style', style: Parlor.body(16, theme: t)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0; i < DiceStyles.names.length; i++)
                      _MiniChip(
                        theme: t,
                        label: DiceStyles.names[i],
                        selected: s.diceStyle == i,
                        onTap: () async {
                          audio.click();
                          await s.setDiceStyle(i);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _SectionTitle('Support', t),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: t.woodDeep.withValues(alpha: 0.65),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Ludo is 100% free. Tips keep the parlor open!',
                        style: Parlor.body(14, theme: t),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      if (_tipJar.products.isEmpty)
                        Text(
                          _tipJar.error ?? 'Loading…',
                          style: Parlor.body(13,
                              theme: t,
                              color:
                                  t.ivory.withValues(alpha: 0.6)),
                        )
                      else
                        Wrap(
                          spacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final p in _tipJar.products)
                              _MiniChip(
                                theme: t,
                                label: p.id == TipJar.chocolateId
                                    ? '🍫 ${p.price}'
                                    : '☕ ${p.price}',
                                selected: false,
                                onTap: () {
                                  audio.click();
                                  _tipJar.buy(p);
                                },
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _SectionTitle('About', t),
                Text(
                  'Ludo — Artisan Parlor edition.\nVersion 2.0.0 • Made with ♥ by WAJIHA',
                  style: Parlor.body(13,
                      theme: t,
                      color: t.ivory.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final ParlorThemeDef theme;
  const _SectionTitle(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(text, style: Parlor.display(19, theme: theme)),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final ParlorThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MiniChip(
      {required this.theme,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? theme.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.3),
          border: Border.all(
            color: selected
                ? theme.accentLight
                : theme.accent.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: Parlor.label(13,
              theme: theme,
              color: selected ? theme.woodDeep : theme.ivory),
        ),
      ),
    );
  }
}
