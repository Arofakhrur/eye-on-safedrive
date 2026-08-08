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
  bool _isExpanded = false;
  double? _localEarThreshold;
  double? _localShockThreshold;

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

    final fileName =
        AppAssets.alarmSoundFiles[soundName] ?? AppAssets.alarmSound1;

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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: _isExpanded,
            onExpansionChanged: (expanded) {
              setState(() => _isExpanded = expanded);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            childrenPadding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16,
            ),
            leading: Icon(
              Icons.settings_suggest_rounded,
              color: AppColors.textPrimary.withValues(alpha: 0.87),
              size: 24,
            ),
            title: Text(
              'Pengaturan Deteksi',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary.withValues(alpha: 0.87),
              ),
            ),
            subtitle: Text(
              'Sesuaikan sensitivitas sensor keselamatan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textPrimary.withValues(alpha: 0.45),
              ),
            ),
            children: [
              SizedBox(height: 8),
              _buildSliderSection(
                'Sensitivitas Kantuk (EAR)',
                _localEarThreshold ?? widget.earThreshold,
                0.15,
                0.35,
                (val) => setState(() => _localEarThreshold = val),
                (val) => widget.onEarChanged(val),
                ['Sangat Sensitif', 'Normal', 'Kurang Sensitif'],
              ),
              const Divider(height: 24),
              _buildShockSliderSection(
                'Sensitivitas Guncangan',
                _localShockThreshold ?? widget.shockSensitivity,
                5.0,
                60.0,
                (val) => setState(() => _localShockThreshold = val),
                (val) => widget.onShockChanged(val),
              ),
              const Divider(height: 24),
              _buildSoundPicker(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderSection(
    String title,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    Function(double)? onChangeEnd,
    List<String> labels,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            valueIndicatorColor: AppColors.primary,
            valueIndicatorTextStyle: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            activeColor: AppColors.primary,
            inactiveColor: Colors.grey.shade200,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map(
                (l) => Text(
                  l,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: AppColors.textPrimary.withValues(alpha: 0.38),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildShockSliderSection(
    String title,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    Function(double)? onChangeEnd,
  ) {
    final clamped = value.clamp(min, max);

    // Determine sensitivity level label based on position in range
    final String levelLabel;
    final double range = max - min;
    final double fraction = (clamped - min) / range;
    if (fraction < 0.25) {
      levelLabel = 'Sangat Sensitif';
    } else if (fraction < 0.55) {
      levelLabel = 'Normal';
    } else {
      levelLabel = 'Kurang Sensitif';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${clamped.toStringAsFixed(0)} m/s²',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    levelLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            valueIndicatorColor: AppColors.primary,
            valueIndicatorTextStyle: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Slider(
            value: clamped,
            min: min,
            max: max,
            divisions: 11, // 5, 10, 15 ... 60
            label: '${clamped.toStringAsFixed(0)} m/s²',
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            activeColor: AppColors.primary,
            inactiveColor: Colors.grey.shade200,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '← Sangat Sensitif',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: Colors.green.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Kurang Sensitif →',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Nilai rendah = trigger pada guncangan lebih kecil. Nilai tinggi = hanya trigger pada benturan keras.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: AppColors.textPrimary.withValues(alpha: 0.38),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildSoundPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suara Peringatan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            for (int i = 0; i < AppAssets.alarmSoundFiles.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSoundItem(
                        AppAssets.alarmSoundFiles.keys.elementAt(i),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: i + 1 < AppAssets.alarmSoundFiles.length
                          ? _buildSoundItem(
                              AppAssets.alarmSoundFiles.keys.elementAt(i + 1),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSoundItem(String sound) {
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              size: 16,
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              sound,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
