\c
\echo --- Day 4: Giant Squid ---

/*
 * Schema
 */

create temp table draw (
  round int primary key generated by default as identity,
  number int
);

create temp table board (
  board_id int,
  x int,
  y int,
  cell int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day04.sample.txt' */
\copy raw_input(line) FROM '2021/day04.txt'

-- Read the first line into "draw"

insert into draw(round, number)
select idx, number::int
from
  raw_input,
  lateral regexp_split_to_table(line, ',') with ordinality as _(number, idx)
where id = 1;

-- Read each board

with board_input as (
  -- boards are separated by a double-newline. rather than trying to figure out
  -- how to deal with boards split across separate rows in "raw_input", just
  -- re-assemble the whole thing into a big string, and then split into boards
  -- by '\n\n'.
  select array_to_string(array(
      select trim(line)
      from raw_input
      where id > 2 -- skip the draw row and the first blank line
      order by id
  ), e'\n') as str
)
insert into board
select id, x, y, cell::int
from
  board_input,
  -- split into boards
  unnest(string_to_array(board_input.str, E'\n\n'))
    with ordinality as _board(board, id),
  -- split into rows
  unnest(string_to_array(board, E'\n'))
    with ordinality as row(row, y),
  -- split rows into cells
  unnest(regexp_split_to_array(row, E' +'))
    with ordinality as _cell(cell, x)
;

/*
 * The problem
 */

-- First, fill in all the boards.
-- Then, determine which round each board was won.

with
marked_board as (
  select board.*, draw.round
  from board
  inner join draw on board.cell = draw.number
),
filled_line as (
  -- rows
  select
    board_id,
    'x' || x as line,
    max(round) as round
  from marked_board
  group by board_id, x

  union all

  -- columns
  select
    board_id,
    'y' || y as line,
    max(round) as round
  from marked_board
  group by board_id, y
),
winning_round_by_board as (
  select board_id, min(round) as round
  from filled_line
  group by board_id
),

-- Part 1: score of the first winning board

winner as (
  select
    winning_round_by_board.board_id,
    winning_round_by_board.round,
    draw.number
  from winning_round_by_board
  inner join draw on winning_round_by_board.round = draw.round
  order by winning_round_by_board.round asc
  limit 1
),
winner_remaining_cells as (
  select sum(marked_board.cell)
  from winner
  inner join marked_board
    on winner.board_id = marked_board.board_id
    and winner.round < marked_board.round
),
part1(part, answer) as (
  select 'part1', winner.number * winner_remaining_cells.sum
  from winner, winner_remaining_cells
),

-- Part 2: score of the last winning board

loser as (
  select
    winning_round_by_board.board_id,
    winning_round_by_board.round,
    draw.number
  from winning_round_by_board
  inner join draw on winning_round_by_board.round = draw.round
  order by winning_round_by_board.round desc
  limit 1
),
loser_remaining_cells as (
  select sum(marked_board.cell)
  from loser
  inner join marked_board
    on loser.board_id = marked_board.board_id
    and loser.round < marked_board.round
),
part2(part, answer) as (
  select 'part2', loser.number * loser_remaining_cells.sum
  from loser, loser_remaining_cells
)

-- Answers

select * from part1
union all
select * from part2
;
