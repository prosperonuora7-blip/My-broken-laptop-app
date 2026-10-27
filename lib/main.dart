import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

void main() {
  runApp(const StrataApp());
}

class Task {
  String title;
  bool isDone;
  String category;
  String priority;
  DateTime dueDate;

  Task({
    required this.title,
    this.isDone = false,
    required this.category,
    required this.priority,
    required this.dueDate,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'isDone': isDone,
        'category': category,
        'priority': priority,
        'dueDate': dueDate.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        title: json['title'],
        isDone: json['isDone'],
        category: json['category'],
        priority: json['priority'],
        dueDate: DateTime.parse(json['dueDate']),
      );
}

class StrataApp extends StatelessWidget {
  const StrataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StrataApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const StrataHomePage(),
    );
  }
}

class StrataHomePage extends StatefulWidget {
  const StrataHomePage({super.key});

  @override
  State<StrataHomePage> createState() => _StrataHomePageState();
}

class _StrataHomePageState extends State<StrataHomePage> {
  int _currentIndex = 0;
  List<Task> _tasks = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Load tasks from SharedPreferences
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksString = prefs.getString('strata_tasks');
    if (tasksString != null) {
      final List<dynamic> decoded = jsonDecode(tasksString);
      setState(() {
        _tasks = decoded.map((item) => Task.fromJson(item)).toList();
      });
    } else {
      // Default sample tasks if empty
      setState(() {
        _tasks = [
          Task(title: 'Dog Food', isDone: false, category: 'Personal', priority: 'Normal', dueDate: DateTime.now()),
          Task(title: 'Payment', isDone: false, category: 'Work', priority: 'High', dueDate: DateTime.now()),
          Task(title: 'Salaries', isDone: true, category: 'Work', priority: 'High', dueDate: DateTime.now()),
        ];
      });
      _saveTasks();
    }
  }

  // Save tasks to SharedPreferences
  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await prefs.setString('strata_tasks', encoded);
  }

  // Export Tasks to JSON File (Web)
  void _exportTasks() {
    final String jsonString = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    
    if (kIsWeb) {
      final bytes = utf8.encode(jsonString);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "strata_app_backup.json")
        ..click();
      html.Url.revokeObjectUrl(url);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup exported successfully!')),
      );
    }
  }

  // Show Dialog to Import Tasks via JSON text paste
  void _showImportDialog() {
    final TextEditingController importController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup (JSON)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste your exported JSON backup text below:'),
            const SizedBox(height: 12),
            TextField(
              controller: importController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste JSON data here...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _importTasks(importController.text);
              Navigator.pop(context);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  // Import Tasks from JSON string
  void _importTasks(String jsonString) {
    try {
      final List<dynamic> decodedData = jsonDecode(jsonString);
      setState(() {
        _tasks = decodedData.map((item) => Task.fromJson(item)).toList();
      });
      _saveTasks();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tasks restored successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import backup: $e')),
      );
    }
  }

  // Add Task Dialog
  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    String category = 'Personal';
    String priority = 'Normal';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Task Title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                items: ['Personal', 'Work', 'Urgent'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setDialogState(() => category = val!),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: priority,
                items: ['Normal', 'High'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) => setDialogState(() => priority = val!),
                decoration: const InputDecoration(labelText: 'Priority'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  setState(() {
                    _tasks.add(Task(
                      title: titleController.text,
                      category: category,
                      priority: priority,
                      dueDate: DateTime.now(),
                    ));
                  });
                  _saveTasks();
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _tasks.where((t) => t.isDone).length;
    final totalCount = _tasks.length;
    final completionPercentage = totalCount == 0 ? 0.0 : completedCount / totalCount;
    final pendingCount = totalCount - completedCount;
    final highPriorityCount = _tasks.where((t) => t.priority == 'High' && !t.isDone).length;

    final filteredTasks = _tasks.where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            labelType: NavigationRailLabelType.none,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: Text('Tasks'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main Content Area
          Expanded(
            child: _currentIndex == 0
                ? _buildDashboardView(completionPercentage, completedCount, totalCount, pendingCount, highPriorityCount)
                : _buildTasksView(filteredTasks),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: _showAddTaskDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDashboardView(double percentage, int completed, int total, int pending, int highPriority) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Productivity Overview',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Overall Completion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: percentage, minHeight: 8),
                  const SizedBox(height: 12),
                  Text('$completed of $total tasks completed (${(percentage * 100).toStringAsFixed(0)}%)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$pending', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
                        const SizedBox(height: 4),
                        const Text('Pending', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$highPriority', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        const SizedBox(height: 4),
                        const Text('High Priority', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Data Backup & Recovery', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _exportTasks,
                icon: const Icon(Icons.download),
                label: const Text('Export JSON'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showImportDialog,
                icon: const Icon(Icons.upload),
                label: const Text('Restore JSON'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTasksView(List<Task> tasks) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search tasks...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: tasks.isEmpty
                ? const Center(child: Text('No tasks found.'))
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Checkbox(
                            value: task.isDone,
                            onChanged: (val) {
                              setState(() {
                                task.isDone = val ?? false;
                              });
                              _saveTasks();
                            },
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Wrap(
                            spacing: 8,
                            children: [
                              Chip(label: Text(task.category), visualDensity: VisualDensity.compact),
                              if (task.priority == 'High')
                                const Chip(
                                  label: Text('High', style: TextStyle(color: Colors.redAccent)),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                _tasks.remove(task);
                              });
                              _saveTasks();
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
