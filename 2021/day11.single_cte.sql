\c
\echo --- Day 11: Dumbo Octopus ---

-- This is how I originally did day 11 before I realized postgresql allows
-- nested recursive CTEs. It's actually pretty reasonable since it works sort
-- of like a state machine, and "jumps" to the correct state during each
-- iteration. It is a bit slower (~200%) than the nested CTE approach though.

/*
 * Schema
 */

create temp table octopus (
  id int primary key generated always as identity,
  x int,
  y int,
  energy int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) from '2021/day11.sample.txt' */
\copy raw_input(line) from '2021/day11.txt'

insert into octopus(x, y, energy)
select
  x,
  id as y,
  energy::int
from raw_input
cross join lateral regexp_split_to_table(line, '') with ordinality as t(energy, x)
;

/*
 * The problem
 */

create temp table generation (
    gen int,
    id int,
    x int,
    y int,
    flash_count int,
    energy bigint
);

-- run through all generations up to the stopping condition

with recursive raw_generation AS (
  select
    0 as gen,
    0 as gen_step,
    id,
    x,
    y,
    0 as flash_count,
    energy::bigint
  from octopus

  union all

  (
    with raw_prev as (
      select *
      from raw_generation
    ),
    prev as (
      select *
      from raw_prev
      -- part 1 condition
      /* where gen < 100 */
      -- part 2 condition: this should be > the part1 condition for most boards
      where (select 1 from raw_prev where energy != 0 limit 1) is not null
    ),
    -- State machine! inc -> propagate -> finalize
    phase as (
      select
        case
          when gen_step = 0 then 'inc'       -- increment energy
          when energy > 9 then   'propagate' -- propagate energy
          else                   'finalize'  -- next generation
        end as phase
      from prev
      order by energy desc
      limit 1
    ),
    -- (1) inc: increment energy levels
    phase_inc as (
      select
        gen,
        gen_step + 1,
        id,
        x,
        y,
        flash_count,
        energy + 1
      from prev
      cross join phase
      where phase.phase = 'inc'
    ),
    -- (2) propagate: if there are still flashes, propagate the energy around
    flashed as (
      select * from prev where energy > 9
    ),
    flashed_neighbor as (
      select
        prev.id,
        count(flashed.id) as count
      from prev
      left join flashed
        on prev.x in (flashed.x - 1, flashed.x, flashed.x + 1)
        and prev.y in (flashed.y - 1, flashed.y, flashed.y + 1)
        and prev.id != flashed.id
      cross join phase
      where phase.phase = 'propagate'
      group by prev.id
    ),
    phase_propagate as (
      select
        prev.gen,
        prev.gen_step + 1,
        prev.id,
        prev.x,
        prev.y,
        prev.flash_count,
        case
          when prev.energy > 9 then -100 -- mark this as flashed once
          else prev.energy + flashed_neighbor.count
        end as energy
      from prev
      left join flashed_neighbor on prev.id = flashed_neighbor.id
      cross join phase
      where phase.phase = 'propagate'
    ),
    -- (3) finalize: if there are no more flashes, go to the next generation
    phase_finalize as (
      select
        gen + 1,
        -- generation is done, so reset gen_step
        0 as gen_step,
        id,
        x,
        y,
        -- energy < 0 means flash
        flash_count + case when energy < 0 then 1 else 0 end as flash_count,
        -- energy < 0 means flash
        case when energy < 0 then 0 else energy end as energy
      from prev
      cross join phase
      where phase.phase = 'finalize'
    )
    select * from phase_inc
    union all
    select * from phase_propagate
    union all
    select * from phase_finalize
  )
)
insert into generation (gen, id, x, y, flash_count, energy)
select gen, id, x, y, flash_count, energy
from raw_generation
where gen_step = 0
;

-- Part 1: total flash count at generation 100

with part1(part, answer) as (
  select 'part1', sum(flash_count)
  from generation
  where gen = 100
),

-- Part 2: first generation where all flashes happened

part2(part, answer) as (
  select 'part2', gen
  from generation
  group by gen
  having(sum(energy) = 0)
  order by gen
  limit 1
)

select * from part1
union all
select * from part2
;

/*
-- debugging / visualization

\pset pager 0
\pset format unaligned
with gen_row as (
  -- colorized rows
  select
    gen,
    y,
    sum(flash_count) as flash_count,
    string_agg(e'\x1b[38;5;' || color || 'm' || energy || e'\x1b[0m', '' order by x) as gen_row
  from generation
  cross join lateral (select case when energy = 0 then 255 else 245 end as color) t
  group by gen, y
)
-- formatted columns
select
  gen,
  sum(flash_count),
  E'\n' || string_agg(gen_row, E'\n' order by y) || E'\n\n'
from gen_row
where
  gen % 10 = 0
  or gen = (select max(gen) from generation)
group by gen
order by gen;
\pset pager 1
\pset format aligned

*/
