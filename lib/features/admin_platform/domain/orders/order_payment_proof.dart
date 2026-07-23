enum OrderPaymentProofKind { image, pdf }

class OrderPaymentProof {
  const OrderPaymentProof({required this.uri, required this.kind});

  final Uri uri;
  final OrderPaymentProofKind kind;
}
