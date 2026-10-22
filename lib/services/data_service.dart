import '../models/auth_models.dart';
import 'api_client.dart';

class RecordPage {
  const RecordPage(this.items, this.total, this.page, this.pageSize);
  final List<Map<String, dynamic>> items;
  final int total, page, pageSize;
  bool get hasNext => page * pageSize < total;

  factory RecordPage.fromJson(Object? value) {
    final json = jsonObject(value);
    if (json['items'] is! List ||
        json['totalCount'] is! int ||
        json['page'] is! int ||
        json['pageSize'] is! int ||
        (json['totalCount'] as int) < 0 ||
        (json['page'] as int) < 1 ||
        (json['pageSize'] as int) < 1 ||
        (json['pageSize'] as int) > 100) {
      throw const FormatException('Dữ liệu phân trang không hợp lệ.');
    }
    return RecordPage(
      (json['items'] as List).map(jsonObject).toList(),
      json['totalCount'],
      json['page'],
      json['pageSize'],
    );
  }
}

class DataService {
  const DataService(this.api);
  final ApiClient api;
  Future<RecordPage> list(
    String path, {
    int page = 1,
    String search = '',
    int pageSize = 20,
  }) async => RecordPage.fromJson(
    (await api.get(
      path,
      query: {
        'page': page,
        'pageSize': pageSize,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    )).data,
  );
  Future<Map<String, dynamic>> detail(String path) async =>
      jsonObject((await api.get(path)).data);

  Future<List<Map<String, dynamic>>> options(String path) async {
    final result = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final next = await list(path, page: page, pageSize: 100);
      if (next.page != page) {
        throw const FormatException(
          'API trả sai số trang. Không thể tải danh sách lựa chọn.',
        );
      }
      result.addAll(next.items);
      if (!next.hasNext) return result;
      if (next.items.isEmpty) {
        throw const FormatException('Phân trang API không nhất quán.');
      }
      page++;
    }
  }
}
