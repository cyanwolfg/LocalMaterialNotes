import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:fleather/fleather.dart';
import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../common/constants/constants.dart';
import '../../common/preferences/enums/sort_method.dart';
import '../../common/preferences/preference_key.dart';
import '../label/label.dart';
import '../../utils/encryption_utils.dart';

part 'note.g.dart';

// ignore_for_file: must_be_immutable

List<String> _labelToJson(IsarLinks<Label> labels) => labels.map((label) => label.name).toList();

/// Rich text note with title, content and metadata.
@JsonSerializable()
@Collection(inheritance: false)
class Note extends Equatable implements Comparable<Note> {
  /// Empty content in fleather data representation.
  static const String _emptyContent = '[{"insert":"\\n"}]';

  /// The ID of the note.
  ///
  /// Excluded from JSON because it's fully managed by Isar.
  @JsonKey(includeFromJson: false, includeToJson: false)
  Id id = Isar.autoIncrement;

  /// Whether the note is selected.
  ///
  /// Excluded from JSON because it's only needed temporarily during multi-selection.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @ignore
  bool selected = false;

  /// Whether the note is deleted.
  @Index()
  bool deleted;

  /// Whether the note is pinned.
  @Index()
  bool pinned;

  /// The date of creation of the note.
  DateTime createdTime;

  /// The last date of edition of the note, including events such as toggling the pinned state.
  DateTime editedTime;

  /// The title of the note.
  String title;

  /// The content of the note, as rich text in the fleather representation.
  String content;

  /// The labels used to categorize the note.
  @JsonKey(includeFromJson: false, includeToJson: true, toJson: _labelToJson)
  IsarLinks<Label> labels = IsarLinks<Label>();

  /// Default constructor of a note.
  Note({
    required this.deleted,
    required this.pinned,
    required this.createdTime,
    required this.editedTime,
    required this.title,
    required this.content,
  });

  /// Note with empty title and content.
  factory Note.empty() => Note(
        deleted: false,
        pinned: false,
        createdTime: DateTime.now(),
        editedTime: DateTime.now(),
        title: '',
        content: _emptyContent,
      );

  /// Note with the provided [content].
  factory Note.content(String content) => Note(
        deleted: false,
        pinned: false,
        createdTime: DateTime.now(),
        editedTime: DateTime.now(),
        title: '',
        content: content,
      );

  /// Note from [json] data.
  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);

  /// Note from [json] data, encrypted with [password].
  factory Note.fromJsonEncrypted(Map<String, dynamic> json, String password) => _$NoteFromJson(json)
    ..title = (json['title'] as String).isEmpty ? '' : EncryptionUtils().decrypt(password, json['title'] as String)
    ..content = EncryptionUtils().decrypt(password, json['content'] as String);

  /// Note to JSON.
  Map<String, dynamic> toJson() => _$NoteToJson(this);

  /// Returns this note with the [title] and the [content] encrypted with the [password].
  Note encrypted(String password) => this
    ..title = isTitleEmpty ? '' : EncryptionUtils().encrypt(password, title)
    ..content = EncryptionUtils().encrypt(password, content);

  /// Returns the visible [labels] of the note as a sorted list.
  @ignore
  List<Label> get labelsVisibleSorted => labels.toList().where((label) => label.visible).sorted();

  /// Returns the names of the visible [labels] of the note as a sorted list.
  @ignore
  List<String> get labelsNamesVisibleSorted => labelsVisibleSorted.map((label) => label.name).toList();

  /// Note content as plain text.
  @ignore
  String get plainText => document.toPlainText();

  /// Note content for the preview of the notes tiles.
  ///
  /// Formats the following rich text elements:
  ///   - Checkboxes (TODO: only partially, see https://github.com/maelchiotti/LocalMaterialNotes/issues/121)
  ///
  /// Skips the following rich text elements:
  ///   - Horizontal rules
  @ignore
  String get contentPreview {
    var content = '';

    for (final child in document.root.children) {
      final operations = child.toDelta().toList();

      for (var i = 0; i < operations.length; i++) {
        final operation = operations[i];

        // Skip horizontal rules
        if (operation.data is Map &&
            (operation.data as Map).containsKey('_type') &&
            (operation.data as Map)['_type'] == 'hr') {
          continue;
        }

        final nextOperation = i == operations.length - 1 ? null : operations[i + 1];

        final checklist = nextOperation != null &&
            nextOperation.attributes != null &&
            nextOperation.attributes!.containsKey('block') &&
            nextOperation.attributes!['block'] == 'cl';

        if (checklist) {
          final checked = nextOperation.attributes!.containsKey('checked');
          content += '${checked ? '✅' : '⬜'} ${operation.value}';
        } else {
          content += operation.value.toString();
        }
      }
    }

    return content.trim();
  }

  /// Note content as markdown.
  @ignore
  String get markdown => parchmentMarkdownCodec.encode(document);

  /// Note title and content to be shared as a single text.
  ///
  /// Uses the [contentPreview] for the content.
  @ignore
  String get shareText => '$title\n\n$contentPreview';

  /// Document containing the fleather content representation.
  @ignore
  ParchmentDocument get document => ParchmentDocument.fromJson(jsonDecode(content) as List);

  /// Whether the title is empty.
  @ignore
  bool get isTitleEmpty => title.isEmpty;

  /// Whether the content is empty.
  @ignore
  bool get isContentEmpty => content == _emptyContent;

  /// Whether the preview of the content is empty.
  @ignore
  bool get isContentPreviewEmpty => contentPreview.isEmpty;

  /// Whether the note is empty.
  ///
  /// Checks both the title and the content.
  @ignore
  bool get isEmpty => isTitleEmpty && isContentEmpty;

  /// Notes are sorted according to:
  ///   1. Their pin state.
  ///   2. The sort method chosen by the user.
  @override
  int compareTo(Note other) {
    final sortMethod = SortMethod.fromPreference();
    final sortAscending = PreferenceKey.sortAscending.getPreferenceOrDefault();

    if (pinned && !other.pinned) {
      return -1;
    } else if (!pinned && other.pinned) {
      return 1;
    } else {
      switch (sortMethod) {
        case SortMethod.createdDate:
          return sortAscending ? createdTime.compareTo(other.createdTime) : other.createdTime.compareTo(createdTime);
        case SortMethod.editedDate:
          return sortAscending ? editedTime.compareTo(other.editedTime) : other.editedTime.compareTo(editedTime);
        case SortMethod.title:
          return sortAscending ? title.compareTo(other.title) : other.title.compareTo(title);
        default:
          throw Exception('The sort method is not valid: $sortMethod');
      }
    }
  }

  @override
  @ignore
  List<Object?> get props => [id];
}
