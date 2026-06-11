module labour::CST2AST

import IO;
import Prelude;
import String;
import ParseTree;

import labour::AST;
extend labour::Syntax;

/*
 * Implement a mapping from concrete syntax trees (CSTs) to abstract syntax trees (ASTs)
 * Hint: Use switch to do case distinction with concrete patterns
 * Map regular CST arguments (e.g., *, +, ?) to lists
 * Map lexical nodes to Rascal primitive types (bool, int, str)
 * Keeping this translation in its own module separates parsing details from checking logic.
 */

/*
 * Remove the quotes around string lexical values.
 */
str unquote(Tree t) {
  str s = unparse(t);
  return substring(s, 1, size(s) - 1);
}

/*
 * Convert an integer literal subtree to a Rascal int.
 */
int toIntLiteral(Tree t) {
  return toInt(unparse(t));
}

/*
 * Top-level conversion
 */
public ASTBoulderingWall cst2ast((start[BoulderingWall]) `bouldering_wall <StringLiteral wallId> { routes [ <RouteList routes> ], volumes [ <VolumeList volumes> ] }`) {
  return boulderingWall(
    unquote(wallId),
    cst2astRouteList(routes),
    cst2astVolumeList(volumes)
  );
}

/*
 * List conversions collect repeated CST nodes into AST lists.
 * These helpers exist because the separated-list CST nodes are easier to process here
 * than directly inside each parent translation rule.
 */
public list[ASTRoute] cst2astRouteList(RouteList routeListCst) {
  list[ASTRoute] result = [];

  visit (routeListCst) {
    case Route r:
      result += [cst2astRoute(r)];
  }

  return result;
}

public list[ASTVolume] cst2astVolumeList(VolumeList volumeListCst) {
  list[ASTVolume] result = [];

  visit (volumeListCst) {
    case Volume v:
      result += [cst2astVolume(v)];
  }

  return result;
}

public list[ASTRouteStep] cst2astRouteStepList(RouteStepList stepListCst) {
  list[ASTRouteStep] result = [];

  visit (stepListCst) {
    case RouteStep s:
      result += [cst2astRouteStep(s)];
  }

  return result;
}

public list[ASTCircleProperty] cst2astCirclePropertyList(CirclePropertyList listCst) {
  list[ASTCircleProperty] result = [];

  visit (listCst) {
    case CircleProperty p:
      result += [cst2astCircleProperty(p)];
  }

  return result;
}

public list[ASTTriangleProperty] cst2astTrianglePropertyList(TrianglePropertyList listCst) {
  list[ASTTriangleProperty] result = [];

  visit (listCst) {
    case TriangleProperty p:
      result += [cst2astTriangleProperty(p)];
  }

  return result;
}

public list[ASTHold] cst2astHoldList(HoldList listCst) {
  list[ASTHold] result = [];

  visit (listCst) {
    case Hold h:
      result += [cst2astHold(h)];
  }

  return result;
}

public list[ASTCoordinate] cst2astCoordinateList(CoordinateList listCst) {
  list[ASTCoordinate] result = [];

  visit (listCst) {
    case Coordinate c:
      result += [cst2astCoordinate(c)];
  }

  return result;
}

public list[ASTHoldProperty] cst2astHoldPropertyList(HoldPropertyList listCst) {
  list[ASTHoldProperty] result = [];

  visit (listCst) {
    case HoldProperty p:
      result += [cst2astHoldProperty(p)];
  }

  return result;
}

public list[ASTColour] cst2astColourList(ColourList listCst) {
  list[ASTColour] result = [];

  visit (listCst) {
    case Colour c:
      result += [cst2astColour(c)];
  }

  return result;
}

/*
 * Routes
 */
public ASTRoute cst2astRoute(Route routeCst) {
  switch (routeCst) {
    case (Route) `bouldering_route <StringLiteral routeId> { grade: <StringLiteral grade>, grid_base_point <Coordinate gridBasePoint>, holds [ <RouteStepList steps> ] }`:
      return route(
        unquote(routeId),
        unquote(grade),
        cst2astCoordinate(gridBasePoint),
        cst2astRouteStepList(steps)
      );

    default:
      throw "Unexpected Route";
  }
}

public ASTRouteStep cst2astRouteStep(RouteStep step) {
  switch (step) {
    case (RouteStep) `<HoldId holdId>`:
      return normalHold(unquote(holdId));

    case (RouteStep) `{ <HoldId left>, <HoldId right> }`:
      return splitHold(unquote(left), unquote(right));

    default:
      throw "Unexpected RouteStep";
  }
}

/*
 * Coordinates
 */
public ASTCoordinate cst2astCoordinate(Coordinate coord) {
  switch (coord) {
    case (Coordinate) `{ x: <IntLiteral x>, y: <IntLiteral y> }`:
      return coordinate(toIntLiteral(x), toIntLiteral(y));

    default:
      throw "Unexpected Coordinate";
  }
}

/*
 * Volumes
 */
public ASTVolume cst2astVolume(Volume volume) {
  switch (volume) {
    case (Volume) `<Circle circleCst>`:
      return cst2astCircle(circleCst);

    case (Volume) `<Triangle triangleCst>`:
      return cst2astTriangle(triangleCst);

    default:
      throw "Unexpected Volume";
  }
}

public ASTVolume cst2astCircle(Circle circleCst) {
  switch (circleCst) {
    case (Circle) `circle { <CirclePropertyList circleProperties> }`:
      return circle(cst2astCirclePropertyList(circleProperties));

    default:
      throw "Unexpected Circle";
  }
}

public ASTVolume cst2astTriangle(Triangle triangleCst) {
  switch (triangleCst) {
    case (Triangle) `triangle { <TrianglePropertyList triangleProperties> }`:
      return triangle(cst2astTrianglePropertyList(triangleProperties));

    default:
      throw "Unexpected Triangle";
  }
}

/*
 * Circle properties
 */
public ASTCircleProperty cst2astCircleProperty(CircleProperty property) {
  switch (property) {
    case (CircleProperty) `pos: <Coordinate coord>`:
      return circlePos(cst2astCoordinate(coord));

    case (CircleProperty) `depth: <IntLiteral depth>`:
      return circleDepth(toIntLiteral(depth));

    case (CircleProperty) `radius: <IntLiteral radius>`:
      return circleRadius(toIntLiteral(radius));

    case (CircleProperty) `front_holds [ <HoldList holds> ]`:
      return circleFrontHolds(cst2astHoldList(holds));

    case (CircleProperty) `side_holds [ <HoldList holds> ]`:
      return circleSideHolds(cst2astHoldList(holds));

    default:
      throw "Unexpected CircleProperty";
  }
}

/*
 * Triangle properties
 */
public ASTTriangleProperty cst2astTriangleProperty(TriangleProperty property) {
  switch (property) {
    case (TriangleProperty) `pos: <Coordinate coord>`:
      return trianglePos(cst2astCoordinate(coord));

    case (TriangleProperty) `extrusion: <Coordinate coord>`:
      return triangleExtrusion(cst2astCoordinate(coord));

    case (TriangleProperty) `depth: <IntLiteral depth>`:
      return triangleDepth(toIntLiteral(depth));

    case (TriangleProperty) `corners [ <CoordinateList corners> ]`:
      return triangleCorners(cst2astCoordinateList(corners));

    case (TriangleProperty) `left_holds [ <HoldList holds> ]`:
      return triangleLeftHolds(cst2astHoldList(holds));

    case (TriangleProperty) `right_holds [ <HoldList holds> ]`:
      return triangleRightHolds(cst2astHoldList(holds));

    case (TriangleProperty) `bottom_holds [ <HoldList holds> ]`:
      return triangleBottomHolds(cst2astHoldList(holds));

    default:
      throw "Unexpected TriangleProperty";
  }
}

/*
 * Holds
 */
public ASTHold cst2astHold(Hold holdCst) {
  switch (holdCst) {
    case (Hold) `hold <HoldId holdId> { <HoldPropertyList properties> }`:
      return hold(
        unquote(holdId),
        cst2astHoldPropertyList(properties)
      );

    default:
      throw "Unexpected Hold";
  }
}

public ASTHoldProperty cst2astHoldProperty(HoldProperty property) {
  switch (property) {
    case (HoldProperty) `pos: <HoldPosition position>`:
      return holdPos(cst2astHoldPosition(position));

    case (HoldProperty) `shape: <StringLiteral shape>`:
      return holdShape(unquote(shape));

    case (HoldProperty) `colours [ <ColourList colours> ]`:
      return holdColours(cst2astColourList(colours));

    case (HoldProperty) `start_hold: <IntLiteral startNumber>`:
      return holdStart(toIntLiteral(startNumber));

    case (HoldProperty) `end_hold`:
      return holdEnd();

    case (HoldProperty) `rotation: <IntLiteral rotation>`:
      return holdRotation(toIntLiteral(rotation));

    default:
      throw "Unexpected HoldProperty";
  }
}

/*
 * Hold positions can be coordinates or angles.
 */
public ASTHoldPosition cst2astHoldPosition(HoldPosition position) {
  switch (position) {
    case (HoldPosition) `<Coordinate coord>`:
      return xyPosition(cst2astCoordinate(coord));

    case (HoldPosition) `{ angle: <IntLiteral angle> }`:
      return anglePosition(toIntLiteral(angle));

    default:
      throw "Unexpected HoldPosition";
  }
}

/*
 * Colours
 */
public ASTColour cst2astColour(Colour colour) {
  switch (colour) {
    case (Colour) `white`:
      return white();

    case (Colour) `yellow`:
      return yellow();

    case (Colour) `green`:
      return green();

    case (Colour) `blue`:
      return blue();

    case (Colour) `red`:
      return red();

    case (Colour) `purple`:
      return purple();

    case (Colour) `pink`:
      return pink();

    case (Colour) `black`:
      return black();

    case (Colour) `orange`:
      return orange();

    default:
      throw "Unexpected Colour";
  }
}
