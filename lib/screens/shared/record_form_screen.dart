import 'package:flutter/material.dart';

import '../../config/validators.dart';
import '../../models/resource_schema.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../widgets/feedback_panel.dart';
import '../../widgets/page_body.dart';

class RecordFormScreen extends StatefulWidget {
  const RecordFormScreen({
    super.key,
    required this.service,
    required this.schema,
    this.record,
  });
  final DataService service;
  final ResourceSchema schema;
  final Map<String, dynamic>? record;
  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _selected = <String, int?>{};
  final _options = <String, List<Map<String, dynamic>>>{};
  bool _loading = true, _saving = false;
  String? _loadError, _error;
  @override
  void initState() {
    super.initState();
    for (final field in widget.schema.fields) {
      if (field.kind == FieldKind.reference) {
        _selected[field.key] = widget.record?[field.key] as int?;
      } else {
        _controllers[field.key] = TextEditingController(
          text: widget.record?[field.key]?.toString() ?? '',
        );
      }
    }
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      for (final field in widget.schema.fields.where(
        (field) => field.reference != null,
      )) {
        _options[field.key] = await widget.service.options(field.reference!);
      }
    } catch (error) {
      _loadError = describeError(error);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final value in _controllers.values) {
      value.dispose();
    }
    super.dispose();
  }

  String? _validate(ResourceField field, String? value) {
    if (field.kind == FieldKind.email) return Validators.email(value);
    if (field.kind == FieldKind.decimal || field.kind == FieldKind.integer) {
      final number = num.tryParse((value ?? '').trim());
      if (number == null ||
          !number.isFinite ||
          (field.kind == FieldKind.integer && number != number.toInt())) {
        return 'Nhập số hợp lệ.';
      }
      if ((field.minValue != null && number < field.minValue!) ||
          (field.maxValue != null && number > field.maxValue!)) {
        return 'Giá trị từ ${field.minValue} đến ${field.maxValue}.';
      }
      return null;
    }
    return Validators.requiredText(value, max: field.max);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, Object?>{};
    for (final field in widget.schema.fields) {
      if (field.kind == FieldKind.reference) {
        body[field.key] = _selected[field.key];
      } else {
        final value = _controllers[field.key]!.text.trim();
        body[field.key] = field.kind == FieldKind.decimal
            ? double.parse(value)
            : field.kind == FieldKind.integer
            ? int.parse(value)
            : value;
      }
    }
    try {
      if (widget.record == null) {
        await widget.service.api.post(widget.schema.path, body: body);
      } else {
        await widget.service.api.put(
          '${widget.schema.path}/${widget.record!['id']}',
          body: body,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = describeError(error);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.record == null ? 'Thêm' : 'Sửa'} ${widget.schema.singular}',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? PageBody(
              children: [
                FeedbackPanel(message: _loadError!, retry: _loadOptions),
              ],
            )
          : PageBody(
              children: [
                if (_error != null) FeedbackPanel(message: _error!),
                if (widget.record?['userId'] != null)
                  const FeedbackPanel(
                    error: false,
                    message: 'Hồ sơ đã liên kết tài khoản. Backend có thể từ chối thay đổi định danh.',
                  ),
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      for (final field in widget.schema.fields)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: field.kind == FieldKind.reference
                              ? DropdownButtonFormField<int>(
                                  initialValue:
                                      (_options[field.key] ?? []).any(
                                        (item) =>
                                            item['id'] == _selected[field.key],
                                      )
                                      ? _selected[field.key]
                                      : null,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: field.label,
                                  ),
                                  items: (_options[field.key] ?? [])
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item['id'] as int,
                                          child: Text(
                                            '${recordTitle(item)} (${recordSubtitle(item)})',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _saving
                                      ? null
                                      : (value) => _selected[field.key] = value,
                                  validator: (value) => value == null
                                      ? 'Vui lòng chọn ${field.label.toLowerCase()}.'
                                      : null,
                                )
                              : TextFormField(
                                  controller: _controllers[field.key],
                                  enabled: !_saving,
                                  decoration: InputDecoration(
                                    labelText: field.label,
                                  ),
                                  keyboardType: field.kind == FieldKind.decimal
                                      ? const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        )
                                      : field.kind == FieldKind.email
                                      ? TextInputType.emailAddress
                                      : TextInputType.text,
                                  validator: (value) => _validate(field, value),
                                ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Đang lưu…' : 'Lưu thông tin'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}
