import 'package:flutter/material.dart';

import '../constants/constants_methods.dart';

class MediumCardWidget extends StatelessWidget {
  final double imageWidth;
  final double imageHeight;

  MediumCardWidget(this.imageWidth, this.imageHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: getHorizontalMediumCardView(imageWidth, imageHeight),
    );
  }

  Widget getHorizontalMediumCardView(double width, double height) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Card(
        elevation: 5,
        shape: kRoundedShape(),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: Column(
          children: [
            FadeInImage(
              placeholder: getPlaceholder,
              image: const NetworkImage(
                  'https://i.pinimg.com/236x/b1/2f/e6/b12fe6f4672732357a365d5b11c6f81b--mens-winter-coat-winter-coats.jpg'),
              fit: BoxFit.cover,
              width: width,
              height: height,
            ),
            const SizedBox(height: 5),
            const Text("Black Coat - 3 pcs"),
            const SizedBox(height: 5),
            RichText(
              text: TextSpan(
                children: <TextSpan>[
                  TextSpan(
                    text: "MRP:-  ",
                    style: kTextStyle(),
                  ),
                  TextSpan(
                    text: "\$50",
                    style: kTextStyle(decoration: TextDecoration.lineThrough),
                  ),
                  TextSpan(
                    text: "  -  ",
                    style: kTextStyle(),
                  ),
                  TextSpan(
                    text: "\$40",
                    style: kTextStyle(decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}
