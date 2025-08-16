enum OrderStatusEnum {
  OrderConfirmed(1),
  Shipped(2),
  OutForDelivery(3),
  Delivery(4),
  PendingPayment(5),
  Processing(6),
  Refunded(7),
  OnTheWay(8),
  Delivered(9),
  Cancelled(10),
  Completed(11),
  Failed(12),
  OnHold(13),
  All(14);

  const OrderStatusEnum(this.value);

  final int value;
}
