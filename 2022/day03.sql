\c
\echo --- Day 3: Rucksack Reorganization ---

/*
 * Schema
 */

create temp table item (
  rucksack int,
  compartment int,
  elf_group int,
  letter char
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day03.sample.txt' */
\copy raw_input(line) FROM '2022/day03.txt'

insert into item
select
  id as rucksack,
  case when idx * 2 > length(line) then 2 else 1 end as compartment,
  ceil(id / 3.0) as elf_group,
  letter
from raw_input
cross join lateral regexp_split_to_table(line, '') with ordinality as _(letter, idx)
;


/*
 * The problem
 */

create temp table score(letter, score) as
select chr(code), idx
from generate_series(ascii('a'), ascii('z')) with ordinality as _(code, idx)
union all
select chr(code), idx + 26
from generate_series(ascii('A'), ascii('Z')) with ordinality as _(code, idx)
;


-- Part 1: shared item between compartments

with shared_item1 as (
  select rucksack, letter
  from item
  group by 1, 2
  having count(distinct compartment) > 1
  order by 1, 2
),
part1(part, answer) as (
  select 'part1', sum(score)
  from shared_item1
  inner join score on shared_item1.letter = score.letter
),

-- Part 2: shared item in the group

shared_item2 as (
  select elf_group, letter
  from item
  group by 1, 2
  having count(distinct rucksack) = 3
  order by 1, 2
),
part2(part, answer) as (
  select 'part2', sum(score)
  from shared_item2
  inner join score on shared_item2.letter = score.letter
)

-- Answers

select * from part1
union all
select * from part2
;
