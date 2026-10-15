/// Sağlayıcının model listesini ve erişilebilirliğini sorgular.
abstract interface class ModelListFetcher {
  /// OpenAI uyumlu /models uç noktasından model kimliklerini döndürür.
  /// Başarısızlıkta istisna fırlatır.
  Future<List<String>> fetchModels({required String baseUrl, String apiKey = ''});

  /// Adres sunucu hatası vermeden cevap veriyor mu.
  Future<bool> isReachable(String url);
}
