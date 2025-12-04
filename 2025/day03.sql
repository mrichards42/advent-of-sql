\echo --- Day 3: Lobby ---

/*
 * Schema
 */

create temp table battery_banks (
  bank_id int,
  battery_id int,
  joltage int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

-- \copy raw_input(line) FROM '2025/day03.sample.txt'
\copy raw_input(line) FROM '2025/day03.txt'

insert into battery_banks
select id as bank_id, battery_id, joltage::int
from raw_input
cross join lateral string_to_table(line, null) with ordinality as _(joltage, battery_id);

/*
 * The problem
 */

-- Part 1: best selection of 2 batteries

with recursive

max_battery_ids as (
  select bank_id, max(battery_id) as max_battery_id
  from battery_banks
  group by 1
),

b1 as (
  select distinct on (bank_id)
    bank_id, battery_id, joltage
  from battery_banks
  inner join max_battery_ids using (bank_id)
  where battery_id != max_battery_id
  order by bank_id, joltage desc, battery_id asc
),

b2 as (
  select distinct on (bank_id)
    bank_id, b2.battery_id, b2.joltage
  from battery_banks as b2
  inner join b1 using (bank_id)
  where b2.battery_id > b1.battery_id
  order by bank_id, b2.joltage desc, b2.battery_id asc
),

best_batteries_1 as (
  select bank_id, b1.joltage * 10 + b2.joltage as joltage
  from b1
  inner join b2 using (bank_id)
),

part1(part, answer) as (
  select 'part1', sum(joltage)
  from best_batteries_1
),

-- Part 2: best selection of 12 batteries

selected_batteries_2 as (
  (
    -- setup row initialized with 0s
    select distinct
      0 as idx,
      bank_id,
      0 as battery_id,
      0::bigint as joltage,
      max_battery_id - 11 as max_battery_id
    from battery_banks
    inner join max_battery_ids using (bank_id)
  )
  union all
  (
    -- at each iteration select the highest joltage that is still available
    -- (right of the last selected battery, left of max_battery_id - number of
    -- selections remaining)
    select distinct on (bank_id) 
      prev.idx + 1 as idx,
      bank_id,
      bank.battery_id,
      bank.joltage,
      prev.max_battery_id + 1 as max_battery_id 
    from battery_banks as bank
    inner join selected_batteries_2 as prev using (bank_id) 
    where bank.battery_id > prev.battery_id
      and bank.battery_id <= prev.max_battery_id 
      and prev.idx < 12
    order by bank_id, bank.joltage desc, bank.battery_id asc 
  )
),

best_batteries_2 as (
  select bank_id, string_agg(joltage::text, '' order by idx)::bigint as joltage
  from selected_batteries_2
  group by 1
  order by 1
),

part2(part, answer) as (
  select 'part2', sum(joltage)
  from best_batteries_2
)

-- Answers

select * from part1
union all
select * from part2
;
