// Toying around with the approach before writing the sql (although I still
// used the sql to parse the input and create a dot language version of the
// graph)

const sampleGraph = `
strict graph G { AA -- DD [label=1] AA -- BB [label=1] AA -- CC [label=2] AA -- EE [label=2] AA -- HH [label=5] AA -- JJ [label=2] DD -- AA [label=1] DD -- BB [label=2] DD -- CC [label=1] DD -- EE [label=1] DD -- HH [label=4] DD -- JJ [label=3] BB -- AA [label=1] BB -- DD [label=2] BB -- CC [label=1] BB -- EE [label=3] BB -- HH [label=6] BB -- JJ [label=3] CC -- AA [label=2] CC -- DD [label=1] CC -- BB [label=1] CC -- EE [label=2] CC -- HH [label=5] CC -- JJ [label=4] EE -- AA [label=2] EE -- DD [label=1] EE -- BB [label=3] EE -- CC [label=2] EE -- HH [label=3] EE -- JJ [label=4] HH -- AA [label=5] HH -- DD [label=4] HH -- BB [label=6] HH -- CC [label=5] HH -- EE [label=3] HH -- JJ [label=7] JJ -- AA [label=2] JJ -- DD [label=3] JJ -- BB [label=3] JJ -- CC [label=4] JJ -- EE [label=4] JJ -- HH [label=7] AA[label="AA 0"] BB[label="BB 13"] CC[label="CC 2"] DD[label="DD 20"] EE[label="EE 3"] HH[label="HH 22"] JJ[label="JJ 21"] }
`

const realGraph = `
trict graph G { AA -- AK [label=6] AA -- NT [label=3] AA -- DS [label=2] AA -- BF [label=7] AA -- KT [label=5] AA -- IC [label=3] AA -- BV [label=2] AA -- XC [label=10] AA -- JH [label=8] AA -- CN [label=5] AA -- GB [label=6] AA -- NK [label=5] AA -- GL [label=11] AA -- KM [label=2] AA -- OE [label=5] AK -- AA [label=6] AK -- NT [label=3] AK -- DS [label=7] AK -- BF [label=5] AK -- KT [label=2] AK -- IC [label=9] AK -- BV [label=8] AK -- XC [label=9] AK -- JH [label=7] AK -- CN [label=11] AK -- GB [label=12] AK -- NK [label=3] AK -- GL [label=10] AK -- KM [label=8] AK -- OE [label=4] NT -- AA [label=3] NT -- AK [label=3] NT -- DS [label=5] NT -- BF [label=5] NT -- KT [label=2] NT -- IC [label=6] NT -- BV [label=5] NT -- XC [label=9] NT -- JH [label=7] NT -- CN [label=8] NT -- GB [label=9] NT -- NK [label=2] NT -- GL [label=10] NT -- KM [label=5] NT -- OE [label=4] DS -- AA [label=2] DS -- AK [label=7] DS -- NT [label=5] DS -- BF [label=5] DS -- KT [label=5] DS -- IC [label=3] DS -- BV [label=2] DS -- XC [label=8] DS -- JH [label=6] DS -- CN [label=6] DS -- GB [label=6] DS -- NK [label=7] DS -- GL [label=9] DS -- KM [label=3] DS -- OE [label=3] BF -- AA [label=7] BF -- AK [label=5] BF -- NT [label=5] BF -- DS [label=5] BF -- KT [label=3] BF -- IC [label=8] BF -- BV [label=7] BF -- XC [label=7] BF -- JH [label=5] BF -- CN [label=11] BF -- GB [label=11] BF -- NK [label=6] BF -- GL [label=8] BF -- KM [label=8] BF -- OE [label=2] KT -- AA [label=5] KT -- AK [label=2] KT -- NT [label=2] KT -- DS [label=5] KT -- BF [label=3] KT -- IC [label=8] KT -- BV [label=7] KT -- XC [label=7] KT -- JH [label=5] KT -- CN [label=10] KT -- GB [label=11] KT -- NK [label=3] KT -- GL [label=8] KT -- KM [label=7] KT -- OE [label=2] IC -- AA [label=3] IC -- AK [label=9] IC -- NT [label=6] IC -- DS [label=3] IC -- BF [label=8] IC -- KT [label=8] IC -- BV [label=3] IC -- XC [label=11] IC -- JH [label=9] IC -- CN [label=6] IC -- GB [label=3] IC -- NK [label=8] IC -- GL [label=12] IC -- KM [label=3] IC -- OE [label=6] BV -- AA [label=2] BV -- AK [label=8] BV -- NT [label=5] BV -- DS [label=2] BV -- BF [label=7] BV -- KT [label=7] BV -- IC [label=3] BV -- XC [label=10] BV -- JH [label=8] BV -- CN [label=6] BV -- GB [label=6] BV -- NK [label=7] BV -- GL [label=11] BV -- KM [label=3] BV -- OE [label=5] XC -- AA [label=10] XC -- AK [label=9] XC -- NT [label=9] XC -- DS [label=8] XC -- BF [label=7] XC -- KT [label=7] XC -- IC [label=11] XC -- BV [label=10] XC -- JH [label=2] XC -- CN [label=14] XC -- GB [label=14] XC -- NK [label=10] XC -- GL [label=5] XC -- KM [label=11] XC -- OE [label=5] JH -- AA [label=8] JH -- AK [label=7] JH -- NT [label=7] JH -- DS [label=6] JH -- BF [label=5] JH -- KT [label=5] JH -- IC [label=9] JH -- BV [label=8] JH -- XC [label=2] JH -- CN [label=12] JH -- GB [label=12] JH -- NK [label=8] JH -- GL [label=3] JH -- KM [label=9] JH -- OE [label=3] CN -- AA [label=5] CN -- AK [label=11] CN -- NT [label=8] CN -- DS [label=6] CN -- BF [label=11] CN -- KT [label=10] CN -- IC [label=6] CN -- BV [label=6] CN -- XC [label=14] CN -- JH [label=12] CN -- GB [label=9] CN -- NK [label=10] CN -- GL [label=15] CN -- KM [label=3] CN -- OE [label=9] GB -- AA [label=6] GB -- AK [label=12] GB -- NT [label=9] GB -- DS [label=6] GB -- BF [label=11] GB -- KT [label=11] GB -- IC [label=3] GB -- BV [label=6] GB -- XC [label=14] GB -- JH [label=12] GB -- CN [label=9] GB -- NK [label=11] GB -- GL [label=15] GB -- KM [label=6] GB -- OE [label=9] NK -- AA [label=5] NK -- AK [label=3] NK -- NT [label=2] NK -- DS [label=7] NK -- BF [label=6] NK -- KT [label=3] NK -- IC [label=8] NK -- BV [label=7] NK -- XC [label=10] NK -- JH [label=8] NK -- CN [label=10] NK -- GB [label=11] NK -- GL [label=11] NK -- KM [label=7] NK -- OE [label=5] GL -- AA [label=11] GL -- AK [label=10] GL -- NT [label=10] GL -- DS [label=9] GL -- BF [label=8] GL -- KT [label=8] GL -- IC [label=12] GL -- BV [label=11] GL -- XC [label=5] GL -- JH [label=3] GL -- CN [label=15] GL -- GB [label=15] GL -- NK [label=11] GL -- KM [label=12] GL -- OE [label=6] KM -- AA [label=2] KM -- AK [label=8] KM -- NT [label=5] KM -- DS [label=3] KM -- BF [label=8] KM -- KT [label=7] KM -- IC [label=3] KM -- BV [label=3] KM -- XC [label=11] KM -- JH [label=9] KM -- CN [label=3] KM -- GB [label=6] KM -- NK [label=7] KM -- GL [label=12] KM -- OE [label=6] OE -- AA [label=5] OE -- AK [label=4] OE -- NT [label=4] OE -- DS [label=3] OE -- BF [label=2] OE -- KT [label=2] OE -- IC [label=6] OE -- BV [label=5] OE -- XC [label=5] OE -- JH [label=3] OE -- CN [label=9] OE -- GB [label=9] OE -- NK [label=5] OE -- GL [label=6] OE -- KM [label=6] NT[label="NT 4"] NK[label="NK 13"] DS[label="DS 3"] OE[label="OE 9"] XC[label="XC 11"] BF[label="BF 10"] GB[label="GB 25"] BV[label="BV 6"] JH[label="JH 12"] CN[label="CN 22"] GL[label="GL 20"] AA[label="AA 0"] KM[label="KM 16"] KT[label="KT 23"] AK[label="AK 14"] IC[label="IC 17"] }
`

const graph = realGraph;
const edges = [...graph.matchAll(/(\w\w) -- (\w\w) \[label=(\d+)\]/g)].map((m) => ({ from: m[1], to: m[2], weight: parseInt(m[3])}));
const nodes = Object.fromEntries([...graph.matchAll(/\[label="(..) (\d+)"\]/g)].map((m) => [m[1], parseInt(m[2])]));
const edgeMap = edges.reduce(
  (m, edge) => ({
    ...m,
    [edge.from]: [...(m[edge.from] ?? []), edge]
  }),
  {}
)

const start = { path: ["AA"], time: 0, onValves: {"AA": 0} };

/// Part 1

const visitNext = (p, maxTime) => {
  const current = p.path[0];
  const tunnels = edgeMap[current].filter((e) => p.time + e.weight < maxTime && p.onValves[e.to] == null);
  return tunnels.map((e) => ({
    path: [e.to, ...p.path],
    time: p.time + e.weight + 1, // 1 to open the valve
    onValves: {...p.onValves, [e.to]: p.time + e.weight + 1 }
  }))
}

const step = (paths, maxTime) =>
  paths.filter((p) => p.time < maxTime).flatMap((p) => visitNext(p, maxTime));

const walk = (start, maxTime) => {
  let allPaths = [start];
  let lastPaths = allPaths;
  while (lastPaths.length) {
    lastPaths = step(lastPaths, maxTime);
    allPaths = [...allPaths, ...lastPaths];
  }
  return allPaths;
}

const scorePath = (p, maxTime) =>
  Object.entries(p.onValves).map(([valve, time]) => nodes[valve] * (maxTime - time)).reduce((a, b) => a + b);

const part1 = () =>
  walk(start, 30)
    .map((path) => scorePath(path, 30))
    .reduce((a, b) => Math.max(a, b));

console.log('part1', part1());

/////// Part 2


// We have a whole lot of paths (36k)! The number of pick 2 combinations is
// through the roof . . . but there are many fewer _distinct_ sets of visited
// valves. So actually we need to just pick the best path for each group of
// valves (which is more like 6.5k, still a lot of combinations, but doable).

const maxBy = (objs, fkey, fval) =>
  objs.reduce((groups, obj) => {
    const k = fkey(obj);
    const v = fval(obj);
    groups[k] = Math.max(v, groups[k] ?? 0);
    return groups;
  }, {})

const hasOverlap = (a, b) => [...a].some((x) => b.has(x));

const part2 = () => {
  const allPaths = walk(start, 26)
    .map((path) => ({ ...path, score: scorePath(path, 26) }));

  const bestPaths = maxBy(allPaths, (p) => p.path.filter((x) => x !== "AA").sort().join("-"), (p) => p.score);
  const valveSets = Object.keys(bestPaths).reduce((ret, k) => { ret[k] = new Set(k.split("-")); return ret }, {});

  const pathKeys = Object.keys(bestPaths);

  return pathKeys.map((k1, i) =>
    pathKeys
      .slice(i)
      .map((k2) => hasOverlap(valveSets[k1], valveSets[k2]) ? 0 : bestPaths[k1] + bestPaths[k2])
      .reduce((a, b) => Math.max(a, b))
  )
  .reduce((a, b) => Math.max(a, b));
}
 console.log('part2', part2());
