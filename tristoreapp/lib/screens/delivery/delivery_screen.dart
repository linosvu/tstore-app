import 'package:flutter/material.dart';

import 'package:tstore/screens/delivery/order_fulfillment_hub_screen.dart';

/// Giữ tên class để tương thích import cũ.
class DeliveryScreen extends StatelessWidget {
  const DeliveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OrderFulfillmentHubScreen();
  }
}
