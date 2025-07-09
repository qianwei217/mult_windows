import 'package:flutter/material.dart';
import 'dart:math'; // For unique IDs and zIndex management
import 'tab_manager.dart'; // For TabModel, to know what we're detaching

class PanelModel {
  final String id;
  final String title;
  final Widget contentWidget; // The actual widget instance
  Offset offset;
  Size size;
  double zIndex;

  PanelModel({
    required this.id,
    required this.title,
    required this.contentWidget,
    this.offset = Offset.zero,
    this.size = const Size(400, 300), // Default size
    this.zIndex = 0,
  });
}

class PanelManager with ChangeNotifier {
  final List<PanelModel> _panels = [];
  double _currentMaxZIndex = 0; // To manage bringing panels to front

  List<PanelModel> get panels => List.unmodifiable(_panels);

  // Detaches a tab and creates a panel from it.
  // The TabManager should handle removing the tab from its own list.
  void detachTabToPanel(TabModel tabModel, Offset initialPosition) {
    _currentMaxZIndex++;
    final newPanel = PanelModel(
      id: 'panel_${tabModel.id}', // Create a panel-specific ID
      title: tabModel.title,
      contentWidget: tabModel.content, // Moves the widget instance
      offset: initialPosition,
      zIndex: _currentMaxZIndex,
      // Potentially use a default size or calculate from content if possible (hard)
    );
    _panels.add(newPanel);
    notifyListeners();
  }

  // Data structure to return when merging a panel back to tabs
  // This helps TabManager recreate the tab.
  // Alternatively, PanelModel could store the original TabModel's non-widget data.
  // For now, let's assume TabManager can recreate a tab from title and contentWidget.
  ({Widget contentWidget, String title, String originalTabId})? mergePanelToTabs(String panelId) {
    PanelModel? panelToMerge;
    int panelIndex = _panels.indexWhere((p) => p.id == panelId);

    if (panelIndex != -1) {
      panelToMerge = _panels.removeAt(panelIndex);
      // Adjust z-indices if needed, though simply removing might be fine.
      // If many panels, could re-normalize z-indices or find new max.
      // For now, _currentMaxZIndex only ever increases. This is simple but could grow large.
      // A more robust z-index management might be needed for very long sessions.
      notifyListeners();

      // Extract original tab ID if panel ID was derived from it
      String originalTabId = panelToMerge.id.startsWith('panel_')
                             ? panelToMerge.id.substring('panel_'.length)
                             : panelToMerge.id;

      return (contentWidget: panelToMerge.contentWidget, title: panelToMerge.title, originalTabId: originalTabId);
    }
    return null;
  }

  void updatePanelPosition(String panelId, Offset newOffset) {
    final panel = _panels.firstWhere((p) => p.id == panelId, orElse: () => throw Exception("Panel not found"));
    panel.offset = newOffset;
    notifyListeners();
  }

  void updatePanelSize(String panelId, Size newSize) { // Added for future use
    final panel = _panels.firstWhere((p) => p.id == panelId, orElse: () => throw Exception("Panel not found"));
    panel.size = newSize;
    notifyListeners();
  }

  void bringPanelToFront(String panelId) {
    final panel = _panels.firstWhere((p) => p.id == panelId, orElse: () => throw Exception("Panel not found"));
    // Only increase zIndex if it's not already the topmost
    if (panel.zIndex < _currentMaxZIndex) {
      _currentMaxZIndex++;
      panel.zIndex = _currentMaxZIndex;
      // Optional: Sort panels by zIndex for rendering if Stack doesn't inherently respect it based on list order after updates.
      // _panels.sort((a, b) => a.zIndex.compareTo(b.zIndex)); // Usually not needed if Stack children order is determined by list order
      notifyListeners();
    }
  }

  void closePanel(String panelId) {
    _panels.removeWhere((p) => p.id == panelId);
    // Similar z-index considerations as mergePanelToTabs
    notifyListeners();
  }
}
