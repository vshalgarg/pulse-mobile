import 'package:badges/badges.dart' as badge;
import 'package:flutter/material.dart';

class ShoppingCartButton extends StatelessWidget {
  final int _counter = 0;

  const ShoppingCartButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _shoppingCartBadge();
  }

  Widget _shoppingCartBadge() {
    return badge.Badge(
      position: badge.BadgePosition.topEnd(top: 0, end: 3),
      //animationDuration: const Duration(milliseconds: 300),
      //animationType: badge.BadgeAnimationType.slide,
      badgeContent: Text(
        _counter.toString(),
        style: const TextStyle(color: Colors.white),
      ),
      child: IconButton(icon: const Icon(Icons.shopping_cart_outlined), onPressed: () {}),
    );
  }
}
