part of chq_native_ads;

final ChqNativeAds _chqNativeAds = ChqNativeAds._instance;

class ChqNativeAds {
  static const MethodChannel _channel =
  const MethodChannel('chq_native_ads');

  ChqNativeAds._();

  static ChqNativeAds _instance = new ChqNativeAds._();

  static void setPlacementId(String placementId) {
    _channel.invokeMethod("setPlacementId", <String, String>{
      "placementId": placementId,
    });
  }

  Future<_ChqNativeAdInfo> _loadAd() async {
    final Map<String,dynamic> adInfo = await _channel.invokeMethod("loadAd");
    return new _ChqNativeAdInfo(adInfo);
  }

  void _clickAd(String id) {
    _channel.invokeMethod("clickAd", <String, String>{
      "id": id,
    });
  }

  void _unloadAd(String id) {
    _channel.invokeMethod("unloadAd", <String, String>{
      "id": id,
    });
  }
}
