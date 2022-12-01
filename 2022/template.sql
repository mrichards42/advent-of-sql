\c
\echo --- Day 0: Title ---

/*
 * Schema
 */

create temp table some_table (
  id int,
  val int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

\copy raw_input(line) FROM '2022/day00.sample.txt'
/* \copy raw_input(line) FROM '2022/day00.txt' */

insert into some_table
select id, line
from raw_input;

/*
 * The problem
 */

-- If you can do the whole thing in a CTE, use this template ...

-- Part 1: description

with
part1(part, answer) as (
  select 'part1', 123
),

-- Part 2: description

part2(part, answer) as (
  select 'part2', 456
)

-- Answers

select * from part1
union all
select * from part2
;


-- ... otherwise, if you need to use multiple statements, use this template

create temp table answer (
  part text,
  answer int
);

-- Part 1: description

insert into answer
select 'part1', 123;

-- Part 2: description

insert into answer
select 'part2', 456;

-- Answers

select * from answer;
