\echo --- Day 9: Movie Theater ---

/*
 * Schema
 */

create temp table points (
  id int primary key,
  x bigint,
  y bigint
);

create temp table polygon (
  geom geometry
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

-- \copy raw_input(line) FROM '2025/day09.sample.txt'
\copy raw_input(line) FROM '2025/day09.txt'

insert into points
select
  id,
  split_part(line, ',', 1)::bigint as x,
  split_part(line, ',', 2)::bigint as y
from raw_input;

insert into polygon(geom)
select concat('polygon((' || string_agg(concat_ws(' ', x, y), ', '), '))')
from (
  (select x, y from points order by id)
  union all
  (select x, y from points order by id limit 1)
);

/*
 * The problem
 */

-- Part 1: largest rectangle

with

rects as (
  select
    a.id,
    b.id,
    (1 + abs(a.x - b.x)) * (1 + abs(a.y - b.y)) as area,
    concat('polygon((',
      concat_ws(', ',
        concat_ws(' ', a.x, a.y),
        concat_ws(' ', b.x, a.y),
        concat_ws(' ', b.x, b.y),
        concat_ws(' ', a.x, b.y),
        concat_ws(' ', a.x, a.y)
      ),
    '))')::geometry as geom
  from points as a
  inner join points as b on a.id < b.id
),

part1(part, answer) as (
  select 'part1', max(area)
  from rects
),

-- Part 2: largest rectangle fully within the bounding polygon

-- Probably a faster way to do this, but good enough for me
part2(part, answer) as (
  select 'part2', max(area)
  from rects
  cross join polygon
  where ST_Covers(polygon.geom, rects.geom)
)

-- Answers

select * from part1
union all
select * from part2
;
