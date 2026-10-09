import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/artisan_parlor.dart';

/// Settings — the walnut drawer: brass lever toggles, wooden-bead volume.
class SettingsScreen extends StatelessWidget {
  final ParlorAudio audio;
  final ParlorSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  Widget build(BuildContext context) {
    return WoodBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Parlor.brassLight),
          title: Text('Settings', style: Parlor.display(22)),
          centerTitle: true,
        ),
        body: AnimatedBuilder(
          animation: settings,
          builder: (_, _) => ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Parlor.feltDark.withValues(alpha: 0.55),
                  border: Border.all(
                      color: Parlor.brass.withValues(alpha: 0.5), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SOUND & MUSIC',
                        style: Parlor.label(13,
                            color: Parlor.brassLight)),
                    const SizedBox(height: 10),
                    SettingRow(
                      label: 'Music',
                      control: ParlorToggle(
                        value: settings.musicOn,
                        onChanged: (v) async {
                          await settings.setMusic(v);
                          audio.configure(
                            musicOn: v,
                            sfxOn: settings.sfxOn,
                            volume: settings.volume,
                          );
                          if (v) {
                            audio.startMenuMusic();
                          } else {
                            audio.stopMusic();
                          }
                        },
                      ),
                    ),
                    SettingRow(
                      label: 'Sound effects',
                      control: ParlorToggle(
                        value: settings.sfxOn,
                        onChanged: (v) async {
                          await settings.setSfx(v);
                          audio.configure(
                            musicOn: settings.musicOn,
                            sfxOn: v,
                            volume: settings.volume,
                          );
                          if (v) audio.click();
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Volume', style: Parlor.body(16)),
                    BeadSlider(
                      value: settings.volume,
                      onChanged: (v) async {
                        await settings.setVolume(v);
                        audio.configure(
                          musicOn: settings.musicOn,
                          sfxOn: settings.sfxOn,
                          volume: v,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Parlor.walnutDeep.withValues(alpha: 0.6),
                  border: Border.all(
                      color: Parlor.brass.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PARLOR RECORDS',
                        style: Parlor.label(13,
                            color: Parlor.brassLight)),
                    const SizedBox(height: 10),
                    _stat('Games played', '${settings.gamesPlayed}'),
                    _stat('Victories', '${settings.wins}'),
                    _stat(
                        'Best win',
                        settings.bestTurns > 0
                            ? '${settings.bestTurns} turns'
                            : '—'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Ludo  •  v1.0.0  •  crafted by Wajiha',
                style: Parlor.label(11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Parlor.body(15))),
          Text(value, style: Parlor.display(17)),
        ],
      ),
    );
  }
}
