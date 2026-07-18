import 'package:supabase_flutter/supabase_flutter.dart';

import '../common/platform_payload_reader.dart';
import 'game_dto.dart';

abstract interface class GamesDataSource {
  Future<List<GameDto>> listGames({int? limit});

  Future<GameDto> createGame(Map<String, Object> payload);

  Future<GameDto> updateGame({
    required String gameId,
    required Map<String, Object> payload,
  });

  Future<GameDto> setGameActive({
    required String gameId,
    required bool isActive,
  });
}

class SupabaseGamesDataSource implements GamesDataSource {
  const SupabaseGamesDataSource(this._client);

  static const String selectedColumns =
      'id,slug,name_ar,name_fr,reward_unit_code,reward_unit_name_ar,'
      'reward_unit_name_fr,is_active,sort_order,created_at,updated_at';

  static const String tableName = 'games';

  final SupabaseClient _client;

  @override
  Future<List<GameDto>> listGames({int? limit}) async {
    var query = _client
        .from(tableName)
        .select(selectedColumns)
        .order('sort_order', ascending: true)
        .order('id', ascending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    final response = await query;
    return decodeListResponse(response);
  }

  @override
  Future<GameDto> createGame(Map<String, Object> payload) async {
    final response = await _client
        .from(tableName)
        .insert(payload)
        .select(selectedColumns)
        .single();
    return decodeSingleResponse(response);
  }

  @override
  Future<GameDto> updateGame({
    required String gameId,
    required Map<String, Object> payload,
  }) async {
    final response = await _client
        .from(tableName)
        .update(payload)
        .eq('id', gameId)
        .select(selectedColumns)
        .single();
    return decodeSingleResponse(response);
  }

  @override
  Future<GameDto> setGameActive({
    required String gameId,
    required bool isActive,
  }) async {
    final response = await _client
        .from(tableName)
        .update(<String, Object>{'is_active': isActive})
        .eq('id', gameId)
        .select(selectedColumns)
        .single();
    return decodeSingleResponse(response);
  }

  static List<GameDto> decodeListResponse(Object? response) {
    if (response is! List) {
      throw const PlatformPayloadException(
        field: 'games',
        reason: PlatformPayloadFailureReason.wrongType,
      );
    }

    return List<GameDto>.unmodifiable(
      response.map((row) => GameDto.fromMap(_toStringKeyedMap(row))),
    );
  }

  static GameDto decodeSingleResponse(Object? response) {
    return GameDto.fromMap(_toStringKeyedMap(response));
  }
}

Map<String, Object?> _toStringKeyedMap(Object? value) {
  if (value is! Map) {
    throw const PlatformPayloadException(
      field: 'game',
      reason: PlatformPayloadFailureReason.wrongType,
    );
  }

  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const PlatformPayloadException(
        field: 'game',
        reason: PlatformPayloadFailureReason.wrongType,
      );
    }
    result[key] = entry.value;
  }
  return Map<String, Object?>.unmodifiable(result);
}
