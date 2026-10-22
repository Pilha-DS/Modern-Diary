import '../../../core/network/api_client.dart';
import '../../../core/network/json_values.dart';
import '../../auth/domain/user.dart';

class UsersPage {
  const UsersPage({
    required this.users,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  final List<User> users;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
}

class UsersRepository {
  UsersRepository(this._client);

  final ApiClient _client;

  Future<UsersPage> fetchPage({required int page, int perPage = 20}) async {
    final envelope = await _client.get(
      '/api/v1/users',
      query: {'page': '$page', 'per_page': '$perPage'},
      parse: (data) {
        final list = data! as List;
        return list
            .map(
              (item) => User.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      },
    );

    final meta = envelope.meta;
    return UsersPage(
      users: envelope.data ?? const [],
      page: readInt(meta['page'], fallback: page),
      perPage: readInt(meta['per_page'], fallback: perPage),
      total: readInt(meta['total']),
      totalPages: readInt(meta['total_pages']),
    );
  }
}
