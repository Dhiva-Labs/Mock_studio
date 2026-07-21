import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/endpoint.dart';
import '../models/mock_project.dart';
import '../models/request_log.dart';
import '../services/mock_server.dart';
import '../services/network_info.dart';
import '../services/sample_data.dart';
import '../services/storage_service.dart';
import '../services/tunnel_service.dart';

/// Central application state: projects, selection, running servers and logs.
class AppState extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final TunnelService tunnel = TunnelService();

  final List<MockProject> projects = [];
  final Map<String, MockServer> _servers = {};
  final Map<String, List<RequestLog>> _logs = {};
  final List<RecordedCall> pendingRecordings = [];

  String? selectedProjectId;
  String? selectedEndpointId;

  List<String> lanAddresses = [];
  ThemeMode themeMode = ThemeMode.system;
  bool guideMode = true; // extra hints for newcomers
  int maxLogsPerProject = 500;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  AppState() {
    tunnel.onChange.listen((_) => notifyListeners());
  }

  // ---- lifecycle ----------------------------------------------------------

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 0;
    themeMode =
        ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)];
    guideMode = prefs.getBool('guideMode') ?? true;

    lanAddresses = await NetworkInfo.lanAddresses();

    final loaded = await _storage.loadAll();
    projects.addAll(loaded);

    if (projects.isEmpty && (prefs.getBool('seeded') ?? false) == false) {
      final sample = SampleData.welcomeProject();
      await _storage.save(sample);
      projects.add(sample);
      await prefs.setBool('seeded', true);
    }

    if (projects.isNotEmpty) {
      selectedProjectId = projects.first.id;
      if (projects.first.endpoints.isNotEmpty) {
        selectedEndpointId = projects.first.endpoints.first.id;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  Future<void> setGuideMode(bool on) async {
    guideMode = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guideMode', on);
    notifyListeners();
  }

  Future<void> refreshLan() async {
    lanAddresses = await NetworkInfo.lanAddresses();
    notifyListeners();
  }

  // ---- selection ----------------------------------------------------------

  MockProject? get selectedProject {
    if (selectedProjectId == null) return null;
    try {
      return projects.firstWhere((p) => p.id == selectedProjectId);
    } catch (_) {
      return null;
    }
  }

  Endpoint? get selectedEndpoint {
    final p = selectedProject;
    if (p == null || selectedEndpointId == null) return null;
    try {
      return p.endpoints.firstWhere((e) => e.id == selectedEndpointId);
    } catch (_) {
      return null;
    }
  }

  void selectProject(String id) {
    selectedProjectId = id;
    final p = selectedProject;
    selectedEndpointId = p != null && p.endpoints.isNotEmpty
        ? p.endpoints.first.id
        : null;
    notifyListeners();
  }

  void selectEndpoint(String? id) {
    selectedEndpointId = id;
    notifyListeners();
  }

  // ---- projects -----------------------------------------------------------

  Future<MockProject> createProject(String name, {int port = 8080}) async {
    // Ensure unique-ish default port.
    final usedPorts = projects.map((p) => p.port).toSet();
    var p = port;
    while (usedPorts.contains(p)) {
      p++;
    }
    final project = MockProject(name: name, port: p);
    await _storage.save(project);
    projects.add(project);
    _sortProjects();
    selectProject(project.id);
    notifyListeners();
    return project;
  }

  Future<void> addProject(MockProject project) async {
    // Avoid port collision.
    final usedPorts = projects.map((p) => p.port).toSet();
    while (usedPorts.contains(project.port)) {
      project.port++;
    }
    await _storage.save(project);
    projects.add(project);
    _sortProjects();
    selectProject(project.id);
    notifyListeners();
  }

  Future<void> saveProject(MockProject project) async {
    await _storage.save(project);
    notifyListeners();
  }

  Future<void> deleteProject(MockProject project) async {
    await stopServer(project);
    await _storage.delete(project);
    projects.removeWhere((p) => p.id == project.id);
    _logs.remove(project.id);
    if (selectedProjectId == project.id) {
      selectedProjectId = projects.isNotEmpty ? projects.first.id : null;
      selectedEndpointId = null;
    }
    notifyListeners();
  }

  Future<String> exportProject(MockProject project, String destination) async {
    await _storage.exportTo(project, destination);
    return destination;
  }

  Future<MockProject> importProjectFile(String path) async {
    final project = await _storage.loadFile(path);
    // Give it a fresh identity so importing a copy doesn't clash.
    final fresh = MockProject.fromJson(project.toJson());
    fresh.name = '${project.name} (imported)';
    await addProject(fresh);
    return fresh;
  }

  void _sortProjects() {
    projects.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }

  String? projectsDirPathCache;
  Future<String> projectsDir() async {
    projectsDirPathCache ??= await _storage.projectsDirPath();
    return projectsDirPathCache!;
  }

  // ---- endpoints ----------------------------------------------------------

  Future<void> addEndpoint(MockProject project, Endpoint endpoint) async {
    project.endpoints.add(endpoint);
    selectedEndpointId = endpoint.id;
    await saveProject(project);
  }

  Future<void> deleteEndpoint(MockProject project, Endpoint endpoint) async {
    project.endpoints.removeWhere((e) => e.id == endpoint.id);
    if (selectedEndpointId == endpoint.id) {
      selectedEndpointId = project.endpoints.isNotEmpty
          ? project.endpoints.first.id
          : null;
    }
    await saveProject(project);
  }

  Future<void> duplicateEndpoint(MockProject project, Endpoint endpoint) async {
    final copy = endpoint.copy();
    final idx = project.endpoints.indexOf(endpoint);
    project.endpoints.insert(idx + 1, copy);
    selectedEndpointId = copy.id;
    await saveProject(project);
  }

  // ---- server control -----------------------------------------------------

  bool isRunning(String projectId) => _servers[projectId]?.isRunning ?? false;

  MockServer? serverFor(String projectId) => _servers[projectId];

  List<RequestLog> logsFor(String projectId) => _logs[projectId] ?? const [];

  Future<String?> startServer(MockProject project) async {
    if (isRunning(project.id)) return null;
    final server = MockServer(
      project: project,
      onLog: (log) => _appendLog(project.id, log),
      onRecord: (call) {
        pendingRecordings.add(call);
        notifyListeners();
      },
    );
    try {
      await server.start();
      _servers[project.id] = server;
      notifyListeners();
      return null;
    } catch (e) {
      final msg =
          e.toString().contains('errno = 98') ||
              e.toString().toLowerCase().contains('address already in use')
          ? 'Port ${project.port} is already in use. Pick another port.'
          : 'Could not start server: $e';
      return msg;
    }
  }

  Future<void> stopServer(MockProject project) async {
    final server = _servers[project.id];
    if (server != null) {
      await server.stop();
      _servers.remove(project.id);
      // Stop tunnel if it was pointing at this server.
      if (tunnel.status == TunnelStatus.running) {
        await tunnel.stop();
      }
      notifyListeners();
    }
  }

  Future<String?> restartServer(MockProject project) async {
    await stopServer(project);
    return startServer(project);
  }

  void _appendLog(String projectId, RequestLog log) {
    final list = _logs.putIfAbsent(projectId, () => []);
    list.insert(0, log);
    if (list.length > maxLogsPerProject) {
      list.removeRange(maxLogsPerProject, list.length);
    }
    notifyListeners();
  }

  void clearLogs(String projectId) {
    _logs[projectId]?.clear();
    notifyListeners();
  }

  void clearRecordings() {
    pendingRecordings.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _servers.values) {
      s.stop();
    }
    tunnel.dispose();
    super.dispose();
  }
}
