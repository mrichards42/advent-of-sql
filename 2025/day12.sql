\echo --- Day 12: Christmas Tree Farm ---

/*
 * Schema
 */

create temp table presents (
  id int,
  x int,
  y int
);

create temp table trees (
  id int,
  w int,
  h int,
  present_id int,
  present_count int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

-- \copy raw_input(line) FROM '2025/day12.sample.txt'
\copy raw_input(line) FROM '2025/day12.txt'

-- don't feel like writing the general parsing logic
insert into presents
select id / 5 as id, x, id % 5 - 1 as y
from raw_input
cross join lateral string_to_table(line, null) with ordinality as _(square, x)
where id < 30 and id % 5 in (2, 3, 4) and square = '#';

insert into trees
select id, parts[1]::int as w, parts[2]::int as h, present_idx - 1 as present_id, present_count::int
from raw_input
cross join lateral regexp_match(line, '(\d+)x(\d+): (.*)') as _parts(parts)
cross join lateral string_to_table(parts[3], ' ') with ordinality as _presents(present_count, present_idx)
where id >= 30;

/*
 * The problem
 */

-- Part 1: how many trees can you definitely fit all the presents under?
-- Note that this is basically impossible to solve so the input is structured
-- so that only the ones that can fit all of the full squares get counted as
-- big enough.

with

present_sizes as (
  select id, count(*) as size
  from presents
  group by 1
),

tree_stats as (
  select
    trees.id,
    sum(present_sizes.size * trees.present_count) as min_area,
    sum(9 * trees.present_count) as max_area,
    any_value(trees.w * trees.h) as tree_area
  from trees
  inner join present_sizes on trees.present_id = present_sizes.id
  group by 1
),

results as (
  select
    count(*) filter (where tree_area < min_area) as too_small,
    count(*) filter (where tree_area >= max_area) as big_enough,
    -- this should be 0
    count(*) filter (where min_area <= tree_area and tree_area < max_area) as ambiguous
  from tree_stats
),

part1(part, answer) as (
  select 'part1', big_enough::text from results where ambiguous = 0
  union all
  select 'part1', 'ambiguous result!' from results where ambiguous > 0
)

select * from part1
;
