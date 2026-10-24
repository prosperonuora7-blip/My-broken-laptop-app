import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// --- 1. MODEL ---
class Task {
  String title;
  bool completed;
  String status;
  DateTime? dueDate;
  int priority;
  String category;

  Task({
    required this.title, 
    this.completed = false, 
    this.status = "todo", 
    this.dueDate, 
    this.priority = 0,
    this.category = "General"
  });

  Map<String, dynamic> toJson() => {
    'title': title, 
    'completed': completed, 
    'status': status, 
    'dueDate': dueDate?.toIso8601String(),
    'priority': priority,
    'category': category
  };
  
  factory Task.fromJson(Map<String, dynamic> json) => Task(
        title: json['title'] ?? '',
        completed: json['completed'] ?? false,
        status: json['status'] ?? 'todo',
        dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
        priority: json['priority'] ?? 0,
        category: json['category'] ?? "General",
      );
}

// --- 2. MAIN APP ENGINE ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StrataApp());
}

class StrataApp extends StatefulWidget {
  const StrataApp({super.key});
  @override
  State<StrataApp> createState() => _StrataAppState();
}

class _StrataAppState extends State<StrataApp> {
  List<Task> tasks = [];
  ThemeMode themeMode = ThemeMode.dark;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final taskData = prefs.getString('tasks');
    final isDark = prefs.getBool('isDark') ?? true;
    setState(() {
      if (taskData != null) tasks = (jsonDecode(taskData) as List).map((e) => Task.fromJson(e)).toList();
      themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tasks', jsonEncode(tasks.map((e) => e.toJson()).toList()));
    await prefs.setBool('isDark', themeMode == ThemeMode.dark);
  }

  void addTask(String title, DateTime? date, int priority, String category) {
    if (title.trim().isEmpty) return;
    setState(() => tasks.add(Task(title: title, dueDate: date, priority: priority, category: category)));
    saveData();
  }

  void deleteTask(int index) {
    setState(() => tasks.removeAt(index));
    saveData();
  }

  void toggleTask(int index, bool value) {
    setState(() {
      tasks[index].completed = value;
      tasks[index].status = value ? "done" : "todo";
    });
    saveData();
  }

  void editTask(int index, String newTitle, DateTime? newDate, int newPriority, String newCategory) {
    setState(() {
      tasks[index].title = newTitle;
      tasks[index].dueDate = newDate;
      tasks[index].priority = newPriority;
      tasks[index].category = newCategory;
    });
    saveData();
  }

  void toggleTheme() {
    setState(() => themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
    saveData();
  }
  
  void updateSearch(String query) {
    setState(() => searchQuery = query);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: StrataLayout(
        tasks: tasks, 
        addTask: addTask, 
        deleteTask: deleteTask, 
        toggleTask: toggleTask, 
        editTask: editTask,
        toggleTheme: toggleTheme,
        searchQuery: searchQuery,
        updateSearch: updateSearch,
      ),
    );
  }
}

// --- 3. UI LAYOUT ---
class StrataLayout extends StatefulWidget {
  final List<Task> tasks;
  final Function(String, DateTime?, int, String) addTask;
  final Function(int) deleteTask;
  final Function(int, bool) toggleTask;
  final Function(int, String, DateTime?, int, String) editTask;
  final VoidCallback toggleTheme;
  final String searchQuery;
  final Function(String) updateSearch;

  const StrataLayout({super.key, required this.tasks, required this.addTask, required this.deleteTask, required this.toggleTask, required this.editTask, required this.toggleTheme, required this.searchQuery, required this.updateSearch});

  @override
  State<StrataLayout> createState() => _StrataLayoutState();
}

class _StrataLayoutState extends State<StrataLayout> {
  int _selectedIndex = 1;
  DateTime? selectedDate;
  int selectedPriority = 0;
  String selectedCategory = "General";
  final List<String> categories = ["General", "Work", "Personal", "Study"];

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime? initial) async {
    final date = await showDatePicker(context: context, initialDate: initial ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
    if (date == null) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()));
    if (time == null) return date;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            leading: IconButton(icon: const Icon(Icons.brightness_6), onPressed: widget.toggleTheme),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text("Dashboard")),
              NavigationRailDestination(icon: Icon(Icons.check_box), label: Text("Tasks")),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _selectedIndex == 1 ? _buildTaskView() : _buildDashboardView()),
        ],
      ),
    );
  }

  Widget _buildTaskView() {
    final controller = TextEditingController();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(children: [
                Expanded(child: TextField(controller: controller, decoration: const InputDecoration(hintText: "Add task...", border: OutlineInputBorder()))),
                IconButton(icon: Icon(Icons.flag, color: [Colors.grey, Colors.orange, Colors.red][selectedPriority]), onPressed: () {
                    setState(() => selectedPriority = (selectedPriority + 1) % 3);
                }),
                IconButton(icon: const Icon(Icons.calendar_today), onPressed: () async {
                  final dt = await _pickDateTime(context, selectedDate);
                  setState(() => selectedDate = dt);
                }),
                IconButton(icon: const Icon(Icons.add), onPressed: () {
                  widget.addTask(controller.text, selectedDate, selectedPriority, selectedCategory);
                  controller.clear();
                  setState(() { selectedDate = null; selectedPriority = 0; });
                }),
              ]),
              DropdownButton<String>(
                value: selectedCategory,
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => selectedCategory = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: widget.updateSearch,
                decoration: const InputDecoration(hintText: "Search tasks...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        Expanded(child: ListView(children: [_buildCategorySection("To-Do", "todo"), _buildCategorySection("Done", "done")])),
      ],
    );
  }

  Widget _buildCategorySection(String title, String status) {
    final filtered = widget.tasks.where((t) => t.status == status && t.title.toLowerCase().contains(widget.searchQuery.toLowerCase())).toList();
    
    // Automatic Sorting: Soonest date first, then highest priority
    filtered.sort((a, b) {
      if (a.dueDate != null && b.dueDate != null) {
        int dateCompare = a.dueDate!.compareTo(b.dueDate!);
        if (dateCompare != 0) return dateCompare;
      }
      return b.priority.compareTo(a.priority);
    });

    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      initiallyExpanded: true,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: filtered.map((task) {
        int index = widget.tasks.indexOf(task);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: Card(
            key: ValueKey(task.title + index.toString() + task.status),
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Checkbox(value: task.completed, shape: const CircleBorder(), onChanged: (v) => widget.toggleTask(index, v!)),
              title: Text(task.title, style: TextStyle(decoration: task.completed ? TextDecoration.lineThrough : null)),
              subtitle: Wrap(spacing: 8, children: [
                 if (task.dueDate != null) Chip(label: Text(DateFormat('yMMMd, h:mm a').format(task.dueDate!), style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
                 Chip(label: Text(task.category, style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
                 Icon(Icons.flag, size: 16, color: [Colors.grey, Colors.orange, Colors.red][task.priority]),
              ]),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showEditDialog(index, task)),
                  IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent), onPressed: () => widget.deleteTask(index)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showEditDialog(int index, Task task) {
    final controller = TextEditingController(text: task.title);
    DateTime? tempDate = task.dueDate;
    int tempPriority = task.priority;
    String tempCategory = task.category;
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setDialogState) => AlertDialog(
        title: const Text("Edit Task"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controller, decoration: const InputDecoration(labelText: "Title")),
          DropdownButton<String>(
            value: tempCategory,
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setDialogState(() => tempCategory = v!),
          ),
          DropdownButton<int>(
            value: tempPriority,
            items: const [
              DropdownMenuItem(value: 0, child: Text("Low")),
              DropdownMenuItem(value: 1, child: Text("Medium")),
              DropdownMenuItem(value: 2, child: Text("High")),
            ],
            onChanged: (v) => setDialogState(() => tempPriority = v!),
          ),
          OutlinedButton(
            onPressed: () async {
              final dt = await _pickDateTime(context, tempDate);
              setDialogState(() => tempDate = dt);
            },
            child: Text(tempDate == null ? "Select Date & Time" : DateFormat('yMMMd, h:mm a').format(tempDate!))
          )
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          FilledButton(onPressed: () {
            widget.editTask(index, controller.text, tempDate, tempPriority, tempCategory);
            Navigator.pop(context);
          }, child: const Text("Save")),
        ],
      )),
    );
  }

  Widget _buildDashboardView() {
    int total = widget.tasks.length;
    int done = widget.tasks.where((t) => t.status == 'done').length;
    double progress = total == 0 ? 0 : done / total;
    return Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text("Productivity Overview", style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 20),
      AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        width: 300, 
        child: LinearProgressIndicator(value: progress, minHeight: 10),
      ),
      const SizedBox(height: 20),
      Text("$done / $total tasks completed"),
    ])));
  }
}
