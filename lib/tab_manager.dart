import 'package:flutter/material.dart';
import 'dart:math'; // For unique IDs

// Represents the data for a single tab.
class TabModel {
  final String id;
  final String title;
  final Widget content;
  // Could add more properties like a favicon, or a reference to a web controller later.

  TabModel({required this.id, required this.title, required this.content});
}

class TabManager with ChangeNotifier {
  final List<TabModel> _tabs = [];
  int _nextTabNumber = 1;

  List<TabModel> get tabs => List.unmodifiable(_tabs);

  TabManager() {
    // Initialize with one tab
    addNewTab();
  }

  void addTab(TabModel tab) {
    // Check if a tab with the same ID already exists to prevent duplicates if necessary
    if (!_tabs.any((existingTab) => existingTab.id == tab.id)) {
      _tabs.add(tab);
      // If we are adding a tab with a title like "Tab X", make sure _nextTabNumber is consistent
      // This logic might need refinement if titles are not strictly "Tab X"
      final tabNumMatch = RegExp(r'Tab (\d+)').firstMatch(tab.title);
      if (tabNumMatch != null) {
        final existingNum = int.parse(tabNumMatch.group(1)!);
        if (existingNum >= _nextTabNumber) {
          _nextTabNumber = existingNum + 1;
        }
      }
      notifyListeners();
    } else {
      // Optional: handle case where tab with ID already exists, e.g., update it or ignore
      print("Tab with ID ${tab.id} already exists. Not adding.");
    }
  }

  void addNewTab() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString() + '_' + Random().nextInt(10000).toString();
    final newTitle = 'Tab $_nextTabNumber';
    _nextTabNumber++;
    final newTab = TabModel(
      id: newId,
      title: newTitle,
      content: Center(child: Text('Content for $newTitle (ID: ${newId.substring(newId.length-6)})')), // Added ID for clarity
    );
    _tabs.add(newTab);
    notifyListeners();
  }

  void removeTabById(String tabId) { // Removed preventEmptyRecreation
    int removedAtIndex = _tabs.indexWhere((tab) => tab.id == tabId);
    if (removedAtIndex != -1) {
      _tabs.removeAt(removedAtIndex);
      // if (_tabs.isEmpty) {
        // addNewTab(); // Logic for auto-adding is currently disabled.
      // }
      notifyListeners();
    }
  }

  // Optional: remove tab by index, might be useful for TabController
  void removeTabByIndex(int index) { // Removed preventEmptyRecreation
    if (index < 0 || index >= _tabs.length) return;
    _tabs.removeAt(index);
    // if (_tabs.isEmpty) {
      // addNewTab(); // Logic for auto-adding is currently disabled.
    // }
    notifyListeners();
  }
}
