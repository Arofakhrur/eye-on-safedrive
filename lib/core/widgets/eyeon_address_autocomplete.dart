import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:eyeon/core/theme/app_theme.dart';

/// A reusable Autocomplete widget for selecting Indonesian cities.
/// Used for Address and Origin fields throughout the app.
class EyeonAddressAutocomplete extends StatelessWidget {
  final String initialValue;
  final String hintText;
  final IconData icon;
  final TextEditingController? externalController;
  final ValueChanged<String>? onSelected;

  const EyeonAddressAutocomplete({
    super.key,
    this.initialValue = '',
    this.hintText = 'Masukkan alamat...',
    this.icon = Icons.location_on_rounded,
    this.externalController,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initialValue),
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        
        try {
          final query = textEditingValue.text;
          final url = Uri.parse(
              'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=id');
          final response = await http.get(url, headers: {'User-Agent': 'EyeOnSafeDrive/1.0'});
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body) as List;
            return data.map((item) => item['display_name'].toString());
          }
        } catch (e) {
          debugPrint('Address autocomplete error: $e');
        }
        return const Iterable<String>.empty();
      },
      onSelected: (String selection) {
        externalController?.text = selection;
        onSelected?.call(selection);
      },
      fieldViewBuilder:
          (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.black45),
            hintText: hintText,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.black26,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade100),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        );
      },
    );
  }
}
