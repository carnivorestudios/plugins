part of chq_native_ads;

typedef void CallToActionCallback(ChqNativeAdInfo adInfo);

abstract class ChqNativeAdWidgetBuilder {
  Widget loadingWidget();
  Widget errorWidget(String errorMessage);
  Widget adWidget(ChqNativeAdInfo adInfo);

  void performCallToAction(ChqNativeAdInfo adInfo) {
    _chqNativeAds._clickAd(adInfo.id);
  }
}

class ChqNativeAd {
  final ChqNativeAdWidgetBuilder builder;

  ChqNativeAd(this.builder);

  bool _hasLoaded = false;
  Future<ChqNativeAdInfo> _loadTask;
  ChqNativeAdInfo _adInfo;
  String _errorMessage;

  Future<ChqNativeAdInfo> _load() {
    Future<ChqNativeAdInfo> task = _chqNativeAds._loadAd();
    task.then((adInfo) {
      _adInfo = adInfo;
      _hasLoaded = true;
      _loadTask = null;
    });
    task.catchError((dynamic error, StackTrace stackTrace) {
      _errorMessage = Error.safeToString(error);
    });
    return task;
  }

  Widget build() {
    if (!_hasLoaded) {
      _loadTask = _load();
    }
    if (_loadTask != null) {
      return new FutureBuilder<ChqNativeAdInfo>(future:_loadTask, builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return builder.loadingWidget();
        }
        else if (snapshot.hasError) {
          return builder.errorWidget(Error.safeToString(snapshot.error));
        }
        else {
          return builder.adWidget(snapshot.data);
        }
      });
    }
    else if (_errorMessage != null) {
      return builder.errorWidget(_errorMessage);
    }
    else {
      return builder.adWidget(_adInfo);
    }
  }

  void dispose() {
    print('dispose ad, _loadTask: $_loadTask, _adInfo: $_adInfo, id: ${_adInfo?.id}');
    if (_loadTask != null) {
      _loadTask.then((info) {
        print('dispose ad after load, id: ${info.id}');
        _chqNativeAds._unloadAd(info.id);
      });
    }
    else if (_adInfo != null) {
      _chqNativeAds._unloadAd(_adInfo.id);
    }
  }
}