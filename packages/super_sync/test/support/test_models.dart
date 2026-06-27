import 'package:meta/meta.dart';
import 'package:super_sync/super_sync.dart';

/// Three unrelated models — proving the engine knows nothing about any of them.

@immutable
class Todo {
  const Todo({required this.id, required this.title, this.done = false});
  final String id;
  final String title;
  final bool done;

  Todo copyWith({String? title, bool? done}) =>
      Todo(id: id, title: title ?? this.title, done: done ?? this.done);

  @override
  bool operator ==(Object o) =>
      o is Todo && o.id == id && o.title == title && o.done == done;
  @override
  int get hashCode => Object.hash(id, title, done);
}

@immutable
class User {
  const User({required this.id, required this.name});
  final String id;
  final String name;

  @override
  bool operator ==(Object o) => o is User && o.id == id && o.name == name;
  @override
  int get hashCode => Object.hash(id, name);
}

@immutable
class Message {
  const Message({required this.id, required this.text});
  final String id;
  final String text;

  @override
  bool operator ==(Object o) => o is Message && o.id == id && o.text == text;
  @override
  int get hashCode => Object.hash(id, text);
}

class TodoSyncAdapter implements SyncEntityAdapter<Todo> {
  @override
  String get type => 'todo';
  @override
  String idOf(Todo v) => v.id;
  @override
  Map<String, Object?> encode(Todo v) => {
    'id': v.id,
    'title': v.title,
    'done': v.done,
  };
  @override
  Todo decode(Map<String, Object?> d) => Todo(
    id: d['id']! as String,
    title: d['title']! as String,
    done: (d['done'] as bool?) ?? false,
  );
}

class UserSyncAdapter implements SyncEntityAdapter<User> {
  @override
  String get type => 'user';
  @override
  String idOf(User v) => v.id;
  @override
  Map<String, Object?> encode(User v) => {'id': v.id, 'name': v.name};
  @override
  User decode(Map<String, Object?> d) =>
      User(id: d['id']! as String, name: d['name']! as String);
}

class MessageSyncAdapter implements SyncEntityAdapter<Message> {
  @override
  String get type => 'message';
  @override
  String idOf(Message v) => v.id;
  @override
  Map<String, Object?> encode(Message v) => {'id': v.id, 'text': v.text};
  @override
  Message decode(Map<String, Object?> d) =>
      Message(id: d['id']! as String, text: d['text']! as String);
}
