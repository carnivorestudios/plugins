part of chq_native_ads;

final _ChqNativeAds _chqNativeAds = _ChqNativeAds._instance;

class _ChqNativeAds {
  static const MethodChannel _channel =
  const MethodChannel('chq_native_ads');

  _ChqNativeAds._();

  static Future<String> get platformVersion =>
      _channel.invokeMethod('getPlatformVersion');

  static _ChqNativeAds _instance = new _ChqNativeAds._();

  Future<_ChqNativeAdInfo> loadAd() async {
    final Map<String,dynamic> adInfo = await _channel.invokeMethod("loadAd");
    return new _ChqNativeAdInfo(adInfo);
  }

  void clickAd(String id) {
    _channel.invokeMethod("clickAd", <String, String>{
      "id": id,
    });
  }

  void unloadAd(String id) {
    _channel.invokeMethod("unloadAd", <String, String>{
      "id": id,
    });
  }
}
