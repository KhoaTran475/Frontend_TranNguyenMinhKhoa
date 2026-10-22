import 'package:flutter/material.dart';

enum FieldKind { text, email, decimal, integer, reference }

class ResourceField {
  const ResourceField(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.max = 150,
    this.minValue,
    this.maxValue,
    this.reference,
  });
  final String key, label;
  final FieldKind kind;
  final int max;
  final double? minValue, maxValue;
  final String? reference;
}

class ResourceSchema {
  const ResourceSchema(
    this.path,
    this.title,
    this.singular,
    this.icon,
    this.fields,
  );
  final String path, title, singular;
  final IconData icon;
  final List<ResourceField> fields;

  static const students = ResourceSchema(
    'students',
    'Sinh viên',
    'sinh viên',
    Icons.school_outlined,
    [
      ResourceField('studentCode', 'Mã sinh viên', max: 40),
      ResourceField('fullName', 'Họ và tên'),
      ResourceField('email', 'Email', kind: FieldKind.email, max: 256),
    ],
  );
  static const lecturers = ResourceSchema(
    'lecturers',
    'Giảng viên',
    'giảng viên',
    Icons.co_present_outlined,
    [
      ResourceField('lecturerCode', 'Mã giảng viên', max: 40),
      ResourceField('fullName', 'Họ và tên'),
      ResourceField('email', 'Email', kind: FieldKind.email, max: 256),
    ],
  );
  static const subjects = ResourceSchema(
    'subjects',
    'Môn học',
    'môn học',
    Icons.menu_book_outlined,
    [
      ResourceField('code', 'Mã môn học', max: 40),
      ResourceField('name', 'Tên môn học'),
    ],
  );
  static const rooms = ResourceSchema(
    'rooms',
    'Phòng học',
    'phòng học',
    Icons.meeting_room_outlined,
    [
      ResourceField('code', 'Mã phòng', max: 40),
      ResourceField('name', 'Tên phòng'),
      ResourceField(
        'latitude',
        'Vĩ độ',
        kind: FieldKind.decimal,
        minValue: -90,
        maxValue: 90,
      ),
      ResourceField(
        'longitude',
        'Kinh độ',
        kind: FieldKind.decimal,
        minValue: -180,
        maxValue: 180,
      ),
      ResourceField(
        'allowedRadiusMeters',
        'Bán kính điểm danh (m)',
        kind: FieldKind.decimal,
        minValue: 1,
        maxValue: 5000,
      ),
    ],
  );
  static const classes = ResourceSchema(
    'classes',
    'Lớp học phần',
    'lớp học phần',
    Icons.groups_outlined,
    [
      ResourceField('code', 'Mã lớp', max: 40),
      ResourceField('name', 'Tên lớp'),
      ResourceField(
        'subjectId',
        'Môn học',
        kind: FieldKind.reference,
        reference: 'subjects',
      ),
      ResourceField(
        'lecturerId',
        'Giảng viên',
        kind: FieldKind.reference,
        reference: 'lecturers',
      ),
    ],
  );
  static const all = [students, lecturers, subjects, rooms, classes];
}

String recordTitle(Map<String, dynamic> item) =>
    (item['fullName'] ??
            item['name'] ??
            item['code'] ??
            'Bản ghi #${item['id']}')
        .toString();

String recordSubtitle(Map<String, dynamic> item) => [
  item['studentCode'] ?? item['lecturerCode'] ?? item['code'],
  item['email'],
].where((value) => value != null).join(' • ');
