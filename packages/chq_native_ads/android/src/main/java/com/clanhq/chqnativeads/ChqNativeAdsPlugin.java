package com.clanhq.chqnativeads;

import android.graphics.PixelFormat;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.Button;

import com.facebook.ads.Ad;
import com.facebook.ads.AdChoicesView;
import com.facebook.ads.AdError;
import com.facebook.ads.AdListener;
import com.facebook.ads.AdSettings;
import com.facebook.ads.NativeAd;
import com.facebook.ads.NativeAdViewAttributes;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.view.FlutterView;

/**
 * ChqNativeAdsPlugin
 */
public class ChqNativeAdsPlugin implements MethodCallHandler {

  private FlutterActivity activity = null;
  private String placementId = null;
  private Map<String, NativeAd> nativeAds = new HashMap<String, NativeAd>();
  private Map<String, View> registeredViews = new HashMap<String, View>();

  private ChqNativeAdsPlugin(FlutterActivity activity) {
    this.activity = activity;
  }
  /**
   * Plugin registration.
   */
  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "chq_native_ads");
    channel.setMethodCallHandler(new ChqNativeAdsPlugin((FlutterActivity) registrar.activity()));
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    String id = call.argument("id");
    switch (call.method) {
      case "setPlacementId":
        placementId = call.argument("placementId");
        break;
      case "loadAd":
        if (placementId == null) {
          result.error("MissingPlacementId", "Must call setPlacementId before calling loadAd", null);
        }
        else {
          createFbAd(result);
        }
        break;
      case "clickAd":
        if (nativeAds.containsKey(id)) {
          nativeAds.get(id).onCtaBroadcast();
          result.success(null);
        }
        else {
          result.error("NativeAdPluginMissingAd", "Could not find ad to perform action with id " + id, null);
        }
        break;
      case "unloadAd":
        if (nativeAds.containsKey(id)) {
          nativeAds.remove(id).unregisterView();
          activity.getWindowManager().removeView(registeredViews.remove(id));
          result.success(null);
        }
        else {
          result.error("NativeAdPluginMissingAd", "Could not find ad to unload with id " + id, null);
        }
        break;
      default:
        result.notImplemented();
    }
  }

  private Map<String, Object> attrs2map(NativeAdViewAttributes attrs) {
    Map<String, Object> map = new HashMap<>();
    map.put("autoplay", attrs.getAutoplay());
    map.put("autoplayOnMobile", attrs.getAutoplayOnMobile());
    map.put("backgroundColor", attrs.getBackgroundColor());
    map.put("buttonBorderColor", attrs.getButtonBorderColor());
    map.put("buttonColor", attrs.getButtonColor());
    map.put("buttonTextColor", attrs.getButtonTextColor());
    map.put("descriptionTextColor", attrs.getDescriptionTextColor());
    map.put("descriptionTextSize", attrs.getDescriptionTextSize());
    map.put("titleTextColor", attrs.getTitleTextColor());
    map.put("titleTextSize", attrs.getTitleTextSize());
    map.put("typeface", attrs.getTypeface());

    return map;
  }
  private void createFbAd(final Result r) {

    final NativeAd nativeAd = new NativeAd(activity.getApplicationContext(), placementId);

    nativeAd.setAdListener(new AdListener() {
      Result result = r;

      private Map<String, Object> image2map(NativeAd.Image image) {
        Map<String, Object> map = new HashMap<>();
        map.put("url", image.getUrl());
        map.put("height", image.getHeight());
        map.put("width", image.getWidth());

        return map;
      }

      @Override
      public void onError(Ad ad, AdError error) {
        nativeAds.remove(nativeAd.getId());
        result.error("Error: " + Integer.toString(error.getErrorCode()), error.getErrorMessage(), null);
      }

      @Override
      public void onAdLoaded(Ad ad) {
        String id = nativeAd.getId();

        Map<String, Object> adChoices = image2map(nativeAd.getAdChoicesIcon());
        adChoices.put("link", nativeAd.getAdChoicesLinkUrl());
        adChoices.put("text", "AdChoices");
        Map<String, Object> adInfo = new HashMap<>();
        adInfo.put("id", nativeAd.getId());
        adInfo.put("title", nativeAd.getAdTitle());
        adInfo.put("socialContext", nativeAd.getAdSocialContext());
        adInfo.put("body", nativeAd.getAdBody());
        adInfo.put("callToAction", nativeAd.getAdCallToAction());
        adInfo.put("icon", image2map(nativeAd.getAdIcon()));
        adInfo.put("coverImage", image2map(nativeAd.getAdCoverImage()));
        adInfo.put("choices", adChoices);
        if (nativeAd.getAdNetwork() != null) {
          adInfo.put("adNetwork", nativeAd.getAdNetwork().toString());
        }
        adInfo.put("rawBody", nativeAd.getAdRawBody());
        adInfo.put("subTitle", nativeAd.getAdSubtitle());
        adInfo.put("placementId", nativeAd.getPlacementId());

        if (nativeAd.getAdViewAttributes() != null) {
          adInfo.put("attributes", attrs2map(nativeAd.getAdViewAttributes()));
        }

        // Register the Title and CTA button to listen for clicks.
        View dummyView = new View(activity.getApplicationContext());

        WindowManager.LayoutParams params = new WindowManager.LayoutParams(0, 0,
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT);

        activity.getWindowManager().addView(dummyView, params);

        List<View> clickable = new ArrayList<View>();
        clickable.add(dummyView);
        nativeAd.registerViewForInteraction(activity.getFlutterView(), clickable);
        registeredViews.put(id, dummyView);

        nativeAds.put(id, nativeAd);
        result.success(adInfo);
      }

      @Override
      public void onAdClicked(Ad ad) {
        Log.d("click", "onAdClicked: " + ad.toString());
      }

      @Override
      public void onLoggingImpression(Ad ad) {
        Log.d("impression", "onLoggingImpression: " + ad.toString());
      }
    });

    nativeAd.loadAd();
  }
}