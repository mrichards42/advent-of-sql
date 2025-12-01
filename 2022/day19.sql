\c
\echo --- Day 19: Not Enough Minerals ---

/*
 * Schema
 */

create temp table blueprint (
  id int,
  robot_type text,
  cost_ore int,
  cost_clay int,
  cost_obsidian int,
  -- optimization: no need to make more of a given resource than it is possible
  -- to consume on one turn
  max_necessary int,
  unique(id, robot_type)
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day19.sample.txt' */
\copy raw_input(line) FROM '2022/day19.txt'

insert into blueprint
select
  id,
  match[1],
  coalesce(match[2]::int, 0),
  coalesce(match[3]::int, 0),
  coalesce(match[4]::int, 0)
from raw_input
cross join lateral regexp_split_to_table(line, '[:.]') as _1(recipe)
cross join lateral regexp_match(recipe, 'Each (.*) robot costs (?:(\d+) ore)?(?: and )?(?:(\d+) clay)?(?: and )?(?:(\d+) obsidian)?') as _2(match)
where match is not null
;

update blueprint
set max_necessary = (
  select max(
    case
      when blueprint.robot_type = 'ore' then other.cost_ore
      when blueprint.robot_type = 'clay' then other.cost_clay
      when blueprint.robot_type = 'obsidian' then other.cost_obsidian
      else 999999 -- geode
    end
  )
  from blueprint as other
  where blueprint.id = other.id
    and blueprint.robot_type != other.robot_type
);

select * from blueprint;

/*
 * The problem
 */

\timing on


-- TODO: one thing to realize is that the optimal path for part 1 is _not_ the
-- same as for part 2! For part 2 we need to build up capacity for longer if it
-- means we can churn out expensive robots faster at the end.

with recursive
tick(i, idx, blueprint, robot_ore, robot_clay, robot_obsidian, robot_geode, ore, clay, obsidian, geode, build_next, built) as (
  -- distinct sets of "things to build next" that can be built with just ore
  select 0, row_number() over (), id, 1, 0, 0, 0, 0, 0, 0, 0, robot_type, array[]::text[]
  from blueprint
  where cost_clay = 0 and cost_obsidian = 0
  union all
  (
    with prev_ as (
      select distinct on (blueprint, robot_ore, robot_clay, robot_obsidian, robot_geode, build_next, ore, clay, obsidian, geode) *
      from tick
      /* select * from tick */
    ), prev as (
      select * from prev_ as p
      -- so in each group of (id, robots) we want to eliminate rows that have a
      -- strictly better one (where all resources are >= what we have)
      where not exists (
        select 1 from prev_ as other
        where p.blueprint = other.blueprint
          -- not the exact same row
          and p.idx != other.idx
          -- has all the same robots
          and p.robot_ore = other.robot_ore
          and p.robot_clay = other.robot_clay
          and p.robot_obsidian = other.robot_obsidian
          and p.robot_geode = other.robot_geode
          -- building the same robot next
          and p.build_next = other.build_next
          -- has worse resources
          and p.ore <= other.ore
          and p.clay <= other.clay
          and p.obsidian <= other.obsidian
          and p.geode <= other.geode
      )
      -- TODO: another thought from reddit: if any branch for the current
      -- blueprint could not possibly catch up with the best branch, we can
      -- prune it (where the heuristic is "score if you were to build a geode
      -- robot every turn")
    )
    select
      i + 1,
      row_number() over (),
      prev.blueprint,
      case when build.robot_type = 'ore' then robot_ore + 1 else robot_ore end,
      case when build.robot_type = 'clay' then robot_clay + 1 else robot_clay end,
      case when build.robot_type = 'obsidian' then robot_obsidian + 1 else robot_obsidian end,
      case when build.robot_type = 'geode' then robot_geode + 1 else robot_geode end,
      ore + robot_ore - coalesce(build.cost_ore, 0),
      clay + robot_clay - coalesce(build.cost_clay, 0),
      obsidian + robot_obsidian - coalesce(build.cost_obsidian, 0),
      geode + robot_geode,
      coalesce(next_build.robot_type, prev.build_next),
      case when build is null then built else built || build.robot_type end
    from prev
    -- the robot we're currently building
    left join lateral (
      select *
      from blueprint
      where prev.blueprint = blueprint.id and prev.build_next = blueprint.robot_type
        and cost_ore <= ore
        and cost_clay <= clay
        and cost_obsidian <= obsidian
    ) as build on true
    -- the next robot to build, if we're about to build one
    left join lateral (
      select *
      from blueprint
      where prev.blueprint = blueprint.id
        -- do we currently have, or are we building a robot that can collect the
        -- required material for the next build?
        and (robot_ore > 0 or cost_ore = 0 or build.robot_type = 'ore')
        and (robot_clay > 0 or cost_clay = 0 or build.robot_type = 'clay')
        and (robot_obsidian > 0 or cost_obsidian = 0 or build.robot_type = 'obsidian')
        -- these optimizations worked for part 1
        -- optimization: ore is never really the problem, so only build a max
        -- of like 3 ore robots?
        /* and not (build.robot_type = 'ore' and i > 16) */
        -- optimization: same thing with clay, we need to focus on geode robots
        -- at the end
        /* and not (build.robot_type = 'clay' and i > 16) */
        -- TODO: the above optimizations only work for part 1, not part 2
        -- Don't build more robots of a given type than we could possibly need
        and blueprint.max_necessary > (
            case
              when blueprint.robot_type = 'ore' then robot_ore + coalesce((build.robot_type = 'ore')::int, 0)
              when blueprint.robot_type = 'clay' then robot_clay + coalesce((build.robot_type = 'clay')::int, 0)
              when blueprint.robot_type = 'obsidian' then robot_obsidian + coalesce((build.robot_type = 'obsidian')::int, 0)
              else robot_geode
            end
          )
    ) as next_build on build is not null
    where
    /* (i < 24) -- part 1 */
      (i < 32 and prev.blueprint < 4) -- part 2
  )
),
result1 as (
  select blueprint, max(geode) as geode
  from tick
  where i = 24
  group by 1
),
result2 as (
  select blueprint, max(geode) as geode
  from tick
  where i = 32
  group by 1
)
(select * from result1 order by blueprint)
union all
(select * from result2 order by blueprint)
union all
(select i, count(*) from tick group by 1 order by 1)
;

/*
select
  i,
  count(*),
  count(distinct (id, robot_geode, robot_obsidian, robot_clay, robot_ore, geode, obsidian, clay, ore, build_next))
from tick
group by 1
order by 1
*/
;

/*
32*10*25 -> 8000 too low
32*11*25 -> 8800 too high
32*10*26 -> 8320 too high
33*10*25 -> 8250 ???
*/

/*
-- is it possible to get any geodes from blueprint 30?

 id | robot_type | cost_ore | cost_clay | cost_obsidian 
----+------------+----------+-----------+---------------
 30 | ore        |        4 |         0 |             0
 30 | clay       |        4 |         0 |             0
 30 | obsidian   |        2 |        14 |             0
 30 | geode      |        4 |         0 |            19


We need to work backward:

assume ore is basically not a problem, so we need to work backward from the
obsidian cost.

Options (need 19 obsidian):
- 1 obsidian robot  * 19 minutes
- 2 obsidian robots * 10 minutes
- 3 obsidian robots *  7 minutes
- 4 obsidian robots *  5 minutes
- 5 obsidian robots *  4 minutes
- 6 obsidian robots *  3 minutes
- 7 obsidian robots *  3 minutes
- 8 obsidian robots *  3 minutes
- 9 obsidian robots *  2 minutes

Now, how many obsidian robots can we make (need 16 clay)?
- 1 clay robot  * 14 minutes
- 2 clay robots *  7 minutes
- 3 clay robots *  5 minutes
- 4 clay robots *  4 minutes
- 5 clay robots *  4 minutes
- 6 clay robots *  3 minutes

So assuming the best case scenario (we start with 6 clay robots)
- It will take 3 minutes to build 1 obsidian robot,
- It will take 3 + 19 = 22 to get 1 geode robot
- Or really it's 3 minutes per obsidian robot, so we get
- t3:  1 robot + 0
- t6:  2 robot + 3
- t9:  3 robot + 3 + 6
- t12: 4 robot + 3 + 6 + 9 = 18
- t13: 4 robot + 3 + 6 + 9 + 4 = 22 -> build the geode robot


Now, a more realistic scenario is
- 3 clay robots means
- t5:  1 robot + 0
- t10: 2 robot + 5
- t15: 3 robot + 5 + 10
- t16: 3 robot + 5 + 10 + 3 = 18
- t17: 3 robot + 5 + 10 + 3 + 3 = 21 -> build the geode robot

- 2 clay robots means
- t7:  1 robot + 0
- t14: 2 robot + 7
- t20: 2 robot + 7 + 12 = 19 -> build the geode robot

except it costs 4 ore to build a clay robot, so the best we can do is minute 4
before we even have 1 clay robot, which means we can never get to the geode
robot in 24 minutes.

*/


/*

Comparing different pruning strategies:

None - brute force, all possible combinations
1    - distinct rows
2    - removing strictly worse rows
3    - only producing robots up to the max cost for the robot's resource

Counting the number of branches in the same data.

 iteration |    none |      1 |    1+2 | 1+2+3 |     3
-----------+---------+--------+--------+-------+-------
         0 |       4 |      4 |      4 |     4 |     4
         1 |       4 |      4 |      4 |     4 |     4
         2 |       4 |      4 |      4 |     4 |     4
         3 |       7 |      7 |      7 |     7 |     7
         4 |       9 |      9 |      9 |     9 |     9
         5 |      15 |     15 |     15 |    14 |    14
         6 |      22 |     22 |     22 |    18 |    18
         7 |      41 |     41 |     41 |    29 |    29
         8 |      73 |     73 |     73 |    39 |    39
         9 |     142 |    135 |    133 |    55 |    57
        10 |     270 |    241 |    234 |    69 |    75
        11 |     639 |    534 |    473 |   122 |   150
        12 |    1685 |   1262 |   1028 |   210 |   264
        13 |    4640 |   3145 |   2264 |   340 |   506
        14 |   13259 |   8097 |   5098 |   607 |  1004
        15 |   38652 |  20772 |  11334 |   975 |  1896
        16 |  113907 |  51831 |  24548 |  1589 |  3547
        17 |  338088 | 124681 |  51142 |  2471 |  6816
        18 | 1008775 | 289243 | 103408 |  3829 | 12635

Runtime in ms for 18 iterations

                none |      1 |    1+2 | 1+2+3 |     3
               ------+--------+--------+-------+-------
                9100 |   3500 |   2400 |    80 |   150

So 3 is definitely the most important, but 1 and 2 also contribute some.

Even so, 24 iterations still takes 4 seconds, and 32 takes almost 3 minutes on
just the sample input.

On my actual input, that's 8 seconds for 24 iterations, and 
*/
