import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../bloc/active_trip_bloc.dart';

Future<void> showTripIncident(BuildContext context) async {
  final message = await showDialog<String>(
    context: context,
    builder: (_) => const _IncidentDialog(),
  );
  if (message != null && context.mounted) {
    context.read<ActiveTripBloc>().add(IncidentReported(message));
  }
}

class _IncidentDialog extends StatefulWidget {
  const _IncidentDialog();
  @override
  State<_IncidentDialog> createState() => _IncidentDialogState();
}

class _IncidentDialogState extends State<_IncidentDialog> {
  final _text = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Báo sự cố'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _text,
        minLines: 3,
        maxLines: 5,
        maxLength: 500,
        decoration: const InputDecoration(
          hintText: 'Mô tả vấn đề để điều phối hỗ trợ…',
        ),
        validator: (v) =>
            (v?.trim().length ?? 0) < 10 ? 'Nhập ít nhất 10 ký tự.' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      PrimaryButton(
        'Gửi yêu cầu hỗ trợ',
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _text.text.trim());
          }
        },
      ),
    ],
  );
}
