// pretty sure this is a linked list problem
const fs = require("node:fs");

const INPUT = fs
  .readFileSync("2022/day20.txt", "UTF-8")
  // .readFileSync("2022/day20.sample.txt", "UTF-8")
  .trim()
  .split("\n")
  .map(x=>+x);

const makeRing = (input) => {
  const nodes = input.map((x, idx) => ({ value: x, idx }));
  nodes.forEach((node, idx) => {
    node.prev = nodes[idx-1];
    node.next = nodes[idx+1];
  });
  nodes[0].prev = nodes[nodes.length-1];
  nodes[nodes.length-1].next = nodes[0];
  return {
    // we only ever traverse the ring starting at value 0, so this might as
    // well be the root of the ring
    root: nodes.find((n) => n.value === 0),
    // we constantly need to access nodes by their original order
    nodes: nodes,
    length: nodes.length,
  };
}

const toArray = (ring) => {
  const root = ring.root;
  const ret = [root.value];
  let n = root.next;
  while (n !== root) {
    ret.push(n.value);
    n = n.next;
  }
  return ret;
}

const swapRight = (node) => {
  const left1 = node.prev;
  const other = node.next;
  const right2 = other.next;
  node.prev = other; other.next = node;
  node.next = right2; right2.prev = node;
  other.prev = left1; left1.next = other;
  return node;
}

const swapLeft = (node) => {
  swapRight(node.prev);
  return node;
}

const mixRing1 = (ring, node) => {
  // The main insight: swapping length-1 times is a no-op
  const count = node.value % (ring.length - 1);
  // This could also be sped up considerably by swapping this node directly
  // with its final location, rather than going one at a time, but this is
  // already fast enough
  for (let i = 0; i < count; i++) {
    swapRight(node);
  }
  for (let i = 0; i > count; i--) {
    swapLeft(node);
  }
  return ring;
}

const mixRing = (ring, n) => {
  if (n == null) {
    return ring.nodes.reduce(mixRing1, ring);
  }
  return ring.nodes.slice(0, n).reduce(mixRing1, ring);
}

const mix1 = (INPUT) => {
  const ring = makeRing(INPUT);
  return toArray(mixRing(ring));
}

const part1 = (INPUT) => {
  const result = mix1(INPUT);
  return (
    result[1000 % result.length]
    + result[2000 % result.length]
    + result[3000 % result.length]
  );
}

const mix2 = (INPUT) => {
  const ring = makeRing(INPUT.map((x) => x * 811589153));
  for (let i = 0; i < 10; i++) {
    mixRing(ring);
  }
  return toArray(ring);
}

const part2 = (INPUT) => {
  const result = mix2(INPUT);
  return (
    result[1000 % result.length]
    + result[2000 % result.length]
    + result[3000 % result.length]
  );
}


console.time('part1');
console.log(part1(INPUT));
console.timeEnd('part1');

console.time('part2');
console.log(part2(INPUT));
console.timeEnd('part2');
