\c
\echo --- Day 6: Lanternfish ---

/*
 * Schema
 */

create temp table fish (
  age int
);

/*
 * Parse input
 */

create temp table raw_input (
  line text
);

/* \copy raw_input FROM '2021/day06.sample.txt' */
\copy raw_input FROM '2021/day06.txt'

insert into fish
select unnest(string_to_array(line, ',')::int[]) as age
from raw_input;

/*
 * The problem
 */

-- Part 1: 80 generations

-- This tracks each individual fish, and is increasingly inefficient with more
-- generations. It's reasonable for 80 generations (around 5 seconds), but the
-- part 2 solution is a lot more efficient.

/*
with recursive generation(gen, age) as (
  -- initial generation
  select 0, age
  from fish

  union all

  -- subsequent generations
  (
    with prev as (
      select *
      from generation
      where gen < 80
    )
    -- existing fish
    select
      gen + 1,
      case
        when age = 0 then 6
        else age - 1
      end
    from prev

    union all

    -- new fish
    select gen + 1, 8
    from prev
    where age = 0
  )
)
select 'part1', count(*)
from generation
where gen = 80
;
*/

-- Part 2: 256 generations

-- This tracks fish age + count, which is efficient for any number of
-- generations.

with recursive generation(gen, age, count) as (
  -- initial generation
  select 0, age, count(*)::bigint
  from fish
  group by age

  union all

  -- subsequent generations
  (
    with prev as (
      select *
      from generation
      where gen < 256
    )
    -- existing fish
    select
      gen + 1,
      case
        when age = 0 then 6
        else age - 1
      end,
      sum(count)::bigint
    from prev
    group by gen, age

    union all

    -- new fish
    select gen + 1, 8, count
    from prev
    where age = 0
  )
)

-- both answers here, since this method is more efficient
select 'part1' as part, sum(count) as answer
from generation
where gen = 80

union all

select 'part2', sum(count)
from generation
where gen = 256
;
