import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Nhãn tiếng Việt + màu cho enum backend (dịch từ ModMove-web/src/api/labels.ts).
class Tone {
  const Tone(this.label, this.fg, this.bg);
  final String label;
  final Color fg, bg;
}

const _blue = Color(0xFF1D4ED8), _blueBg = Color(0xFFEAF1FF);
const _indigo = Color(0xFF4338CA), _indigoBg = Color(0xFFEEF0FF);
const _purple = Color(0xFF7E22CE), _purpleBg = Color(0xFFF5EBFF);
const _sky = Color(0xFF0369A1), _skyBg = Color(0xFFE6F4FB);
const _teal = Color(0xFF0F766E), _tealBg = Color(0xFFE4F6F3);
const _slate = AppColors.secondary, _slateBg = AppColors.pale;

const orderStatusTone = <String, Tone>{
  'Pending': Tone('Đang tìm tài xế', AppColors.amber, AppColors.amberBg),
  'Accepted': Tone('Tài xế đã nhận', _blue, _blueBg),
  'Arrived': Tone('Đã đến điểm lấy', _indigo, _indigoBg),
  'PickedUp': Tone('Đã lấy hàng', _purple, _purpleBg),
  'InTransit': Tone('Đang giao hàng', _sky, _skyBg),
  'Delivered': Tone('Đã giao hàng', _teal, _tealBg),
  'Completed': Tone('Hoàn thành', AppColors.green, AppColors.greenBg),
  'Cancelled': Tone('Đã huỷ', _slate, _slateBg),
};

/// GB-31: đơn PayOS chưa thanh toán chưa được gửi tới tài xế.
const awaitingPaymentTone = Tone('Chờ thanh toán', AppColors.red, AppColors.redBg);

const paymentStatusTone = <String, Tone>{
  'Unpaid': Tone('Chưa thanh toán', AppColors.red, AppColors.redBg),
  'Paid': Tone('Đã thanh toán', AppColors.green, AppColors.greenBg),
};

const paymentMethodLabel = {'Cash': 'Tiền mặt', 'PayOS': 'PayOS (QR / chuyển khoản)'};
const payerRoleLabel = {'Sender': 'Người gửi trả khi lấy hàng', 'Receiver': 'Người nhận trả khi giao hàng'};

const incidentTypeLabel = {
  'VehicleBreakdown': 'Hỏng xe',
  'DamagedCargo': 'Hư hỏng hàng hoá',
  'Accident': 'Tai nạn',
  'Other': 'Khác (trễ, sai tuyến, vắng mặt…)',
};
const incidentStatusTone = <String, Tone>{
  'Open': Tone('Mới', AppColors.red, AppColors.redBg),
  'InProgress': Tone('Đang xử lý', AppColors.amber, AppColors.amberBg),
  'Resolved': Tone('Đã xử lý', AppColors.green, AppColors.greenBg),
  'Cancelled': Tone('Đã huỷ', _slate, _slateBg),
};
const incidentDecisionLabel = {'ContinueTrip': 'Tiếp tục chuyến', 'ReassignDriver': 'Đổi tài xế', 'CancelOrder': 'Huỷ đơn'};

const refundSourceLabel = {'Cancellation': 'Hoàn do huỷ đơn', 'Incident': 'Hoàn do sự cố', 'Complaint': 'Khiếu nại'};
const refundStatusTone = <String, Tone>{
  'Requested': Tone('Đang xem xét', AppColors.amber, AppColors.amberBg),
  'Approved': Tone('Đã duyệt – chờ chi', _blue, _blueBg),
  'Rejected': Tone('Từ chối', AppColors.red, AppColors.redBg),
  'Processed': Tone('Đã chuyển khoản', AppColors.green, AppColors.greenBg),
  'Failed': Tone('Chi trả lỗi', AppColors.red, AppColors.redBg),
  'Withdrawn': Tone('Đã rút', _slate, _slateBg),
};
const proofStatusTone = <String, Tone>{
  'Pending': Tone('Chờ bạn duyệt', AppColors.amber, AppColors.amberBg),
  'Verified': Tone('Đã duyệt', AppColors.green, AppColors.greenBg),
  'Rejected': Tone('Đã từ chối', AppColors.red, AppColors.redBg),
};
const changedByLabel = {'Customer': 'Khách hàng', 'Driver': 'Tài xế', 'Dispatcher': 'Điều phối', 'Administrator': 'Admin', 'System': 'Hệ thống'};

Tone toneOf(Map<String, Tone> map, String key) => map[key] ?? Tone(key, _slate, _slateBg);
