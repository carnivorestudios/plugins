part of chq_native_ads;

class ChqNativeAdInfo {
  final String id;
  final String title;
  final String social;
  final String body;
  final String cta;
  final String coverUrl;
  final String iconUrl;
  final double iconWidth;
  final double iconHeight;
  final String choicesUrl;
  final double choicesWidth;
  final double choicesHeight;
  final String choicesLink;
  final String choicesText;

  ChqNativeAdInfo(Map<String, dynamic> adInfo)
      : id = adInfo["id"],
        title = adInfo["title"],
        social = adInfo["socialContext"],
        body = adInfo["body"],
        cta = adInfo["callToAction"],
        coverUrl = adInfo["coverImage"]["url"],
        iconUrl = adInfo["icon"]["url"],
        iconWidth = adInfo["icon"]["width"] * 1.0,
        iconHeight = adInfo["icon"]["height"] * 1.0,
        choicesUrl = adInfo["choices"]["url"],
        choicesWidth = adInfo["choices"]["width"] * 1.0,
        choicesHeight = adInfo["choices"]["height"] * 1.0,
        choicesLink = adInfo["choices"]["link"],
        choicesText = adInfo["choices"]["text"];
}
