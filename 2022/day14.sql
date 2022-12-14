\c
\echo --- Day 14: Regolith Reservoir ---
\echo expect this to take 10+ seconds

\timing on

/*
 * Schema
 */

create temp table rock (
  x int,
  y int,
  unique(y, x)
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day14.sample.txt' */
\copy raw_input(line) FROM '2022/day14.txt'

with point as (
  select id, idx, point[1]::int as x, point[2]::int as y
  from raw_input
  cross join lateral regexp_split_to_table(line, ' -> ') with ordinality as _1(point_str, idx)
  cross join lateral string_to_array(point_str, ',') as _2(point)
),
segment as (
  select
    id,
    x as x1,
    y as y1,
    lead(x) over input_line as x2,
    lead(y) over input_line as y2
  from point
  window input_line as (partition by id order by idx)
)
insert into rock(x, y)
select distinct x, y
from segment
cross join lateral generate_series(least(x1, x2), greatest(x1, x2)) as x(x)
cross join lateral generate_series(least(y1, y2), greatest(y1, y2)) as y(y)
;

/*
 * The problem
 */

create temp table answer (
  part text,
  answer int
);

-- Part 1: falling sand

create temp table sand1 as (
  with recursive
  sand(x, y) as (
    -- Placeholder since we need to start the recursive cte with a non-empty
    -- row. This gets removed at the end.
    select 0, 0
    union all
    (
      with recursive
      prev_sand as (
        select * from sand
      ),
      blocks as (
        select x, y from rock
        union all
        select x, y from prev_sand
      ),
      sand_path(x, y) as (
        -- Simulate a single grain of falling sand
        select 500, 0
        union all
        (
          with prev as (
            select * from sand_path
          ),
          below as (
            select * from blocks where y = (select y + 1 from prev)
          ),
          next_square as (
            select
              case
                when not exists (select 1 from below where x = prev.x)
                  then prev.x
                when not exists (select 1 from below where x = prev.x - 1)
                  then prev.x - 1
                when not exists (select 1 from below where x = prev.x + 1)
                  then prev.x + 1
              end as x,
              prev.y + 1 as y
            from prev
          )
          select *
          from next_square
          -- stop when sand starts falling to infinity
          where y <= (select max(y) + 1 from rock)
            and x >= (select min(x) - 1 from rock)
            and x <= (select max(x) + 1 from rock)
        )
      ),
      final_sand as (
        select * from sand_path
        order by y desc
        limit 1
      ),
      resting_place as (
        select *
        from final_sand
        where y < (select max(y) from rock)
          and x >= (select min(x) from rock)
          and x <= (select max(x) from rock)
      )
      -- we need to track all previous grains for the next iteration since sand
      -- can't fall into the same space twice
      (
        select x, y
        from prev_sand
        where exists (select 1 from resting_place)
      )
      union all
      (
        select x, y
        from resting_place
      )
    )
  )
  select distinct x, y
  from sand
  where (x, y) != (0, 0)
);

insert into answer
select 'part1', count(*)
from sand1;

-- Part 2: sand keeps falling until the entrance is blocked (and there's a
-- floor at max(y) + 2)

-- Instead of tracking each piece of sand, we can assume the sand will fill the
-- full triangle starting at the top, and instead subtract the negative space.

-- Given a 7-width block of rocks, you end up with negative space that looks
-- like this (a downward pointing triangle)

-- ......o......
-- .....ooo.....
-- ....ooooo....
-- ...ooooooo...
-- ..o#######o..
-- .ooo.....ooo.
-- ooooo...ooooo
-- oooooo.oooooo
-- ooooooooooooo

create temp table sand2 as (
  with recursive
  negative_space(x, y) as (
    -- Placeholder since we need to start the recursive cte with a non-empty
    -- row. This gets removed at the end.
    select 0, 0
    union all
    (
      with prev as (
        select x, y from negative_space
      ),
      blocked as (
        select x, y from prev
        union all
        select x, y from rock
      ),
      new_blocked as (
        select x, y + 1
        from blocked as candidate
        cross join lateral (
          select count(*)
          from blocked
          where y = candidate.y
            and x between candidate.x - 1 and candidate.x + 1
        ) as _(block_size)
        where
          -- 3 blocks in a row is the minimum that has negative space under it
          block_size = 3
          and not exists (
            select 1 from blocked where y = candidate.y+1 and x = candidate.x
          )
          and candidate.y < (select max(y) + 1 from rock)
      ),
      next_iteration as (
        select * from prev
        union all
        select * from new_blocked
      )
      select * from next_iteration 
      where exists (select 1 from new_blocked)
    )
  ),
  -- I don't actually need to fill in the sand, but it's handy for visualization.
  -- The formula is (max(y) + 1)^2 - count(rock) - count(negative_space)
  all_sand as (
    select x, y
    from generate_series(0, (select max(y) + 1 from rock)) as y(y)
    cross join lateral generate_series(500 - y, 500 + y) as x(x)
  )
  select * from all_sand
  except all
  select * from negative_space
  except all
  select * from rock
);

insert into answer
select 'part2', count(*)
from sand2;

-- Answers

select * from answer;


-- Visualization
-- This might take a minute or two

/*

create unique index sand1_index on sand1(y, x);
create unique index sand2_index on sand2(y, x);

with
sand as (
  select * from sand2
),
bounds(min_x, max_x, min_y, max_y) as (
  select min(x) - 1, max(x) + 1, 0, max(y) + 1
  from rock
  -- ^^ this should really be rock union sand, but for part2 the grid is
  -- so big that it takes like 10 minutes to visualize with this method
),
grid(x, y) as (
  select x, y
  from bounds
  cross join generate_series(min_x, max_x) as x(x)
  cross join generate_series(min_y, max_y) as y(y)
)
select grid.y, string_agg(pixel, '' order by grid.x)
from grid
cross join lateral (select
  case
    when exists (select 1 from rock where grid.* = rock.*) then '#'
    when exists (select 1 from sand where grid.* = sand.*) then 'o'
    when grid.x = 500 and grid.y = 0 then '+'
    else '.'
  end
) as _(pixel)
group by 1
order by y
;

*/
