import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api.dart';

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:5209',
);

class CommunityApi {
  final String baseUrl;
  final http.Client _client;

  CommunityApi({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? _apiBaseUrl).replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  Future<List<CommunityGroup>> groups({
    required String token,
    String? query,
  }) async {
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      params['query'] = query.trim();
    }

    final response = await _client.get(
      _uri('/api/community/groups', params),
      headers: _jsonHeaders(token),
    );

    return _decodeList(response).map(CommunityGroup.fromJson).toList();
  }

  Future<CommunityGroup> createGroup({
    required String token,
    required String groupName,
    String? description,
    required String groupType,
    String? coverImageUrl,
  }) async {
    final response = await _client.post(
      _uri('/api/community/groups'),
      headers: _jsonHeaders(token),
      body: jsonEncode({
        'groupName': groupName,
        'description': description,
        'groupType': groupType,
        'coverImageUrl': coverImageUrl,
      }),
    );

    return CommunityGroup.fromJson(_decodeObject(response));
  }

  Future<CommunityGroup> updateGroup({
    required String token,
    required int groupId,
    required String groupName,
    String? description,
    required String groupType,
    String? coverImageUrl,
  }) async {
    final response = await _client.put(
      _uri('/api/community/groups/$groupId'),
      headers: _jsonHeaders(token),
      body: jsonEncode({
        'groupName': groupName,
        'description': description,
        'groupType': groupType,
        'coverImageUrl': coverImageUrl,
      }),
    );

    return CommunityGroup.fromJson(_decodeObject(response));
  }

  Future<CommunityGroup> joinGroup({
    required String token,
    required int groupId,
  }) async {
    final response = await _client.post(
      _uri('/api/community/groups/$groupId/join'),
      headers: _jsonHeaders(token),
    );

    return CommunityGroup.fromJson(_decodeObject(response));
  }

  Future<CommunityGroup> leaveGroup({
    required String token,
    required int groupId,
  }) async {
    final response = await _client.post(
      _uri('/api/community/groups/$groupId/leave'),
      headers: _jsonHeaders(token),
    );

    return CommunityGroup.fromJson(_decodeObject(response));
  }

  Future<List<CommunityMember>> members({
    required String token,
    required int groupId,
  }) async {
    final response = await _client.get(
      _uri('/api/community/groups/$groupId/members'),
      headers: _jsonHeaders(token),
    );

    return _decodeList(response).map(CommunityMember.fromJson).toList();
  }

  Future<CommunityMember> approveMember({
    required String token,
    required int groupId,
    required int memberUserId,
  }) async {
    final response = await _client.post(
      _uri('/api/community/groups/$groupId/members/$memberUserId/approve'),
      headers: _jsonHeaders(token),
    );

    return CommunityMember.fromJson(_decodeObject(response));
  }

  Future<void> removeMember({
    required String token,
    required int groupId,
    required int memberUserId,
  }) async {
    final response = await _client.delete(
      _uri('/api/community/groups/$groupId/members/$memberUserId'),
      headers: _jsonHeaders(token),
    );
    _throwIfFailed(response);
  }

  Future<List<CommunityPost>> posts({
    required String token,
    required int groupId,
  }) async {
    final response = await _client.get(
      _uri('/api/community/groups/$groupId/posts'),
      headers: _jsonHeaders(token),
    );

    return _decodeList(response).map(CommunityPost.fromJson).toList();
  }

  Future<CommunityPost> createPost({
    required String token,
    required int groupId,
    required String content,
    List<String> mediaUrls = const [],
  }) async {
    final response = await _client.post(
      _uri('/api/community/groups/$groupId/posts'),
      headers: _jsonHeaders(token),
      body: jsonEncode({
        'content': content,
        'mediaUrls': mediaUrls,
      }),
    );

    return CommunityPost.fromJson(_decodeObject(response));
  }

  Future<CommunityPost> reactToPost({
    required String token,
    required int postId,
    String reactionType = 'Like',
  }) async {
    final response = await _client.post(
      _uri('/api/community/posts/$postId/reaction'),
      headers: _jsonHeaders(token),
      body: jsonEncode({'reactionType': reactionType}),
    );

    return CommunityPost.fromJson(_decodeObject(response));
  }

  Future<CommunityPost> removeReaction({
    required String token,
    required int postId,
  }) async {
    final response = await _client.delete(
      _uri('/api/community/posts/$postId/reaction'),
      headers: _jsonHeaders(token),
    );

    return CommunityPost.fromJson(_decodeObject(response));
  }

  Future<List<CommunityComment>> comments({
    required String token,
    required int postId,
  }) async {
    final response = await _client.get(
      _uri('/api/community/posts/$postId/comments'),
      headers: _jsonHeaders(token),
    );

    return _decodeList(response).map(CommunityComment.fromJson).toList();
  }

  Future<CommunityComment> createComment({
    required String token,
    required int postId,
    required String content,
    int? parentCommentId,
  }) async {
    final response = await _client.post(
      _uri('/api/community/posts/$postId/comments'),
      headers: _jsonHeaders(token),
      body: jsonEncode({
        'content': content,
        'parentCommentId': parentCommentId,
      }),
    );

    return CommunityComment.fromJson(_decodeObject(response));
  }

  Future<List<CommunityMessage>> messages({
    required String token,
    required int groupId,
  }) async {
    final response = await _client.get(
      _uri('/api/community/groups/$groupId/messages'),
      headers: _jsonHeaders(token),
    );

    return _decodeList(response).map(CommunityMessage.fromJson).toList();
  }

  Future<CommunityMessage> sendMessage({
    required String token,
    required int groupId,
    required String content,
  }) async {
    final response = await _client.post(
      _uri('/api/community/groups/$groupId/messages'),
      headers: _jsonHeaders(token),
      body: jsonEncode({'content': content}),
    );

    return CommunityMessage.fromJson(_decodeObject(response));
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final uri = Uri.parse('$baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: queryParameters);
  }

  Map<String, String> _jsonHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  List<Map<String, dynamic>> _decodeList(http.Response response) {
    _throwIfFailed(response);

    try {
      final decoded = response.body.isEmpty ? [] : jsonDecode(response.body);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {
      throw ApiException(
        'Server returned an invalid response.',
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      'Server returned an invalid response.',
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    _throwIfFailed(response);

    try {
      return response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Server returned an invalid response.',
        statusCode: response.statusCode,
      );
    }
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    Map<String, dynamic> body = const {};
    try {
      if (response.body.isNotEmpty) {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      body = const {};
    }

    throw ApiException(
      _extractMessage(body, response.statusCode),
      statusCode: response.statusCode,
    );
  }

  String _extractMessage(Map<String, dynamic> body, int statusCode) {
    final message = body['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    final detail = body['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail;
    }

    final title = body['title'];
    if (title is String && title.trim().isNotEmpty) {
      return title;
    }

    return 'Request failed with status code $statusCode.';
  }
}

class CommunityGroup {
  final int groupId;
  final String groupName;
  final String? description;
  final String groupType;
  final String? coverImageUrl;
  final DateTime? createdAt;
  final int ownerPlayerId;
  final String ownerName;
  final int memberCount;
  final String? myRole;
  final String? myStatus;
  final int postCount;
  final int messageCount;

  const CommunityGroup({
    required this.groupId,
    required this.groupName,
    required this.description,
    required this.groupType,
    required this.coverImageUrl,
    required this.createdAt,
    required this.ownerPlayerId,
    required this.ownerName,
    required this.memberCount,
    required this.myRole,
    required this.myStatus,
    required this.postCount,
    required this.messageCount,
  });

  bool get isPrivate => groupType.toLowerCase() == 'private';
  bool get isMember => myStatus?.toLowerCase() == 'accepted';
  bool get isPending => myStatus?.toLowerCase() == 'pending';
  bool get canViewContent => !isPrivate || isMember;
  bool get canManage {
    final role = myRole?.toLowerCase();
    return isMember &&
        (role == 'owner' || role == 'admin' || role == 'moderator');
  }

  CommunityGroup copyWith({
    int? postCount,
    int? messageCount,
    String? myRole,
    String? myStatus,
    int? memberCount,
  }) {
    return CommunityGroup(
      groupId: groupId,
      groupName: groupName,
      description: description,
      groupType: groupType,
      coverImageUrl: coverImageUrl,
      createdAt: createdAt,
      ownerPlayerId: ownerPlayerId,
      ownerName: ownerName,
      memberCount: memberCount ?? this.memberCount,
      myRole: myRole ?? this.myRole,
      myStatus: myStatus ?? this.myStatus,
      postCount: postCount ?? this.postCount,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  factory CommunityGroup.fromJson(Map<String, dynamic> json) {
    return CommunityGroup(
      groupId: _asInt(json['groupId']) ?? 0,
      groupName: json['groupName'] as String? ?? 'Community',
      description: json['description'] as String?,
      groupType: json['groupType'] as String? ?? 'Public',
      coverImageUrl: json['coverImageUrl'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      ownerPlayerId: _asInt(json['ownerPlayerId']) ?? 0,
      ownerName: json['ownerName'] as String? ?? 'Owner',
      memberCount: _asInt(json['memberCount']) ?? 0,
      myRole: json['myRole'] as String?,
      myStatus: json['myStatus'] as String?,
      postCount: _asInt(json['postCount']) ?? 0,
      messageCount: _asInt(json['messageCount']) ?? 0,
    );
  }
}

class CommunityMember {
  final int groupId;
  final int userId;
  final String username;
  final String? profileImageUrl;
  final String role;
  final String status;
  final DateTime? joinedAt;

  const CommunityMember({
    required this.groupId,
    required this.userId,
    required this.username,
    required this.profileImageUrl,
    required this.role,
    required this.status,
    required this.joinedAt,
  });

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isOwner => role.toLowerCase() == 'owner';

  factory CommunityMember.fromJson(Map<String, dynamic> json) {
    return CommunityMember(
      groupId: _asInt(json['groupId']) ?? 0,
      userId: _asInt(json['userId']) ?? 0,
      username: json['username'] as String? ?? 'Member',
      profileImageUrl: json['profileImageUrl'] as String?,
      role: json['role'] as String? ?? 'Member',
      status: json['status'] as String? ?? 'Accepted',
      joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? ''),
    );
  }
}

class CommunityPost {
  final int postId;
  final int? groupId;
  final int authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String? content;
  final String postType;
  final String visibility;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> mediaUrls;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final String? myReactionType;

  const CommunityPost({
    required this.postId,
    required this.groupId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.content,
    required this.postType,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
    required this.mediaUrls,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.myReactionType,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    final media = json['mediaUrls'];
    return CommunityPost(
      postId: _asInt(json['postId']) ?? 0,
      groupId: _asInt(json['groupId']),
      authorId: _asInt(json['authorId']) ?? 0,
      authorName: json['authorName'] as String? ?? 'Player',
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      content: json['content'] as String?,
      postType: json['postType'] as String? ?? 'Post',
      visibility: json['visibility'] as String? ?? 'Group',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      mediaUrls: media is List ? media.whereType<String>().toList() : const [],
      likeCount: _asInt(json['likeCount']) ?? 0,
      commentCount: _asInt(json['commentCount']) ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      myReactionType: json['myReactionType'] as String?,
    );
  }
}

class CommunityComment {
  final int commentId;
  final int postId;
  final int userId;
  final String username;
  final String? userAvatarUrl;
  final int? parentCommentId;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CommunityComment({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.username,
    required this.userAvatarUrl,
    required this.parentCommentId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      commentId: _asInt(json['commentId']) ?? 0,
      postId: _asInt(json['postId']) ?? 0,
      userId: _asInt(json['userId']) ?? 0,
      username: json['username'] as String? ?? 'Member',
      userAvatarUrl: json['userAvatarUrl'] as String?,
      parentCommentId: _asInt(json['parentCommentId']),
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class CommunityMessage {
  final int messageId;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String? content;
  final String messageType;
  final String? mediaUrl;
  final int? replyToMessageId;
  final DateTime? sentAt;
  final bool isMine;

  const CommunityMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.content,
    required this.messageType,
    required this.mediaUrl,
    required this.replyToMessageId,
    required this.sentAt,
    required this.isMine,
  });

  factory CommunityMessage.fromJson(Map<String, dynamic> json) {
    return CommunityMessage(
      messageId: _asInt(json['messageId']) ?? 0,
      conversationId: _asInt(json['conversationId']) ?? 0,
      senderId: _asInt(json['senderId']) ?? 0,
      senderName: json['senderName'] as String? ?? 'Member',
      senderAvatarUrl: json['senderAvatarUrl'] as String?,
      content: json['content'] as String?,
      messageType: json['messageType'] as String? ?? 'Text',
      mediaUrl: json['mediaUrl'] as String?,
      replyToMessageId: _asInt(json['replyToMessageId']),
      sentAt: DateTime.tryParse(json['sentAt'] as String? ?? ''),
      isMine: json['isMine'] as bool? ?? false,
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
