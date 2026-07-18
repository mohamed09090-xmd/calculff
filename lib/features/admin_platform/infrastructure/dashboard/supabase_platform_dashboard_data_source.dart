import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class PlatformDashboardDataSource {
  Future<int> countNewOrders();

  Future<int> countProcessingOrders();

  Future<int> countPaymentsUnderReview();

  Future<int> countCompletedOrders();

  Future<int> countPublishedOffers();

  Future<int> countActiveGames();
}

class SupabasePlatformDashboardDataSource
    implements PlatformDashboardDataSource {
  const SupabasePlatformDashboardDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<int> countNewOrders() {
    return _client
        .from('orders')
        .count(CountOption.exact)
        .eq('order_status', 'new');
  }

  @override
  Future<int> countProcessingOrders() {
    return _client
        .from('orders')
        .count(CountOption.exact)
        .eq('order_status', 'processing');
  }

  @override
  Future<int> countPaymentsUnderReview() {
    return _client
        .from('orders')
        .count(CountOption.exact)
        .eq('payment_status', 'under_review');
  }

  @override
  Future<int> countCompletedOrders() {
    return _client
        .from('orders')
        .count(CountOption.exact)
        .eq('order_status', 'completed');
  }

  @override
  Future<int> countPublishedOffers() {
    return _client
        .from('public_offers')
        .count(CountOption.exact)
        .eq('is_published', true);
  }

  @override
  Future<int> countActiveGames() {
    return _client
        .from('games')
        .count(CountOption.exact)
        .eq('is_active', true);
  }
}
