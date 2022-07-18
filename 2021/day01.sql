\c
\echo --- Day 1: Sonar Sweep ---

/*
 * Schema
 */

create temp table reading (
  id int primary key generated always as identity,
  depth int
);

/*
 * Read input
 */

/* \copy reading(depth) FROM '2021/day01.sample.txt' */
\copy reading(depth) FROM '2021/day01.txt'

/*
 * The problem
 */

-- Part 1: count of increasing readings

with diff1 as (
  select (lead(depth) over (order by id)) - depth as diff
  from reading
),
part1(part, answer) as (
  select 'part1', count(*)
  from diff1
  where diff > 0
),

-- Part 2: same, but with a 3-reading window

windowed_reading as (
  select
    id,
    sum(depth) over (order by id rows between current row and 2 following) as depth
  from reading
),
diff2 as (
  select (lead(depth) over (order by id)) - depth as diff
  from windowed_reading
),
part2(part, answer) as (
  select 'part2', count(*)
  from diff2
  where diff > 0
)

-- Answers

select * from part1
union all
select * from part2
;
