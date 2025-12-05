\timing
\echo --- Day 4: Printing Department ---

/*
 * Schema
 */

create temp table grid (
  id int primary key,
  x int,
  y int,
  cell char
);

create temp table neighbors (
  from_id int,
  to_id int
);

create or replace function grid_id(x int, y int) returns int as $$
  select y * 200 + x
$$ language sql immutable parallel safe;

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

-- \copy raw_input(line) FROM '2025/day04.sample.txt'
\copy raw_input(line) FROM '2025/day04.txt'

insert into grid
select grid_id(x::int, id::int) as id, x, id as y, cell
from raw_input
cross join lateral string_to_table(line, null) with ordinality as _(cell, x);

insert into neighbors (
  select id, grid_id(x-1, y-1) from grid
  union all
  select id, grid_id(x  , y-1) from grid
  union all
  select id, grid_id(x+1, y-1) from grid
  union all
  select id, grid_id(x-1, y  ) from grid
  -- skip the current position: id, grid_id(x, y)
  union all
  select id, grid_id(x+1, y  ) from grid
  union all
  select id, grid_id(x-1, y+1) from grid
  union all
  select id, grid_id(x  , y+1) from grid
  union all
  select id, grid_id(x+1, y+1) from grid
);

/*
 * The problem
 */

create temp table answer (
  part text,
  answer int
);

-- Part 1: rolls of paper that are available to pick up (< 4 neighbors)

with
neighbor_rolls as (
  -- we have to the filter here instead of in the where clause since otherwise
  -- that would exclude rolls with 0 neighbors
  select g.id, count(*) filter (where neighbor.cell = '@') as neighbor_count
  from grid as g
  inner join neighbors on g.id = neighbors.from_id
  inner join grid as neighbor on neighbors.to_id = neighbor.id
  where g.cell = '@'
  group by 1
)
insert into answer
select 'part1', count(*)
from neighbor_rolls where neighbor_count < 4;

-- Part 2: total number of rolls that can be removed

with recursive

init as (
  select
    -- For each iteration we pack the grid into a varbit so that we only carry
    -- over a single row.
    bit_or(set_bit(repeat('0', 40000)::bit(40000), id, 1)) as grid,
    count(*) as roll_count,
    0 as idx
  from grid
  where cell = '@'
),

step as (
  select grid, roll_count, idx from init
  union all
  (
    with
    state as (
      select * from step where idx < 100
    ),
    new_grid as (
      select
        from_id as id,
        count(*) filter (where get_bit(state.grid, to_id) = 1) as neighbor_count
      from neighbors, state
      where get_bit(state.grid, from_id) = 1
      group by 1
    ),
    new_state as (
      select
        bit_or(set_bit(repeat('0', 40000)::bit(40000), id, 1)) as grid,
        count(*) as roll_count,
        (select idx + 1 from state) as idx
      from new_grid
      where neighbor_count >= 4 -- keep remaining rolls
    )
    select *
    from new_state
    where new_state.roll_count < (select roll_count from state)
  )
)
insert into answer
select 'part2', max(roll_count) - min(roll_count)
from step;

-- Answers

select * from answer;
