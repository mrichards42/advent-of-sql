\c
\echo --- Day 1: Calorie Counting ---

/*
 * Schema
 */

create temp table provisions (
  elf int,
  calories int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day01.sample.txt' */
\copy raw_input(line) FROM '2022/day01.txt'

insert into provisions
select elf, calories::int
from (select string_agg(line, e'\n') from raw_input) as input(input)
cross join lateral regexp_split_to_table(input, e'\n\n') with ordinality as _a(meal_lines, elf)
cross join lateral regexp_split_to_table(meal_lines, e'\n') as _b(calories);

/*
 * The problem
 */

-- Part 1: max calories

with
elf_calories as (
  select elf, sum(calories) as calories
  from provisions
  group by elf
),
part1(part, answer) as (
  select 'part1', calories
  from elf_calories
  order by calories desc
  limit 1
),

-- Part 2: sum of top 3 calories

top3_elves as (
  select calories
  from elf_calories
  order by calories desc
  limit 3
),
part2(part, answer) as (
  select 'part2', sum(calories)
  from top3_elves
)

-- Answers

select * from part1
union all
select * from part2
;
