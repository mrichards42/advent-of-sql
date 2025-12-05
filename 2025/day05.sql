\echo --- Day 5: Cafeteria ---

/*
 * Schema
 */

create temp table fresh_ranges (
  id int,
  fresh_range int8range
);

create temp table ingredients (
  id int8
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

-- \copy raw_input(line) FROM '2025/day05.sample.txt'
\copy raw_input(line) FROM '2025/day05.txt'

insert into fresh_ranges
select id, ('[' || replace(line, '-', ',') || ']')::int8range -- both inclusive
from raw_input
where line like '%-%';

insert into ingredients
select line::int8
from raw_input
where line != '' and line not like '%-%';

/*
 * The problem
 */

create temp table answer (
  part text,
  answer int
);

-- Part 1: number of fresh ingredients in the list of ingredients

insert into answer
select 'part1', count(*)
from ingredients
where exists (select 1 from fresh_ranges where fresh_range @> ingredients.id);

-- Part 2: total number of possible fresh ingredients (ranges overlap)

with normalized_ranges as  (
  select unnest(range_agg(fresh_range)) as fresh_range
  from fresh_ranges
)
insert into answer
select 'part2', sum(upper(fresh_range) - lower(fresh_range))
from normalized_ranges;

-- Answers

select * from answer;
