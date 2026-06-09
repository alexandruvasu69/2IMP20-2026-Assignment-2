module labour::AST

/*
 * Define the Abstract Syntax for LaBouR
 * - Hint: make sure there is an almost one-to-one correspondence with the grammar in Syntax.rsc
 */

data ASTBoulderingWall(loc src=|unknown:///|)
  = boulderingWall(str id, list[ASTRoute] routes, list[ASTVolume] volumes);

data ASTRoute
  = route(str id, str grade, ASTCoordinate gridBasePoint, list[ASTRouteStep] steps);

data ASTRouteStep
  = normalHold(str holdId)
  | splitHold(str leftHoldId, str rightHoldId);

data ASTCoordinate
  = coordinate(int x, int y);

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

data ASTHold
  = hold(str id, list[ASTHoldProperty] properties);

data ASTHoldProperty
  = holdPos(ASTHoldPosition position)
  | holdShape(str shape)
  | holdColours(list[ASTColour] colours)
  | holdStart(int number)
  | holdEnd()
  | holdRotation(int rotation);

data ASTHoldPosition
  = xyPosition(ASTCoordinate coordinate)
  | anglePosition(int angle);

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