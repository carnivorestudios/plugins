part of chq_native_ads;

class ChqNativeAd extends StatefulWidget {
  @override
  _ChqNativeAdState createState() => new _ChqNativeAdState();
}

class _ChqNativeAdState extends State<ChqNativeAd> {
  _ChqNativeAdInfo _adInfo;
  String _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAdInfo();
  }

  @override
  void dispose() {
    if (_adInfo != null) {
      _chqNativeAds._unloadAd(_adInfo.id);
    }
    super.dispose();
  }

  Future<Null> _loadAdInfo() async {
    _ChqNativeAdInfo adInfo;
    String errorMessage;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      adInfo = await _chqNativeAds._loadAd();
    }
    on PlatformException catch (ex) {
      adInfo = null;
      errorMessage = ex.message;
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted)
      return;

    setState(() {
      _adInfo = adInfo;
      _errorMessage = errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null)
      return new Text("Ad loading error: " + _errorMessage);

    if (_adInfo == null)
      return const Text("Loading ...");

    final double deviceRatio = MediaQuery.of(context).devicePixelRatio;

    return new Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        new Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            new Image.network(
              _adInfo.iconUrl,
              width: _adInfo.iconWidth / deviceRatio * 0.75,
              height: _adInfo.iconHeight / deviceRatio * 0.75,
            ),
            const Padding(padding: const EdgeInsets.all(3.0)),
            new Expanded(
              child: new Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  new Text(_adInfo.title,
                      style: new TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromRGBO(0, 0, 0, 0.75))),
                  new Text("Sponsored",
                      style: new TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.normal,
                          color: const Color.fromRGBO(120, 120, 120, 0.9))),
                ],
              ),
            )
          ],
        ),
        const Padding(padding: const EdgeInsets.all(3.0)),
        new Image.network(_adInfo.coverUrl),
        const Padding(padding: const EdgeInsets.all(3.0)),
        new Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            new Expanded(
              child: new Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  new Text(_adInfo.social,
                      style: new TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.normal,
                          color: const Color.fromRGBO(120, 120, 120, 0.9))),
                  new Text(_adInfo.body,
                      style: new TextStyle(
                          fontWeight: FontWeight.normal,
                          color: const Color.fromRGBO(0, 0, 0, 0.75))),
                ],
              ),
            ),
            new RaisedButton(
                color: const Color.fromRGBO(66, 244, 244, 1.0),
                child: new Text(_adInfo.cta),
                onPressed: () {
                  _chqNativeAds._clickAd(_adInfo.id);
                }),
          ],
        ),
      ],
    );
  }
}