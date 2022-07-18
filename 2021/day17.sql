\c
\echo --- Day 17: Trick Shot ---

/*
 * Read input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day17.sample.txt' */
\copy raw_input(line) FROM '2021/day17.txt'

/*
 * The problem
 */

with recursive target as (
  select
    m[1]::int as x_min,
    m[2]::int as x_max,
    m[3]::int as y_min,
    m[4]::int as y_max
  from
    raw_input,
    lateral regexp_matches(line, 'x=(-?\d+)[.][.](-?\d+), y=(-?\d+)[.][.](-?\d+)') as m
),
launcher as (
  select
    -- X velocity decreases by 1 every step until we hit 0. The total distance
    -- traveled at this point is a triangular number based on the original x
    -- velocity. So, launcher.x_min is the lowest triangular number >=
    -- target.x_min.
    -- x * (x + 1) / 2 >= target.x_min
    -- x * (x + 1) >= 2 * target.x_min
    -- (x + 1/2)^2 - 1/4 >= 2 * target.x_min
    -- (x + 1/2)^2 >= 2 * target.x_min + 1/4
    -- x >= sqrt(2 * target.x_min + 1/4) - 1/2
    -- or, from wikipedia, the same thing but slightly rearranged:
    -- x >= (sqrt(8 * target.x_min + 1) - 1) / 2
    (sqrt(2 * x_min::float + 0.25) - 0.5)::int as x_min,
    -- Any more than target.x_max and we'd overshoot to the right.
    x_max as x_max,
    -- Any more than target.y_min and we'd overshoot below.
    y_min as y_min,
    -- We want to aim as high as possible without overshooting on the way down.
    -- Based on the problem description, we're guaranteed that once the probe
    -- has come back to y = 0, the y velocity is negative whatever we started
    -- with . . . and the next step will be -1 more. So the highest y initial
    -- velocity is negative whatever target.y_min is, minus 1. Given that we're
    -- shooting into a trench, I think we're guaranteed that target.y_min is
    -- negative, otherwise this calculation breaks!
    -y_min - 1 as y_max
  from target
),

-- Part 1: the highest y position we can achieve.
-- Since y velocity decreases by 1 each step, this is also a triangular number.

part1(part, answer) as (
  select 'part1', y_max * (y_max + 1) / 2
  from launcher
),

-- Part 2: the number of possible launch positions

-- Find all possible y ending positions (with their starting velocities). Note
-- that a given starting velocity may have multiple valid ending positions!
all_y_rec(y_init, step, y_velocity, y_pos) as (
  -- For negative velocities, just start at 0
  select y_init, 0, y_init, 0
  from launcher
  cross join lateral generate_series(launcher.y_min - 1, -1) as y_init

  union all

  -- For positive velocities, fast forward until we get back to y = 0, i.e.
  -- we've gone up and back down. That means we've gone y_init * 2 + 1 steps
  -- (+1 for the one step we take at the top of the arc). The y velocity is
  -- -y_init - 1, since, as mentioned in the y_max calculation, when y
  -- position is back to 0, y velocity has just hit negative y_init, so the
  -- next velocity is -(y_init + 1).
  select
    y_init,
    y_init * 2 + 1 as step,
    -y_init - 1 as y_velocity,
    0 as y_pos
  from launcher
  cross join target
  cross join lateral generate_series(0, launcher.y_max) as y_init

  union all

  -- The recursive part: advance until we get past the target
  select y_init, step + 1, y_velocity - 1, y_pos + y_velocity
  from all_y_rec
  where y_pos > (select y_min from target)
),
-- just the final positions that are on target
all_y as (
  select step, y_init, y_pos as y_final
  from all_y_rec
  cross join target
  where all_y_rec.y_pos between target.y_min and target.y_max
),
-- Calculate final x positions for each y and make sure they all work. X
-- positions are x + (x-1) + (x-2) . . . except (x-step) never goes past 0.
-- Ultimately this is the x-th triangular number, minus the (x-step)-th
-- triangular number:
-- x*(x+1)/2 - (x-step)*(x-step+1)/2
all_init as (
  select step, y_init, y_final, x_init, x_final
  from all_y
  cross join target
  cross join launcher
  cross join generate_series(launcher.x_min, launcher.x_max) as x_init
  cross join lateral (
    select
      x_init * (x_init + 1) / 2
      /* x never goes backwards, hence greatest(0 ...) */
      - greatest(0, x_init - step) * (x_init - step + 1) / 2
  ) as _(x_final)
  where x_final between target.x_min and target.x_max
),
part2(part, answer) as (
  select 'part2', count(distinct (x_init, y_init))
  from all_init
)

-- Answers

select * from part1
union all
select * from part2
;
