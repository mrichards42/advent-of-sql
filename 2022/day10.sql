\c
\echo --- Day 10: Cathode-Ray Tube ---

/*
 * Schema
 */

create temp table instruction (
  id int,
  instruction text,
  arg int,
  cycle_count int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day10.sample.txt' */
\copy raw_input(line) FROM '2022/day10.txt'

insert into instruction
select id, split[1], split[2]::int, case when split[1] = 'noop' then 1 else 2 end
from raw_input
cross join string_to_array(line, ' ') as _(split)
;

/*
 * The problem
 */

create temp table computer as (
  select
    *,
    -- inclusive, first cycle is cycle 1, not 0
    1 + coalesce(sum(cycle_count) over before, 0) as first_cycle,
    -- exclusive
    sum(cycle_count) over after as last_cycle,
    -- register starts at 1
    1 + coalesce(sum(arg) over before, 0) as start_value,
    1 + sum(arg) over after as end_value
  from instruction
  window
    before as (rows between unbounded preceding and 1 preceding),
    after as (rows between unbounded preceding and current row)
);

-- Part 1: do some math on the register at certain cycles:

select sum(cycle * computer.start_value) as part1
from generate_series(20, 220, 40) as _(cycle)
left join computer
  on cycle between computer.first_cycle and computer.last_cycle
;

-- Part 2: draw a picture!

with screen as (
  select
    x,
    y,
    case when coord.x between start_value - 1 and start_value + 1
      then '█'
      else '.'
    end as pixel
  from generate_series(1, 240) as _(cycle)
  left join computer
    on cycle between computer.first_cycle and computer.last_cycle
  cross join lateral (
    select
      (cycle - 1) % 40 as x,
      floor((cycle - 1) / 40) as y
  ) as coord
)
select string_agg(pixel, '' order by x) as part2
from screen
group by y
;
