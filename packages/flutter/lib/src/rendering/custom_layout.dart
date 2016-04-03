// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'box.dart';
import 'object.dart';

// For SingleChildLayoutDelegate and RenderCustomSingleChildLayoutBox, see shifted_box.dart

/// [ParentData] used by [RenderCustomMultiChildLayoutBox].
class MultiChildLayoutParentData extends ContainerBoxParentDataMixin<RenderBox> {
  /// An object representing the identity of this child.
  Object id;

  @override
  String toString() => '${super.toString()}; id=$id';
}

/// A delegate that controls the layout of multiple children.
///
/// Used with [MultiChildCustomLayout], the widget for the
/// [RenderCustomMultiChildLayoutBox] render object.
///
/// Subclasses must override some or all of the methods
/// marked "Override this method to..." to provide the constraints and
/// positions of the children.
abstract class MultiChildLayoutDelegate {
  Map<Object, RenderBox> _idToChild;
  Set<RenderBox> _debugChildrenNeedingLayout;

  /// True if a non-null LayoutChild was provided for the specified id.
  ///
  /// Call this from the [performLayout] or [getSize] methods to
  /// determine which children are available, if the child list might
  /// vary.
  bool hasChild(Object childId) => _idToChild[childId] != null;

  /// Ask the child to update its layout within the limits specified by
  /// the constraints parameter. The child's size is returned.
  ///
  /// Call this from your [performLayout] function to lay out each
  /// child. Every child must be laid out using this function exactly
  /// once each time the [performLayout] function is invoked.
  Size layoutChild(Object childId, BoxConstraints constraints) {
    final RenderBox child = _idToChild[childId];
    assert(() {
      if (child == null) {
        throw new FlutterError(
          'The $this custom multichild layout delegate tried to lay out a non-existent child.\n'
          'There is no child with the id "$childId".'
        );
      }
      if (!_debugChildrenNeedingLayout.remove(child)) {
        throw new FlutterError(
          'The $this custom multichild layout delegate tried to lay out the child with id "$childId" more than once.\n'
          'Each child must be laid out exactly once.'
        );
      }
      try {
        assert(constraints.debugAssertIsNormalized);
      } on AssertionError catch (exception) {
        throw new FlutterError(
          'The $this custom multichild layout delegate provided invalid box constraints for the child with id "$childId".\n'
          '$exception\n'
          'The minimum width and height must be greater than or equal to zero.\n'
          'The maximum width must be greater than or equal to the minimum width.\n'
          'The maximum height must be greater than or equal to the minimum height.'
        );
      }
      return true;
    });
    child.layout(constraints, parentUsesSize: true);
    return child.size;
  }

  /// Specify the child's origin relative to this origin.
  ///
  /// Call this from your [performLayout] function to position each
  /// child. If you do not call this for a child, its position will
  /// remain unchanged. Children initially have their position set to
  /// (0,0), i.e. the top left of the [RenderCustomMultiChildLayoutBox].
  void positionChild(Object childId, Offset offset) {
    final RenderBox child = _idToChild[childId];
    assert(() {
      if (child == null) {
        throw new FlutterError(
          'The $this custom multichild layout delegate tried to position out a non-existent child:\n'
          'There is no child with the id "$childId".'
        );
      }
      if (offset == null) {
        throw new FlutterError(
          'The $this custom multichild layout delegate provided a null position for the child with id "$childId".'
        );
      }
      return true;
    });
    final MultiChildLayoutParentData childParentData = child.parentData;
    childParentData.offset = offset;
  }

  String _debugDescribeChild(RenderBox child) {
    final MultiChildLayoutParentData childParentData = child.parentData;
    return '${childParentData.id}: $child';
  }

  void _callPerformLayout(Size size, RenderBox firstChild) {
    // A particular layout delegate could be called reentrantly, e.g. if it used
    // by both a parent and a child. So, we must restore the _idToChild map when
    // we return.
    final Map<Object, RenderBox> previousIdToChild = _idToChild;

    Set<RenderBox> debugPreviousChildrenNeedingLayout;
    assert(() {
      debugPreviousChildrenNeedingLayout = _debugChildrenNeedingLayout;
      _debugChildrenNeedingLayout = new Set<RenderBox>();
      return true;
    });

    try {
      _idToChild = new Map<Object, RenderBox>();
      RenderBox child = firstChild;
      while (child != null) {
        final MultiChildLayoutParentData childParentData = child.parentData;
        assert(() {
          if (childParentData.id == null) {
            throw new FlutterError(
              'The following child has no ID:\n'
              '  $child\n'
              'Every child of a RenderCustomMultiChildLayoutBox must have an ID in its parent data.'
            );
          }
          return true;
        });
        _idToChild[childParentData.id] = child;
        assert(() {
          _debugChildrenNeedingLayout.add(child);
          return true;
        });
        child = childParentData.nextSibling;
      }
      performLayout(size);
      assert(() {
        if (_debugChildrenNeedingLayout.isNotEmpty) {
          if (_debugChildrenNeedingLayout.length > 1) {
            throw new FlutterError(
              'The $this custom multichild layout delegate forgot to lay out the following children:\n'
              '  ${_debugChildrenNeedingLayout.map(_debugDescribeChild).join("\n  ")}\n'
              'Each child must be laid out exactly once.'
            );
          } else {
            throw new FlutterError(
              'The $this custom multichild layout delegate forgot to lay out the following child:\n'
              '  ${_debugDescribeChild(_debugChildrenNeedingLayout.single)}\n'
              'Each child must be laid out exactly once.'
            );
          }
        }
        return true;
      });
    } finally {
      _idToChild = previousIdToChild;
      assert(() {
        _debugChildrenNeedingLayout = debugPreviousChildrenNeedingLayout;
        return true;
      });
    }
  }

  /// Override this method to return the size of this object given the
  /// incoming constraints. The size cannot reflect the instrinsic
  /// sizes of the children. If this layout has a fixed width or
  /// height the returned size can reflect that; the size will be
  /// constrained to the given constraints.
  ///
  /// By default, attempts to size the box to the biggest size
  /// possible given the constraints.
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  /// Override this method to lay out and position all children given this
  /// widget's size. This method must call [layoutChild] for each child. It
  /// should also specify the final position of each child with [positionChild].
  void performLayout(Size size);

  /// Override this method to return true when the children need to be
  /// laid out. This should compare the fields of the current delegate
  /// and the given oldDelegate and return true if the fields are such
  /// that the layout would be different.
  bool shouldRelayout(MultiChildLayoutDelegate oldDelegate);

  /// Override this method to include additional information in the
  /// debugging data printed by [debugDumpRenderTree] and friends.
  ///
  /// By default, returns the [runtimeType] of the class.
  @override
  String toString() => '$runtimeType';
}

/// Defers the layout of multiple children to a delegate.
///
/// The delegate can determine the layout constraints for each child and can
/// decide where to position each child. The delegate can also determine the
/// size of the parent, but the size of the parent cannot depend on the sizes of
/// the children.
class RenderCustomMultiChildLayoutBox extends RenderBox
  with ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
       RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  RenderCustomMultiChildLayoutBox({
    List<RenderBox> children,
    MultiChildLayoutDelegate delegate
  }) : _delegate = delegate {
    assert(delegate != null);
    addAll(children);
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData)
      child.parentData = new MultiChildLayoutParentData();
  }

  /// The delegate that controls the layout of the children.
  MultiChildLayoutDelegate get delegate => _delegate;
  MultiChildLayoutDelegate _delegate;
  void set delegate (MultiChildLayoutDelegate newDelegate) {
    assert(newDelegate != null);
    if (_delegate == newDelegate)
      return;
    if (newDelegate.runtimeType != _delegate.runtimeType || newDelegate.shouldRelayout(_delegate))
      markNeedsLayout();
    _delegate = newDelegate;
  }

  Size _getSize(BoxConstraints constraints) {
    assert(constraints.debugAssertIsNormalized);
    return constraints.constrain(_delegate.getSize(constraints));
  }

  @override
  double getMinIntrinsicWidth(BoxConstraints constraints) {
    return _getSize(constraints).width;
  }

  @override
  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    return _getSize(constraints).width;
  }

  @override
  double getMinIntrinsicHeight(BoxConstraints constraints) {
    return _getSize(constraints).height;
  }

  @override
  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    return _getSize(constraints).height;
  }

  @override
  void performLayout() {
    size = _getSize(constraints);
    delegate._callPerformLayout(size, firstChild);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(HitTestResult result, { Point position }) {
    return defaultHitTestChildren(result, position: position);
  }
}
