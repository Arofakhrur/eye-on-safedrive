import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/theme/app_theme.dart';

/// A data class holding both display name and coordinates from Nominatim.
class _NominatimPlace {
  final String displayName;
  final String shortName;
  final double lat;
  final double lon;

  const _NominatimPlace({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lon,
  });

  @override
  String toString() => displayName;
}

class DestinationSearchSheet extends StatefulWidget {
  final Function(LatLng destination, String addressName) onSelected;

  const DestinationSearchSheet({super.key, required this.onSelected});

  static Future<void> show(
    BuildContext context, {
    required Function(LatLng destination, String addressName) onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DestinationSearchSheet(onSelected: onSelected),
      ),
    );
  }

  @override
  State<DestinationSearchSheet> createState() => _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<DestinationSearchSheet> {
  List<_NominatimPlace> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;
  String _currentQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<List<_NominatimPlace>> _fetchSuggestions(String query) async {
    if (query.isEmpty) return [];

    try {
      final url = Uri.parse(AppUrls.nominatimSearchUrl(query));
      final response = await http.get(url, headers: {
        'User-Agent': 'EyeOnSafeDrive/1.0',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.map((item) {
          final fullName = item['display_name']?.toString() ?? 'Unknown';
          final parts = fullName.split(',');
          final short = parts.isNotEmpty ? parts[0].trim() : fullName;
          return _NominatimPlace(
            displayName: fullName,
            shortName: short,
            lat: double.tryParse(item['lat']?.toString() ?? '0') ?? 0,
            lon: double.tryParse(item['lon']?.toString() ?? '0') ?? 0,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Nominatim search error: $e');
    }
    return [];
  }

  void _onSearchChanged(String query) {
    _currentQuery = query;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _fetchSuggestions(query);
      if (mounted && query == _currentQuery) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    });
  }

  void _onPlaceSelected(_NominatimPlace place) {
    Navigator.pop(context);
    widget.onSelected(
      LatLng(place.lat, place.lon),
      place.shortName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tentukan Tujuan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pilih destinasi Anda untuk pelacakan rute.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),

          // Search field
          TextField(
            autofocus: true,
            onChanged: _onSearchChanged,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Cari alamat, gedung, kota...',
              hintStyle: GoogleFonts.plusJakartaSans(color: Colors.black38),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.black54),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),

          // Results
          Expanded(
            child: _suggestions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentQuery.isEmpty
                              ? Icons.travel_explore_rounded
                              : Icons.search_off_rounded,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currentQuery.isEmpty
                              ? 'Mulai ketik tujuan Anda'
                              : (_isLoading ? 'Mencari...' : 'Tidak ditemukan hasil'),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black38,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.grey.shade100,
                    ),
                    itemBuilder: (context, index) {
                      final place = _suggestions[index];
                      return _buildPlaceTile(place);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceTile(_NominatimPlace place) {
    return InkWell(
      onTap: () => _onPlaceSelected(place),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.black87,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.shortName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.black45,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
