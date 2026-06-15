import 'dart:convert';

import 'package:http/http.dart' as http;

class AdministrativeProvince {
  final String name;
  final int code;

  const AdministrativeProvince({
    required this.name,
    required this.code,
  });

  factory AdministrativeProvince.fromJson(Map<String, dynamic> json) {
    return AdministrativeProvince(
      name: json['name'] as String? ?? '',
      code: _asInt(json['code']) ?? 0,
    );
  }
}

class AdministrativeWard {
  final String name;
  final int code;

  const AdministrativeWard({
    required this.name,
    required this.code,
  });

  factory AdministrativeWard.fromJson(Map<String, dynamic> json) {
    return AdministrativeWard(
      name: json['name'] as String? ?? '',
      code: _asInt(json['code']) ?? 0,
    );
  }
}

class VietnamLocationService {
  static const fallbackProvinces = <AdministrativeProvince>[
    AdministrativeProvince(name: 'Thành phố Hà Nội', code: 1),
    AdministrativeProvince(name: 'Tỉnh Cao Bằng', code: 4),
    AdministrativeProvince(name: 'Tỉnh Tuyên Quang', code: 8),
    AdministrativeProvince(name: 'Tỉnh Điện Biên', code: 11),
    AdministrativeProvince(name: 'Tỉnh Lai Châu', code: 12),
    AdministrativeProvince(name: 'Tỉnh Sơn La', code: 14),
    AdministrativeProvince(name: 'Tỉnh Lào Cai', code: 15),
    AdministrativeProvince(name: 'Tỉnh Thái Nguyên', code: 19),
    AdministrativeProvince(name: 'Tỉnh Lạng Sơn', code: 20),
    AdministrativeProvince(name: 'Tỉnh Quảng Ninh', code: 22),
    AdministrativeProvince(name: 'Tỉnh Bắc Ninh', code: 24),
    AdministrativeProvince(name: 'Tỉnh Phú Thọ', code: 25),
    AdministrativeProvince(name: 'Thành phố Hải Phòng', code: 31),
    AdministrativeProvince(name: 'Tỉnh Hưng Yên', code: 33),
    AdministrativeProvince(name: 'Tỉnh Ninh Bình', code: 37),
    AdministrativeProvince(name: 'Tỉnh Thanh Hóa', code: 38),
    AdministrativeProvince(name: 'Tỉnh Nghệ An', code: 40),
    AdministrativeProvince(name: 'Tỉnh Hà Tĩnh', code: 42),
    AdministrativeProvince(name: 'Tỉnh Quảng Trị', code: 44),
    AdministrativeProvince(name: 'Thành phố Huế', code: 46),
    AdministrativeProvince(name: 'Thành phố Đà Nẵng', code: 48),
    AdministrativeProvince(name: 'Tỉnh Quảng Ngãi', code: 51),
    AdministrativeProvince(name: 'Tỉnh Gia Lai', code: 52),
    AdministrativeProvince(name: 'Tỉnh Khánh Hòa', code: 56),
    AdministrativeProvince(name: 'Tỉnh Đắk Lắk', code: 66),
    AdministrativeProvince(name: 'Tỉnh Lâm Đồng', code: 68),
    AdministrativeProvince(name: 'Tỉnh Đồng Nai', code: 75),
    AdministrativeProvince(name: 'Thành phố Hồ Chí Minh', code: 79),
    AdministrativeProvince(name: 'Tỉnh Tây Ninh', code: 80),
    AdministrativeProvince(name: 'Tỉnh Đồng Tháp', code: 82),
    AdministrativeProvince(name: 'Tỉnh Vĩnh Long', code: 86),
    AdministrativeProvince(name: 'Tỉnh An Giang', code: 91),
    AdministrativeProvince(name: 'Thành phố Cần Thơ', code: 92),
    AdministrativeProvince(name: 'Tỉnh Cà Mau', code: 96),
  ];

  final String baseUrl;
  final http.Client _client;

  VietnamLocationService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = (baseUrl ?? 'https://provinces.open-api.vn/api/v2')
            .replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  Future<List<AdministrativeProvince>> provinces() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/p/'));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallbackProvinces;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) return fallbackProvinces;

      final provinces = decoded
          .whereType<Map<String, dynamic>>()
          .map(AdministrativeProvince.fromJson)
          .where((province) => province.name.isNotEmpty && province.code > 0)
          .toList();

      return provinces.length == 34 ? provinces : fallbackProvinces;
    } catch (_) {
      return fallbackProvinces;
    }
  }

  Future<List<AdministrativeWard>> wards(int provinceCode) async {
    try {
      final response =
          await _client.get(Uri.parse('$baseUrl/p/$provinceCode?depth=2'));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return const [];

      final wardsJson = decoded['wards'];
      if (wardsJson is! List) return const [];

      return wardsJson
          .whereType<Map<String, dynamic>>()
          .map(AdministrativeWard.fromJson)
          .where((ward) => ward.name.isNotEmpty && ward.code > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static AdministrativeProvince? findProvinceByName(String? value) {
    final normalized = _normalizeLocationName(value);
    if (normalized == null) return null;

    for (final province in fallbackProvinces) {
      if (_normalizeLocationName(province.name) == normalized) {
        return province;
      }
    }

    return null;
  }

  static AdministrativeProvince? matchProvince(
    String? value,
    List<AdministrativeProvince> provinces,
  ) {
    final normalized = _normalizeLocationName(value);
    if (normalized == null) return null;

    for (final province in provinces) {
      if (_normalizeLocationName(province.name) == normalized) {
        return province;
      }
    }

    return findProvinceByName(value);
  }

  static String? normalizeProvinceName(String? value) {
    return findProvinceByName(value)?.name ?? _clean(value);
  }

  static String? _normalizeLocationName(String? value) {
    final cleaned = _clean(value);
    if (cleaned == null) return null;

    final lower = _foldVietnamese(cleaned)
        .replaceAll(RegExp(r'^(thanh pho|tp\.?|tinh)\s+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (lower == 'hcm' ||
        lower == 'tphcm' ||
        lower == 'tp hcm' ||
        lower == 'ho chi minh' ||
        lower == 'saigon' ||
        lower == 'sai gon') {
      return 'ho chi minh';
    }

    return lower;
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String _foldVietnamese(String value) {
  const source =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
      'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
  const target =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
      'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

  final buffer = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    final char = String.fromCharCode(codeUnit);
    final index = source.indexOf(char);
    buffer
        .write(index == -1 ? char.toLowerCase() : target[index].toLowerCase());
  }

  return buffer.toString();
}
