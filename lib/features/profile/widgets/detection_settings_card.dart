import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';

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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _previewSound(String soundName) async {
    // Mapping display names to actual filenames in assets/sounds/
    String fileName = '';
    switch (soundName) {
      case 'Sound 1': fileName = 'sound 1.mp3'; break;
      case 'Sound 2': fileName = 'sound 2.mp3'; break;
      case 'Sound 3': fileName = 'sound 3.mp3'; break;
      case 'Sound 4': fileName = 'sound 4.mp3'; break;
      default: fileName = 'sound 1.mp3';
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint('Error playing sound preview: $e');
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
            0.5,
            2.0,
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
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: const Color(0xFFD7F454),
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
          children: ['Sound 1', 'Sound 2', 'Sound 3', 'Sound 4'].map((sound) {
            final isSelected = widget.alarmSound == sound;
            return InkWell(
              onTap: () {
                widget.onSoundChanged(sound);
                _previewSound(sound);
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFD7F454) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  sound,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.black54,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
