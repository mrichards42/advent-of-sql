const fs = require("node:fs");
const _ = require("/Users/mike/.asdf/installs/nodejs/lts/.npm/lib/node_modules/lodash");

// -- input parsing --

const linePoints = ([x1, y1], [x2, y2]) => {
  const xs = _.range(Math.min(x1, x2), Math.max(x1, x2) + 1);
  const ys = _.range(Math.min(y1, y2), Math.max(y1, y2) + 1);
  return xs.flatMap((x) => ys.map((y) => [x, y]));
};

const polylinePoints = (vertices) =>
  vertices.slice(0, -1).flatMap((p1, idx) => linePoints(p1, vertices[idx + 1]));

const parsePolyline = (line) =>
  line.split(" -> ").map((point) => point.split(",").map((x) => +x));

const INPUT = fs
  // .readFileSync("2022/day14.sample.txt", "UTF-8")
  .readFileSync("2022/day14.txt", "UTF-8")
  .trim()
  .split("\n")
  .map(parsePolyline)
  .flatMap(polylinePoints);

const buildGrid = (points) =>
  points.reduce((grid, point) => setPoint(grid, point, "█"), {});



// -- A few helpers to make 2d grid access a lot easier --

const getPoint = (grid, p) => grid[p[1]]?.[p[0]];

const setPoint = (grid, p, val) => {
  grid[p[1]] ??= {};
  grid[p[1]][p[0]] = val;
  return grid; // this just makes the reduce simpler
};

/** Flattens the grid into an array of { x, y, value } objects. */
const flattenGrid = (grid) =>
  _.flatMap(grid, (inner, y) =>
    // since the grid is an object, x and y are strings so we have to re-parse
    // them :\
    _.map(inner, (value, x) => ({ x: +x, y: +y, value }))
  );



// -- viz --

const gridBounds = (grid) => {
  const points = flattenGrid(grid);
  const xs = _.map(points, "x");
  const ys = _.map(points, "y");
  return {
    xMin: _.min(xs),
    xMax: _.max(xs),
    yMin: _.min(ys),
    yMax: _.max(ys),
  }
}

const gridToString = (grid) => {
  const { xMin, xMax, yMin, yMax } = gridBounds(grid);
  const cols = _.range(xMin, xMax + 1);
  const rows = _.range(yMin, yMax + 1);
  return rows
    .map((y) => cols.map((x) => getPoint(grid, [x, y]) ?? " ").join(""))
    .join("\n");
};



// -- the actual problem --

const sandStep = (grid, sand) => {
  const [x, y] = sand;
  const candidates = [
    [x, y + 1],     // straight down
    [x - 1, y + 1], // down left
    [x + 1, y + 1], // down right
  ];
  return candidates.find((nextPoint) => !getPoint(grid, nextPoint));
};

const nextSandRestingPlace = (grid, oblivion, floor = Infinity) => {
  let sand = [500, 0];
  while (sand[1] < oblivion) {
    const nextSand = sandStep(grid, sand);
    if (!nextSand) {
      return sand; // stuck on a rock or another piece of sand
    } else if (nextSand[1] === floor - 1) {
      return nextSand; // hit the floor
    }
    sand = nextSand;
  }
  // ... into oblivion
};

const sandCount = (grid) =>
  flattenGrid(grid).filter(({ value }) => value === "o").length;

const part1 = () => {
  // Note that I am mutating the grid here since this would take a long time to
  // clone the full grid for each piece of sand, but since I'm building a fresh
  // grid at the start of the function, there's never any mutation happening in
  // the outside world. And importantly, the mutation is constraint just to
  // this function, the sand falling functions are pure, so they're easier to
  // test in isolation if I needed to.
  const grid = buildGrid(INPUT);
  const oblivion = gridBounds(grid).yMax;
  while (true) {
    const sand = nextSandRestingPlace(grid, oblivion);
    // sand has fallen into the void, we're done
    if (!sand) {
      return grid;
    }
    setPoint(grid, sand, "o");
  }
};

const part2 = () => {
  const grid = buildGrid(INPUT);
  const floor = 2 + gridBounds(grid).yMax;
  while (true) {
    const sand = nextSandRestingPlace(grid, Infinity, floor);
    setPoint(grid, sand, "o");
    // we couldn't move past the drop point, we're done
    if (sand[1] === 0) {
      return grid;
    }
  }
};

const finalGrid1 = part1();
// console.log(gridToString(finalGrid1)); // uncomment for a visual
console.log('part 1', sandCount(finalGrid1));

const finalGrid2 = part2();
// console.log(gridToString(finalGrid2)); // uncomment for a visual
console.log('part 2', sandCount(finalGrid2));
