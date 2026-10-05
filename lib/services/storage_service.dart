import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/mock_project.dart';

/// Persists projects as individual JSON files inside the app documents dir.
/// Files are human-readable and git-committable so mock sets can be shared.
class StorageService {
  Directory? _projectsDir;

  /// Pending write per file, so overlapping debounced saves run in order.
  final Map<String, Future<void>> _writes = {};

  Future<Directory> _dir() async {
    if (_projectsDir != null) return _projectsDir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'MockStudio', 'projects'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _projectsDir = dir;
    return dir;
  }

  Future<String> projectsDirPath() async => (await _dir()).path;

  /// Loads every project file from the projects directory.
  Future<List<MockProject>> loadAll() async {
    final dir = await _dir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList();
    final projects = <MockProject>[];
    for (final f in files) {
      try {
        final project = await loadFile(f.path);
        projects.add(project);
      } catch (_) {
        // Skip unreadable/corrupt files rather than failing the whole load.
      }
    }
    projects.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return projects;
  }

  Future<MockProject> loadFile(String filePath) async {
    final contents = await File(filePath).readAsString();
    final json = jsonDecode(contents) as Map<String, dynamic>;
    return MockProject.fromJson(json, filePath: filePath);
  }

  /// Saves a project, assigning a file path on first save. Returns the path.
  Future<String> save(MockProject project) async {
    final dir = await _dir();
    project.filePath ??= p.join(
      dir.path,
      '${_slug(project.name)}-${project.id.substring(0, 8)}.json',
    );
    final encoder = const JsonEncoder.withIndent('  ');
    await _atomicWrite(project.filePath!, encoder.convert(project.toJson()));
    return project.filePath!;
  }

  /// Exports a project to an arbitrary path chosen by the user.
  Future<void> exportTo(MockProject project, String destinationPath) async {
    final encoder = const JsonEncoder.withIndent('  ');
    await File(
      destinationPath,
    ).writeAsString(encoder.convert(project.toJson()));
  }

  /// Writes via a temp file + rename so a crash mid-save can't leave a
  /// truncated project file (which loadAll would silently skip).
  Future<void> _atomicWrite(String path, String contents) {
    final previous = _writes[path] ?? Future<void>.value();
    late final Future<void> next;
    next = previous
        .then((_) async {
          final tmp = File('$path.tmp');
          await tmp.writeAsString(contents, flush: true);
          await tmp.rename(path);
        })
        .whenComplete(() {
          if (identical(_writes[path], next)) _writes.remove(path);
        });
    _writes[path] = next;
    return next;
  }

  Future<void> delete(MockProject project) async {
    if (project.filePath == null) return;
    final f = File(project.filePath!);
    if (await f.exists()) await f.delete();
  }

  String _slug(String name) {
    final s = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isEmpty ? 'project' : s;
  }
}
