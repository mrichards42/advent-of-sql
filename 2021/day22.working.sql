\c
\echo --- Day 22: Reactor Reboot ---

-- Since we're just executing a bunch of prepared statements in a row, timing
-- information isn't helpful in this file. We'll just compute the total time
-- for the whole file.
create temp table start_time as (select now() as t);

/*
 * Schema
 */

create temp table cuboid (
  id int primary key generated always as identity,
  orig_id int,
  is_on bool,
  x_range int8range,
  y_range int8range,
  z_range int8range
);

create temp table split_cuboid (
  like cuboid
  including all
);

create index if not exists cuboid_xyz_btree
  on cuboid (x_range, y_range, z_range);

create index if not exists cuboid_xyz
  on cuboid using gist (x_range, y_range, z_range);

create index if not exists cuboid_x
  on cuboid using gist (x_range);

create index if not exists cuboid_y
  on cuboid using gist (y_range);

create index if not exists cuboid_z
  on cuboid using gist (z_range);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day22.sample.small.txt' */
/* \copy raw_input(line) FROM '2021/day22.sample.txt' */
\copy raw_input(line) FROM '2021/day22.sample.large.txt'
/* \copy raw_input(line) FROM '2021/day22.txt' */

insert into cuboid(orig_id, is_on, x_range, y_range, z_range)
select
  id,
  m[1] = 'on',
  -- Note that since this is a discrete range, postgresql will convert these
  -- into [) format! i.e. [x_min, x_max+1).
  int8range(m[2]::int, m[3]::int, '[]'),
  int8range(m[4]::int, m[5]::int, '[]'),
  int8range(m[6]::int, m[7]::int, '[]')
from
  raw_input,
  lateral regexp_match(line, '(on|off) x=(-?\d+)..(-?\d+),y=(-?\d+)..(-?\d+),z=(-?\d+)..(-?\d+)') as m
order by id
;

/*
 * The problem
 */

prepare split_cubes as
  -- Find all the cuboids that overlap with another one.
  with subj as (
    select
      cuboid.*,
      other.id as other_id,
      other.x_range as other_x_range,
      other.y_range as other_y_range,
      other.z_range as other_z_range
    from cuboid
    cross join lateral (
      select *
      from cuboid as other
      where
        cuboid.id != other.id
        -- overlaps with other
        and cuboid.x_range && other.x_range
        and cuboid.y_range && other.y_range
        and cuboid.z_range && other.z_range
        -- but not identical to other
        and not (
          cuboid.x_range = other.x_range
          and cuboid.y_range = other.y_range
          and cuboid.z_range = other.z_range
        )
      order by other.id -- order so this is deterministic
      limit 1
    ) as other
    where other.id is not null
  ),
  -- Anything without an overlap can get moved to the final split_cuboid table
  _split_insert as (
    insert into split_cuboid(orig_id, is_on, x_range, y_range, z_range)
    select orig_id, is_on, x_range, y_range, z_range
    from cuboid
    where id not in (select id from subj)
  ),
  -- Replace the entire cuboid table with the new splits
  _clear as (
    delete from cuboid
  )
  insert into cuboid(orig_id, is_on, x_range, y_range, z_range)
  select
    subj.orig_id,
    subj.is_on,
    new_x_range,
    new_y_range,
    new_z_range
  from subj
  -- pick the plane to use
  cross join lateral (
    select
      case
        when lower(x_range) < lower(other_x_range) then lower(other_x_range)
        when upper(x_range) > upper(other_x_range) then upper(other_x_range)
      end
  ) _x(x_split)
  cross join lateral (
    select
      case
        when x_split is not null then null
        when lower(y_range) < lower(other_y_range) then lower(other_y_range)
        when upper(y_range) > upper(other_y_range) then upper(other_y_range)
      end
  ) _y(y_split)
  cross join lateral (
    select
      case
        when x_split is not null or y_split is not null then null
        when lower(z_range) < lower(other_z_range) then lower(other_z_range)
        when upper(z_range) > upper(other_z_range) then upper(other_z_range)
      end
  ) _z(z_split)
  cross join lateral (
    select
      case
        when x_split is not null then
          array[
            int8range(lower(subj.x_range), x_split),
            int8range(x_split, upper(subj.x_range))
          ]
        else array[subj.x_range]
      end
  ) as xs(x_range)
  cross join lateral (
    select
      case
        when y_split is not null then
          array[
            int8range(lower(subj.y_range), y_split),
            int8range(y_split, upper(subj.y_range))
          ]
        else array[subj.y_range]
      end
  ) as ys(y_range)
  cross join lateral (
    select
      case
        when z_split is not null then
          array[
            int8range(lower(subj.z_range), z_split),
            int8range(z_split, upper(subj.z_range))
          ]
        else array[subj.z_range]
      end
  ) as zs(z_range)
  cross join lateral unnest(xs.x_range) as new_x_range
  cross join lateral unnest(ys.y_range) as new_y_range
  cross join lateral unnest(zs.z_range) as new_z_range
  -- order so this is deterministic
  order by id, xs.x_range, ys.y_range, zs.z_range
;

execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;
execute split_cubes;


-- debugging information
select 'cuboids left to split', count(*) from cuboid
union all
select 'fully split cuboids', count(*) from split_cuboid
union all
select 'original cuboids processed', count(distinct orig_id) from split_cuboid;

-- Answers

with final_cuboid as (
  select distinct on (x_range, y_range, z_range)
    *,
    (upper(x_range) - lower(x_range))
    * (upper(y_range) - lower(y_range))
    * (upper(z_range) - lower(z_range)) as volume
  from split_cuboid
  order by x_range, y_range, z_range, orig_id desc
),
part1(part, answer) as (
  select 'part1', sum(volume)
  from final_cuboid
  where is_on
    and int8range(-50,50, '[]') @> x_range 
    and int8range(-50,50, '[]') @> y_range 
    and int8range(-50,50, '[]') @> z_range 
),
part2(part, answer) as (
  select 'part2', sum(volume)
  from final_cuboid
  where is_on
)
select * from part1
union all
select * from part2
;

-- Total time
select now() - t as total_time
from start_time;
