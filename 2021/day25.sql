\c
\echo --- Day 25: Sea Cucumber ---

-- Like in day 22, we'll time the whole file instead of each statement.
create temp table start_time as (select now() as t);

/*
 * Schema
 */

create temp table cucumber (
  id int primary key generated always as identity,
  step int default 0,
  x int,
  y int,
  herd char
);

create index if not exists cucumber_herd_idx
on cucumber(herd);

create index if not exists cucumber_grid_idx
on cucumber(x, y);

create temp table grid (
  width int,
  height int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day25.sample.txt' */
\copy raw_input(line) FROM '2021/day25.txt'

insert into grid(width, height)
select
  length(line) as width,
  id as height
from raw_input
order by id desc
limit 1
;

insert into cucumber(x, y, herd)
select
  x - 1 as x,
  id - 1 as y,
  herd
from
  raw_input,
  lateral regexp_split_to_table(line, '') with ordinality as pos(herd, x)
where herd in ('>', 'v')
;

select * from cucumber;

/*
 * The problem
 */

prepare move_east as
  update cucumber
  set
    x = (x + 1) % grid.width,
    step = (select max(step) from cucumber where herd = '>') + 1
  from grid
  where
    cucumber.herd = '>'
    and not exists (
      select 1
      from cucumber as east
      where
        (cucumber.x + 1) % grid.width = east.x
        and cucumber.y = east.y
    )
;

prepare move_south as
  update cucumber
  set
    y = (y + 1) % grid.height,
    step = (select max(step) from cucumber where herd = 'v') + 1
  from grid
  where
    cucumber.herd = 'v'
    and not exists (
      select 1
      from cucumber as south
      where
        cucumber.x = south.x
        and (cucumber.y + 1) % grid.height = south.y
    )
;

-- Unrolling this loop again (like in day 22) since the recursive CTE
-- performance is terrible with the large number of rows. Being able to use
-- indexes probably helps a bit as well.

-- Each of these blocks is 50 steps (where one step is move_east + move_south),
-- so this is a total of 650 steps (13 blocks * 50 steps).

execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;

execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;

execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;

execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;

execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;

execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;

execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;

execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;

execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;

execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;

execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;

execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;

execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;
execute move_east; execute move_south; execute move_east; execute move_south;

-- The answer

select
  'part1' as part,
  max(step) + 1 as answer
from cucumber;

-- Total time
select now() - t as total_time
from start_time;
