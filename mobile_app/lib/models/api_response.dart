class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final String? error;
  final Map<String, dynamic>? rawData;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.error,
    this.rawData,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T? Function(Map<String, dynamic>)? parser) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'],
      error: json['error'],
      data: parser != null && json['data'] != null ? parser(json['data']) : null,
      rawData: json,
    );
  }

  factory ApiResponse.success(T data, {String? message}) {
    return ApiResponse(
      success: true,
      data: data,
      message: message,
    );
  }

  factory ApiResponse.error(String error) {
    return ApiResponse(
      success: false,
      error: error,
    );
  }
}



