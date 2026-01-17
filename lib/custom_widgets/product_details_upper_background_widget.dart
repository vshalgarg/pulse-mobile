import 'package:flutter/material.dart';

class ProductDetailsUpperBackgroundWidget extends StatelessWidget {
  const ProductDetailsUpperBackgroundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
            height: 600,
            child: Stack(
              children: [
                // RoundedCornersBackground(),
                const Positioned.fill(
                  top: 140,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 200),
                    // child: Image.asset(
                    //   'images/dark_yellow_background.png',
                    //   // Replace with your image asset
                    //   fit: BoxFit.fitHeight,
                    //   alignment: Alignment.bottomLeft,
                    // ),
                  ),
                ),
              ],
            )),
        // Positioned(
        //   top: 0,
        //   left: 20,
        //   right: 0,
        //   child: Image.asset(
        //     'images/bottle_image.png', // Replace with your image path
        //     fit: BoxFit.fitHeight,
        //     height: 430,
        //     alignment: Alignment.bottomLeft,
        //   ),
        // ),
      ],
    );
  }
}
