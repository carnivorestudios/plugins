part of chq_native_ads;

class ChqAdChoicesButton extends StatefulWidget {
  final ChqNativeAdInfo adInfo;

  ChqAdChoicesButton(this.adInfo);

  @override
  _ChqAdChoicesButtonState createState() => new _ChqAdChoicesButtonState();
}

class _ChqAdChoicesButtonState extends State<ChqAdChoicesButton>
    with TickerProviderStateMixin {
  bool expanded = false;
  Animation<double> animation;
  AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = new AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    final CurvedAnimation curve =
        new CurvedAnimation(parent: controller, curve: Curves.easeIn);
    animation = new Tween(begin: 0.0, end: 1.0).animate(curve);
  }

  @override
  dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new InkWell(
        child: new Row(children: [
          new Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: new SizeTransition(
              axis: Axis.horizontal,
              sizeFactor: animation,
              child: new Text(widget.adInfo.choicesText),
            ),
          ),
          new Image.network(
            widget.adInfo.choicesUrl,
            width: widget.adInfo.choicesWidth,
            height: widget.adInfo.choicesHeight,
          ),
        ]),
        onTap: () {
          if (expanded) {
            launch(widget.adInfo.choicesLink);
          }
          else {
            if (animation.isDismissed) {
              expanded = true;
              controller.forward().whenComplete(() {
                new Timer(new Duration(seconds: 2), () {
                  controller.reverse().whenComplete(() {
                    expanded = false;
                  });
                });
              });
            }
          }
        });
  }
}
