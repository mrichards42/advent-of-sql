\c
\echo --- Day 12: Passage Pathing ---

/*
 * Schema
 */

create temp table edge (
  cave_from text,
  cave_to text,
  is_small bool, -- edge to a small cave
  primary key (cave_from, cave_to)
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day12.sample.tiny.txt' */
\copy raw_input(line) FROM '2021/day12.txt'

with split as (
  select string_to_array(line, '-') as cave
  from raw_input
),
undirected_split as (
  select cave from split
  union all
  select array[cave[2], cave[1]] as cave from split
)
insert into edge(cave_from, cave_to, is_small)
select
  cave[1],
  cave[2],
  lower(cave[2]) = cave[2]
from undirected_split
;

/*
 * The problem
 */

-- Part 1: all paths, only allowed to visit small caves once

with recursive path1(curr, visited, smalls) as (
  select 'start', array['start'], array['start']

  union all

  (
    with prev as (
      select * 
      from path1
      where
        curr != 'end'
        and array_length(visited, 1) < 1000
    )
    select
      edge.cave_to as curr,
      prev.visited || edge.cave_to as visited,
      case
        when edge.is_small then prev.smalls || edge.cave_to
        else prev.smalls
      end as smalls
    from prev
    inner join edge on prev.curr = edge.cave_from
    where not (edge.is_small and smalls @> array[edge.cave_to])
  )
),
part1(part, answer) as (
  select 'part1', count(*)
  from path1
  where curr = 'end'
),

-- Part 2: can visit one small cave twice

path2(curr, visited, smalls, used_double_small)  as (
  select 'start', array['start'], array['start'], false

  union all

  (
    with prev as (
      select *
      from path2
      where
        curr != 'end'
        and array_length(visited, 1) < 1000
    )
    select
      edge.cave_to as curr,
      prev.visited || edge.cave_to as visited,
      case
        when edge.is_small then prev.smalls || edge.cave_to
        else prev.smalls
      end as smalls,
      used_double_small or seen_small as used_double_small
    from prev
    inner join edge on prev.curr = edge.cave_from
    cross join lateral (select prev.smalls @> array[edge.cave_to] as seen_small) _
    where
      (
        not edge.is_small              -- big caves always ok
        or not seen_small              -- never seen this small cave
        or not prev.used_double_small  -- haven't used the double-small yet
      )
      and edge.cave_to != 'start' -- but never hit start twice
  )
),
part2(part, answer) as (
  select 'part2', count(*)
  from path2
  where curr = 'end'
)

-- Answers

select * from part1
union all
select * from part2
;
