import '../../application/common/platform_session_coordinator.dart';
import '../../domain/common/cursor_page.dart';
import '../../domain/common/platform_failure.dart';
import '../../domain/offers/public_offer.dart';
import '../../domain/offers/public_offer_input.dart';
import '../../domain/offers/public_offers_repository.dart';
import '../common/supabase_platform_error_mapper.dart';
import 'public_offer_dto.dart';
import 'public_offer_input_mapper.dart';
import 'supabase_offers_datasource.dart';

class SupabasePublicOffersRepository implements PublicOffersRepository {
  const SupabasePublicOffersRepository({
    required SupabaseOffersDataSource dataSource,
    required SupabasePlatformErrorMapper errorMapper,
    required PlatformReadCoordinator readCoordinator,
  }) : _dataSource = dataSource,
       _errorMapper = errorMapper,
       _readCoordinator = readCoordinator;

  final SupabaseOffersDataSource _dataSource;
  final SupabasePlatformErrorMapper _errorMapper;
  final PlatformReadCoordinator _readCoordinator;

  @override
  Future<CursorPage<PublicOffer>> listOffers({String? cursor, int? limit}) {
    final offset = _parseCursor(cursor);
    final pageSize = (limit ?? 50).clamp(1, 100).toInt();

    return _readCoordinator.runRead(() async {
      final rows = await _dataSource.listOffers(
        offset: offset,
        limit: pageSize + 1,
      );
      final hasMore = rows.length > pageSize;
      final offers = rows
          .take(pageSize)
          .map(PublicOfferDto.fromMap)
          .map((dto) => dto.toDomain())
          .toList(growable: false);
      return CursorPage<PublicOffer>(
        items: offers,
        nextCursor: hasMore ? '${offset + pageSize}' : null,
        hasMore: hasMore,
      );
    });
  }

  @override
  Future<PublicOffer> createOffer(PublicOfferInput input) {
    return _runWrite(
      () => _dataSource.createOffer(
        payload: PublicOfferInputMapper.toWritePayload(input),
      ),
    );
  }

  @override
  Future<PublicOffer> updateOffer({
    required String offerId,
    required PublicOfferInput input,
  }) {
    return _runWrite(
      () => _dataSource.updateOffer(
        offerId: offerId,
        payload: PublicOfferInputMapper.toWritePayload(input),
      ),
    );
  }

  @override
  Future<PublicOffer> setOfferPublished({
    required String offerId,
    required bool isPublished,
  }) {
    return _runWrite(
      () => _dataSource.setOfferPublished(
        offerId: offerId,
        isPublished: isPublished,
      ),
    );
  }

  Future<PublicOffer> _runWrite(
    Future<Map<String, Object?>> Function() operation,
  ) async {
    try {
      final row = await operation();
      return PublicOfferDto.fromMap(row).toDomain();
    } catch (error) {
      throw _errorMapper.map(error);
    }
  }
}

int _parseCursor(String? cursor) {
  if (cursor == null) {
    return 0;
  }
  final parsed = int.tryParse(cursor);
  if (parsed == null || parsed < 0) {
    throw const PlatformFailure(PlatformFailureCode.validation);
  }
  return parsed;
}
