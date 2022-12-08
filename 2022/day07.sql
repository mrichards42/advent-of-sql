\c
\echo --- Day 7: No Space Left On Device ---

/*
 * Schema
 */

create temp table directory (
  path text,
  size int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day07.sample.txt' */
\copy raw_input(line) FROM '2022/day07.txt'

with recursive
raw_dir as (
  select
    cd.path,
    coalesce(contents.size, 0)
  from raw_input as ls
  -- the full path to this directory
  cross join lateral (
    select string_agg((regexp_match(line, '\$ cd /?(.*)'))[1], '/' order by id)
    from raw_input as cd
    where cd.id < ls.id
    and cd.line like '$ cd %'
  ) as cd(path)
  -- the size of the files in this directory
  cross join lateral (
    select sum((regexp_match(line, '\d+'))[1]::int)
    from raw_input as file
    where file.id > ls.id
      -- before the next command
      and file.id < coalesce(
        (select min(id) from raw_input where line like '$%' and id > ls.id),
        (select max(id)+1 from raw_input)
      )
      and line not like 'dir%'
  ) as contents(size)
  where ls.line = '$ ls'
),
simplified(path, size) as (
  select * from raw_dir
  union all
  -- recursively replace '/somedir/..' with ''
  select regexp_replace(path, '/[^./]+/[.][.]', ''), size
  from simplified
  where path like '%/%/..%'
)
insert into directory(path, size)
select * from simplified
where path not like '%..%'
;


/*
 * The problem
 */

-- Part1: sum of all directories <= 100000

with
total_dir_size as (
  select directory.path, sum(children.size) as size
  from directory
  left join directory as children
    on left(children.path, length(directory.path) + 1) = directory.path || '/'
    or directory.path = children.path
  group by 1
),
part1(part, answer) as (
  select 'part1', sum(size)
  from total_dir_size
  where size <= 100000
),

-- Part 2: best directory to delete

free_space_needed as (
  /* select 30000000 - (70000000 - sum(size)) as space */
  select sum(size) - (70000000 - 30000000) as space
  from total_dir_size
  where path = ''
),
part2(part, answer) as (
  select 'part2', size
  from total_dir_size
  -- large enough to cover the needed free space
  where size > (select space from free_space_needed)
  -- pick the smallest one
  order by size asc
  limit 1
)

-- Answers

select * from part1
union all
select * from part2
;
