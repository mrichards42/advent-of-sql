\c
\echo --- Day 17: Pyroclastic Flow ---

\timing on

/*
 * Schema
 */

create temp table jet (
  id int primary key,
  dx int
);

create temp table shape (
  id int,
  x int,
  y int,
  unique(id, x, y)
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day17.sample.txt' */
\copy raw_input(line) FROM '2022/day17.txt'

insert into jet(id, dx)
select idx - 1, case when jet = '<' then -1 else 1 end
from raw_input
cross join lateral regexp_split_to_table(line, '') with ordinality as _(jet, idx)
;

-- negative y coordinates so that the bottom is 0
insert into shape(id, x, y)
values
  -- horizontal line
  (0, 0, 0),
  (0, 1, 0),
  (0, 2, 0),
  (0, 3, 0),
  -- plus
  (1, 1, 0),
  (1, 0, -1),
  (1, 1, -1),
  (1, 2, -1),
  (1, 1, -2),
  -- backward L
  (2, 0, 0),
  (2, 1, 0),
  (2, 2, 0),
  (2, 2, -1),
  (2, 2, -2),
  -- vertical line
  (3, 0, 0),
  (3, 0, -1),
  (3, 0, -2),
  (3, 0, -3),
  -- box
  (4, 0, 0),
  (4, 0, -1),
  (4, 1, -1),
  (4, 1, 0)
;

/*
 * The problem
 */

create temp table answer (
  part text,
  answer bigint
);

-- Part 1: play tetris with 2022 shapes

-- This is a horrible nested loop, but I don't feel like trying to simplifying
-- it (if that's even possible). The basic idea is
/*
  for shape in cycle(shapes):
    while shape is not at rest
      pick next jet from cycle(jets)
      blow jet horizontally
      move down if possible
    add the final resting place to the set of blocks
*/

create temp table game as (
  with recursive
  block(i, j, x, y) as (
    -- start with just the floor, 7 units wide
    -- we'll build up in the negative y direction
    select 0, 0, generate_series(0, 6), 0
    union all
    (
      with recursive
      prev_block as (
        select * from block
      ),
      top_block as (
        select min(y) as min_y from prev_block
      ),
      shape_id as (
        select i % (select max(id) + 1 from shape) as id
        from prev_block
        limit 1
      ),
      current_shape as (
        select * from shape where id = (select id from shape_id)
      ),
      falling(j, dx, dy, fall_end) as (
        -- start 2 units from the left wall, so dx = 2
        -- start 3 units above the top block, so dy = min_y - 4
        select
          (select max(j) from prev_block),
          2, min_y - 4,
          false
        from top_block
        union all
        -- first move the jet, then move the block
        (
          with prev_falling as (
            select * from falling
            where not fall_end
          ),
          current_jet as (
            select jet.id, jet.dx
            from jet, prev_falling
            where jet.id = prev_falling.j % (select count(*) from jet)
          ),
          horizontal(dx) as (
            select
            case when
              exists (
                -- should not hit another block
                select 1
                from prev_block
                inner join (
                  select
                    current_shape.x + prev_falling.dx + current_jet.dx as x,
                    current_shape.y + prev_falling.dy as y
                  from current_shape, prev_falling, current_jet
                ) as new_shape
                on (prev_block.x, prev_block.y) = (new_shape.x, new_shape.y)
              ) or exists (
                -- should not hit a wall
                select 1
                from current_shape, prev_falling, current_jet
                where current_shape.x + prev_falling.dx + current_jet.dx < 0
                  or current_shape.x + prev_falling.dx + current_jet.dx > 6
              )
              then 0
              else dx
            end
            from current_jet
          ),
          vertical(dy) as (
            select
              case when exists (
                select 1
                from prev_block
                inner join (
                  select
                    current_shape.x + prev_falling.dx + horizontal.dx as x,
                    current_shape.y + prev_falling.dy + 1 as y
                  from current_shape, prev_falling, horizontal
                ) as new_shape
                on (prev_block.x, prev_block.y) = (new_shape.x, new_shape.y)
              )
              then 0
              else 1
            end
          )
          select
            j + 1,
            prev_falling.dx + horizontal.dx,
            prev_falling.dy + vertical.dy,
            -- we're done with this piece if we weren't able to move down
            vertical.dy = 0
          from prev_falling, horizontal, vertical, current_jet
        )
      ),
      final(j, x, y) as (
        select j, x + dx, y + dy
        from falling, current_shape
        where fall_end
      )
      select i + 1, j, x, y
      from prev_block
      where i < 2022
        -- optimization: only keep the previous 50 lines, otherwise we end up
        -- copying thousands of lines between each iteration
        and y < (select min(y) + 50 from prev_block)
      union all
      select (select i + 1 from prev_block limit 1), j, x, y
      from final
      where (select i from prev_block limit 1) < 2022
    )
  )
  select * from block
);

insert into answer
select 'part1', -min(y)
from game
;

-- Part 2: play the game for 1000000000000 rounds

-- Take a look at the results for a repeating pattern of increases. It starts
-- somewhere within the first 2022 rounds, so take longer and longer tails and
-- try to find a match earlier.

-- To make sure this would work at all, I actually just did a regex search in
-- vim across the joined height_by_round (starting at the end) until I got the
-- longest match possible, then did some math by hand to get the answer.
-- Expanding that math into sql is . . . long :)

with height_by_round as (
  select i, -min(y) as height
  from game
  group by i
  order by i
),
height_diff_by_round as (
  select i, height - lag(height) over () as diff
  from height_by_round
),
height_diff_string as (
  select string_agg(diff::text, '' order by i) as diff_str
  from height_diff_by_round
),
-- Now look for successively longer patterns in the string, starting from the
-- end
diff_string_match as (
  select
    len,
    (select count(*) from regexp_matches(diff_str, right(diff_str, len), 'g')) as match_count,
    position(right(diff_str, len) in diff_str) as start_pos,
    length(diff_str) - len as end_pos
  from height_diff_string
  -- for the sample, we end up with a really long repetition
  /* cross join lateral generate_series(500, 1011) as _(len) */
  -- but for the actual input, we get a much shorter repetition (and doing
  -- generate_series until 1000 takes a while)
  cross join lateral generate_series(10, 200) as _(len)
),
best_match as (
  select * from diff_string_match
  where match_count = 2
  order by start_pos
  limit 1
),
-- Finally, we can figure out how much taller the stack of rocks gets in a
-- single repetition, then expand it out to 1 trillion rounds
prefix as (
  select
    (select start_pos - 1 from best_match) as rounds,
    sum(diff) as height
  from height_diff_by_round
  where i < (select start_pos from best_match)
),
repetition as (
  select
    (select end_pos - start_pos + 1 from best_match) as rounds,
    sum(diff) as height,
    (select start_pos from best_match),
    (select end_pos from best_match)
  from height_diff_by_round
  where i between (select start_pos from best_match) and (select end_pos from best_match)
),
-- So we need a few numbers:
--
-- 1. Length of the repeated section and total height
-- 2. Number of repetitions
--    this is total_rounds - prefix_rounds // repetition_length
-- 3. Number of extra rounds (where total rounds doesn't divide evenly)
--    this is total_rounds - prefix_founds % repetition_length
-- 4. Height added by extra rounds
--    this is basically starting at the first round, and ending at
--    repetition_start + number_of_extra_rounds
--
-- Then we can do:
-- repetition_height * repetition_count + extra_round_height
repetition_count(n) as (
  select floor(
    (1000000000000 - (select rounds from prefix))
    / (select rounds from repetition)
  )
),
extra_rounds(rounds) as (
  select floor(
    (1000000000000 - (select rounds from prefix))
    % (select rounds from repetition)
  )
),
extra_height(height) as (
  select sum(height_diff_by_round.diff)
  from height_diff_by_round, repetition, extra_rounds
  where i < repetition.start_pos + extra_rounds.rounds
)
insert into answer
select
  'part2',
  + (select height from repetition) * (select n from repetition_count)
  + (select height from extra_height)
;
-- Answers

select * from answer;


-- Visualization

/*
with
bounds(min_x, max_x, min_y, max_y) as (
  select min(x), max(x), min(y), max(y)
  from game
),
grid(x, y) as (
  select x, y
  from bounds
  cross join generate_series(min_x, max_x) as x(x)
  cross join generate_series(min_y, max_y) as y(y)
)
select
  grid.y,
  string_agg(
    case
      when game is not null then '#'
      else '.'
    end,
  '' order by grid.x)
from grid
left join game on (grid.x, grid.y) = (game.x, game.y) and game.i = 2022
group by 1
order by 1
;
*/
