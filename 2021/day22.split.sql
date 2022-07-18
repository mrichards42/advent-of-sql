\c
\echo --- Day 22: Reactor Reboot ---

\timing on

/*
 * Schema
 */

create temp table instruction (
  id int,
  is_on bool,
  x_range int8range,
  y_range int8range,
  z_range int8range
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

-- I made this one up
/* \copy raw_input(line) FROM '2021/day22.sample.tiny.txt' */
/* \copy raw_input(line) FROM '2021/day22.sample.tiny.split.txt' */

/* \copy raw_input(line) FROM '2021/day22.sample.txt' */
/* \copy raw_input(line) FROM '2021/day22.sample.split.txt' */

/* \copy raw_input(line) FROM '2021/day22.sample.small.txt' */
\copy raw_input(line) FROM '2021/day22.sample.large.txt'
/* \copy raw_input(line) FROM '2021/day22.txt' */

insert into instruction(id, is_on, x_range, y_range, z_range)
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
;

/*
 * The problem
 */

select * from instruction;

-- TODO: this takes a while, but I think it's mostly b/c the algorithm is off
-- and it's not actually slicing anything

-- TODO: parallel slicing doesn't seem to work?
with recursive split(i, orig_id, id, is_on, x_range, y_range, z_range, other_id, x, y, z, xs, ys, zs) as (
  select 0, id, id::bigint, is_on, x_range, y_range, z_range
  , null::bigint, null::bigint, null::bigint, null::bigint
  , null::int8range[], null::int8range[], null::int8range[]
  from instruction
  /* where id in (1, 2, 3, 4) */

  union all

  (
    with prev as (
      select
        i,
        orig_id,
        -- renumber each time so id is unique even with splits
        row_number() over (order by id, x_range, y_range, z_range) as id,
        is_on,
        x_range,
        y_range,
        z_range
      from split
      where i < 50
    ),
    subj as (
      select
        prev.*,
        other.id as other_id,
        other.x_range as other_x_range,
        other.y_range as other_y_range,
        other.z_range as other_z_range
      from prev
      cross join lateral (
        select *
        from prev as other
        where
          -- overlaps with other
          prev.x_range && other.x_range
          and prev.y_range && other.y_range
          and prev.z_range && other.z_range
          and not (
            -- but not wholly contained within other
            prev.x_range <@ other.x_range
            and prev.y_range <@ other.y_range
            and prev.z_range <@ other.z_range
          )
          and prev.id != other.id
        limit 1
      ) as other
      where other.id is not null
    )
    -- pick a single plane to slice
    -- compute the range combinations based on the slice plane
    -- make the slice
    select
      subj.i + 1,
      subj.orig_id,
      subj.id,
      subj.is_on,
      new_x_range,
      new_y_range,
      new_z_range
      , subj.other_id, x_split, y_split, z_split
      , xs.x_range
      , ys.y_range
      , zs.z_range
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
          /* when x_split is not null then null */
          when lower(y_range) < lower(other_y_range) then lower(other_y_range)
          when upper(y_range) > upper(other_y_range) then upper(other_y_range)
        end
    ) _y(y_split)
    cross join lateral (
      select
        case
          /* when x_split is not null or y_split is not null then null */
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

    union all

    -- keep everything but subj
    select i + 1, orig_id, id, is_on, x_range, y_range, z_range
    , null, null, null, null, null, null, null
    from prev
    where id not in (select id from subj)
      and (select count(*) from subj) > 0
  )
),
final_split as (
  select
    *,
    (upper(x_range) - lower(x_range))
    * (upper(y_range) - lower(y_range))
    * (upper(z_range) - lower(z_range)) as size
  from split
  where i = (select max(i) from split)
),
final_cube as (
  select distinct on (x_range, y_range, z_range)
    *
  from final_split
  order by x_range, y_range, z_range, id desc
)

/* select i, count(*) from split group by i */

/* select * */
/* from final_split */
/* order by i, orig_id, x_range, y_range, z_range */

/* select 'scene.add(cube({ ' */
/*     || 'x: [' || lower(x_range) || ',' || (upper(x_range) - 1) || '], ' */
/*     || 'y: [' || lower(y_range) || ',' || (upper(y_range) - 1) || '], ' */
/*     || 'z: [' || lower(z_range) || ',' || (upper(z_range) - 1) || '], ' */
/*     || 'color: ' || case when is_orig then '0xffffff' when is_on then '0x00ff00' else '0xffff00' end */
/*     || ' }));' */
/* from ( */
/*   select true as is_orig, is_on, x_range, y_range, z_range from instruction */
/*   where id in (select orig_id from final_split) */
/*   union all */
/*   select false as is_orig, is_on, x_range, y_range, z_range from final_split */
/* ) _ */

select sum(size)
from final_cube
where
  is_on
  /* and int8range(-50,50, '[]') @> x_range */ 
  /* and int8range(-50,50, '[]') @> y_range */ 
  /* and int8range(-50,50, '[]') @> z_range */ 
;
