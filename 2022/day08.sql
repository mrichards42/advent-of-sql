\c
\echo --- Day 8: Treetop Tree House ---

/*
 * Schema
 */

create temp table tree (
  row int,
  col int,
  height int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day08.sample.txt' */
\copy raw_input(line) FROM '2022/day08.txt'

insert into tree(row, col, height)
select id, col, height::int
from raw_input
cross join lateral regexp_split_to_table(line, '') with ordinality as _(height, col)
;

-- doing a lot of work with rows and cols, this speeds things up considerably
create index row_idx on tree(row);
create index col_idx on tree(col);

/*
 * The problem
 */

-- Part 1: count of trees visible from the outside

with
blocked as (
  select
    row,
    col,
    height,
    (
      select max(col)
      from tree
      where height >= t.height and row = t.row and col < t.col
    ) as next_left,
    (
      select min(col)
      from tree
      where height >= t.height and row = t.row and col > t.col
    ) as next_right,
    (
      select max(row)
      from tree
      where height >= t.height and row < t.row and col = t.col
    ) as next_up,
    (
      select min(row)
      from tree
      where height >= t.height and row > t.row and col = t.col
    ) as next_down
  from tree as t
  order by row, col
),
part1(part, answer) as (
  select 'part1', count(*)
  from blocked
  where next_left is null
    or next_right is null
    or next_up is null
    or next_down is null
),

-- Part 2: score trees based on how many other trees they can see

grid_size as (
  select max(row) as grid_width, max(col) as grid_height
  from tree
),
visibility as (
  select
    row,
    col,
    coalesce(abs(col - next_left), col - 1) as visible_left,
    coalesce(abs(col - next_right), grid_width - col) as visible_right,
    coalesce(abs(row - next_up), row - 1) as visible_up,
    coalesce(abs(row - next_down), grid_height - row) as visible_down
  from blocked
  cross join grid_size
),
part2(part, answer) as (
  select 'part2', max(visible_left * visible_right * visible_up * visible_down)
  from visibility
)

-- Answers

select * from part1
union all
select * from part2
;
