import 'dart:async';

import 'package:flutter/material.dart';

class UserFocusedTab<T> {
  final Widget child;
  final T? attachment;
  final Widget thumbnail;
  final bool showCloseButton;
  final bool reorderable;

  const UserFocusedTab({required this.child, this.attachment, required this.thumbnail, this.showCloseButton = false, this.reorderable = true});
}

class UserFocusedTabViewController<T> {
  List<UserFocusedTab<T>> tabs;
  UserFocusedTabViewController(this.tabs);

  final StreamController<int> _onCurrentTabChangeController = StreamController.broadcast();
  final StreamController<(int? i, UserFocusedTab tab)> _onTabAddedController = StreamController.broadcast();
  final StreamController<int> _onTabRemovedController = StreamController.broadcast();

  void setCurrentTab(int i) {
    _onCurrentTabChangeController.sink.add(i);
  }

  void addTab(UserFocusedTab<T> tab, [int? i]) {
    _onTabAddedController.sink.add((i, tab));
  }

  void removeTab(int i) {
    _onTabRemovedController.sink.add(i);
  }
}

class UserFocusedTabView<T> extends StatefulWidget {
  final UserFocusedTabViewController<T> controller;
  final double? borderRadius;
  final bool reorderable;

  UserFocusedTabView({super.key, required this.controller, this.borderRadius, this.reorderable = false});

  @override
  State<UserFocusedTabView> createState() => _UserFocusedTabViewState<T>();
}

class _UserFocusedTabViewState<T> extends State<UserFocusedTabView> {
  StreamSubscription? _onCurrentTabChangeControllerSubscription;
  StreamSubscription? _onTabAddedControllerSubscription;
  StreamSubscription? _onTabRemovedControllerSubscription;

  int currentTab = 0;

  @override
  void initState() {
    _onCurrentTabChangeControllerSubscription = widget.controller._onCurrentTabChangeController.stream.listen((i) {
      currentTab = i;
      setState(() {});
    });

    _onTabAddedControllerSubscription = widget.controller._onTabAddedController.stream.listen((data) {
      widget.controller.tabs.insert(data.$1 ?? widget.controller.tabs.length, data.$2);
      setState(() {});
    });

    _onTabRemovedControllerSubscription = widget.controller._onTabRemovedController.stream.listen((i) {
      widget.controller.tabs.removeAt(i);
      if (currentTab >= i) widget.controller.setCurrentTab(i - 1);
      setState(() {});
    });

    super.initState();
  }

  @override
  void dispose() {
    _onCurrentTabChangeControllerSubscription?.cancel();
    _onTabAddedControllerSubscription?.cancel();
    _onTabRemovedControllerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ReorderableListView.builder(
        shrinkWrap: true,
        buildDefaultDragHandles: false,
        scrollDirection: Axis.horizontal,
        itemCount: widget.controller.tabs.length,
        onReorder: (oldIndex, newIndex) {
          var tabs = widget.controller.tabs;
          if (widget.reorderable == false || tabs[oldIndex].reorderable == false || (tabs.elementAtOrNull(newIndex) ?? tabs.elementAt(newIndex - 1)).reorderable == false) return;

          var tab = tabs.removeAt(oldIndex);
          if (newIndex > oldIndex) newIndex -= 1;
          tabs.insert(newIndex, tab);
          widget.controller.setCurrentTab(newIndex);
          setState(() {});
        },
        itemBuilder: ((context, i) {
          UserFocusedTab tab = widget.controller.tabs[i];
          Radius radius = widget.borderRadius == null ? Radius.zero : Radius.circular(widget.borderRadius!);
  
          Widget child = Container(
            key: Key("tab.container.${tab.hashCode}"),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(topLeft: radius, topRight: radius),
              color: currentTab == i ? (Theme.of(context).brightness == Brightness.light ? Colors.grey : const Color.fromARGB(255, 53, 60, 80)) : Colors.transparent,
            ),
            child: InkWell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: tab.thumbnail,
                    ),
                    if (tab.showCloseButton)
                    IconButton(onPressed: () => widget.controller.removeTab(i), icon: Icon(Icons.cancel_outlined), iconSize: 20),
                  ],
                ),
              ),
              onTap: () => widget.controller.setCurrentTab(i),
            ),
          );

          if (widget.reorderable && tab.reorderable) {
            return ReorderableDragStartListener(child: child, index: i, key: Key("tab.listener.${tab.hashCode}"));
          } else {
            return child;
          }
        }),
      ),
    );
  }
}

class UserFocusedTabViewContent extends StatefulWidget {
  final UserFocusedTabViewController controller;
  const UserFocusedTabViewContent({super.key, required this.controller});

  @override
  State<UserFocusedTabViewContent> createState() => _UserFocusedTabViewContentState();
}

class _UserFocusedTabViewContentState extends State<UserFocusedTabViewContent> {
  StreamSubscription? _onCurrentTabChangeControllerSubscription;
  int currentTab = 0;

  @override
  void initState() {
    _onCurrentTabChangeControllerSubscription = widget.controller._onCurrentTabChangeController.stream.listen((i) {
      currentTab = i;
      setState(() {});
    });

    super.initState();
  }

  @override
  void dispose() {
    _onCurrentTabChangeControllerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: currentTab,
      children: widget.controller.tabs.map((tab) => tab.child).toList(),
    );
  }
}