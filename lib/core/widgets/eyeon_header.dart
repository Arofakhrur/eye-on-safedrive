import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EyeOnHeader extends StatelessWidget {
  const EyeOnHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Assuming there is an icon or just text.
            const Icon(Icons.remove_red_eye_rounded, size: 20, color: Colors.black87),
            const SizedBox(width: 8),
            Text(
              'EYE-ON! (아이온)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
