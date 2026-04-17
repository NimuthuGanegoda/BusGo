/// Generic wrapper for the standard API response shape:
/// { "success": bool, "data": T, "message": string, "pagination": {} }
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String message;
  final Pagination? pagination;

  const ApiResponse({
    required this.success,
    this.data,
    this.message = '',
    this.pagination,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromData,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null ? fromData(json['data']) : null,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}

class Pagination {
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  const Pagination({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        total:      json['total']     as int? ?? 0,
        page:       json['page']      as int? ?? 1,
        pageSize:   json['pageSize']  as int? ?? 20,
        totalPages: json['totalPages'] as int? ?? 1,
        hasNext:    json['hasNext']   as bool? ?? false,
        hasPrev:    json['hasPrev']   as bool? ?? false,
      );
}
