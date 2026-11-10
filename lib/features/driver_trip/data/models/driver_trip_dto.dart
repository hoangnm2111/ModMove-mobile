import '../../domain/entities/trip_models.dart';

abstract final class DriverTripDto {
  static ActiveTrip parse(Map data) {
    final cargo = data['cargo'] as Map;
    final proof = data['proof'] as Map?;
    final histories = data['statusHistories'] as List? ?? [];
    DateTime? time(String key) => DateTime.tryParse('${data[key]}');
    DateTime? transition(String status) {
      final row = histories.where((e) => e['toStatus'] == status).lastOrNull;
      return row == null ? null : DateTime.tryParse('${row['changedAt']}');
    }

    final handover = data['handoverPoint'] as Map?;
    int number(String key) => (data[key] as num).round();
    final stage = switch (data['orderStatus']) {
      'Accepted' => TripStage.accepted,
      'Arrived' => TripStage.arrived,
      'PickedUp' => TripStage.pickedUp,
      'InTransit' => TripStage.inTransit,
      'Delivered' => TripStage.delivered,
      'Completed' => TripStage.completed,
      'Cancelled' => TripStage.cancelled,
      _ => throw const TripFailure(
        'Trạng thái chuyến chưa được hỗ trợ. Hãy cập nhật ứng dụng.',
      ),
    };
    return ActiveTrip(
      job: DeliveryJob(
        id: '${data['id']}',
        orderCode: '${data['orderCode']}',
        pickup: data['pickupAddress'] as String,
        dropoff: data['dropoffAddress'] as String,
        pickupPoint: GeoPoint(
          (data['pickupLatitude'] as num).toDouble(),
          (data['pickupLongitude'] as num).toDouble(),
        ),
        dropoffPoint: GeoPoint(
          (data['dropoffLatitude'] as num).toDouble(),
          (data['dropoffLongitude'] as num).toDouble(),
        ),
        handoverPoint: handover == null
            ? null
            : GeoPoint(
                (handover['latitude'] as num).toDouble(),
                (handover['longitude'] as num).toDouble(),
              ),
        createdAt: time('createdAt')!,
        distanceKm: (data['estimatedDistanceKm'] as num).toDouble(),
        minutes: number('estimatedDurationMin'),
        boxes: (cargo['quantity'] as num).toInt(),
        weightKg: (cargo['weightKg'] as num).round(),
        fare: number('totalFee'),
        commission: number('commissionAmount'),
        distanceFee: number('distanceFee'),
        serviceFee: number('serviceFee'),
        discount: number('discountAmount'),
        commissionRate: (data['commissionRate'] as num).toDouble(),
        payment: data['paymentMethod'] == 'PayOS'
            ? PaymentMethod.payos
            : data['payerRole'] == 'Receiver'
            ? PaymentMethod.cashReceiver
            : PaymentMethod.cashSender,
        paid: data['paymentStatus'] == 'Paid',
        fragile: cargo['cargoType'] == 'Fragile',
        vehicle: '${data['vehicleTypeName']}',
        customerName: '${data['customerName']}',
        customerPhone: '${data['customerPhone']}',
        receiverName: '${data['receiverName']}',
        receiverPhone: '${data['receiverPhone']}',
        cargoDescription:
            '${cargo['cargoTypeName'] ?? cargo['cargoType']} · ${cargo['lengthCm']} × ${cargo['widthCm']} × ${cargo['heightCm']} cm',
        notes: '${cargo['specialNotes'] ?? ''}',
        photoUrls: (cargo['photoUrls'] as List).cast<String>(),
        loadingService: data['hasLoadingService'] == true,
      ),
      stage: stage,
      review: switch (proof?['proofStatus']) {
        'Pending' => EvidenceReview.pending,
        'Verified' => EvidenceReview.approved,
        'Rejected' => EvidenceReview.rejected,
        _ => EvidenceReview.none,
      },
      attempts: (proof?['pickupSubmissionCount'] as num?)?.toInt() ?? 0,
      reason:
          proof?['rejectionReason'] as String? ??
          data['cancellationReason'] as String?,
      arrivedAt: transition('Arrived'),
      submittedAt: transition('PickedUp'),
      cashCollected: data['paymentStatus'] == 'Paid',
      evidence: [
        for (final (i, url)
            in (proof?['pickupPhotoUrls'] as List? ?? []).indexed)
          UploadedEvidence(
            i == 0 ? CargoPhotoKind.overall : CargoPhotoKind.secured,
            url as String,
          ),
      ],
      deliveryPhotoUrl: proof?['deliveryPhotoUrl'] as String?,
      deliveredAt: time('deliveredAt'),
      completedAt: time('completedAt'),
      incidents: [
        for (final incident in data['incidents'] as List? ?? [])
          TripIncident(
            '${incident['id']}',
            '${incident['description']}',
            '${incident['resolutionStatus']}',
            incident['resolutionNote'] as String?,
          ),
      ],
    );
  }
}
