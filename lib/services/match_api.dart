import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'auth_api.dart' show ApiException;

// ─── Base URL ─────────────────────────────────────────────────────────────────

/// The FindMatchModule base URL.
/// - Override at build time: flutter run --dart-define=MATCH_API_URL=http://192.168.x.x:5063
/// - Web & desktop default:  http://localhost:5063
/// - Android emulator:       http://10.0.2.2:5063  (maps to host localhost)
const _kEnvMatchUrl = String.fromEnvironment('MATCH_API_URL', defaultValue: '');

String get _matchBaseUrl {
  if (_kEnvMatchUrl.isNotEmpty) return _kEnvMatchUrl;
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5015';
  return 'http://localhost:5015';
}

// ─── MatchApi ─────────────────────────────────────────────────────────────────

/// HTTP client for the FindMatchModule microservice running on **port 5063**.
///
/// Workflow:
///   1. Call [enqueue] → POST /api/match/enqueue
///      Server responds **202 Accepted** with a [EnqueueResponse] containing
///      the [queueId] needed for subsequent polling.
///
///   2. Call [getMatch] every ~10 s → GET /api/match/{queueId}
///      - **200 OK**  → matched! Returns [LobbyStatusResponse.isMatched]=true.
///      - **202 Accepted** → still waiting. Returns [LobbyStatusResponse.isMatched]=false.
///      - **404** → unknown queueId, throws [ApiException].
class MatchApi {
  final String baseUrl;
  final http.Client _client;

  MatchApi({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? _matchBaseUrl).replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  // ── POST /api/match/enqueue ───────────────────────────────────────────────

  /// Submits a lobby to the matchmaking queue.
  ///
  /// Returns an [EnqueueResponse] containing the [queueId] to use for polling.
  /// The server always responds with **202 Accepted** on success.
  Future<EnqueueResponse> enqueue(CreateLobbyRequest request) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/match/enqueue'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Enqueue failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return EnqueueResponse.fromJson(decoded);
  }

  // ── GET /api/match/{queueId} ──────────────────────────────────────────────

  /// Polls for a match result.
  ///
  /// - **200 OK**      → matched; returns [LobbyStatusResponse] with [isMatched]=true.
  /// - **202 Accepted** → still waiting; returns [LobbyStatusResponse] with [isMatched]=false.
  /// - Any other status → throws [ApiException].
  Future<LobbyStatusResponse> getMatch(String queueId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/match/$queueId'),
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return LobbyStatusResponse.fromMatchedLobby(decoded);
    }

    if (response.statusCode == 202) {
      // Still waiting – body is { queueId, status: "Waiting" }
      return LobbyStatusResponse.waiting(queueId);
    }

    throw ApiException(
      'GetMatch failed (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  // ── GET /api/match/{matchId}/voting-status ─────────────────────────────────

  /// Fetches the candidate time slots, candidate venues, and current voting status for a match.
  Future<MatchVotingStatusResponse> getVotingStatus(String token, int matchId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/match/$matchId/voting-status'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to fetch voting status (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return MatchVotingStatusResponse.fromJson(decoded);
  }

  // ── POST /api/match/{matchId}/vote ─────────────────────────────────────────

  /// Submits a player's vote for the match venue and start time.
  Future<MatchVotingStatusResponse> castVote({
    required String token,
    required int matchId,
    required int venueId,
    required String startTime,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/match/$matchId/vote'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'venueId': venueId,
        'startTime': startTime,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to cast vote (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return MatchVotingStatusResponse.fromJson(decoded);
  }
}

// ─── DTOs ─────────────────────────────────────────────────────────────────────

/// A single player entry inside [CreateLobbyRequest].
/// Mirrors the backend `Players` DTO exactly (note: `prefferedVenue` has a
/// double 'f' — intentional to match the backend spelling).
class LobbyPlayerDto {
  final int playerId;
  final String playerName;
  final double playerSkill;
  final String? playerProfilePictureUrl;
  final String preferredTimeStart; // 'HH:mm:ss'
  final String preferredTimeEnd;   // 'HH:mm:ss'
  final List<int> prefferedVenue;  // double 'f' — matches backend spelling

  const LobbyPlayerDto({
    required this.playerId,
    required this.playerName,
    required this.playerSkill,
    this.playerProfilePictureUrl,
    required this.preferredTimeStart,
    required this.preferredTimeEnd,
    required this.prefferedVenue,
  });

  Map<String, dynamic> toJson() => {
    'playerId':                playerId,
    'playerName':              playerName,
    'playerSkill':             playerSkill,
    'playerProfilePictureUrl': playerProfilePictureUrl,
    'preferredTimeStart':      preferredTimeStart,
    'preferredTimeEnd':        preferredTimeEnd,
    'prefferedVenue':          prefferedVenue,
  };

  factory LobbyPlayerDto.fromJson(Map<String, dynamic> json) {
    return LobbyPlayerDto(
      playerId:               json['playerId']   as int,
      playerName:             json['playerName'] as String,
      playerSkill:            (json['playerSkill'] as num).toDouble(),
      playerProfilePictureUrl: json['playerProfilePictureUrl'] as String?,
      preferredTimeStart:     json['preferredTimeStart'] as String? ?? '00:00:00',
      preferredTimeEnd:       json['preferredTimeEnd']   as String? ?? '23:59:59',
      prefferedVenue:         (json['prefferedVenue'] as List<dynamic>? ?? [])
          .map((e) => e as int)
          .toList(),
    );
  }
}

/// Request body sent to POST /api/match/enqueue.
class CreateLobbyRequest {
  final List<LobbyPlayerDto> players;
  final String lobbyType; // 'normal' or 'ranked'
  final int lobbySize;    // 2 or 4

  const CreateLobbyRequest({
    required this.players,
    required this.lobbyType,
    required this.lobbySize,
  });

  Map<String, dynamic> toJson() => {
    'players':   players.map((p) => p.toJson()).toList(),
    'lobbyType': lobbyType,
    'lobbySize': lobbySize,
  };
}

/// Response from POST /api/match/enqueue (202 Accepted).
class EnqueueResponse {
  final String queueId;
  final String message;

  const EnqueueResponse({required this.queueId, required this.message});

  factory EnqueueResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['queueId'];
    return EnqueueResponse(
      queueId: raw is String ? raw : raw.toString(),
      message: json['message'] as String? ?? '',
    );
  }
}

/// Returned by [MatchApi.getMatch].
///
/// - [isMatched]=true  when the server returned 200 OK (full Lobby body).
/// - [isMatched]=false when the server returned 202 Accepted (still waiting).
class LobbyStatusResponse {
  final String queueId;
  final DateTime? matchedAt;
  final List<LobbyPlayerDto> players;
  final String lobbyType;
  final int lobbySize;
  final int? matchId;

  const LobbyStatusResponse({
    required this.queueId,
    required this.matchedAt,
    required this.players,
    required this.lobbyType,
    required this.lobbySize,
    this.matchId,
  });

  bool get isMatched => matchedAt != null;

  /// Builds from a full Lobby response body (200 OK – matched).
  factory LobbyStatusResponse.fromMatchedLobby(Map<String, dynamic> json) {
    final rawPlayers = json['players'] as List<dynamic>? ?? [];
    final rawId = json['queueId'];
    return LobbyStatusResponse(
      queueId:   rawId is String ? rawId : rawId.toString(),
      matchedAt: json['matchedAt'] != null
          ? DateTime.tryParse(json['matchedAt'] as String)
          : DateTime.now(), // treat a 200 with no timestamp as matched right now
      players:   rawPlayers
          .map((e) => LobbyPlayerDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      lobbyType: (json['lobbyType'] ?? 'normal') as String,
      lobbySize: (json['lobbySize'] as num?)?.toInt() ?? 4,
      matchId:   json['matchId'] as int?,
    );
  }

  /// Builds a "still waiting" placeholder (202 Accepted).
  factory LobbyStatusResponse.waiting(String queueId) {
    return LobbyStatusResponse(
      queueId:   queueId,
      matchedAt: null,
      players:   [],
      lobbyType: 'normal',
      lobbySize: 4,
      matchId:   null,
    );
  }
}

// ─── Voting System DTOs ────────────────────────────────────────────────────────

class MatchVotingStatusResponse {
  final int matchId;
  final String status;
  final String preferredTimeStart;
  final String preferredTimeEnd;
  final List<CandidateSlotDto> candidateSlots;
  final List<CandidateVenueDto> candidateVenues;
  final List<ParticipantVoteDto> votes;

  const MatchVotingStatusResponse({
    required this.matchId,
    required this.status,
    required this.preferredTimeStart,
    required this.preferredTimeEnd,
    required this.candidateSlots,
    required this.candidateVenues,
    required this.votes,
  });

  factory MatchVotingStatusResponse.fromJson(Map<String, dynamic> json) {
    return MatchVotingStatusResponse(
      matchId: json['matchId'] as int,
      status: json['status'] as String,
      preferredTimeStart: json['preferredTimeStart'] ?? '',
      preferredTimeEnd: json['preferredTimeEnd'] ?? '',
      candidateSlots: (json['candidateSlots'] as List<dynamic>? ?? [])
          .map((e) => CandidateSlotDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      candidateVenues: (json['candidateVenues'] as List<dynamic>? ?? [])
          .map((e) => CandidateVenueDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      votes: (json['votes'] as List<dynamic>? ?? [])
          .map((e) => ParticipantVoteDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CandidateSlotDto {
  final String start;
  final String end;

  const CandidateSlotDto({required this.start, required this.end});

  factory CandidateSlotDto.fromJson(Map<String, dynamic> json) {
    return CandidateSlotDto(
      start: json['start'] as String? ?? '00:00:00',
      end: json['end'] as String? ?? '00:00:00',
    );
  }
}

class CandidateVenueDto {
  final int venueId;
  final String venueName;
  final String address;

  const CandidateVenueDto({
    required this.venueId,
    required this.venueName,
    required this.address,
  });

  factory CandidateVenueDto.fromJson(Map<String, dynamic> json) {
    return CandidateVenueDto(
      venueId: json['venueId'] as int,
      venueName: json['venueName'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }
}

class ParticipantVoteDto {
  final int playerId;
  final String playerName;
  final String? playerProfilePictureUrl;
  final int? votedVenueId;
  final String? votedStartTime;
  final String? votedEndTime;

  const ParticipantVoteDto({
    required this.playerId,
    required this.playerName,
    this.playerProfilePictureUrl,
    this.votedVenueId,
    this.votedStartTime,
    this.votedEndTime,
  });

  factory ParticipantVoteDto.fromJson(Map<String, dynamic> json) {
    return ParticipantVoteDto(
      playerId: json['playerId'] as int,
      playerName: json['playerName'] as String? ?? '',
      playerProfilePictureUrl: json['playerProfilePictureUrl'] as String?,
      votedVenueId: json['votedVenueId'] as int?,
      votedStartTime: json['votedStartTime'] as String?,
      votedEndTime: json['votedEndTime'] as String?,
    );
  }
}
