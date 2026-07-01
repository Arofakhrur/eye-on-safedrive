import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:eyeon/core/constants/app_constants.dart';

import 'package:eyeon/core/theme/app_theme.dart';

class DetectionSettingsCard extends StatefulWidget {
  final double earThreshold;
  final double shockSensitivity;
  final String alarmSound;
  final Function(double) onEarChanged;
  final Function(double) onShockChanged;
  final Function(String) onSoundChanged;

  const DetectionSettingsCard({
    super.key,
    required this.earThreshold,
    required this.shockSensitivity,
    required this.alarmSound,
    required this.onEarChanged,
    required this.onShockChanged,
    required this.onSoundChanged,
  });

  @override
  State<DetectionSettingsCard> createState() => _DetectionSettingsCardState();
}

class _DetectionSettingsCardState extends State<DetectionSettingsCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingSound;
  Timer? _stopTimer;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        _stopPreview();
      }
    });
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _previewSound(String soundName) async {
    if (_playingSound == soundName) {
      await _stopPreview();
      return;
    }

    await _stopPreview();

    final fileName = AppAssets.alarmSoundFiles[soundName] ?? AppAssets.alarmSound1;

    try {
      setState(() => _playingSound = soundName);
      await _audioPlayer.play(AssetSource(fileName));
      
      _stopTimer = Timer(const Duration(seconds: 3), () {
        _stopPreview();
      });
    } catch (e) {
      debugPrint('Error playing sound preview: $e');
      if (mounted) setState(() => _playingSound = null);
    }
  }

  Future<void> _stopPreview() async {
    _stopTimer?.cancel();
    await _audioPlayer.stop();
    if (mounted && _playingSound != null) {
      setState(() => _playingSound = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSliderSection(
            'Sensitivitas Microsleep (EAR)',
            widget.earThreshold,
            0.15,
            0.35,
            widget.onEarChanged,
            ['Sangat Sensitif', 'Normal', 'Kurang Sensitif'],
          ),
          const Divider(height: 32),
          _buildSliderSection(
            'Sensitivitas Guncangan',
            widget.shockSensitivity,
            10.0,
            50.0,
            widget.onShockChanged,
            ['Rendah', 'Normal', 'Tinggi'],
          ),
          const Divider(height: 32),
          _buildSoundPicker(),
        ],
      ),
    );
  }

  Widget _buildSliderSection(String title, double value, double min, double max, Function(double) onChanged, List<String> labels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          inactiveColor: Colors.grey.shade200,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels.map((l) => Text(l, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.black38))).toList(),
        ),
      ],
    );
  }

  Widget _buildSoundPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Suara Alarm', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppAssets.alarmSoundFiles.keys.map((sound) {
            final isSelected = widget.alarmSound == sound;
            final isPlaying = _playingSound == sound;
            
            return InkWell(
              onTap: () {
                widget.onSoundChanged(sound);
                _previewSound(sound);
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      size: 16,
                      color: isSelected ? Colors.black : Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sound,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.black : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
