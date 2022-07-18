\c
\echo --- Day 7: The Treachery of Whales ---

/*
 * Schema
 */

create temp table crab (
  pos int
);

/*
 * Parse input
 */

create temp table raw_input (
  line text
);

/* \copy raw_input FROM '2021/day07.sample.txt' */
\copy raw_input FROM '2021/day07.txt'

insert into crab
select unnest(string_to_array(line, ','))::int
from raw_input;

/*
 * The problem
 */

-- Part 1: simple distance

with target as (
  select generate_series(min(pos), max(pos)) as pos
  from crab
),
target_distance as (
  select
    target.pos,
    abs(target.pos - crab.pos) as distance
  from crab
  cross join target
),
target_cost_simple as (
  select
    pos,
    sum(distance) as fuel_cost
  from target_distance
  group by pos
),
part1(part, answer) as (
  select 'part1', min(fuel_cost)
  from target_cost_simple
),

-- Part 2: triangular distance

target_cost_triangular as (
  select
    pos,
    sum(distance * (distance + 1) / 2) as fuel_cost
  from target_distance
  group by pos
),
part2(part, answer) as (
  select 'part2', min(fuel_cost)
  from target_cost_triangular
)

-- Answers

select * from part1
union all
select * from part2
;


/*

-- Same thing but as a binary search
-- This takes a little less than half a second for each part, which is roughly
-- twice as fast as the other method, but it's a lot less readable :)

with recursive
target_cost_search(next_min, next_max, target, cost) as (
  (
    select min(pos), max(pos), null::int, null::bigint
    from crab
  )
  union all
  (
    with prev as (
      select * from target_cost_search
    ),
    next_target as (
      select generate_series(mid-1, mid+1) as target
      from (
        select (next_min + next_max) / 2 from prev
        where next_min is not null and next_max is not null
        limit 1
      ) mid(mid)
    ),
    next_search as (
      select
        target,
        -- part 1
        /* (select sum(abs(target - pos)) from crab) as cost */
        -- part 2
        (select sum(abs(target - pos) * (1 + abs(target - pos)) / 2) from crab) as cost
      from next_target
    ),
    next_bounds as (
      select
        case
          when cost[1] < cost[2] and cost[2] < cost[3] then array[min, target[1]]
          when cost[1] > cost[2] and cost[2] > cost[3] then array[target[3], max]
          else null
        end as bounds
      from (
        select
          (select next_min from prev limit 1) as min,
          (select next_max from prev limit 1) as max,
          array_agg(target) as target,
          array_agg(cost) as cost
        from next_search
        group by min, max
        order by cost
      ) t
    )
    select bounds[1], bounds[2], target, cost
    from next_search, next_bounds
  )
)
select cost from target_cost_search
order by cost
limit 1
;
*/
