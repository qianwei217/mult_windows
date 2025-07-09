import 'package:flutter/material.dart';
import 'panel_manager.dart'; // Assuming PanelModel and PanelManager are in here

class FloatingPanelWidget extends StatefulWidget {
  final PanelModel panelModel;
  final PanelManager panelManager;

  const FloatingPanelWidget({
    super.key, // Use Key(panelModel.id) when creating in Stack for better state preservation if panels reorder
    required this.panelModel,
    required this.panelManager,
  });

  @override
  State<FloatingPanelWidget> createState() => _FloatingPanelWidgetState();
}

class _FloatingPanelWidgetState extends State<FloatingPanelWidget> {
  // No local offset needed if PanelManager is the source of truth and updates trigger rebuilds.
  // If we wanted smoother local dragging before updating PanelManager, we might use a local offset.
  // For now, direct update to PanelManager is simpler.

  @override
  Widget build(BuildContext context) {
    // This Draggable is for merging the panel back into the TabBar
    return Draggable<String>(
      data: widget.panelModel.id, // Data is the panelId
      feedback: Material( // Feedback is a slightly smaller, perhaps semi-transparent version of the panel
        elevation: 8.0,
        borderRadius: BorderRadius.circular(8.0),
        child: Opacity(
          opacity: 0.7,
          child: Container(
            width: widget.panelModel.size.width * 0.8, // Smaller feedback
            height: widget.panelModel.size.height * 0.8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.blueAccent, width: 2),
              color: Colors.white,
            ),
            child: Column( // Simplified content for feedback
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.blueGrey.shade200,
                  child: Text(widget.panelModel.title, style: TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                Expanded(child: Center(child: Icon(Icons.tab, size: 40, color: Colors.grey.shade400))),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity( // How the panel looks in the Stack while being dragged for merge
        opacity: 0.4,
        child: _buildPanelContent(context),
      ),
      onDragStarted: () {
        // Optional: could set a flag in PanelManager if specific visual state is needed for the source panel
        widget.panelManager.bringPanelToFront(widget.panelModel.id); // Ensure it's on top during drag for merge
      },
      // onDragEnd, onDraggableCanceled can be used if we need to handle drops not on the TabBar target
      // For example, if onDraggableCanceled is called, it means it wasn't merged.
      // If onDragCompleted is called, it was accepted by a DragTarget (hopefully the TabBar).
      child: _buildPanelContent(context), // The actual panel
    );
  }

  // Extracted panel content build method for reuse by Draggable's child and childWhenDragging
  Widget _buildPanelContent(BuildContext context) {
    return Material(
      elevation: 4.0 + (widget.panelModel.zIndex / 100),
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        width: widget.panelModel.size.width,
        height: widget.panelModel.size.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.blueGrey.shade400, width: 1),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Custom Title Bar - This GestureDetector is for moving the panel around the Stack
            GestureDetector(
              onPanStart: (details) {
                widget.panelManager.bringPanelToFront(widget.panelModel.id);
              },
              onPanUpdate: (details) {
                Offset newOffset = widget.panelModel.offset + details.delta;
                widget.panelManager.updatePanelPosition(widget.panelModel.id, newOffset);
              },
              child: Container( // The actual title bar content
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7.0), // Match parent's border radius minus border width
                    topRight: Radius.circular(7.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.panelModel.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 18,
                      onPressed: () {
                        widget.panelManager.closePanel(widget.panelModel.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Colors.blueGrey),
            // Content
            Expanded(
              child: ClipRRect( // Ensure content respects rounded corners if it's flush
                 borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(7.0),
                    bottomRight: Radius.circular(7.0),
                  ),
                child: widget.panelModel.contentWidget,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
