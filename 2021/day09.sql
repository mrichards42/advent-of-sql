\c
\echo --- Day 9: Smoke Basin ---

/*
 * Schema
 */

create temp table grid (
  x int,
  y int,
  val int,
  primary key (x, y)
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day09.sample.txt' */
\copy raw_input(line) FROM '2021/day09.txt'

insert into grid(x, y, val)
select x, id, val::int
from
  raw_input,
  lateral regexp_split_to_table(line, '') with ordinality as _val(val, x)
;

-- insert a border of 9s so that smoke flows down from the edges

with bounds as (
  select
    min(x) as x_min,
    max(x) as x_max,
    min(y) as y_min,
    max(y) as y_max
  from grid
)
insert into grid(x, y, val)
select x, y, 9
from bounds
cross join generate_series(bounds.x_min - 1, bounds.x_max + 1) as x
cross join generate_series(bounds.y_min - 1, bounds.y_max + 1) as y
on conflict
do nothing
;

/* visualize the grid with basins in grayscale

\pset format unaligned
select string_agg(e'\x1b[38;5;' || 255 - val*2 || 'm' || val || e'\x1b[0m', '' order by x)
from grid
group by y order by y;
\pset format aligned

*/


/*
 * The problem
 */

-- Part 1: just the low points

with recursive -- recursive for part 2
low_point as (
  select grid.*
  from grid
  inner join grid as n on n.x = grid.x     and n.y = grid.y - 1 and n.val > grid.val
  inner join grid as s on s.x = grid.x     and s.y = grid.y + 1 and s.val > grid.val
  inner join grid as e on e.x = grid.x - 1 and e.y = grid.y     and e.val > grid.val
  inner join grid as w on w.x = grid.x + 1 and w.y = grid.y     and w.val > grid.val
),
part1(part, answer) as (
  select 'part1', sum(val + 1)
  from low_point
),

-- Part 2: fill in each basin

basin(x, y, val, basin_id) as (
  -- start at the low points
  select x, y, val, row_number() over ()
  from low_point
  -- union instead of union all since we visit some points multiple times
  union
  -- and work upward
  (
    with prev as (
      select *
      from basin
    )
    select n.x, n.y, n.val, g.basin_id
    from grid as n
    join prev as g on n.x = g.x     and n.y = g.y - 1 and n.val > g.val and n.val < 9
    union
    select s.x, s.y, s.val, g.basin_id
    from grid as s
    join prev as g on s.x = g.x     and s.y = g.y + 1 and s.val > g.val and s.val < 9
    union
    select e.x, e.y, e.val, g.basin_id
    from grid as e
    join prev as g on e.x = g.x - 1 and e.y = g.y     and e.val > g.val and e.val < 9
    union
    select w.x, w.y, w.val, g.basin_id
    from grid as w
    join prev as g on w.x = g.x + 1 and w.y = g.y     and w.val > g.val and w.val < 9
  )
),
basin_size as (
  select basin_id, count(*) as size
  from basin
  group by basin_id
  order by size desc
  limit 3
),
part2(part, answer) as (
  select 'part2', size[1] * size[2] * size[3]
  from (select array(select size from basin_size)) as _size(size)
)

/* visualize basins with color!

\pset format unaligned

select string_agg(e'\x1b[' || color || 'm' || val || e'\x1b[0m', '' order by x)
from (
  select x, y, val, '38;5;' || basin_id as color -- 256 colors
  from basin
  union all
  -- basins don't include 9s
  select x, y, val, '38;5;0' as color -- black foreground
  from grid
  where val = 9
) t
where val < 10
group by y
order by y

*/

-- Answers

select * from part1
union all
select * from part2
;
