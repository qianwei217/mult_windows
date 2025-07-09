import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:collection/collection.dart'; // For args.firstOrNull
import 'tab_manager.dart';

void main(List<String> args) {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  if (args.firstOrNull == 'multi_window') {
    final windowId = int.parse(args[1]);
    final arguments = args[2].isEmpty
        ? <String, dynamic>{}
        : jsonDecode(args[2]) as Map<String, dynamic>;

    String tabId = arguments['tabId'] ?? 'unknown_tab';
    String tabTitle = arguments['tabTitle'] ?? 'Detached Tab';
    // In a real scenario, you might pass more complex data or an identifier
    // to fetch the full content for the tab.
    // For now, we'll just use the title.

    runApp(DetachedTabApp(
      windowController: WindowController.fromWindowId(windowId),
      tabId: tabId,
      tabTitle: tabTitle,
      initialContentData: arguments['initialContentData'] // Example of passing more data
    ));
  } else {
    runApp(
      ChangeNotifierProvider(
        create: (context) => TabManager(),
        child: const MyApp(isMainWindow: true),
      ),
    );
  }
}

// New App class for detached windows
class DetachedTabApp extends StatelessWidget {
  final WindowController windowController;
  final String tabId;
  final String tabTitle;
  final dynamic initialContentData; // Placeholder for actual content

  const DetachedTabApp({
    super.key,
    required this.windowController,
    required this.tabId,
    required this.tabTitle,
    this.initialContentData,
  });

  @override
  Widget build(BuildContext context) {
    // Potentially, provide a simpler TabManager or specific state for this single window
    return MaterialApp(
      title: tabTitle,
      theme: ThemeData(
        primarySwatch: Colors.teal, // Different theme for detached?
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: DetachedTabWindowWidget(
        windowController: windowController,
        tabId: tabId,
        tabTitle: tabTitle,
        initialContent: Center(child: Text('Content for $tabTitle (ID: ${tabId.substring(tabId.length - 4)})')),
      ),
    );
  }
}

// Widget for the content of the detached tab window
class DetachedTabWindowWidget extends StatelessWidget {
  final WindowController windowController;
  final String tabId;
  final String tabTitle;
  final Widget initialContent;

  const DetachedTabWindowWidget({
    super.key,
    required this.windowController,
    required this.tabId,
    required this.tabTitle,
    required this.initialContent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tabTitle),
        leading: IconButton( // Example: Add a button to signal merge
          icon: Icon(Icons.merge_type),
          onPressed: () async {
            // Send data back to main window (windowId 0)
            // This is a placeholder for the "drag window to merge" step
            if (WindowController.fromWindowId(0) != null) {
               DesktopMultiWindow.invokeMethod(
                0, // Assuming 0 is the main window ID
                "mergeTab",
                jsonEncode({'tabId': tabId, 'tabTitle': tabTitle, /* other data */}),
              );
              // Optionally close this window after sending
              // windowController.close();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              windowController.close();
            },
          )
        ],
      ),
      body: initialContent, // Display the passed content
    );
  }
}


class MyApp extends StatelessWidget {
  final bool isMainWindow;
  const MyApp({super.key, this.isMainWindow = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Multi-Tab Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: isMainWindow ? const TabbedWindow() : null, // Main window gets TabbedWindow
      // If not main window, the specific DetachedTabApp will be run directly by main()
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

  @override
  void initState() {
    super.initState();
    _tabManager = Provider.of<TabManager>(context, listen: false);
    _tabController = TabController(length: _tabManager.tabs.length, vsync: this);
    _tabManager.addListener(_handleTabChange);
    _tabController.addListener(_handleTabSelection);

    // Listener for messages from other windows (e.g., for merging)
    DesktopMultiWindow.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call, int fromWindowId) async {
    if (call.method == "mergeTab") {
      final args = jsonDecode(call.arguments) as Map<String, dynamic>;
      final tabId = args['tabId'] as String;
      final tabTitle = args['tabTitle'] as String;

      // Check if tab with this ID already exists (e.g. if user didn't close the original)
      // For now, let's assume we always add it as new, or replace if ID exists.
      // A more robust solution would be needed for perfect state sync.
      print('Main window received merge request for tab: $tabTitle (ID: $tabId) from window $fromWindowId');

      // Potentially close the source window
      // final fromWindow = WindowController.fromWindowId(fromWindowId);
      // fromWindow?.close();


      // Add it as a new tab
      _tabManager.addTab(TabModel(
          id: tabId, // Reuse ID or generate new? For now, reuse.
          title: tabTitle,
          content: Center(child: Text('Content for $tabTitle (ID: ${tabId.substring(tabId.length-4)}) - Merged'))
      ));
      return "Merge request processed";
    }
    return Future.value(null);
  }

  void _handleTabChange() {
    if (!mounted) return;

    final newTabCount = _tabManager.tabs.length;
    if (newTabCount == 0 && _tabController.length > 0) { // All tabs closed
        _tabController.removeListener(_handleTabSelection);
        _tabController.dispose();
        _tabController = TabController(length: 0, vsync: this); // Empty controller
        _tabController.addListener(_handleTabSelection);
        setState(() {}); // Update UI to show empty state
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
    DesktopMultiWindow.setMethodCallHandler(null); // Clear handler
    super.dispose();
  }

  void _onTabDraggedOut(TabModel tabModel) async {
    print("Tab dragged out: ${tabModel.title}");

    // 1. Create new window
    final newWindow = await DesktopMultiWindow.createWindow(jsonEncode({
      'tabId': tabModel.id,
      'tabTitle': tabModel.title,
      // 'initialContentData': ... // serialize tabModel.content if needed, or reconstruct in sub-window
    }));

    newWindow
      ..setFrame(const Offset(100, 100) & const Size(800, 600)) // Example position & size
      ..setTitle(tabModel.title)
      ..show();

    // 2. Remove tab from this window
    // Important: Ensure this doesn't trigger unwanted index changes before new window is ready
    // Consider a slight delay or ensure TabManager handles empty state gracefully
    _tabManager.removeTabById(tabModel.id, preventEmptyRecreation: true);
  }


  @override
  Widget build(BuildContext context) {
    final tabManager = Provider.of<TabManager>(context);

    if (tabManager.tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Multi-Tab Browser'),
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
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Tab Browser'),
        bottom: TabBar(
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
                    int tabIndexToRemove = tabManager.tabs.indexWhere((t) => t.id == tabModel.id);
                    if (tabIndexToRemove != -1) {
                       // Default behavior for close button: allow recreation if it's the last tab and manager is configured to do so.
                       // If we want the window to close when the last tab is closed by its button,
                       // this logic and TabManager's would need adjustment.
                       // For now, it might recreate a new "Tab 1" if this was the last tab.
                       _tabManager.removeTabById(tabModel.id, preventEmptyRecreation: false);
                    }
                  },
                  child: const Icon(Icons.close, size: 16),
                ),
              ],
            );

            return Draggable<TabModel>(
              data: tabModel,
              feedback: Material( // Material needed for text style during drag
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(tabModel.title, style: Theme.of(context).textTheme.bodyLarge),
                ),
              ),
              childWhenDragging: Opacity( // How the tab looks in the bar while dragging
                opacity: 0.5,
                child: Tab(child: tabContent),
              ),
              onDraggableCanceled: (velocity, offset) {
                // This is called if the draggable is not accepted by any DragTarget.
                // We assume this means it was dragged "out".
                _onTabDraggedOut(tabModel);
              },
              onDragEnd: (details) {
                // onDragEnd is called regardless of whether it was accepted or cancelled.
                // If accepted by a DragTarget, details.wasAccepted will be true.
                // If not (e.g. dropped outside, or no target), it's effectively a cancel.
                // Using onDraggableCanceled is more specific for our "drag out" case.
              },
              child: Tab(child: tabContent),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
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
}
