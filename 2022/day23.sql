\c
\echo --- Day 23: Unstable Diffusion ---
\echo expect about 45 seconds

/*
 * Schema
 */

-- Packing points into a single number makes the recursive CTE a good deal
-- faster, even if this whole thing is still pretty slow (without this part1
-- took around 15 seconds, so it seems like part 2 would have taken almost half
-- an hour)
drop function if exists point_id;
create function point_id(x integer, y integer) returns integer as $$
  select y * 1000000 + x
$$ language sql immutable;

create temp table elf (
  x int,
  y int,
  id int generated always as (point_id(x, y)) stored,
  unique(x, y)
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day23.sample.small.txt' */
/* \copy raw_input(line) FROM '2022/day23.sample.txt' */
\copy raw_input(line) FROM '2022/day23.txt'

insert into elf(x, y)
select x + 1000, id + 1000 as y
from raw_input
cross join lateral regexp_split_to_table(line, '') with ordinality as _(cell, x)
where cell = '#';

/*
 * The problem
 */

-- Run a game of life simulation until it stops. We use it for both parts.

create temp table board as (
  with recursive
  move_order(idx, direction_id, delta) as (
    values
      (0, 1, point_id( 0, -1)), -- north
      (1, 2, point_id( 0,  1)), -- south
      (2, 3, point_id(-1,  0)), -- west
      (3, 4, point_id( 1,  0))  -- east
  ),
  tick(i, id) as (
    select 0, id from elf
    union all
    (
      with
      prev as (
        select * from tick where i < 2000
      ),
      current_move_order as (
        select
          array_agg(direction_id order by sort) as move_directions,
          array_agg(delta order by sort) as move_deltas
        from move_order
        cross join lateral (
          select (idx + (select 4 - (i % 4) from prev limit 1)) % 4
        ) as _(sort)
      ),
      proposed as (
        select
          subj.id,
          subj.id + coalesce(move_deltas[move_idx], 0) as proposed_id,
          move_idx
        from prev as subj
        cross join current_move_order
        left join prev as N  on N.id  = subj.id + point_id( 0, -1)
        left join prev as NE on NE.id = subj.id + point_id( 1, -1)
        left join prev as E  on E.id  = subj.id + point_id( 1,  0)
        left join prev as SE on SE.id = subj.id + point_id( 1,  1)
        left join prev as S  on S.id  = subj.id + point_id( 0,  1)
        left join prev as SW on SW.id = subj.id + point_id(-1,  1)
        left join prev as W  on W.id  = subj.id + point_id(-1,  0)
        left join prev as NW on NW.id = subj.id + point_id(-1, -1)
        cross join lateral (
          -- same order as the original move_order: N, S, W, E
          select array[
            coalesce(NW.id, N.id, NE.id),
            coalesce(SW.id, S.id, SE.id),
            coalesce(SW.id, W.id, NW.id),
            coalesce(SE.id, E.id, NE.id)
          ]
        ) _1(blocked_moves)
        cross join lateral (
          select
            case
              when blocked_moves[1] is null
                and blocked_moves[2] is null
                and blocked_moves[3] is null
                and blocked_moves[4] is null then null -- no move
              when blocked_moves[move_directions[1]] is null then 1
              when blocked_moves[move_directions[2]] is null then 2
              when blocked_moves[move_directions[3]] is null then 3
              when blocked_moves[move_directions[4]] is null then 4
            end
        ) as _2(move_idx)
      ),
      invalid_moves as (
        select proposed_id, array_agg(id) as invalid_ids
        from proposed
        group by 1
        having count(*) > 1
      )
      select
        (select i + 1 from prev limit 1),
        case when invalid then id else proposed_id end
      from proposed
      left join lateral (
        select true from invalid_moves where invalid_ids @> array[id]
      ) as _(invalid) on true
      -- stop when all elves failed to move
      where exists (select 1 from proposed where move_idx is not null)
    )
  )
  select *
  from tick
);

-- Part 1: score the 10th board

with
board10(x, y) as (
  select
    (id % point_id(0, 1)),
    (id / point_id(0, 1))
  from board where i = 10
),
bounds(min_x, max_x, min_y, max_y) as (
  select min(x), max(x), min(y), max(y)
  from board10
),
part1(part, answer) as (
  select 'part1', (max_x - min_x + 1) * (max_y - min_y + 1) - (select count(*) from board10)
  from bounds
),

-- Part 2: find the first round where no elf moved

part2(part, answer) as (
  select 'part2', i + 1
  from board
  order by i
  desc limit 1
)

-- Answers

select * from part1
union all
select * from part2
;

/*

-- Viz

do $$
declare display varchar;
begin
  for loop_i in (select min(i) from board)..(select max(i) from board) loop

    with
    boardxy(i, x, y) as (
      select
        i, 
        (id % point_id(0, 1)),
        (id / point_id(0, 1))::int
      from board
    ),
    bounds(min_x, max_x, min_y, max_y) as (
      select min(x), max(x), min(y), max(y)
      from boardxy
    ),
    grid(x, y) as (
      select x, y
      from bounds
      cross join generate_series(min_x, max_x) as x(x)
      cross join generate_series(min_y, max_y) as y(y)
    ),
    rows as (
      select
        grid.y,
        string_agg(case
          when boardxy is null then '.'
          else '#'
        end, '' order by grid.x) as row
      from grid
      left join boardxy on (grid.x, grid.y) = (boardxy.x, boardxy.y) and loop_i = boardxy.i
      group by 1
      order by 1
    )
    select string_agg(row, e'\n' order by y)
    into display
    from rows
    ;
    raise notice e'\n%\n%', loop_i, display;
  end loop;
end $$
;

*/
