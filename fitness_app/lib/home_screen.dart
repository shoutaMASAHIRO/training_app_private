import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const DashboardScreen(),
    const Center(child: Text('Workouts Screen', style: TextStyle(fontSize: 24, color: Colors.black87))),
    const Center(child: Text('Progress Screen', style: TextStyle(fontSize: 24, color: Colors.black87))),
    const Center(child: Text('Profile Screen', style: TextStyle(fontSize: 24, color: Colors.black87))),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome Back!'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Navigate back to the login screen
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_rounded),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        backgroundColor: Colors.white,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey[500],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Summary',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: StatCard(title: 'Calories', value: '1,234', unit: 'kcal', icon: Icons.local_fire_department_rounded, color: Colors.orangeAccent)),
              SizedBox(width: 16),
              Expanded(child: StatCard(title: 'Steps', value: '5,678', unit: 'steps', icon: Icons.directions_walk_rounded, color: Colors.lightBlueAccent)),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Your Plan',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          const ActionCard(
            title: 'Full Body Workout',
            subtitle: '45 min • 350 kcal',
            icon: Icons.fitness_center_rounded,
          ),
          const SizedBox(height: 16),
           const ActionCard(
            title: 'Cardio Session',
            subtitle: '30 min • 250 kcal',
            icon: Icons.directions_run_rounded,
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const StatCard({super.key, required this.title, required this.value, required this.unit, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text(unit, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const ActionCard({super.key, required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 40),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),
          Icon(Icons.play_circle_fill_rounded, color: Colors.grey[300], size: 30),
        ],
      ),
    );
  }
}
