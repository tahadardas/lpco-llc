class CheckoutForm {
  final String fullName;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String email;
  final String notes;
  final String paymentMethod;
  final String paymentMethodTitle;
  final double? latitude;
  final double? longitude;

  const CheckoutForm({
    required this.fullName,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.email,
    required this.notes,
    required this.paymentMethod,
    required this.paymentMethodTitle,
    this.latitude,
    this.longitude,
  });

  bool get hasValidShippingData {
    return fullName.trim().isNotEmpty &&
        phone.trim().isNotEmpty &&
        address.trim().isNotEmpty;
  }

  String buildOrderComment() {
    var comment = notes.trim();
    if (latitude != null && longitude != null) {
      final gps =
          'GPS: ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
      comment = comment.isEmpty ? gps : '$comment\n$gps';
    }
    return comment;
  }
}
