import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/features/checkout/application/checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit() : super(const CheckoutState());

  void initialize() {
    emit(state.copyWith(status: CheckoutStatus.editing, clearError: true));
  }

  void selectPaymentMethod(String method) {
    if (method.trim().isEmpty) {
      return;
    }
    emit(
      state.copyWith(
        paymentMethod: method.trim(),
        status: CheckoutStatus.editing,
        clearError: true,
      ),
    );
  }

  void nextStep() {
    if (state.currentStep >= 3 || state.isSubmitting) {
      return;
    }
    emit(
      state.copyWith(
        currentStep: state.currentStep + 1,
        status: CheckoutStatus.editing,
        clearError: true,
      ),
    );
  }

  void previousStep() {
    if (state.currentStep <= 0 || state.isSubmitting) {
      return;
    }
    emit(
      state.copyWith(
        currentStep: state.currentStep - 1,
        status: CheckoutStatus.editing,
        clearError: true,
      ),
    );
  }

  void goToStep(int step) {
    if (state.isSubmitting) {
      return;
    }
    final clamped = step < 0
        ? 0
        : step > 3
        ? 3
        : step;
    emit(
      state.copyWith(
        currentStep: clamped,
        status: CheckoutStatus.editing,
        clearError: true,
      ),
    );
  }

  void validating() {
    emit(state.copyWith(status: CheckoutStatus.validating, clearError: true));
  }

  bool beginSubmit() {
    if (state.isSubmitting) {
      return false;
    }
    emit(state.copyWith(status: CheckoutStatus.submitting, clearError: true));
    return true;
  }

  void setAwaitingPaymentConfirmation() {
    emit(
      state.copyWith(
        status: CheckoutStatus.awaitingPaymentConfirmation,
        clearError: true,
      ),
    );
  }

  void setSuccess() {
    emit(state.copyWith(status: CheckoutStatus.success, clearError: true));
  }

  void setFailure(String message) {
    emit(state.copyWith(status: CheckoutStatus.failure, errorMessage: message));
  }

  void clearFailure() {
    emit(state.copyWith(status: CheckoutStatus.editing, clearError: true));
  }

  void startLocationDetection() {
    emit(state.copyWith(detectingLocation: true, clearError: true));
  }

  void finishLocationDetection({double? latitude, double? longitude}) {
    emit(
      state.copyWith(
        detectingLocation: false,
        latitude: latitude,
        longitude: longitude,
        status: CheckoutStatus.editing,
      ),
    );
  }
}
