import 'package:flutter/material.dart';

import '../../models/resource_schema.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../widgets/feedback_panel.dart';
import 'class_detail_screen.dart';
import 'record_form_screen.dart';

class ResourceListScreen extends StatefulWidget {
  const ResourceListScreen({
    super.key,
    required this.service,
    required this.schema,
    this.canWrite = false,
    this.path,
    this.canManageSessions = false,
    this.isAdmin = false,
  });
  final DataService service;
  final ResourceSchema schema;
  final bool canWrite, canManageSessions, isAdmin;
  final String? path;
  @override
  State<ResourceListScreen> createState() => _ResourceListScreenState();
}

class _ResourceListScreenState extends State<ResourceListScreen> {
  final _search = TextEditingController();
  RecordPage? _data;
  String? _error;
  String _term = '';
  bool _loading = false, _mutating = false;
  int _page = 1, _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.service.list(
        widget.path ?? widget.schema.path,
        page: _page,
        search: _term,
      );
      if (mounted && generation == _generation) setState(() => _data = data);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = describeError(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _edit([Map<String, dynamic>? record]) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      final fresh = record == null
          ? null
          : await widget.service.detail(
              '${widget.schema.path}/${record['id']}',
            );
      if (!mounted) return;
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RecordFormScreen(
            service: widget.service,
            schema: widget.schema,
            record: fresh,
          ),
        ),
      );
      if (changed == true && mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    if (_mutating) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa ${widget.schema.singular}?'),
        content: Text(
          'Bạn muốn xóa “${recordTitle(record)}”? Dữ liệu đã sử dụng có thể không được phép xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted || _mutating) return;
    setState(() => _mutating = true);
    try {
      await widget.service.api.delete('${widget.schema.path}/${record['id']}');
      if (_data?.items.length == 1 && _page > 1) _page--;
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _detail(Map<String, dynamic> item) async {
    if (widget.schema.path == 'classes') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClassDetailScreen(
            service: widget.service,
            courseClass: item,
            isAdmin: widget.isAdmin,
            canManage: widget.canManageSessions,
          ),
        ),
      );
    } else {
      if (_mutating) return;
      setState(() => _mutating = true);
      try {
        final data = await widget.service.detail(
          '${widget.schema.path}/${item['id']}',
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(recordTitle(data)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final field in widget.schema.fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('${field.label}: ${data[field.key]}'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      } catch (error) {
        if (mounted) setState(() => _error = describeError(error));
      } finally {
        if (mounted) setState(() => _mutating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.schema.title),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: widget.canWrite
        ? FloatingActionButton.extended(
            onPressed: _mutating ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Thêm mới'),
          )
        : null,
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            maxLength: 150,
            decoration: InputDecoration(
              hintText: 'Tìm theo mã hoặc tên',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Tìm kiếm',
                icon: const Icon(Icons.arrow_forward),
                onPressed: () {
                  _page = 1;
                  _term = _search.text;
                  _load();
                },
              ),
            ),
            onSubmitted: (_) {
              _page = 1;
              _term = _search.text;
              _load();
            },
          ),
        ),
        if (_mutating) const LinearProgressIndicator(),
        if (_error != null) FeedbackPanel(message: _error!, retry: _load),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _data == null || _data!.items.isEmpty
              ? const Center(child: Text('Chưa có dữ liệu.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                    itemCount: _data!.items.length,
                    itemBuilder: (context, index) {
                      final item = _data!.items[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(widget.schema.icon),
                          ),
                          title: Text(recordTitle(item)),
                          subtitle: Text(recordSubtitle(item)),
                          onTap: () => _detail(item),
                          trailing: widget.canWrite
                              ? PopupMenuButton<String>(
                                  enabled: !_mutating,
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _edit(item);
                                    } else {
                                      _delete(item);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Sửa'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Xóa'),
                                    ),
                                  ],
                                )
                              : const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _loading || _page <= 1
                      ? null
                      : () {
                          _page--;
                          _load();
                        },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Trang $_page • ${_data?.total ?? 0} bản ghi'),
                IconButton(
                  onPressed: _loading || !(_data?.hasNext ?? false)
                      ? null
                      : () {
                          _page++;
                          _load();
                        },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
