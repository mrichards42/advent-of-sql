// LOL this is a total mess but the graph based approach is kind of neat...
// Turns out just tracking pair counts is easer, seems obvious once you think
// about it.

const mergeCount = (a, b) => {
  const merged = { ...a };
  Object.entries(b).forEach(([k, v]) => {
    merged[k] = (merged[k] || 0) + v;
    return merged;
  });
  return merged;
};

const polymerCountStep = (rules, counts) => {
  return Object.entries(counts).flatMap(([pair, count]) => (
    rules[pair].map((p) => ({ [p]: count }))
  )).reduce(mergeCount)
};

const polymerCountsAtIteration = (rules, polymer, steps) => {
  const init = polymer.map((pair) => ({[pair]: 1})).reduce(mergeCount);
  const pairCounts = range(steps)
    .reduce((counts) => polymerCountStep(rules, counts), init);
  const letterCounts = Object.entries(pairCounts)
    .map(([pair, count]) => ({ [pair[1]]: count }))
    .reduce(mergeCount);
  letterCounts[polymer[0][0]] += 1;
  return letterCounts;
};



const fs = require('fs');
const path = require('path');

const parseRule = (rule) => {
  const [, a, b, mid] = rule.match(/(.)(.) -> (.)/);
  return {
    a, b, mid,
    input: `${a}${b}`,
    output: [`${a}${mid}`, `${mid}${b}`],
  };
};

const parseInput = (input) => {
  const [init, rules] = input.split('\n\n');
  return {
    polymer: Array.from(init).slice(0, -1).map((_, idx) => init.slice(idx, idx+2)),
    rules: rules
      .split('\n')
      .filter(Boolean)
      .map(parseRule)
      .reduce((ret, { input, output }) => { ret[input] = output; return ret }, {}),
  };
};

const INPUT = parseInput(fs.readFileSync(path.join(__dirname, 'day14.txt'), { encoding: 'utf-8' }));

// TODO: getting close. I think what's next is converting from an array for the
// polymer to a map of seen nodes and their progressions. It's just as easy to
// calculate each one I think. And then we match the input to the set of
// progressions.

const step = ({ polymer, rules, seen }) => {
  const nextSeen = new Set(Array.from(seen).concat(polymer.map(({ pair }) => pair)));
  const nextPolymer =
    polymer
      .flatMap(({ pair, step }) => {
        if (seen.has(pair)) {
          return [{ pair, step: step + 1 }];
        } else {
          return rules[pair]
            .map((p) => ({ pair: p, step: 0 }))
        }
      });
  return {
    rules,
    seen: nextSeen,
    polymer: nextPolymer,
  }
};

// The goal is to have a data structure where as pairs are encountered, they're
// added to the overall object. Instead of expanding already seen nodes, we
// just add a step counter, so we can ultimately reconstruct the expanded
// series by replacing nodes with their expansion until everything is at step
// 0.
// {
//   // NN -> NC,CN -> NC(1),CC,CN -> ...
//   'NN': [
//     // NN step 0
//     [{ pair: 'NN', step: 0 }],
//     // NN step 1
//     [{ pair: 'NC', step: 0 }, { pair: 'CN', step: 0 }],
//     // NN step 2 (we've already seen NC)
//     [{ pair: 'NC', step: 1 }, { pair: 'CC', step: 0 }, { pair: 'CN', step: 0 }],
//   ],
// };

const nextPolymer = (rules, seen, polymer) => {
  if (polymer.length === 1) {
    // first iteration can't reference itself
    return polymer.flatMap(({ pair }) => (
      rules[pair].map((p) => ({ pair: p, step: 0 }))
    ));
  } else {
    // after the first iteration, check for already seen polymers
    return polymer
      .flatMap(({ pair, step }) => {
        if (seen[pair]) {
          return [{ pair, step: step + 1 }];
        } else {
          return rules[pair]
            .map((p) => ({ pair: p, step: 0 }))
        }
      });
  }
};

const graphPolymerStep = (rules, seen, originalPair, polymer) => ({
  ...seen,
  [originalPair]: [... seen[originalPair], nextPolymer(rules, seen, polymer)],
});

const graphStep = (rules, seen) => Object.entries(seen).reduce(
  (seen, [originalPair, polymerHistory]) => graphPolymerStep(
    rules,
    seen,
    originalPair,
    polymerHistory.slice(-1)[0], // the last polymer chain for this step
  ),
  seen,
);

const range = (stop) => Array.from({ length: stop }).map((_, idx) => idx);

const fullyExpand = (ruleGraph, { pair, step }) => {
  if (step === 0) {
    return [{ pair, step }];
  } else {
    return ruleGraph[pair][step].flatMap((node) => fullyExpand(ruleGraph, node));
  }
};

const expandPolymer = (rules, polymer, steps) => {
  const graph = Object.fromEntries(
    Object.keys(INPUT.rules).map((pair) => [pair, [[{ pair, step: 0 }]]])
  );
  const fullGraph = range(steps).reduce(graphStep.bind(null, INPUT.rules), graph);

  return polymer.flatMap((pair) => fullyExpand(fullGraph, { pair, step: steps }));
};

const graphPairCounts = (graph, stepCount) => {
  const keys = Object.keys(graph);
  const counts = Object.fromEntries(keys.map((k) => [k, []]));
  const pairCounts = ({ pair, step }) => {
    if (step === 0) {
      return { [pair]: 1 };
    } else {
      return counts[pair][step];
    }
  };
  range(stepCount + 1).forEach((step) => {
    keys.forEach((k) => {
      counts[k][step] = graph[k][step]
        .map(pairCounts)
        .reduce(mergeCount);
    })
  });
  return counts;
}

const expandPolymerCount = (rules, polymer, steps) => {
  const graph = Object.fromEntries(
    Object.keys(INPUT.rules).map((pair) => [pair, [[{ pair, step: 0 }]]])
  );
  const fullGraph = range(steps).reduce(graphStep.bind(null, INPUT.rules), graph);
  const counts = graphPairCounts(fullGraph, steps);
  return Object.entries(
    polymer
      .map((pair) => counts[pair][steps])
      .reduce(mergeCount),
  ).map(([pair, count]) => ({ [pair[1]]: count }))
    .reduce(mergeCount, { [polymer[0][0]]: 1 });
};

/*
for (let x = 0; x <= 10; x++) {
  console.log(
    x,
    expandPolymer(INPUT.rules, INPUT.polymer, x)
      .map(({ pair }) => pair)
      .flatMap((pair, idx) => idx === 0 ? pair : pair[1])
      .join('')
  );
}
*/


/*
console.log(new Date());
console.log(
  expandPolymer(INPUT.rules, INPUT.polymer, 20)
    .map(({ pair }) => pair)
    .flatMap((pair, idx) => idx === 0 ? pair : pair[1])
    .join('')
);
  */
console.log(new Date());
const counts = Object.values(
  expandPolymerCount(INPUT.rules, INPUT.polymer, 40)
);
console.log(Math.max(...counts) - Math.min(...counts));

console.log(new Date());

const counts2 = Object.values(
  polymerCountsAtIteration(INPUT.rules, INPUT.polymer, 40)
);
console.log(Math.max(...counts2) - Math.min(...counts2));
console.log(new Date());

// let r = {
//   rules: INPUT.rules,
//   // polymer: INPUT.polymer.map((x) => ({ pair: x, step: 0 })),
//   polymer: ['NN'].map((x) => ({ pair: x, step: 0 })),
//   seen: new Set(),
// };
// for (let x = 0; x < 11; x++) {
//   console.log(x, r.polymer)
//   r = step(r);
// }
