package com.clanhq.chqnativeads;

import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;

import com.facebook.ads.Ad;
import com.facebook.ads.AdError;
import com.facebook.ads.AdListener;
import com.facebook.ads.NativeAd;
import com.facebook.ads.NativeAdViewAttributes;

import java.util.HashMap;
import java.util.Map;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * ChqNativeAdsPlugin
 */
public class ChqNativeAdsPlugin implements MethodCallHandler {

  private static Map<String, Button> callToActions = new HashMap<String, Button>();

  public ChqNativeAdsPlugin(FlutterActivity activity) {
    this.activity = activity;
  }

  private FlutterActivity activity = null;
  private String placementId = null;
  /**
   * Plugin registration.
   */
  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "chq_native_ads");
    channel.setMethodCallHandler(new ChqNativeAdsPlugin((FlutterActivity) registrar.activity()));
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
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
        String id = call.argument("id");
        if (callToActions.containsKey(id)) {
          callToActions.get(id).performClick();
          result.success(null);
        }
        else {
          result.error("", "", "");
        }
        break;
      case "unloadAd":
        //TODO
        result.success(null);
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
    final Button ctaButton = new Button(activity.getApplicationContext());
    ctaButton.setText("click me");
    ctaButton.setLayoutParams(new ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.WRAP_CONTENT,
        ViewGroup.LayoutParams.WRAP_CONTENT));

    ctaButton.setOnClickListener(new View.OnClickListener() {
      @Override
      public void onClick(View v) {
        Log.d("NativeAdPlugin", "onClick: " + v.toString());
      }
    });

    final NativeAd nativeAd = new NativeAd(activity.getApplicationContext(), placementId);
    Log.d("NativeAdPlugin", "PlacementId: " + nativeAd.getPlacementId());

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
        result.error("Error: " + Integer.toString(error.getErrorCode()), error.getErrorMessage(), null);
      }

      @Override
      public void onAdLoaded(Ad ad) {
        String id = nativeAd.getId();

        // Set the Text.
        Map<String, Object> adInfo = new HashMap<>();
        adInfo.put("id", nativeAd.getId());
        adInfo.put("title", nativeAd.getAdTitle());
        adInfo.put("socialContext", nativeAd.getAdSocialContext());
        adInfo.put("body", nativeAd.getAdBody());
        adInfo.put("callToAction", nativeAd.getAdCallToAction());
        adInfo.put("icon", image2map(nativeAd.getAdIcon()));
        adInfo.put("coverImage", image2map(nativeAd.getAdCoverImage()));
        adInfo.put("adChoicesIcon", image2map(nativeAd.getAdChoicesIcon()));
        adInfo.put("adChoicesLinkUrl", nativeAd.getAdChoicesLinkUrl());
        adInfo.put("adNetwork", nativeAd.getAdNetwork().toString());
        adInfo.put("rawBody", nativeAd.getAdRawBody());
        adInfo.put("subTitle", nativeAd.getAdSubtitle());
        adInfo.put("placementId", nativeAd.getPlacementId());

        if (nativeAd.getAdViewAttributes() != null) {
          adInfo.put("attributes", attrs2map(nativeAd.getAdViewAttributes()));
        }

        // Register the Title and CTA button to listen for clicks.
        nativeAd.registerViewForInteraction(ctaButton);

        callToActions.put(id, ctaButton);
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
