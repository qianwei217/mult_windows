import 'dart:convert'; // Will likely remove if not used elsewhere after cleanup
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:desktop_multi_window/desktop_multi_window.dart'; // REMOVED
// import 'package:collection/collection.dart'; // REMOVED - was for args.firstOrNull

import 'tab_manager.dart'; // Keep
import 'panel_manager.dart'; // ADDED
import 'floating_panel_widget.dart'; // ADDED

// void main(List<String> args) { // REVERTED to simple main
void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Keep

  // REMOVED: multi_window argument parsing logic
  // if (args.firstOrNull == 'multi_window') { ... }
  // else { ... }

  runApp(
    MultiProvider( // CHANGED to MultiProvider
      providers: [
        ChangeNotifierProvider(create: (context) => TabManager()),
        ChangeNotifierProvider(create: (context) => PanelManager()), // ADDED PanelManager
      ],
      child: const MyApp(), // Simplified MyApp call
    ),
  );
}

// REMOVED: DetachedTabApp class
// REMOVED: DetachedTabWindowWidget class

class MyApp extends StatelessWidget {
  // REMOVED: isMainWindow parameter
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Multi-Tab Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const TabbedWindow(), // Always home to TabbedWindow now
    );
  }
}

class TabbedWindow extends StatefulWidget {
  const TabbedWindow({super.key});

  @override
  State<TabbedWindow> createState() => _TabbedWindowState();
}

class _TabbedWindowState extends State<TabbedWindow> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TabManager _tabManager;
  late PanelManager _panelManager; // Added PanelManager instance variable

  final GlobalKey _stackKey = GlobalKey(); // Key for the Stack

  @override
  void initState() {
    super.initState();
    _tabManager = Provider.of<TabManager>(context, listen: false);
    _panelManager = Provider.of<PanelManager>(context, listen: false); // Initialize PanelManager
    _tabController = TabController(length: _tabManager.tabs.length, vsync: this);
    _tabManager.addListener(_handleTabChange);
    _tabController.addListener(_handleTabSelection);

    // REMOVED: DesktopMultiWindow.setMethodCallHandler(_handleMethodCall);
  }

  // REMOVED: _handleMethodCall Future<dynamic> _handleMethodCall(...)

  void _handleTabChange() {
    if (!mounted) return;

    final newTabCount = _tabManager.tabs.length;
    if (newTabCount == 0 && _tabController.length > 0) {
        _tabController.removeListener(_handleTabSelection);
        _tabController.dispose();
        _tabController = TabController(length: 0, vsync: this);
        _tabController.addListener(_handleTabSelection);
        setState(() {});
        return;
    }

    if (newTabCount > 0 && newTabCount != _tabController.length) {
      int oldIndex = _tabController.index;
      _tabController.removeListener(_handleTabSelection);
      _tabController.dispose();
      _tabController = TabController(length: newTabCount, vsync: this);

      if (oldIndex >= newTabCount) {
        _tabController.index = newTabCount - 1;
      } else {
        _tabController.index = oldIndex;
      }
      _tabController.addListener(_handleTabSelection);
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTabSelection() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabManager.removeListener(_handleTabChange);
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    // REMOVED: DesktopMultiWindow.setMethodCallHandler(null);
    super.dispose();
  }

  // REMOVED: _onTabDraggedOut method that used DesktopMultiWindow

  @override
  Widget build(BuildContext context) {
    final tabManager = Provider.of<TabManager>(context);
    final panelManager = Provider.of<PanelManager>(context); // Get PanelManager

    // The main tabbed interface
    Widget tabbedInterface;
    if (tabManager.tabs.isEmpty && panelManager.panels.isEmpty) { // Show empty state only if no tabs AND no panels
      tabbedInterface = Scaffold(
        appBar: AppBar(
          title: const Text('Multi-Tab Browser (Empty)'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              tabManager.addNewTab();
            },
            child: const Text('Add First Tab'),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            tabManager.addNewTab();
          },
          child: const Icon(Icons.add),
        ),
      );
    } else if (tabManager.tabs.isEmpty && panelManager.panels.isNotEmpty) {
      // Has panels but no tabs in the main bar, show a minimal app bar
       tabbedInterface = Scaffold(
        appBar: AppBar(
          title: const Text('Multi-Tab Browser'),
        ),
        body: Center(child: Text("All tabs are in floating panels.")), // Placeholder for when tabs are empty but panels exist
        floatingActionButton: FloatingActionButton( // Still allow adding new tabs
          onPressed: () {
            tabManager.addNewTab();
          },
          child: const Icon(Icons.add),
        ),
      );
    }
    else {
      tabbedInterface = Scaffold(
        appBar: AppBar(
          title: const Text('Multi-Tab Browser'),
          bottom: PreferredSize( // Wrap TabBar in PreferredSize for DragTarget
            preferredSize: Size.fromHeight(kTextTabBarHeight),
            child: DragTarget<String>( // String is panelId
              onWillAccept: (panelId) {
                // You can add logic here to highlight the TabBar when a panel is dragged over it
                return panelId != null && panelId.startsWith("panel_"); // Basic check
              },
              onAcceptWithDetails: (details) { // Changed from onAccept to onAcceptWithDetails
                final panelId = details.data;
                final mergeData = _panelManager.mergePanelToTabs(panelId);
                if (mergeData != null) {
                  // Check if a tab with the original ID already exists (e.g. user created new one with same name)
                  // For simplicity, we'll try to use the original ID, but TabManager.addTab might
                  // create a new one if the ID is taken or handle it based on its internal logic.
                  // A more robust merge might involve checking if a tab with mergeData.originalTabId exists
                  // and deciding whether to replace it or add as new.
                  _tabManager.addTab(
                    TabModel(
                      id: mergeData.originalTabId, // Attempt to reuse original ID
                      title: mergeData.title,
                      content: mergeData.contentWidget,
                    ),
                  );
                  // Optionally, try to select the newly added tab
                  // This requires finding its index after it's added.
                  // int newTabIndex = _tabManager.tabs.indexWhere((t) => t.id == mergeData.originalTabId);
                  // if (newTabIndex != -1) {
                  //   _tabController.animateTo(newTabIndex);
                  // }
                }
              },
              builder: (context, candidateData, rejectedData) {
                // Optionally change TabBar appearance when a panel is dragged over
                return Container(
                  color: candidateData.isNotEmpty ? Colors.blue.withOpacity(0.1) : null,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: tabManager.tabs.map((tabModel) {
                      Widget tabContent = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tabModel.title),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              tabManager.removeTabById(tabModel.id);
                            },
                            child: const Icon(Icons.close, size: 16),
                          ),
                        ],
                      );

                      return LongPressDraggable<TabModel>(
                        data: tabModel,
                        feedback: Material(
                          elevation: 4.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(tabModel.title, style: Theme.of(context).textTheme.titleSmall),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: Tab(child: tabContent),
                        ),
                        onDragEnd: (details) {
                          final appBar = AppBar();
                          final double tabBarBottomY = appBar.preferredSize.height + kTextTabBarHeight + MediaQuery.of(context).padding.top;

                          if (details.offset.dy > tabBarBottomY + 20) {
                            final RenderBox stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox;
                            final Offset localDropPosition = stackBox.globalToLocal(details.offset);

                            _panelManager.detachTabToPanel(tabModel, localDropPosition);
                            _tabManager.removeTabById(tabModel.id);
                          }
                        },
                        hapticFeedbackOnStart: true,
                        child: Tab(key: ValueKey(tabModel.id), child: tabContent),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ),
      body: TabBarView(
          controller: _tabController,
          children: tabManager.tabs.map((tabModel) => tabModel.content).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        children: tabManager.tabs.map((tabModel) => tabModel.content).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          tabManager.addNewTab();
        },
        child: const Icon(Icons.add),
      ),
    );
    }

    return Stack( // Assign the key to the Stack
      key: _stackKey,
      children: [
        tabbedInterface,
        // Render panels on top
        ...panelManager.panels.map((panel) {
          // Now use the actual FloatingPanelWidget
          return Positioned(
            key: Key(panel.id), // Use panel ID as key for widget identity
            left: panel.offset.dx,
            top: panel.offset.dy,
            child: FloatingPanelWidget(
              panelModel: panel,
              panelManager: panelManager,
            ),
          );
        }).toList(),
      ],
    );
  }
}
