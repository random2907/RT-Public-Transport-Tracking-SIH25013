import 'package:flutter/material.dart';
import 'home.dart';

class CommonDrawer extends StatelessWidget {
  const CommonDrawer({super.key});
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const SizedBox(
            height: 50,
            child: DrawerHeader(
              padding: EdgeInsets.only(left: 100),
              child: Text(
                "Menu",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            title: const Text("Home"),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const Homepage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
