module labour::Check

import labour::AST;

import IO;
import List;
import Set;
import String;

/*
 * Well-formedness checker for LaBouR.
 *
 * The checker only looks at the AST, so we don't import Syntax/Parser/CST2AST here. Keeping
 * it grammar-agnostic makes it easier to test the checks on their own.
 *
 * A few constraints are already taken care of by the grammar, so there's nothing to do for
 * them here:
 *   - #6  grid_base_point always has an x and a y (it's just an ASTCoordinate).
 *   - #9  hold ids are four digits (the HOLDID rule guarantees it). We still re-check it
 *         below, mostly as a sanity net.
 *   - #15 only the nine allowed colours exist (the Colour rule).
 *   - #16 only circle/triangle volumes exist (the Volume rule).
 *   - #18/#20 a circle can only hold front/side holds and a triangle only left/right/bottom
 *         holds (their property rules don't allow anything else).
 * Everything else is checked below, one function per constraint so each has its own test.
 * We also reject repeated or conflicting property definitions, since properties are stored
 * as lists in the AST and ambiguous duplicates would otherwise be accepted silently.
 *
 * Every check returns a bool and prints a message when it fails (handy when running the
 * tests). We run all of them and AND the results, so a program reports every problem it has,
 * not just the first one.
 */

// All hold ids referenced by a route, in order. A split step references two holds.
list[str] routeHoldIds(ASTRoute r) {
  list[str] ids = [];
  for (s <- r.steps) {
    switch (s) {
      case normalHold(x): ids += x;
      case splitHold(l, rr): ids += [l, rr];
    }
  }
  return ids;
}

// All hold definitions contained in a single volume.
list[ASTHold] volumeHolds(ASTVolume v) {
  list[ASTHold] hs = [];
  switch (v) {
    case circle(ps):
      for (p <- ps) switch (p) {
        case circleFrontHolds(h): hs += h;
        case circleSideHolds(h): hs += h;
        default: ;
      }
    case triangle(ps):
      for (p <- ps) switch (p) {
        case triangleLeftHolds(h): hs += h;
        case triangleRightHolds(h): hs += h;
        case triangleBottomHolds(h): hs += h;
        default: ;
      }
  }
  return hs;
}

// Every hold definition in the wall.
list[ASTHold] allWallHolds(ASTBoulderingWall wall) = [h | v <- wall.volumes, h <- volumeHolds(v)];

// Index hold definitions by their id so routes can resolve the holds they reference.
map[str, ASTHold] collectHolds(ASTBoulderingWall wall) {
  map[str, ASTHold] m = ();
  for (h <- allWallHolds(wall)) m[h.id] = h;
  return m;
}

// The colour set of a hold ("" if it has no colours property).
set[ASTColour] getColours(ASTHold h) {
  for (holdColours(cs) <- h.properties) return toSet(cs);
  return {};
}

bool hasXYPosition(ASTHold h) = any(holdPos(xyPosition(_)) <- h.properties);
bool hasAnglePosition(ASTHold h) = any(holdPos(anglePosition(_)) <- h.properties);

/*
 * A "split region" is a run of consecutive split steps. The tricky bit is that Listing 4
 * has two split steps in a row but that's still a single split (the two branches just run
 * in parallel for two holds), while Listing 5 genuinely splits twice. So we count regions,
 * not split steps, to know how many times a route actually splits (constraint 4).
 */
int splitRegionCount(ASTRoute r) {
  int regions = 0;
  bool prevSplit = false;
  for (s <- r.steps) {
    bool isSplit = splitHold(_, _) := s;
    if (isSplit && !prevSplit) regions += 1;
    prevSplit = isSplit;
  }
  return regions;
}

// True unless the route splits again after it has already merged back (a normal step that
// comes right after a split step counts as the merge). This is constraint #8.
bool noSplitAfterMerge(ASTRoute r) {
  bool merged = false;
  bool prevSplit = false;
  for (s <- r.steps) {
    bool isSplit = splitHold(_, _) := s;
    if (!isSplit && prevSplit) merged = true; // split -> normal transition is a merge
    if (isSplit && merged) return false;       // splitting again after a merge
    prevSplit = isSplit;
  }
  return true;
}

bool isFourDigits(str s) = /^[0-9][0-9][0-9][0-9]$/ := s;

// Wall and route ids may use any alphanumeric character; the provided examples ("Example
// wall", "Split route") also contain spaces, so we permit those as well.
bool isAlphanumeric(str s) = s != "" && /^[A-Za-z0-9 ]+$/ := s;

bool checkBoulderWallConfiguration(ASTBoulderingWall wall) {
  map[str, ASTHold] defs = collectHolds(wall);

  list[bool] results = [
    checkAtLeastOneVolumeAndRoute(wall),   //  1
    checkRoutesHaveTwoHolds(wall),         //  2
    checkStartHoldCount(wall, defs),       //  3 (+ start_hold argument is 1 or 2)
    checkAtMostOneSplit(wall),             //  4
    checkRoutePropertiesPresent(wall),     //  5 (and 6, structurally)
    checkEndHoldCount(wall, defs),         //  7
    checkNoSplitAfterMerge(wall),          //  8
    checkHoldIdFormat(wall, defs),         //  9
    checkWallAndRouteIds(wall),            // 10
    checkRouteSameColour(wall, defs),      // 11
    checkHoldRequiredProperties(wall),     // 12
    checkUniquePropertyDefinitions(wall),  // extra consistency checks on property lists
    checkVolumeHoldPositionKinds(wall),    // volume holds: only circle side_holds may use angles
    checkAngleAndRotationRanges(wall),     // 13, 14
    checkCircleProperties(wall),           // 17
    checkTriangleProperties(wall)          // 19
  ];

  return (true | it && r | r <- results);
}

bool checkBoulderRouteConfiguration(ASTBoulderingWall wall) = checkBoulderWallConfiguration(wall);

// #1: a wall needs at least one route and at least one volume.
bool checkAtLeastOneVolumeAndRoute(ASTBoulderingWall wall) {
  bool ok = true;
  if (wall.routes == []) { println("FAIL [1]: wall \'<wall.id>\' has no routes"); ok = false; }
  if (wall.volumes == []) { println("FAIL [1]: wall \'<wall.id>\' has no volumes"); ok = false; }
  return ok;
}

// #2: a route must reference at least two holds.
bool checkRoutesHaveTwoHolds(ASTBoulderingWall wall) {
  bool ok = true;
  for (r <- wall.routes) {
    if (size(routeHoldIds(r)) < 2) {
      println("FAIL [2]: route \'<r.id>\' has fewer than two holds");
      ok = false;
    }
  }
  return ok;
}

// #3: a route can have 0..2 start holds, and each start_hold argument must be 1 or 2.
bool checkStartHoldCount(ASTBoulderingWall wall, map[str, ASTHold] defs) {
  bool ok = true;
  for (r <- wall.routes) {
    int count = 0;
    for (id <- routeHoldIds(r), id in defs, holdStart(n) <- defs[id].properties) {
      count += 1;
      if (n != 1 && n != 2) {
        println("FAIL [3]: hold \'<id>\' has invalid start_hold argument <n> (must be 1 or 2)");
        ok = false;
      }
    }
    if (count > 2) {
      println("FAIL [3]: route \'<r.id>\' has <count> start holds (max 2)");
      ok = false;
    }
  }
  return ok;
}

// #4: a route may only split once (so at most two sub-routes).
bool checkAtMostOneSplit(ASTBoulderingWall wall) {
  bool ok = true;
  for (r <- wall.routes) {
    if (splitRegionCount(r) > 1) {
      println("FAIL [4]: route \'<r.id>\' splits more than once");
      ok = false;
    }
  }
  return ok;
}

// #5: a route needs a grade, a grid_base_point and an id. The grid_base_point is always
// there (the grammar requires it), so we just make sure the grade and id aren't empty.
bool checkRoutePropertiesPresent(ASTBoulderingWall wall) {
  bool ok = true;
  for (r <- wall.routes) {
    if (r.id == "")    { println("FAIL [5]: a route is missing an identifier"); ok = false; }
    if (r.grade == "") { println("FAIL [5]: route \'<r.id>\' is missing a grade"); ok = false; }
  }
  return ok;
}

// #7: at most two end holds if the route splits, otherwise at most one.
bool checkEndHoldCount(ASTBoulderingWall wall, map[str, ASTHold] defs) {
  bool ok = true;
  for (r <- wall.routes) {
    int count = (0 | it + 1 | id <- routeHoldIds(r), id in defs, holdEnd() <- defs[id].properties);
    int maxEnd = (splitRegionCount(r) >= 1) ? 2 : 1;
    if (count > maxEnd) {
      println("FAIL [7]: route \'<r.id>\' has <count> end holds (max <maxEnd>)");
      ok = false;
    }
  }
  return ok;
}

// #8: once a route has merged back together, it can't split again.
bool checkNoSplitAfterMerge(ASTBoulderingWall wall) {
  bool ok = true;
  for (r <- wall.routes) {
    if (!noSplitAfterMerge(r)) {
      println("FAIL [8]: route \'<r.id>\' splits again after a merge");
      ok = false;
    }
  }
  return ok;
}

// #9: hold ids are four digits. The grammar already guarantees this, so this is just a
// belt-and-braces check (also covers the ids a route refers to).
bool checkHoldIdFormat(ASTBoulderingWall wall, map[str, ASTHold] defs) {
  bool ok = true;
  for (id <- defs) {
    if (!isFourDigits(id)) { println("FAIL [9]: hold id \'<id>\' is not four digits"); ok = false; }
  }
  for (r <- wall.routes, id <- routeHoldIds(r)) {
    if (!isFourDigits(id)) {
      println("FAIL [9]: route \'<r.id>\' references malformed hold id \'<id>\'");
      ok = false;
    }
  }
  return ok;
}

// #10: wall and route ids should be alphanumeric (we also allow spaces, since the
// examples use names like "Example wall").
bool checkWallAndRouteIds(ASTBoulderingWall wall) {
  bool ok = true;
  if (!isAlphanumeric(wall.id)) {
    println("FAIL [10]: wall id \'<wall.id>\' is not alphanumeric");
    ok = false;
  }
  for (r <- wall.routes) {
    if (!isAlphanumeric(r.id)) {
      println("FAIL [10]: route id \'<r.id>\' is not alphanumeric");
      ok = false;
    }
  }
  return ok;
}

// #11: all holds in a route must share a colour. For multicoloured holds that means the
// intersection of their colour lists has to be non-empty.
bool checkRouteSameColour(ASTBoulderingWall wall, map[str, ASTHold] defs) {
  bool ok = true;
  for (r <- wall.routes) {
    list[set[ASTColour]] colourSets = [getColours(defs[id]) | id <- routeHoldIds(r), id in defs];
    if (colourSets != []) {
      set[ASTColour] common = colourSets[0];
      for (cs <- colourSets[1..]) common = common & cs;
      if (common == {}) {
        println("FAIL [11]: holds in route \'<r.id>\' do not share a common colour");
        ok = false;
      }
    }
  }
  return ok;
}

// #12: every hold must have a position, a shape and at least one colour.
bool checkHoldRequiredProperties(ASTBoulderingWall wall) {
  bool ok = true;
  for (h <- allWallHolds(wall)) {
    if (!any(holdPos(_) <- h.properties)) {
      println("FAIL [12]: hold \'<h.id>\' has no position");
      ok = false;
    }
    if (!any(holdShape(_) <- h.properties)) {
      println("FAIL [12]: hold \'<h.id>\' has no shape");
      ok = false;
    }
    if (!any(holdColours(cs) <- h.properties, cs != [])) {
      println("FAIL [12]: hold \'<h.id>\' has no colour");
      ok = false;
    }
  }
  return ok;
}

// Extra consistency checks: property-list constructs should not define the same field
// more than once, and a hold position should not mix coordinate- and angle-based forms.
bool checkUniquePropertyDefinitions(ASTBoulderingWall wall) {
  bool ok = true;

  for (h <- allWallHolds(wall)) {
    list[ASTHoldPosition] positions = [p | holdPos(p) <- h.properties];
    bool hasXY = false;
    bool hasAngle = false;
    for (p <- positions) {
      switch (p) {
        case xyPosition(_): hasXY = true;
        case anglePosition(_): hasAngle = true;
      }
    }
    if (size(positions) > 1) {
      if (hasXY && hasAngle) {
        println("FAIL [props]: hold \'<h.id>\' mixes coordinate and angle position definitions");
      } else {
        println("FAIL [props]: hold \'<h.id>\' defines position more than once");
      }
      ok = false;
    }
    if (size([true | holdShape(_) <- h.properties]) > 1) {
      println("FAIL [props]: hold \'<h.id>\' defines shape more than once");
      ok = false;
    }
    if (size([true | holdColours(_) <- h.properties]) > 1) {
      println("FAIL [props]: hold \'<h.id>\' defines colours more than once");
      ok = false;
    }
    if (size([true | holdStart(_) <- h.properties]) > 1) {
      println("FAIL [props]: hold \'<h.id>\' defines start_hold more than once");
      ok = false;
    }
    if (size([true | holdEnd() <- h.properties]) > 1) {
      println("FAIL [props]: hold \'<h.id>\' defines end_hold more than once");
      ok = false;
    }
    if (size([true | holdRotation(_) <- h.properties]) > 1) {
      println("FAIL [props]: hold \'<h.id>\' defines rotation more than once");
      ok = false;
    }
  }

  for (circle(ps) <- wall.volumes) {
    if (size([true | circlePos(_) <- ps]) > 1) {
      println("FAIL [props]: a circle volume defines position more than once");
      ok = false;
    }
    if (size([true | circleDepth(_) <- ps]) > 1) {
      println("FAIL [props]: a circle volume defines depth more than once");
      ok = false;
    }
    if (size([true | circleRadius(_) <- ps]) > 1) {
      println("FAIL [props]: a circle volume defines radius more than once");
      ok = false;
    }
    if (size([true | circleFrontHolds(_) <- ps]) > 1) {
      println("FAIL [props]: a circle volume defines front_holds more than once");
      ok = false;
    }
    if (size([true | circleSideHolds(_) <- ps]) > 1) {
      println("FAIL [props]: a circle volume defines side_holds more than once");
      ok = false;
    }
  }

  for (triangle(ps) <- wall.volumes) {
    if (size([true | trianglePos(_) <- ps]) > 1) {
      println("FAIL [props]: a triangle volume defines position more than once");
      ok = false;
    }
    if (size([true | triangleDepth(_) <- ps]) > 1) {
      println("FAIL [props]: a triangle volume defines depth more than once");
      ok = false;
    }
    if (size([true | triangleExtrusion(_) <- ps]) > 1) {
      println("FAIL [props]: a triangle volume defines extrusion more than once");
      ok = false;
    }
    if (size([true | triangleCorners(_) <- ps]) > 1) {
      println("FAIL [props]: a triangle volume defines corners more than once");
      ok = false;
    }
    if (size([true | triangleLeftHolds(_) <- ps]) > 1) {
      println("FAIL [props]: a triangle volume defines left_holds more than once");
      ok = false;
    }
    if (size([true | triangleRightHolds(_) <- ps]) > 1) {
      println("FAIL [props]: a triangle volume defines right_holds more than once");
      ok = false;
    }
    if (size([true | triangleBottomHolds(_) <- ps]) > 1) {
      println("FAIL [props]: a triangle volume defines bottom_holds more than once");
      ok = false;
    }
  }

  return ok;
}

// Circle side_holds are the only volume holds that may use angle-based positions. Every
// other volume hold must use a coordinate-based position instead.
bool checkVolumeHoldPositionKinds(ASTBoulderingWall wall) {
  bool ok = true;

  for (circle(ps) <- wall.volumes, circleFrontHolds(hs) <- ps, h <- hs) {
    if (hasAnglePosition(h)) {
      println("FAIL [props]: circle front hold \'<h.id>\' must use an x/y position");
      ok = false;
    }
  }

  for (circle(ps) <- wall.volumes, circleSideHolds(hs) <- ps, h <- hs) {
    if (hasXYPosition(h)) {
      println("FAIL [props]: circle side hold \'<h.id>\' must use an angle position");
      ok = false;
    }
  }

  for (triangle(ps) <- wall.volumes, p <- ps) {
    switch (p) {
      case triangleLeftHolds(hs):
        for (h <- hs) {
          if (hasAnglePosition(h)) {
            println("FAIL [props]: triangle left hold \'<h.id>\' must use an x/y position");
            ok = false;
          }
        }
      case triangleRightHolds(hs):
        for (h <- hs) {
          if (hasAnglePosition(h)) {
            println("FAIL [props]: triangle right hold \'<h.id>\' must use an x/y position");
            ok = false;
          }
        }
      case triangleBottomHolds(hs):
        for (h <- hs) {
          if (hasAnglePosition(h)) {
            println("FAIL [props]: triangle bottom hold \'<h.id>\' must use an x/y position");
            ok = false;
          }
        }
      default: ;
    }
  }

  return ok;
}

// #13 and #14: an angle position and a rotation (if given) both have to be in [0, 359].
bool checkAngleAndRotationRanges(ASTBoulderingWall wall) {
  bool ok = true;
  for (h <- allWallHolds(wall), p <- h.properties) {
    switch (p) {
      case holdPos(anglePosition(a)):
        if (a < 0 || a > 359) {
          println("FAIL [13]: hold \'<h.id>\' angle <a> is out of range [0, 359]");
          ok = false;
        }
      case holdRotation(rot):
        if (rot < 0 || rot > 359) {
          println("FAIL [14]: hold \'<h.id>\' rotation <rot> is out of range [0, 359]");
          ok = false;
        }
      default: ;
    }
  }
  return ok;
}

// #17: a circle needs a radius, a depth and a position. (#18 — only front/side holds — is
// already guaranteed by the grammar.)
bool checkCircleProperties(ASTBoulderingWall wall) {
  bool ok = true;
  for (circle(ps) <- wall.volumes) {
    if (!any(circleRadius(_) <- ps)) { println("FAIL [17]: a circle volume has no radius"); ok = false; }
    if (!any(circleDepth(_) <- ps))  { println("FAIL [17]: a circle volume has no depth");  ok = false; }
    if (!any(circlePos(_) <- ps))    { println("FAIL [17]: a circle volume has no position"); ok = false; }
  }
  return ok;
}

// #19: a triangle needs a position, a depth, an extrusion point and exactly three corners.
// (#20 — only left/right/bottom holds — is already guaranteed by the grammar.)
bool checkTriangleProperties(ASTBoulderingWall wall) {
  bool ok = true;
  for (triangle(ps) <- wall.volumes) {
    if (!any(trianglePos(_) <- ps))       { println("FAIL [19]: a triangle volume has no position");  ok = false; }
    if (!any(triangleDepth(_) <- ps))     { println("FAIL [19]: a triangle volume has no depth");     ok = false; }
    if (!any(triangleExtrusion(_) <- ps)) { println("FAIL [19]: a triangle volume has no extrusion"); ok = false; }

    list[list[ASTCoordinate]] corners = [cs | triangleCorners(cs) <- ps];
    if (corners == []) {
      println("FAIL [19]: a triangle volume has no corners");
      ok = false;
    } else if (size(corners[0]) != 3) {
      println("FAIL [19]: a triangle volume must have exactly 3 corners (has <size(corners[0])>)");
      ok = false;
    }
  }
  return ok;
}
