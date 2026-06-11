module labour::AST

/*
 * Define the Abstract Syntax for LaBouR
 * - Hint: make sure there is an almost one-to-one correspondence with the grammar in Syntax.rsc
 * The AST stays close to the grammar to keep the CST-to-AST translation simple.
 */

/*
 * Root node for a full wall description.
 */
data ASTBoulderingWall(loc src=|unknown:///|)
  = boulderingWall(str id, list[ASTRoute] routes, list[ASTVolume] volumes);

/*
 * Route definitions and route steps.
 */
data ASTRoute
  = route(str id, str grade, ASTCoordinate gridBasePoint, list[ASTRouteStep] steps);

data ASTRouteStep
  = normalHold(str holdId)
  | splitHold(str leftHoldId, str rightHoldId);

/*
 * Shared coordinate representation.
 */
data ASTCoordinate
  = coordinate(int x, int y);

/*
 * Volume definitions and their properties.
 * Separate constructors make the two volume variants explicit in later checks.
 */
data ASTVolume
  = circle(list[ASTCircleProperty] circleProperties)
  | triangle(list[ASTTriangleProperty] triangleProperties);

data ASTCircleProperty
  = circlePos(ASTCoordinate coord)
  | circleDepth(int depth)
  | circleRadius(int radius)
  | circleFrontHolds(list[ASTHold] holds)
  | circleSideHolds(list[ASTHold] holds);

data ASTTriangleProperty
  = trianglePos(ASTCoordinate coord)
  | triangleExtrusion(ASTCoordinate coord)
  | triangleDepth(int depth)
  | triangleCorners(list[ASTCoordinate] corners)
  | triangleLeftHolds(list[ASTHold] holds)
  | triangleRightHolds(list[ASTHold] holds)
  | triangleBottomHolds(list[ASTHold] holds);

/*
 * Hold definitions and their properties.
 * Properties stay in lists so validation can detect missing or repeated fields later.
 */
data ASTHold
  = hold(str id, list[ASTHoldProperty] properties);

data ASTHoldProperty
  = holdPos(ASTHoldPosition position)
  | holdShape(str shape)
  | holdColours(list[ASTColour] colours)
  | holdStart(int number)
  | holdEnd()
  | holdRotation(int rotation);

/*
 * Holds can use absolute coordinates or an angle.
 */
data ASTHoldPosition
  = xyPosition(ASTCoordinate coordinate)
  | anglePosition(int angle);

/*
 * Enumerated hold colours.
 */
data ASTColour
  = white()
  | yellow()
  | green()
  | blue()
  | red()
  | purple()
  | pink()
  | black()
  | orange();
