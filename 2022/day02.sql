\c
\echo --- Day 2: Rock Paper Scissors ---

/*
 * Schema
 */

create temp table round (
  id int,
  opponent char,
  you char
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day02.sample.txt' */
\copy raw_input(line) FROM '2022/day02.txt'

insert into round
select id, left(line, 1), right(line, 1)
from raw_input;

/*
 * The problem
 */

create temp table answer (
  part text,
  answer int
);

-- Part 1: x, y, z = rock, paper, scissors

create temp table score1 (
  opponent char,
  you char,
  score int
);

-- 1 = rock, 2 = paper, 3 = scissors
-- 0 = lose, 3 = draw,  6 = win
insert into score1
values ('A', 'X', 1 + 3),
       ('A', 'Y', 2 + 6),
       ('A', 'Z', 3 + 0),
       ('B', 'X', 1 + 0),
       ('B', 'Y', 2 + 3),
       ('B', 'Z', 3 + 6),
       ('C', 'X', 1 + 6),
       ('C', 'Y', 2 + 0),
       ('C', 'Z', 3 + 3);

insert into answer
select 'part1', sum(score)
from round
inner join score1 on round.opponent = score1.opponent and round.you = score1.you;

-- Part 2: x, y, z = lose, draw, win

create temp table score2 (
  opponent char,
  you char,
  score int
);

-- 1 = rock, 2 = paper, 3 = scissors
-- 0 = lose, 3 = draw,  6 = win
insert into score2
values ('A', 'X', 3 + 0),
       ('A', 'Y', 1 + 3),
       ('A', 'Z', 2 + 6),
       ('B', 'X', 1 + 0),
       ('B', 'Y', 2 + 3),
       ('B', 'Z', 3 + 6),
       ('C', 'X', 2 + 0),
       ('C', 'Y', 3 + 3),
       ('C', 'Z', 1 + 6);

insert into answer
select 'part2', sum(score)
from round
inner join score2 on round.opponent = score2.opponent and round.you = score2.you;

-- Answers

select * from answer;
