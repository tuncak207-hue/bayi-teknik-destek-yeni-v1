import 'package:flutter/material.dart';
import '../data/turkey_locations.dart';

/// İl seçilince ilçe listesi otomatik gelen, dinamik filtrelenen,
/// il değişince önceki ilçe seçimini otomatik temizleyen ortak bileşen.
/// Kullanıcı isteği: "İl seçilmeden ilçe seçilememeli. Kullanıcı ilçe
/// adını manuel yazmak zorunda kalmamalı."
class ProvinceDistrictPicker extends StatelessWidget {
  final String? province;
  final String? district;
  final ValueChanged<String?> onProvinceChanged;
  final ValueChanged<String?> onDistrictChanged;

  const ProvinceDistrictPicker({
    super.key,
    required this.province,
    required this.district,
    required this.onProvinceChanged,
    required this.onDistrictChanged,
  });

  @override
  Widget build(BuildContext context) {
    final districts = province != null ? (kTurkeyProvinceDistricts[province] ?? []) : <String>[];

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: province,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'İl', border: InputBorder.none, isDense: true),
            items: kTurkeyProvinceDistricts.keys
                .map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) {
              // İl değişince önceki ilçe seçimi otomatik temizlenir.
              onProvinceChanged(v);
              onDistrictChanged(null);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: district,
            isExpanded: true,
            // İl seçilmeden ilçe seçilemez.
            decoration: InputDecoration(labelText: 'İlçe', border: InputBorder.none, isDense: true, enabled: province != null),
            items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: province == null ? null : onDistrictChanged,
            hint: Text(province == null ? 'Önce il seçin' : 'Seçin', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ),
        ),
      ],
    );
  }
}
