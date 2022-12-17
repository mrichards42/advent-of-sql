\c
\echo --- Day 16: Proboscidea Volcanium ---

/*
 * Schema
 */

create temp table valve (
  id int primary key,
  valve_name text,
  flow_rate int
);

create temp table raw_tunnel (
  from_valve int,
  to_valve int
);

create temp table tunnel (
  from_valve int,
  to_valve int,
  weight int,
  to_valve_bit int8 generated always as (1 << to_valve) stored,
  unique(from_valve, to_valve)
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day16.sample.txt' */
\copy raw_input(line) FROM '2022/day16.txt'

with parsed(id, valve_name, flow_rate, to_valves) as (
  select id, match[1], match[2]::int, to_valves
  from raw_input
  cross join lateral regexp_match(line, 'Valve (..) has flow rate=(\d+); tunnels? leads? to valves? (.*)') as _1(match)
  cross join lateral string_to_array(match[3], ', ') as _2(to_valves)
),
_node_insert as (
  insert into valve(id, valve_name, flow_rate)
  select id, valve_name, flow_rate
  from parsed
)
insert into raw_tunnel
select from_valve_id.id, to_valve_id.id
from parsed
cross join lateral unnest(to_valves) as _(to_valve)
left join parsed as from_valve_id on parsed.valve_name = from_valve_id.valve_name
left join parsed as to_valve_id on to_valve = to_valve_id.valve_name
;

/*
 * The problem
 */

create temp table answer (
  part text,
  answer int
);


-- First off, let's compress the graph since most of the nodes are 0 flow rate
-- values, so effectively they just make for 1 step.

with important_valve as (
  select id
  from valve
  where flow_rate > 0 or valve_name = 'AA'
)
insert into tunnel(from_valve, to_valve, weight)
select start_vid, end_vid, agg_cost
from pgr_johnson(
 'select
    row_number() over () as id,
    from_valve as source,
    to_valve as target,
    1 as cost,
    1 as reverse_cost
  from raw_tunnel'
)
where start_vid in (select id from important_valve)
  and end_vid in (select id from important_valve)
;

-- Part 1: best total pressure release in 30 seconds
-- Moving tunnels takes 1 second (but we've compressed the graph, so it takes
-- `weight` seconds).
-- Opening a valve takes 1 second

with recursive
max_time(max_time) as (
  select 30
),
path(i, current_valve, total_seconds, score, visited) as (
  -- there are not very many valves, so we can use a 64bit and bit operations
  -- for `visited`
  select 0, (select id from valve where valve_name = 'AA'), 0, 0, 0::int8
  union all
  select
    i + 1,
    tunnel.to_valve,
    end_time,
    score + flow_rate * remaining_time,
    visited | tunnel.to_valve_bit
  from path
  inner join tunnel
    on tunnel.from_valve = current_valve
    and visited & tunnel.to_valve_bit = 0
  cross join lateral (select total_seconds + tunnel.weight + 1) as _1(end_time)
  cross join lateral (select flow_rate from valve where id = tunnel.to_valve) as _2
  cross join lateral (select max_time - end_time from max_time) as _3(remaining_time)
  where remaining_time > 0
)
insert into answer
select 'part1', max(score)
from path;


-- Part 2: best total pressure release in 26 seconds with you and an elephant
-- moving around. This is basically:
-- (1) run part 1, but for 26 seconds
-- (2) find the greatest sum of scores between any 2 pairs of routes that do
-- not have overlapping valves

with recursive
-- exact same thing as part1, just 26 instead of 30 seconds
max_time(max_time) as (
  select 26
),
path(i, current_valve, total_seconds, score, visited) as (
  select 0, (select id from valve where valve_name = 'AA'), 0, 0, 0::int8
  union all
  select
    i + 1,
    tunnel.to_valve,
    end_time,
    score + valve_score,
    visited | tunnel.to_valve_bit
  from path
  inner join tunnel
    on tunnel.from_valve = current_valve
    and visited & tunnel.to_valve_bit = 0
  cross join lateral (select total_seconds + tunnel.weight + 1) as _1(end_time)
  cross join lateral (select flow_rate from valve where id = tunnel.to_valve) as _2
  cross join lateral (select max_time - end_time from max_time) as _3(remaining_time)
  cross join lateral (select flow_rate * remaining_time) as _4(valve_score)
  where remaining_time > 0
),
-- there are a lot of total paths, but we only care about the highest score for
-- a given set of visited valves, which reduces the total number by an order of
-- magnitude (tens of thousands to thousands).
best_path as (
  select row_number() over () as i, visited, max(score) as score
  from path
  group by 2
),
-- Then we just need to find the best pair of non-overlapping paths
score_pair(score) as (
  select best_path.score + other.score
  from best_path
  inner join best_path as other
    on other.i > best_path.i
    and (best_path.visited & other.visited) = 0
)
insert into answer
select 'part2', max(score)
from score_pair;

-- Answers

select * from answer;
