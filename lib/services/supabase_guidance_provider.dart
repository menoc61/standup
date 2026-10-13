import 'package:standup_app/data/remote/supabase_service.dart';
import 'package:standup_app/services/guidance_provider.dart';

/// Calls the company-hosted guidance proxy through the signed-in Supabase
/// session. The function receives only the explicit, coarse input allowlist.
class SupabaseGuidanceProvider implements GuidanceProvider {
  SupabaseGuidanceProvider(this._supabaseService);

  static const Duration _requestTimeout = Duration(seconds: 20);
  static const String consentVersion = 'guidance-v1';

  final SupabaseService _supabaseService;

  @override
  Future<GuidanceResult?> suggest(GuidanceInput input) async {
    final client = _supabaseService.client;
    if (client == null || _supabaseService.signedInUserId == null) {
      throw StateError('Company AI requires a signed-in Supabase account.');
    }

    final response = await client.functions
        .invoke(
          'ai-guidance',
          body: {
            'consent_version': consentVersion,
            'input': input.toModelInput(),
          },
        )
        .timeout(_requestTimeout);

    if (response.status != 200) return null;
    return GuidanceResult.fromModelPayload(response.data);
  }
}
