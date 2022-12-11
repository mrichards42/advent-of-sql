\c
\echo --- Day 11: Monkey in the Middle ---

/*
 * Schema
 */

create temp table monkey (
  id int,
  starting_items int[],
  op text,
  arg int,
  test_divisible int,
  true_monkey int,
  false_monkey int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day11.sample.txt' */
\copy raw_input(line) FROM '2022/day11.txt'

-- A lot of parsing today

with chunks as (
  select floor(id / 7) as monkey, string_to_array(trim(line), ': ') as split
  from raw_input
),
starting_item as (
  select
    monkey,
    string_to_array(split[2], ', ')::int[] as starting_items
  from chunks
  where split[1] = 'Starting items'
),
operation as (
  select
    monkey,
    case
      when split[2] like '%old * old' then 'square'
      when split[2] like '%old *%' then 'mult'
      when split[2] like '%old +%' then 'add'
    end as op,
    (regexp_match(split[2], '\d+'))[1]::int as arg
  from chunks
  where split[1] = 'Operation'
),
test as (
  select
    monkey,
    (regexp_match(split[2], '\d+'))[1]::int as test_divisible
  from chunks
  where split[1] = 'Test'
),
test_true as (
  select
    monkey,
    (regexp_match(split[2], '\d+'))[1]::int as true_monkey
  from chunks
  where split[1] = 'If true'
),
test_false as (
  select
    monkey,
    (regexp_match(split[2], '\d+'))[1]::int as false_monkey
  from chunks
  where split[1] = 'If false'
)
insert into monkey
select *
from starting_item
natural join operation
natural join test
natural join test_true
natural join test_false
;

/*
 * The problem
 */

\echo expect this to take a couple seconds

create temp table answer (
  part text,
  answer bigint
);

-- Part 1: top 2 monkeys after 20 rounds

with recursive
round(i, j, monkey_id, item) as (
  select 0, -1, id, unnest(starting_items) from monkey
  union all
  select
    case when j = (select max(id) from monkey) then i + 1 else i end,
    case when j = (select max(id) from monkey) then -1 else j + 1 end,
    case
      -- we aren't processing this monkey yet
      when monkey_id != j then monkey_id
      -- we're processing this monkey, so throw the thing
      when (new_worry % test_divisible) = 0 then true_monkey
      else false_monkey
    end as monkey_id,
    new_worry
  from round
  inner join monkey on round.monkey_id = monkey.id
  cross join lateral (select
    case
      -- we aren't processing this monkey yet
      when monkey_id != j then item
      -- we're processing this monkey
      when op = 'mult' then ((item * arg) / 3)::int
      when op = 'add' then ((item + arg) / 3)::int
      when op = 'square' then ((item * item) / 3)::int
    end
  ) as _(new_worry)
  where i < 20
),
touch as (
  select i as round, monkey_id, item
  from round
  where j = monkey_id -- j is the monkey counter
),
top_2_monkeys as (
  select monkey_id, count(*) as touches
  from touch
  group by 1
  order by 2 desc
  limit 2
)
insert into answer(part, answer)
select 'part1', touches[1] * touches[2]
from (select array_agg(touches) from top_2_monkeys) as _(touches)
;

-- Part 2: 10000 rounds, no more divide by 3

with recursive
-- have to use modular arithmetic using the product of the test divisors as the
-- base (note that all the divisors are prime)
divisor as (
  -- there's no `product` aggregate, this is a substitute
  select exp(sum(ln(test_divisible)))::bigint as divisor_mod from monkey
),
round(i, j, monkey_id, item) as (
  select 0, -1, id, unnest(starting_items::bigint[]) from monkey
  union all
  select
    case when j = (select max(id) from monkey) then i + 1 else i end,
    case when j = (select max(id) from monkey) then -1 else j + 1 end,
    case
      -- we aren't processing this monkey yet
      when monkey_id != j then monkey_id
      -- we're processing this monkey, so throw the thing
      when (new_worry % test_divisible) = 0 then true_monkey
      else false_monkey
    end as monkey_id,
    new_worry
  from round
  inner join monkey on round.monkey_id = monkey.id
  cross join divisor
  cross join lateral (select
    case
      -- we aren't processing this monkey yet
      when monkey_id != j then item
      -- we're processing this monkey
      when op = 'mult' then (item * arg) % divisor_mod
      when op = 'add' then (item + arg) % divisor_mod
      when op = 'square' then (item * item) % divisor_mod
    end
  ) as _(new_worry)
  where i < 10000
),
touch as (
  select i as round, monkey_id, item
  from round
  where j = monkey_id -- j is the monkey counter
),
top_2_monkeys as (
  select monkey_id, count(*) as touches
  from touch
  group by 1
  order by 2 desc
  limit 2
)
insert into answer(part, answer)
select 'part2', touches[1] * touches[2]
from (select array_agg(touches) from top_2_monkeys) as _(touches)
;

-- Answers

select * from answer;
