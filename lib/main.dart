import 'dart:convert'; // Will likely remove if not used elsewhere after cleanup
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:desktop_multi_window/desktop_multi_window.dart'; // REMOVED
// import 'package:collection/collection.dart'; // REMOVED - was for args.firstOrNull

import 'tab_manager.dart'; // Keep
import 'panel_manager.dart'; // ADDED
import 'floating_panel_widget.dart'; // ADDED
import 'package:window_manager/window_manager.dart'; // ADDED window_manager

// void main(List<String> args) { // REVERTED to simple main
Future<void> main() async { // Changed to Future<void> and async
  WidgetsFlutterBinding.ensureInitialized(); // Keep
  await windowManager.ensureInitialized(); // ADDED window_manager initialization

  // Configure the window
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800), // Initial large size
    center: true,
    backgroundColor: Colors.transparent, // For Flutter view
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Crucial for frameless
    windowButtonVisibility: false, // Hide macOS specific buttons
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless(); // Make it frameless
    await windowManager.setBackgroundColor(Colors.transparent); // Ensure native window is transparent
    // await windowManager.setFullScreen(true); // Alternative to setting large size
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MultiProvider(
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
      debugShowCheckedModeBanner: false, // Optional: hide debug banner
      title: 'Flutter Multi-Tab Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Important for transparency: MaterialApp's default background is white.
      color: Colors.transparent, // Setting MaterialApp's color
      home: const TabbedWindow(),
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
  late PanelManager _panelManager;

  final GlobalKey _stackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabManager = Provider.of<TabManager>(context, listen: false);
    _panelManager = Provider.of<PanelManager>(context, listen: false);
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
    if (tabManager.tabs.isEmpty && panelManager.panels.isEmpty) {
      tabbedInterface = Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize( // Wrap AppBar in PreferredSize to make it a consistent height for GestureDetector
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: GestureDetector(
            onPanStart: (details) {
              windowManager.startDragging();
            },
            child: AppBar(
              backgroundColor: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.85),
              elevation: 0,
              title: const Text('Multi-Tab Browser (Empty)'),
            ),
          ),
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
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: GestureDetector(
            onPanStart: (details) {
              windowManager.startDragging();
            },
            child: AppBar(
              backgroundColor: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.85),
              elevation: 0,
              title: const Text('Multi-Tab Browser'),
            ),
          ),
        ),
        body: Center(child: Text("All tabs are in floating panels.")),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            tabManager.addNewTab();
          },
          child: const Icon(Icons.add),
        ),
      );
    }
    else {
      tabbedInterface = Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize( // Wrap AppBar for GestureDetector
          preferredSize: Size.fromHeight(kToolbarHeight + ( _tabManager.tabs.isNotEmpty ? kTextTabBarHeight : 0)),
          child: GestureDetector(
            onPanStart: (details) {
               // Only allow dragging if not interacting with TabBar or its elements.
               // This is a simple check; more precise hit testing might be needed if there are interactive elements in AppBar title area.
               // For now, assume dragging anywhere on AppBar (not TabBar part) moves the window.
              if (details.localPosition.dy < kToolbarHeight) { // Check if drag started on main AppBar area
                windowManager.startDragging();
              }
            },
            child: AppBar(
              backgroundColor: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.85),
              elevation: 0,
              title: const Text('Multi-Tab Browser'),
              bottom: _tabManager.tabs.isNotEmpty ? PreferredSize(
                preferredSize: Size.fromHeight(kTextTabBarHeight),
                child: DragTarget<String>(
              onWillAccept: (panelId) {
                return panelId != null && panelId.startsWith("panel_");
              },
              onAcceptWithDetails: (details) {
                final panelId = details.data;
                final mergeData = _panelManager.mergePanelToTabs(panelId);
                if (mergeData != null) {
                  _tabManager.addTab(
                    TabModel(
                      id: mergeData.originalTabId,
                      title: mergeData.title,
                      content: mergeData.contentWidget,
                    ),
                  );
                }
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  // Use a color from the theme for the TabBar background
                  color: candidateData.isNotEmpty
                       ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6)
                       : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.75),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    // Consider theming for TabBar indicator, label color for better visibility
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(tabModel.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSecondaryContainer)),
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
                            final RenderBox? stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
                            if (stackBox != null) {
                              final Offset localDropPosition = stackBox.globalToLocal(details.offset);
                              _panelManager.detachTabToPanel(tabModel, localDropPosition);
                              _tabManager.removeTabById(tabModel.id);
                            }
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
      body: Container( // ADDED Container to provide a default background for TabBarView content
          color: Theme.of(context).colorScheme.surface.withOpacity(0.8), // Semi-transparent surface
          child: TabBarView(
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
