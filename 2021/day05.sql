\c
\echo --- Day 5: Hydrothermal Venture ---

/*
 * Schema
 */

create temp table line (
  x1 int,
  y1 int,
  x2 int,
  y2 int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) from '2021/day05.sample.txt' */
\copy raw_input(line) from '2021/day05.txt'

insert into line
select
  start_point[1]::int as x1,
  start_point[2]::int as y1,
  end_point[1]::int as x2,
  end_point[2]::int as y2
from
  raw_input,
  lateral string_to_array(raw_input.line, ' -> ') as points,
  lateral string_to_array(points[1], ',') as start_point,
  lateral string_to_array(points[2], ',') as end_point
;

/*
 * The problem
 */

-- Day 1: just horizontal and vertical lines

with
ortho_point as (
  select
    x1 as x,
    generate_series(y1, y2, sign(y2 - y1)::int) as y
  from line
  where x1 = x2

  union all

  select
    generate_series(x1, x2, sign(x2 - x1)::int) as x,
    y1 as y
  from line
  where y1 = y2
),
part1(part, answer) as (
  select 'part1', count(*)
  from (
    select x, y, count(*)
    from ortho_point
    group by 1, 2
    having count(*) > 1
  ) t
),

-- Part 2: also diagonals (but only 45 degrees)

diagonal_point as (
  select
    generate_series(x1, x2, sign(x2 - x1)::int) as x,
    generate_series(y1, y2, sign(y2 - y1)::int) as y
  from line
  where x1 <> x2 and y1 <> y2
),
all_point as (
  select * from diagonal_point
  union all
  select * from ortho_point
),
part2(part, answer) as (
  select 'part2', count(*)
  from (
    select x, y, count(*)
    from all_point
    group by 1, 2
    having count(*) > 1
  ) as _
)

-- Answers

select * from part1
union all
select * from part2
;
