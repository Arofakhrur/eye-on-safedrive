import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/constants/app_constants.dart';

/// A reusable Autocomplete widget for selecting Indonesian cities.
/// Sync dua arah: externalController selalu mencerminkan apa yang diketik
/// user, baik dari pilihan dropdown maupun ketikan manual.
class EyeonAddressAutocomplete extends StatefulWidget {
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
  State<EyeonAddressAutocomplete> createState() =>
      _EyeonAddressAutocompleteState();
}

class _EyeonAddressAutocompleteState extends State<EyeonAddressAutocomplete> {
  // Internal controller yang digunakan oleh Autocomplete widget
  late final TextEditingController _internalController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _internalController =
        TextEditingController(text: widget.initialValue);

    // Sync setiap perubahan ketikan ke externalController
    _internalController.addListener(_syncToExternal);

    // Jika externalController sudah punya nilai awal, set ke internal juga
    if (widget.externalController != null &&
        widget.externalController!.text.isNotEmpty &&
        _internalController.text.isEmpty) {
      _internalController.text = widget.externalController!.text;
    }
  }

  void _syncToExternal() {
    if (widget.externalController != null) {
      // Hanya update jika berbeda untuk menghindari loop tak terbatas
      if (widget.externalController!.text != _internalController.text) {
        widget.externalController!.text = _internalController.text;
      }
    }
  }

  @override
  void dispose() {
    _internalController.removeListener(_syncToExternal);
    _internalController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<Iterable<String>> _fetchSuggestions(String query) async {
    if (query.length < 3) return const [];
    try {
      final url = Uri.parse(AppUrls.nominatimSearchUrl(query));
      final response = await http
          .get(url, headers: {'User-Agent': AppUrls.userAgent})
          .timeout(AppDurations.nominatimTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.map((item) => item['display_name'].toString());
      }
    } catch (e) {
      debugPrint('Address autocomplete error: $e');
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.initialValue),
      optionsBuilder: (TextEditingValue textEditingValue) async {
        // Debounce: tunggu 400ms setelah user berhenti mengetik
        _debounce?.cancel();
        final completer = Completer<Iterable<String>>();
        _debounce = Timer(const Duration(milliseconds: 400), () async {
          final results = await _fetchSuggestions(textEditingValue.text);
          if (!completer.isCompleted) completer.complete(results);
        });
        return completer.future;
      },
      onSelected: (String selection) {
        // Update internal controller → listener akan sync ke external
        _internalController.text = selection;
        widget.onSelected?.call(selection);
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            shadowColor: Colors.black12,
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 250,
                maxWidth: MediaQuery.of(context).size.width - 48, // Padding Kiri-Kanan 24
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.grey.shade100,
                ),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_city_rounded,
                              size: 18, color: Colors.black38),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
        // Sync fieldController (milik Autocomplete) ke internalController
        // agar listener kita bisa menangkap setiap perubahan
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (fieldController.text != _internalController.text) {
            // Ini hanya terjadi saat widget pertama kali build
          }
        });

        // Override listener fieldController agar selalu sync ke internalController
        fieldController.addListener(() {
          if (_internalController.text != fieldController.text) {
            _internalController.text = fieldController.text;
          }
        });

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: fieldController,
            focusNode: focusNode,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(widget.icon, size: 20, color: Colors.black45),
              hintText: widget.hintText,
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.black26,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
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
          ),
        );
      },
    );
  }
}
