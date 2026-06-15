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
  throw UnsupportedError('Chọn ảnh từ máy chỉ hỗ trợ trên web trong bản này.');
}
