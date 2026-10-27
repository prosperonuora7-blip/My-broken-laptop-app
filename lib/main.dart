import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:async';

void main() {
  runApp(const StrataApp());
}

class Task {
  String title;
  bool isDone;
  String category;
  String priority;
  DateTime dueDate;
  bool notified;

  Task({
    required this.title,
    this.isDone = false,
    required this.category,
    required this.priority,
    required this.dueDate,
    this.notified = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'isDone': isDone,
        'category': category,
        'priority': priority,
        'dueDate': dueDate.toIso8601String(),
        'notified': notified,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        title: json['title'],
        isDone: json['isDone'],
        category: json['category'],
        priority: json['priority'],
        dueDate: DateTime.parse(json['dueDate']),
        notified: json['notified'] ?? false,
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
  bool _isToDoExpanded = true;
  bool _isDoneExpanded = true;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    
    // Check for due tasks every 10 seconds for live notifications
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkTaskNotifications();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Live Notification Checker
  void _checkTaskNotifications() {
    final now = DateTime.now();
    for (var task in _tasks) {
      if (!task.isDone && !task.notified && now.isAfter(task.dueDate)) {
        task.notified = true;
        _saveTasks();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reminder: Task "${task.title}" is due now!'),
              backgroundColor: Colors.indigoAccent,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksString = prefs.getString('strata_tasks');
    if (tasksString != null) {
      final List<dynamic> decoded = jsonDecode(tasksString);
      setState(() {
        _tasks = decoded.map((item) => Task.fromJson(item)).toList();
      });
    } else {
      setState(() {
        _tasks = [
          Task(title: 'Dog Food', isDone: false, category: 'General', priority: 'Normal', dueDate: DateTime.now().add(const Duration(minutes: 2))),
          Task(title: 'Payment', isDone: false, category: 'Work', priority: 'High', dueDate: DateTime.now().add(const Duration(hours: 1))),
          Task(title: 'Salaries', isDone: true, category: 'Work', priority: 'High', dueDate: DateTime.now().add(const Duration(hours: 2))),
        ];
      });
      _saveTasks();
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await prefs.setString('strata_tasks', encoded);
  }

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
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste JSON data here...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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

  void _importTasks(String jsonString) {
    try {
      final List<dynamic> decodedData = jsonDecode(jsonString);
      setState(() {
        _tasks = decodedData.map((item) => Task.fromJson(item)).toList();
      });
      _saveTasks();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tasks restored successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to import backup: $e')));
    }
  }

  void _showTaskDialog({Task? taskToEdit}) {
    final titleController = TextEditingController(text: taskToEdit?.title ?? '');
    String category = taskToEdit?.category ?? 'General';
    String priority = taskToEdit?.priority ?? 'Normal';
    DateTime selectedDate = taskToEdit?.dueDate ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(taskToEdit?.dueDate ?? DateTime.now());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(taskToEdit == null ? 'Add New Task' : 'Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: category,
                  items: ['General', 'Personal', 'Work', 'Urgent'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setDialogState(() => category = val!),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: priority,
                  items: ['Normal', 'High'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) => setDialogState(() => priority = val!),
                  decoration: const InputDecoration(labelText: 'Priority'),
                ),
                const SizedBox(height: 20),
                const Text('Due Date & Time', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('${selectedDate.year}${selectedDate.month.toString().padLeft(2, '0')}${selectedDate.day.toString().padLeft(2, '0')}'),
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (pickedDate != null) {
                            setDialogState(() => selectedDate = pickedDate);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(selectedTime.format(context)),
                        onPressed: () async {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (pickedTime != null) {
                            setDialogState(() => selectedTime = pickedTime);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  final DateTime finalDueDate = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  setState(() {
                    if (taskToEdit == null) {
                      _tasks.add(Task(
                        title: titleController.text,
                        category: category,
                        priority: priority,
                        dueDate: finalDueDate,
                        notified: false,
                      ));
                    } else {
                      taskToEdit.title = titleController.text;
                      taskToEdit.category = category;
                      taskToEdit.priority = priority;
                      taskToEdit.dueDate = finalDueDate;
                      taskToEdit.notified = false; // Reset notification flag on edit
                    }
                  });
                  _saveTasks();
                  Navigator.pop(context);
                }
              },
              child: Text(taskToEdit == null ? 'Add' : 'Save'),
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
    final toDoTasks = filteredTasks.where((t) => !t.isDone).toList();
    final doneTasks = filteredTasks.where((t) => t.isDone).toList();

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            labelType: NavigationRailLabelType.none,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Overview')),
              NavigationRailDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: Text('Tasks')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _currentIndex == 0
                ? _buildDashboardView(completionPercentage, completedCount, totalCount, pendingCount, highPriorityCount)
                : _buildTasksView(toDoTasks, doneTasks),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () => _showTaskDialog(),
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
          const Text('Productivity Overview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
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

  Widget _buildTasksView(List<Task> toDo, List<Task> done) {
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
            child: ListView(
              children: [
                ExpansionTile(
                  title: Text('To-Do (${toDo.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  initiallyExpanded: _isToDoExpanded,
                  onExpansionChanged: (val) => setState(() => _isToDoExpanded = val),
                  children: toDo.isEmpty
                      ? [const Padding(padding: EdgeInsets.all(12.0), child: Text('No pending tasks'))]
                      : toDo.map((task) => _buildTaskCard(task)).toList(),
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  title: Text('Done (${done.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  initiallyExpanded: _isDoneExpanded,
                  onExpansionChanged: (val) => setState(() => _isDoneExpanded = val),
                  children: done.isEmpty
                      ? [const Padding(padding: EdgeInsets.all(12.0), child: Text('No completed tasks'))]
                      : done.map((task) => _buildTaskCard(task)).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final String formattedDate = '${task.dueDate.year}'
        '${task.dueDate.month.toString().padLeft(2, '0')}'
        '${task.dueDate.day.toString().padLeft(2, '0')} '
        '${task.dueDate.hour.toString().padLeft(2, '0')}:${task.dueDate.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: task.isDone,
                  onChanged: (val) {
                    setState(() {
                      task.isDone = val ?? false;
                    });
                    _saveTasks();
                  },
                ),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                  onPressed: () => _showTaskDialog(taskToEdit: task),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                  onPressed: () => setState(() {
                    _tasks.remove(task);
                    _saveTasks();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.flag,
                  size: 16,
                  color: task.priority == 'High' ? Colors.redAccent : Colors.grey,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(formattedDate, style: const TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(task.category, style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
