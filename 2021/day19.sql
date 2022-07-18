\c
\echo --- Day 19: Beacon Scanner ---

/*
 * Schema
 */

create temp table beacon (
  id int primary key generated always as identity,
  scanner int,
  rotation int,
  x int,
  y int,
  z int,
  distance numeric -- the next closest beacon in the positive direction
);

-- These two indexes drastically speed up the distance calculation.
create index if not exists beacon_coord_idx
  on beacon(x, y, z);

create index if not exists beacon_scanner_idx
  on beacon(scanner, rotation);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day19.sample.txt' */
\copy raw_input(line) FROM '2021/day19.txt'

with full_input as (
  select string_agg(line, e'\n' order by id) as all_lines
  from raw_input
)
insert into beacon(scanner, rotation, x, y, z)
select
  scanner - 1 as scanner, -- the input is 0-indexed
  0 as rotation,
  coord[1]::int as x,
  coord[2]::int as y,
  coord[3]::int as z
from full_input
cross join lateral regexp_split_to_table(all_lines, e'\n\n') with ordinality
  as _1(scanner_block, scanner)
cross join lateral regexp_split_to_table(scanner_block, e'\n') with ordinality
  as _2(line, idx)
cross join lateral string_to_array(line, ',') as coord
where idx > 1 -- skip the '--- scanner x ---' line
;



/*
 * The problem
 */

-- Part 1: assembe the full map of beacons

-- First, calculate every possible rotation for each scanner.

insert into beacon(scanner, rotation, x, y, z)
-- With z facing z
/* x,y,z already exists */
select scanner,  1,  y, -x,  z from beacon
union all
select scanner,  2, -x, -y,  z from beacon
union all
select scanner,  3, -y,  x,  z from beacon
union all
-- With z facing -z
select scanner,  4, -x,  y, -z from beacon
union all
select scanner,  5,  y,  x, -z from beacon
union all
select scanner,  6,  x, -y, -z from beacon
union all
select scanner,  7, -y, -x, -z from beacon
union all
-- With z facing x
select scanner,  8,  z,  y, -x from beacon
union all
select scanner,  9,  z, -x, -y from beacon
union all
select scanner, 10,  z, -y,  x from beacon
union all
select scanner, 11,  z,  x,  y from beacon
union all
-- With z facing -x
select scanner, 12, -z,  y,  x from beacon
union all
select scanner, 13, -z, -x,  y from beacon
union all
select scanner, 14, -z, -y, -x from beacon
union all
select scanner, 15, -z,  x, -y from beacon
union all
-- With z facing y
select scanner, 16,  x,  z, -y from beacon
union all
select scanner, 17,  y,  z,  x from beacon
union all
select scanner, 18, -x,  z,  y from beacon
union all
select scanner, 19, -y,  z, -x from beacon
union all
-- With z facing -y
select scanner, 20,  x, -z,  y from beacon
union all
select scanner, 21, -y, -z,  x from beacon
union all
select scanner, 22, -x, -z, -y from beacon
union all
select scanner, 23,  y, -z, -x from beacon
;

-- Then for each beacon, find the distance to the closest beacon with a greater
-- x, y, and z coordinate. This makes matching up scanners much simpler, since
-- we can find matching distances directly without having to first shift one
-- scanner relative to the other.

with nearest as (
  select id, near.distance
  from beacon
  cross join lateral (
    select calc.distance
    from beacon as other
    cross join lateral (
      select sqrt(
        (other.x - beacon.x) ^ 2
        + (other.y - beacon.y) ^ 2
        + (other.z - beacon.z) ^ 2
      )
    ) as calc(distance)
    where
      beacon.scanner = other.scanner
      and beacon.rotation = other.rotation
      and beacon.x < other.x
      and beacon.y < other.y
      and beacon.z < other.z
    order by distance
    limit 1
  ) as near
)
update beacon
set distance = nearest.distance
from nearest
where beacon.id = nearest.id
;

with recursive fixed(scanner, rotation, x_shift, y_shift, z_shift) as (
  -- the first scanner, with no shift or rotation
  select 0, 0, 0, 0, 0
  union all
  (
    with prev as (
      select * from fixed
    ),
    target as (
      select
        beacon.scanner,
        beacon.x + prev.x_shift as x,
        beacon.y + prev.y_shift as y,
        beacon.z + prev.z_shift as z,
        beacon.distance
      from prev
      inner join beacon
        on prev.scanner = beacon.scanner
        and prev.rotation = beacon.rotation
    ),
    candidate as (
      select *
      from beacon
      where scanner not in (select scanner from target)
    ),
    -- Find two beacons that are the same distance apart for the given scanner
    -- pair. Calculate the shift that would be required to match up those two
    -- beacons. Each of these is a possible shift.
    shift as (
      select distinct
        target.scanner as target_scanner,
        candidate.scanner,
        candidate.rotation,
        target.x - candidate.x as x_shift,
        target.y - candidate.y as y_shift,
        target.z - candidate.z as z_shift
      from candidate
      inner join target on candidate.distance = target.distance
    ),
    -- Given each rotation + shift combination, see how many candidate beacons
    -- match a target beacon.
    shifted as (
      select
        shift.target_scanner,
        candidate.scanner,
        candidate.rotation,
        shift.x_shift,
        shift.y_shift,
        shift.z_shift,
        candidate.x + shift.x_shift as x,
        candidate.y + shift.y_shift as y,
        candidate.z + shift.z_shift as z
      from candidate
      inner join shift
        on candidate.scanner = shift.scanner
        and candidate.rotation = shift.rotation
    ),
    -- Finally, for each pair of scanners, find the shift + rotation
    -- combination that results in at least 12 matching beacons.
    matching_scanner as (
      select
        shifted.target_scanner,
        shifted.scanner,
        shifted.rotation,
        shifted.x_shift,
        shifted.y_shift,
        shifted.z_shift,
        count(*)
      from shifted
      inner join target
        on shifted.x = target.x
        and shifted.y = target.y
        and shifted.z = target.z
      group by 1,2,3,4,5,6
      having count(*) >= 12
    )
    -- Select all previous and newly fixed scanners, stopping when there are no
    -- more candidates (which would mean all scanners are fixed)
    select * from prev
    where exists (select 1 from candidate)
    union all
    select distinct scanner, rotation, x_shift, y_shift, z_shift
    from matching_scanner
  )
),
scanner_shift as (
  select distinct *
  from fixed
  order by scanner
),
all_beacon as (
  select distinct
    beacon.x + scanner_shift.x_shift,
    beacon.y + scanner_shift.y_shift,
    beacon.z + scanner_shift.z_shift
  from scanner_shift
  inner join beacon
    on scanner_shift.scanner = beacon.scanner
    and scanner_shift.rotation = beacon.rotation
),
part1(part, answer) as (
  select 'part1', count(*)
  from all_beacon
),

-- Part 2: the max distance between any two scanners

scanner_dist as (
  select
    scanner_shift.scanner as scanner_from,
    other.scanner as scanner_to,
    (
      abs(scanner_shift.x_shift - other.x_shift)
      + abs(scanner_shift.y_shift - other.y_shift)
      + abs(scanner_shift.z_shift - other.z_shift)
    ) as dist
  from scanner_shift
  inner join scanner_shift as other on scanner_shift.scanner != other.scanner
),
part2(part, answer) as (
  select 'part2', max(dist)
  from scanner_dist
)

-- Answers

select * from part1
union all
select * from part2
;
