module labour::Syntax

/*
 * Define a concrete syntax for LaBouR. The language's specification is available in the PDF (Section 2)
 * This module only describes the shape of the language; semantic checks stay separate.
 */

/*
 * Note, the Server expects the language base to be called BoulderingWall.
 * You are free to change this name, but if you do so, make sure to change everywhere else to make sure the
 * plugin works accordingly.
 */

layout Layout = WhitespaceOrComment*;

/*
 * Basic lexical elements used by the grammar.
 */
lexical WhitespaceOrComment
  = [\t-\n\r\ ]
  | "//" ![\n\r]* $
  ;

lexical STRING = "\"" ![\"]* "\"";
lexical INT = "-"? [0-9]+;
lexical HOLDID = "\"" [0-9][0-9][0-9][0-9] "\"";
lexical Id = [a-zA-Z][a-zA-Z0-9_]*;

syntax StringLiteral = stringLiteral: STRING;
syntax IntLiteral = intLiteral: INT;
syntax HoldId = holdId: HOLDID;

/*
 * Top-level rule for a complete wall specification.
 */
start syntax BoulderingWall
  = wall: "bouldering_wall" StringLiteral wallId "{"
      "routes" "[" RouteList routes "]" ","
      "volumes" "[" VolumeList volumes "]"
    "}";

/*
 * Lists
 * These named list rules are here to simplify the cst to ast translation.
 * Rascal's list notation ({Something ","}*) produces a CST shape that is
 * hard to pattern-match during translation, so we convert these lists in 
 * separate helpers.
 */
syntax RouteList
  = routeList: {Route ","}* routes;

syntax VolumeList
  = volumeList: {Volume ","}* volumes;

syntax RouteStepList
  = routeStepList: {RouteStep ","}* steps;

syntax CirclePropertyList
  = circlePropertyList: {CircleProperty ","}* circleProperties;

syntax TrianglePropertyList
  = trianglePropertyList: {TriangleProperty ","}* triangleProperties;

syntax HoldList
  = holdList: {Hold ","}* holds;

syntax CoordinateList
  = coordinateList: {Coordinate ","}* coordinates;

syntax HoldPropertyList
  = holdPropertyList: {HoldProperty ","}* holdProperties;

syntax ColourList
  = colourList: {Colour ","}* colours;

/*
 * Routes
 */
syntax Route
  = route: "bouldering_route" StringLiteral routeId "{"
      "grade" ":" StringLiteral grade ","
      "grid_base_point" Coordinate gridBasePoint ","
      "holds" "[" RouteStepList steps "]"
    "}";

syntax RouteStep
  = normalHold: HoldId holdId
  | splitHold: "{" HoldId left "," HoldId right "}";

/*
 * Coordinates used for walls, holds, and volumes.
 */
syntax Coordinate
  = coordinate: "{" "x" ":" IntLiteral x "," "y" ":" IntLiteral y "}";

/*
 * Volumes
 */
syntax Volume
  = circleVolume: Circle
  | triangleVolume: Triangle;

syntax Circle
  = circle: "circle" "{" CirclePropertyList circleProperties "}";

syntax CircleProperty
  = circlePos: "pos" ":" Coordinate circleCoord 
  | circleDepth: "depth" ":" IntLiteral circleDepth
  | circleRadius: "radius" ":" IntLiteral circleRadius
  | circleFrontHolds: "front_holds" "[" HoldList circleFrontHolds "]"
  | circleSideHolds: "side_holds" "[" HoldList circleSideHolds "]";

syntax Triangle
  = triangle: "triangle" "{" TrianglePropertyList triangleProperties "}";

syntax TriangleProperty
  = trianglePos: "pos" ":" Coordinate triangleCoord
  | triangleExtrusion: "extrusion" ":" Coordinate triangleExtrusion
  | triangleDepth: "depth" ":" IntLiteral triangleDepth
  | triangleCorners: "corners" "[" CoordinateList triangleCorners "]"
  | triangleLeftHolds: "left_holds" "[" HoldList triangleLeftHolds "]"
  | triangleRightHolds: "right_holds" "[" HoldList triangleRightHolds "]"
  | triangleBottomHolds: "bottom_holds" "[" HoldList triangleBottomHolds "]";

/*
 * Holds
 */
syntax Hold
  = hold: "hold" HoldId holdId "{" HoldPropertyList properties "}";

syntax HoldProperty
  = holdPos: "pos" ":" HoldPosition position
  | holdShape: "shape" ":" StringLiteral shape
  | holdColours: "colours" "[" ColourList colours "]"
  | holdStart: "start_hold" ":" IntLiteral startNumber
  | holdEnd: "end_hold"
  | holdRotation: "rotation" ":" IntLiteral rotation
  ;

/*
 * A hold position can be absolute or angle-based.
 */
syntax HoldPosition
  = xyPosition: Coordinate coordinate
  | anglePosition: "{" "angle" ":" IntLiteral angle "}"
  ;

/*
 * Allowed colour values for holds.
 */
syntax Colour
  = white: "white"
  | yellow: "yellow"
  | green: "green"
  | blue: "blue"
  | red: "red"
  | purple: "purple"
  | pink: "pink"
  | black: "black"
  | orange: "orange"
  ;
