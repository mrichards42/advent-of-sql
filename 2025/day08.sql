\echo --- Day 8: Playground ---

/*
 * Schema
 */

create temp table junction_box (
  id int,
  x int,
  y int,
  z int
);

-- https://stackoverflow.com/a/71840581
create or replace function mul_sfunc(anyelement, anyelement) returns anyelement
   language sql as 'select $1 * coalesce($2, 1)';

create or replace aggregate product(anyelement) (
   stype = anyelement,
   initcond = 1,
   sfunc = mul_sfunc,
   combinefunc = mul_sfunc,
   parallel = safe
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

-- \copy raw_input(line) FROM '2025/day08.sample.txt'; \set max_edges=10
\copy raw_input(line) FROM '2025/day08.txt';

insert into junction_box
select id, split_part(line, ',', 1)::int, split_part(line, ',', 2)::int, split_part(line, ',', 3)::int
from raw_input;
/*
 * The problem
 */

-- Part 1: product of the size of the largest 3 circuits after connecting the
-- 1000 shortest edges

create temp table edges (
  id int primary key,
  source int,
  target int,
  distance float
);

insert into edges (id, source, target, distance)
with all_edges as (
  select distinct on (self.id, other.id)
    self.id as source,
    other.id as target,
    sqrt(pow(self.x - other.x, 2) + pow(self.y - other.y, 2) + pow(self.z - other.z, 2)) as distance
  from junction_box as self
  inner join junction_box as other on self.id < other.id
  order by 1, 2, 3
)
select row_number() over (order by distance) as id, source, target, distance
from all_edges;


with

connected_components as (
  select * from pgr_connectedComponents($$
    select id, source, target, 1 as cost, 1 as reverse_cost
    from edges
    -- 1000 for real input, 10 for sample input
    where id <= 1000
  $$)
),

circuits as (
  select component, count(*) as size
  from connected_components
  group by 1
),

top_3_circuits as (
  select * from circuits order by size desc limit 3
),

part1(part, answer) as (
  select 'part1', product(size)
  from top_3_circuits
),

-- Part 2: product of the x coordinates of the final edge that completes the
-- circuit

minimum_spanning_tree_edges as (
  select edge from pgr_kruskal('
    select id, source, target, distance as cost, distance as reverse_cost
    from edges
  ')
),

part2(part, answer) as (
  select 'part2', source.x::bigint * target.x::bigint
  from edges
  inner join junction_box as source on edges.source = source.id
  inner join junction_box as target on edges.target = target.id
  where edges.id = (select max(edge) from minimum_spanning_tree_edges)
)

-- Answers

select * from part1
union all
select * from part2
;
