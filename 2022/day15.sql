\c
\echo --- Day 15: Beacon Exclusion Zone ---

/*
 * Schema
 */

create temp table sensor (
  id int,
  sensor int[],
  beacon int[],
  range int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day15.sample.txt' */
\copy raw_input(line) FROM '2022/day15.txt'

insert into sensor
select
  id,
  sensor,
  beacon,
  abs(sensor[1] - beacon[1]) + abs(sensor[2] - beacon[2])
from raw_input
cross join lateral regexp_match(line, 'Sensor at x=(-?\d+), y=(-?\d+): closest beacon is at x=(-?\d+), y=(-?\d+)') as _1(match)
cross join lateral (select array[match[1]::int, match[2]::int]) as _2(sensor)
cross join lateral (select array[match[3]::int, match[4]::int]) as _3(beacon)
;

select * from sensor;

with
target_row(y) as (
  /* select 10 */
  select 2000000
),
x_ranges as (
  select
    *,
    case
      when x_width > 0 then int4range(sensor[1] - x_width, sensor[1] + x_width, '[]')
      else null
    end as x_range
  from sensor
  cross join target_row
  cross join lateral (select abs(sensor[2] - target_row.y)) as _1(dist_to_y)
  cross join lateral (select range - dist_to_y) as _2(x_width)
),
range_merge as (
  select range_agg(x_range) as x_multirange
  from x_ranges
),
range_unnest as (
  select unnest(x_multirange) as x_range
  from range_merge
),
target_beacon as (
  select distinct beacon
  from sensor
  where beacon[2] = (select y from target_row)
    and beacon[1] <@ (select x_multirange from range_merge)
)
select
  (select abs(lower(x_range) - upper(x_range)) from range_unnest)
  - (select count(*) from target_beacon)
;

with
polygons as (
  -- PostGIS uses normal coordinate systems, so we need to reflect about the x
  -- axis in order for this to look right in an svg
  select *, format('polygon((%s %s, %s %s, %s %s, %s %s, %1$s %2$s))',
    sensor[1] - range, -sensor[2],
    sensor[1], -(sensor[2] - range),
    sensor[1] + range, -sensor[2],
    sensor[1], -(sensor[2] + range)
  )::geometry as poly
  from sensor
),
svg as (
  select
    format(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s %s %s %s"><!--
      %s--></svg>',
      ST_XMin(st_extent(poly)) - 30,
      ST_YMin(st_extent(poly)) - 30,
      ST_XMax(st_extent(poly)) - ST_XMin(st_extent(poly)) + 60,
      ST_YMax(st_extent(poly)) - ST_YMin(st_extent(poly)) + 60,
      string_agg(
        format(
          '--><path stroke="transparent" fill="green" stroke-width="0.1" d="%s" /><!--',
          st_assvg(poly)
      ), e'\n')
    )
  from polygons
),
difference as (
  select st_difference(
    'polygon((0 0, 4000000 0, 4000000 -4000000, 0 -4000000, 0 0))'::geometry,
    st_union(poly)
  )
  from polygons
)
select st_astext(st_difference) from difference
/* select id, sensor, range, st_astext(poly), st_assvg(poly) from polygons */
/* select * from svg */
;



-- so we have 6 guesses
with x(x) as (
  values (2900204),(2900205),(2900206)
),
y(y) as (
  values (3139120),(3139121)
)
select x, y, x::bigint * 4000000 + y::bigint
from x, y
;

-- it's this one 2900205, 3139120 = 11600823139120
-- now the question is how do I deal with coordinate systems so that I only get
-- a single answer instead of 6?
