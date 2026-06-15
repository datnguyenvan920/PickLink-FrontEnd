// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

class PickedAvatar {
  final String fileName;
  final Uint8List bytes;

  const PickedAvatar({
    required this.fileName,
    required this.bytes,
  });
}

Future<PickedAvatar?> pickAvatarFile() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  input.click();
  await input.onChange.first;

  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) return null;

  if (!file.type.startsWith('image/')) {
    throw const FormatException('Vui long chon dung file anh.');
  }

  if (file.size > 2 * 1024 * 1024) {
    throw const FormatException('Anh dai dien khong duoc vuot qua 2MB.');
  }

  final reader = html.FileReader();
  reader.readAsDataUrl(file);
  await reader.onLoad.first;

  final result = reader.result;
  if (result is String) {
    final commaIndex = result.indexOf(',');
    if (commaIndex != -1 && commaIndex < result.length - 1) {
      return PickedAvatar(
        fileName: file.name,
        bytes: base64Decode(result.substring(commaIndex + 1)),
      );
    }
  }

  throw const FormatException('Khong doc duoc file anh da chon.');
}
