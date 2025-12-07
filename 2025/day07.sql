\echo --- Day 7: Laboratories ---

/*
 * Schema
 */

create temp table grid (
  x int,
  y int,
  cell char
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

-- \copy raw_input(line) FROM '2025/day07.sample.txt'
\copy raw_input(line) FROM '2025/day07.txt'

insert into grid
select x, id as y, cell
from raw_input
cross join string_to_table(line, null) with ordinality as _(cell, x)
where cell in ('S', '^');

/*
 * The problem
 */

-- Part 1: count the number of splits

with recursive

beams(x, y, timeline_count) as (
  -- start with a single beam below 'S'
  select x, y + 1, 1::bigint from grid where cell = 'S'
  union all
  -- advance the beam if there's a `.` split the beam if there's a `^`
  (
    with next_beams as (
      select beams.x + dx as x, beams.y + 1 as y, beams.timeline_count
      from beams
      left join grid on beams.x = grid.x and beams.y + 1 = grid.y
      cross join lateral generate_series(-1, 1) as _(dx)
      where
        case
          when grid.cell is null then dx = 0
          else dx != 0
        end
        and beams.y < (select max(y) from grid)
    )
    select x, y, sum(timeline_count)::bigint
    from next_beams
    group by 1, 2
  )
),

part1(part, answer) as (
  select 'part1', count(*)
  from grid
  left join beams on grid.x = beams.x and grid.y = beams.y + 1
  where grid.cell = '^' and beams is not null
),

-- Part 2: count the number of timelines

part2(part, answer) as (
  select 'part2', sum(timeline_count)
  from beams
  where y = (select max(y) from beams)
)

-- Answers

select * from part1
union all
select * from part2
;
