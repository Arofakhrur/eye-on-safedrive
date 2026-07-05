import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/constants/app_constants.dart';

// ── Driving Guide Card ──
class DrivingGuideCard extends StatelessWidget {
  const DrivingGuideCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Ready to drive?',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'PANDUAN SEBELUM BERKENDARA',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _guideItem('1', 'Helm SNI', 'Gunakan helm standar Nasional Indonesia.'),
          _guideItem('2', 'Sistem Rem', 'Tes fungsi rem depan dan belakang.'),
          _guideItem('3', 'Lampu & Sein', 'Pastikan semua lampu berfungsi.'),
          _guideItem('4', 'Tekanan Ban', 'Cek tekanan ban depan dan belakang.'),
          _guideItem('5', 'SIM & STNK', 'Pastikan dokumen berkendara terbawa.'),
          const SizedBox(height: 16),
          Text(
            'HATI-HATI DIJALAN',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'TEXT AFIRMASI TAMBAHAN',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideItem(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number.',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: description,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Interactive Swipe Button ──
class InteractiveSwipeButton extends StatefulWidget {
  final VoidCallback onStarted;
  final String label;
  const InteractiveSwipeButton({
    super.key,
    required this.onStarted,
    this.label = 'GESER KE ATAS UNTUK MEMULAI',
  });

  @override
  State<InteractiveSwipeButton> createState() => _InteractiveSwipeButtonState();
}

class _InteractiveSwipeButtonState extends State<InteractiveSwipeButton> {
  double _dragOffset = 0.0;
  static const double _maxDrag = 120.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onVerticalDragUpdate: (details) {
            setState(() {
              _dragOffset -= details.delta.dy;
              if (_dragOffset < 0) _dragOffset = 0;
              if (_dragOffset > _maxDrag) _dragOffset = _maxDrag;
            });
          },
          onVerticalDragEnd: (details) {
            if (_dragOffset >= _maxDrag * 0.8) {
              widget.onStarted();
            } else {
              setState(() {
                _dragOffset = 0;
              });
            }
          },
          child: Container(
            width: 80,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  top: 24,
                  child: Opacity(
                    opacity: 1.0 - (_dragOffset / _maxDrag),
                    child: Column(
                      children: const [
                        Icon(Icons.expand_less_rounded, color: Colors.white54, size: 32),
                        Icon(Icons.expand_less_rounded, color: Colors.white24, size: 28),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10 + _dragOffset,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.navigation_rounded, color: Colors.black, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.0,
          ),
        ),
      ],
    );
  }
}

// ── Blinking Overlay ──
class BlinkingOverlay extends StatefulWidget {
  final Widget child;
  const BlinkingOverlay({super.key, required this.child});
  @override
  State<BlinkingOverlay> createState() => _BlinkingOverlayState();
}

class _BlinkingOverlayState extends State<BlinkingOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          color: Colors.red.withValues(alpha: 0.6 + (_controller.value * 0.4)),
          child: widget.child,
        );
      },
    );
  }
}

// ── Blinking Warning Lamp ──
class BlinkingWarningLamp extends StatefulWidget {
  const BlinkingWarningLamp({super.key});
  @override
  State<BlinkingWarningLamp> createState() => _BlinkingWarningLampState();
}

class _BlinkingWarningLampState extends State<BlinkingWarningLamp> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 350)
    )..repeat(reverse: true);
    
    _colorAnimation = ColorTween(
      begin: Colors.grey.shade400, 
      end: Colors.red,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _colorAnimation.value?.withValues(alpha: 0.15),
          ),
          child: Icon(
            Icons.error_rounded, // Using error_rounded (circle with '!') as siren lamp
            color: _colorAnimation.value,
            size: 80,
          ),
        );
      },
    );
  }
}

// ── Stop Button ──
class MonitoringStopButton extends StatelessWidget {
  const MonitoringStopButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 8),
          Text(
            'STOP RIDE',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ── Screen Toggle Button ──
class ScreenToggleButton extends StatelessWidget {
  final bool isFull;
  final VoidCallback onTap;

  const ScreenToggleButton({super.key, required this.isFull, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isFull ? 'COLLAPSE SCREEN' : 'VIEW FULL SCREEN',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isFull ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ── No Face Warning Overlay ──
class NoFaceWarningOverlay extends StatelessWidget {
  const NoFaceWarningOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade800.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.face_retouching_off, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Wajah tidak terdeteksi',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Circular Reveal Clipper ──
class CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  CircularRevealClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant CircularRevealClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}

// ── Alert Overlays ──
class AlertOverlay extends StatelessWidget {
  final double currentMagnitude;
  final VoidCallback onResetAccident;
  final VoidCallback onCallEmergency;

  const AlertOverlay({
    super.key,
    required this.currentMagnitude,
    required this.onResetAccident,
    required this.onCallEmergency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BlinkingWarningLamp(),
              const SizedBox(height: 16),
              Text(
                'INSIDEN TERDETEKSI!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: Colors.red, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Text(
                'Sistem mendeteksi guncangan keras (${currentMagnitude.toStringAsFixed(1)} rad/s).\nSedang mengirim SOS ke kontak darurat...',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: Colors.black87, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Memproses rekaman video...',
                style: GoogleFonts.plusJakartaSans(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onResetAccident,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Saya Baik-Baik Saja (Matikan Alarm)',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCallEmergency,
                  icon: const Icon(Icons.call, color: Colors.white, size: 20),
                  label: Text(
                    'Hubungi Kontak Darurat',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Level1Overlay extends StatelessWidget {
  final VoidCallback onResume;

  const Level1Overlay({super.key, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.orange.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 80),
            const SizedBox(height: 16),
            Text(
              'PERHATIAN!\nAnda terdeteksi mengantuk',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 48),
            InteractiveSwipeButton(
              onStarted: onResume,
              label: 'SWIPE UP TO RESUME',
            ),
          ],
        ),
      ),
    );
  }
}

class Level2Overlay extends StatelessWidget {
  final VoidCallback onResume;

  const Level2Overlay({super.key, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return BlinkingOverlay(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dangerous_rounded, color: Colors.white, size: 100),
            const SizedBox(height: 16),
            Text(
              'BAHAYA!\nSegera Menepi!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            const SizedBox(height: 48),
            HoldToConfirmButton(
              onConfirm: onResume,
              label: 'TAHAN UNTUK LANJUT',
              duration: const Duration(milliseconds: 1500),
            ),
          ],
        ),
      ),
    );
  }
}

class Level3Overlay extends StatelessWidget {
  final bool canUnlock;
  final VoidCallback onResume;

  const Level3Overlay({
    super.key,
    required this.canUnlock,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.shade900.withValues(alpha: 0.95),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block_rounded, color: Colors.white, size: 100),
            const SizedBox(height: 16),
            Text(
              'SISTEM TERKUNCI\n(Level 3 Microsleep)',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            const SizedBox(height: 16),
            Text(
              'Menunggu ${DetectionConfig.level3LockdownSeconds} detik...\nSistem mendeteksi Anda terlalu sering mengantuk.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 48),
            if (canUnlock)
              HoldToConfirmButton(
                onConfirm: onResume,
                label: 'TAHAN UNTUK BUKA KUNCI',
                duration: const Duration(milliseconds: 2000),
                fillColor: Colors.white,
                textColor: Colors.red.shade900,
              )
            else
              const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class HoldToConfirmButton extends StatefulWidget {
  final VoidCallback onConfirm;
  final String label;
  final Duration duration;
  final Color outlineColor;
  final Color fillColor;
  final Color textColor;

  const HoldToConfirmButton({
    super.key,
    required this.onConfirm,
    required this.label,
    this.duration = const Duration(milliseconds: 1500),
    this.outlineColor = Colors.white,
    this.fillColor = Colors.white,
    this.textColor = Colors.black,
  });

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller.addListener(() {
      setState(() {});
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isConfirmed) {
        _isConfirmed = true;
        widget.onConfirm();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isConfirmed) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_isConfirmed) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (!_isConfirmed) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _controller.value;
    
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        decoration: BoxDecoration(
          color: Color.lerp(Colors.black54, widget.fillColor, progress),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: widget.outlineColor, width: 2),
        ),
        child: Text(
          widget.label,
          style: GoogleFonts.plusJakartaSans(
            color: Color.lerp(widget.outlineColor, widget.textColor, progress),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}



