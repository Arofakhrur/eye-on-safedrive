import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PersonalInfoCard extends StatelessWidget {
  final String address;
  final String bloodType;
  final String origin;
  final String medicalNotes;

  const PersonalInfoCard({
    super.key,
    required this.address,
    required this.bloodType,
    required this.origin,
    required this.medicalNotes,
  });

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
        children: [
          _buildInfoRow(Icons.location_on_rounded, 'Address', address),
          const Divider(height: 24),
          _buildInfoRow(Icons.bloodtype_rounded, 'Blood Type', bloodType),
          const Divider(height: 24),
          _buildInfoRow(Icons.home_work_rounded, 'Origin', origin),
          if (medicalNotes.isNotEmpty) ...[
            const Divider(height: 24),
            _buildInfoRow(Icons.medical_information_rounded, 'Medical Notes', medicalNotes),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.black54, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: Colors.black38,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
