import QtQuick
import QtQuick.Shapes

// A square inverted-corner fillet. Place one on each side of a panel that sits
// on a screen edge so the panel flows into the edge instead of meeting it at a
// hard corner.
//
// Mirroring is done in the path itself rather than with a Scale transform, so
// the parent is free to set its own `transform` (e.g. a slide animation)
// without silently replacing the mirror.
Shape {
  id: root

  property int radius: 14
  property color color: "#1e1e2d"
  property bool isTop: false
  property bool mirrored: false   // true = flipped horizontally (left-hand side)

  implicitWidth: radius
  implicitHeight: radius

  preferredRendererType: Shape.CurveRenderer

  // Horizontal coordinate, flipped when mirrored
  function mx(v) { return mirrored ? radius - v : v }

  // Flipping horizontally reverses the winding of the arc
  readonly property int arcDirection: (isTop !== mirrored)
    ? PathArc.Counterclockwise
    : PathArc.Clockwise

  ShapePath {
    fillColor: root.color
    strokeColor: "transparent"

    startX: root.mx(root.isTop ? root.radius : 0)
    startY: 0

    PathLine { x: root.mx(0); y: root.isTop ? 0 : root.radius }
    PathLine { x: root.mx(root.isTop ? 0 : root.radius); y: root.radius }
    PathArc {
      x: root.mx(root.isTop ? root.radius : 0)
      y: 0
      radiusX: root.radius
      radiusY: root.radius
      direction: root.arcDirection
    }
  }
}
