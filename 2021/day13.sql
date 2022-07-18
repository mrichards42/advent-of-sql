\c
\echo --- Day 13: Transparent Origami ---

/*
 * Schema
 */

create temp table dot (
  id int,
  x int,
  y int
);

create temp table fold (
  id int,
  x int,
  y int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day13.sample.txt' */
\copy raw_input(line) FROM '2021/day13.txt'

with blank_line as (
  select id
  from raw_input
  where line = ''
  limit 1
),
_dot as (
  insert into dot(id, x, y)
  select id, coords[1]::int, coords[2]::int
  from
    raw_input,
    lateral string_to_array(line, ',') as coords
  where id < (select id from blank_line)
)
-- folds
insert into fold(id, x, y)
select id, x[1]::int, y[1]::int
from
  raw_input,
  lateral regexp_match(line, 'fold along y=(.*)') as y,
  lateral regexp_match(line, 'fold along x=(.*)') as x
where id > (select id from blank_line)
;

/*
 * The problem
 */

-- Part 1: just the first fold

with recursive first_fold as (
  select *
  from fold
  order by id
  limit 1
),
folded_dot(fold_id, x, y) as (
  select first_fold.id - 1, dot.x, dot.y
  from dot
  cross join first_fold

  union -- eliminate duplicate dots

  (
    with prev as (
      select *
      from folded_dot
      where fold_id + 1 in (select id from fold)
    )
    select
      prev.fold_id + 1,
      case
        when fold.x is not null then prev.x - (2 * (prev.x - fold.x))
        else prev.x
      end as x,
      case
        when fold.y is not null then prev.y - (2 * (prev.y - fold.y))
        else prev.y
      end as y
    from prev
    left join fold
      on prev.fold_id + 1 = fold.id
      and (prev.x > fold.x or fold.x is null)
      and (prev.y > fold.y or fold.y is null)
  )
),
first_fold_dot as (
  select *
  from folded_dot
  where fold_id = (select id from first_fold)
),
part1(part, answer) as (
  select 'part1', count(*)::text
  from first_fold_dot
),

-- Part 2: the rest of the folds

final_dot as (
  select *
  from folded_dot
  where fold_id = (select max(id) from fold)
),
viz_dot as (
  select * from final_dot
),
grid as (
  select x, y
  from generate_series(0, (select max(x) from viz_dot)) as x
  cross join generate_series(0, (select max(y) from viz_dot)) as y
),
viz_grid as (
select
  grid.x,
  grid.y,
  case when viz_dot.x is null then '.' else '#' end as ch
  from grid
  left join viz_dot
    on grid.x = viz_dot.x
    and grid.y = viz_dot.y
),
viz_row as (
  select y, string_agg(ch, '' order by x) as row
  from viz_grid
  group by y
),
part2(part, answer) as (
  select 'part2', string_agg(row, E'\n' order by y)
  from viz_row
)

select * from part1
union all
select * from part2
;
