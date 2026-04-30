enum CheckoutStatus {
  initializing,
  editing,
  validating,
  submitting,
  awaitingPaymentConfirmation,
  success,
  failure,
}

class CheckoutState {
  final int currentStep;
  final String paymentMethod;
  final CheckoutStatus status;
  final bool detectingLocation;
  final double? latitude;
  final double? longitude;
  final String? errorMessage;

  const CheckoutState({
    this.currentStep = 0,
    this.paymentMethod = 'cod',
    this.status = CheckoutStatus.initializing,
    this.detectingLocation = false,
    this.latitude,
    this.longitude,
    this.errorMessage,
  });

  bool get isSubmitting => status == CheckoutStatus.submitting;
  bool get isBusy => isSubmitting || detectingLocation;

  CheckoutState copyWith({
    int? currentStep,
    String? paymentMethod,
    CheckoutStatus? status,
    bool? detectingLocation,
    double? latitude,
    double? longitude,
    String? errorMessage,
    bool clearError = false,
    bool clearCoordinates = false,
  }) {
    return CheckoutState(
      currentStep: currentStep ?? this.currentStep,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      detectingLocation: detectingLocation ?? this.detectingLocation,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
