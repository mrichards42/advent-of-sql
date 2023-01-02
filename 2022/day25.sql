\c
\echo --- Day 25: Full of Hot Air ---

/*
 * Schema
 */

create temp table number (
  id int,
  digit int,
  value int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day25.sample.txt' */
\copy raw_input(line) FROM '2022/day25.txt'

insert into number
select
  id,
  digit,
  array_position(array['=', '-', '0', '1', '2'], value) - 3
from raw_input
cross join lateral regexp_split_to_table(reverse(line), '') with ordinality as _(value, digit)
;

/*
 * The problem
 */

-- Part 1: add up all the numbers

with recursive
summed as (
  select digit, sum(value) as value
  from number
  group by digit
  order by digit
),
simplified(idx, number) as (
  select 1, array_agg(value order by digit)
  from summed
  union all
  select idx + 1, number[:idx-1] || remainder || coalesce(number[idx+1], 0) + carry || number[idx+2:]
  from simplified
  -- first compute the simple remainder and carry amount
  cross join lateral (
    select
      (number[idx] / 5)::int as carry_raw,
      number[idx] % 5 as remainder_raw
  ) as _1
  -- since we need to adjust each place to be between -2 and 2, carry extra or
  -- borrow extra from the next place if necessary
  cross join lateral (
    select
      case
        when remainder_raw >  2 then carry_raw + 1
        when remainder_raw < -2 then carry_raw - 1
        else carry_raw
      end carry,
      case
        when remainder_raw >  2 then remainder_raw - 5
        when remainder_raw < -2 then remainder_raw + 5
        else remainder_raw
      end as remainder
  ) as _2
  where number[idx+1] is not null or carry != 0
),
final_number as (
  select number
  from simplified
  order by idx desc
  limit 1
)
select
  'part1' as part,
  reverse(string_agg(('[-2:2] = {=,-,0,1,2}'::text[])[number], '')) as answer
from (select unnest(number) as number from final_number) _
;
