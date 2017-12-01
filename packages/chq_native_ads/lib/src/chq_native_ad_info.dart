part of chq_native_ads;

class ChqNativeAdInfo {
  final String id;
  final String title;
  final String social;
  final String body;
  final String cta;
  final String coverUrl;
  final String iconUrl;
  final int iconWidth;
  final int iconHeight;

  ChqNativeAdInfo(Map<String, dynamic> adInfo)
      : id = adInfo["id"],
        title = adInfo["title"],
        social = adInfo["socialContext"],
        body = adInfo["body"],
        cta = adInfo["callToAction"],
        coverUrl = adInfo["coverImage"]["url"],
        iconUrl = adInfo["icon"]["url"],
        iconWidth = adInfo["icon"]["width"],
        iconHeight = adInfo["icon"]["height"];
}
