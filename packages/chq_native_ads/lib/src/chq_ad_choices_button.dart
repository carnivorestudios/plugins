part of chq_native_ads;

class ChqAdChoicesButton extends StatefulWidget {
  final ChqNativeAdInfo adInfo;

  ChqAdChoicesButton(this.adInfo);

  @override
  _ChqAdChoicesButtonState createState() => new _ChqAdChoicesButtonState();
}

class _ChqAdChoicesButtonState extends State<ChqAdChoicesButton> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return new InkWell(
        child: new Image.network(
          widget.adInfo.choicesUrl,
          width: widget.adInfo.choicesWidth,
          height: widget.adInfo.choicesHeight,
        ),
        onTap: () {
          //TODO: animate choices text
          launch(widget.adInfo.choicesLink);
        });
  }
}
