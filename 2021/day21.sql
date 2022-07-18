\c
\echo --- Day 21: Dirac Dice ---

/*
 * Schema
 */

-- This is just the input schema. There's a later one with roll transition
-- tables for part 2.

create temp table game_start (
  pos1 int,
  pos2 int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day21.sample.txt' */
\copy raw_input(line) FROM '2021/day21.txt'

with player as (
  select id, (regexp_match(line, '\d+$'))[1]::int as pos
  from raw_input
),
player1 as (
  select * from player where id = 1
),
player2 as (
  select * from player where id = 2
)
insert into game_start(pos1, pos2)
select player1.pos, player2.pos
from player1, player2
;

/*
 * The problem
 */

create temp table answer (
  part text,
  answer bigint
);

-- Part 1: deterministic dice up to 1000 points

-- I actually worked this out by hand to get the answer, then wrote the code
-- later.

/*

The first 10 turns look like this:

     1, 2, 3 =  6 = 6 mod 10
     4, 5, 6 = 15 = 5 mod 10
     7, 8, 9 = 24 = 4 mod 10
    10,11,12 = 33 = 3 mod 10
    13,14,15 = 42 = 2 mod 10
    16,17,18 = 51 = 1 mod 10
    19,20,21 = 60 = 0 mod 10
    22,23,24 = 69 = 9 mod 10
    25,26,27 = 78 = 8 mod 10
    28,29,30 = 87 = 7 mod 10

Each roll is 9 more than the last. Since the game board is 10 spaces, the pawn
moves forward n mod 10 spaces. So adding 9 to each number is the same as
subtracting 1.

This pattern also holds when the die rolls over the first time:

     97,98,99 = 294 = 4 mod 10
    100, 1, 2 = 103 = 3 mod 10
      3, 4, 5 =  12 = 2 mod 10

The second time:

    96,97,98 = 291 = 1 mod 10
    99,100,1 = 200 = 0 mod 10
     2, 3, 4 =   9 = 9 mod 10

And the third time:

    95,96,97  = 288 = 8 mod 10
    98,99,100 = 297 = 7 mod 10
     1, 2, 3  =   6 = 6 mod 10

And then we're back to the begining

Translating that to rounds we have:

    round 1 = 6 mod 10
    round 2 = 5 mod 10
    round 3 = 4 mod 10
    round 4 = 3 mod 10
    round 5 = 2 mod 10
    ...
    round n = (7 - n) % 10

Finally, you score points based on where your pawn lands, so using the example,
for player 1 starting on 4 (player 1 moves on odd numbered rounds):

      start  =  4
    round  1 =  4 + (7 -  1) % 10 =  4 + 6 = 10 = 10 points
    round  3 = 10 + (7 -  3) % 10 = 10 + 4 = 14 =  4 points
    round  5 =  4 + (7 -  5) % 10 =  4 + 2 =  6 =  6 points
    round  7 =  6 + (7 -  7) % 10 =  6 + 0 =  6 =  6 points
    round  9 =  6 + (7 -  9) % 10 =  6 + 8 = 14 =  4 points
    -- repeat!
    round 11 =  4 + (7 - 11) % 10 =  4 + 6 = 10 = 10 points
    round 13 = 10 + (7 - 13) % 10 = 10 + 4 = 14 =  4 points
    round 15 =  4 + (7 - 15) % 10 =  4 + 2 =  6 =  6 points
    round 17 =  6 + (7 - 17) % 10 =  6 + 0 =  6 =  6 points
    round 19 =  6 + (7 - 19) % 10 =  6 + 8 = 14 =  4 points
    -- repeat!
    ...

So, things repeat every 10 rounds. In this case, player 1 gets 30 points every
10 rounds / 5 turns (10 + 4 + 6 + 6 + 4)

Player 2, starting at 8, and moving on even numbered rounds:

      start  =  8
    round  2 =  8 + (7 -  2) % 10 =  8 + 5 = 13 =  3 points
    round  4 =  3 + (7 -  4) % 10 =  3 + 3 =  6 =  6 points
    round  6 =  6 + (7 -  6) % 10 =  6 + 1 =  7 =  7 points
    round  8 =  7 + (7 -  8) % 10 =  7 + 9 = 16 =  6 points
    round 10 =  6 + (7 - 10) % 10 =  6 + 7 = 13 =  3 points -> total 25
    round 12 =  3 + (7 - 12) % 10 =  3 + 5 =  8 =  8 points
    round 14 =  8 + (7 - 14) % 10 =  8 + 3 = 11 =  1 points
    round 16 =  1 + (7 - 16) % 10 =  1 + 1 =  2 =  2 points
    round 18 =  2 + (7 - 18) % 10 =  2 + 9 = 11 =  1 points
    round 20 =  1 + (7 - 20) % 10 =  1 + 7 =  8 =  8 points -> total 40
    -- repeat!
    round 22 =  8 + (7 - 22) % 10 =  8 + 5 = 13 =  3 points
    round 24 =  3 + (7 - 24) % 10 =  3 + 3 =  6 =  6 points
    round 26 =  6 + (7 - 26) % 10 =  6 + 1 =  7 =  7 points
    round 28 =  7 + (7 - 28) % 10 =  7 + 9 = 16 =  6 points
    round 30 =  6 + (7 - 10) % 10 =  6 + 7 = 13 =  3 points
    ...

Here, things repeat every 20 rounds. Player 2 gets 45 points every 20 rounds /
10 turns (3 + 6 + 7 + 6 + 3 + 8 + 1 + 2 + 1 + 8)

So fast-forwarding to the end:

    Player 1 would hit 1000 points near round (1000 / (30 / 10)) = 333.333...
    Player 2 would hit 1000 points near round (1000 / (45 / 20)) = 444.444...

    The closest round that's a multiple of the player 1 and 2 periods (10 and
    20) is 320.

    round |   p1 |  p2
      320 |  960 | 720
      330 |  990 | 745
      331 | 1000 | 745

    total rolls = 331 * 3 = 993
    answer = 745 * 993 = 739785

*/

/* So the actual problem for part 1 :)

Player 1 starts at 4; no change
Player 2 starts at 3

      start  =  3
    round  2 =  3 + (7 -  2) % 10 =  3 + 5 =  8 =  8 points
    round  4 =  8 + (7 -  4) % 10 =  8 + 3 = 11 =  1 points
    round  6 =  1 + (7 -  6) % 10 =  1 + 1 =  2 =  2 points
    round  8 =  2 + (7 -  8) % 10 =  2 + 9 = 11 =  1 points
    round 10 =  1 + (7 - 10) % 10 =  1 + 7 =  8 =  8 points -> total 20
    round 12 =  8 + (7 - 12) % 10 =  8 + 5 = 13 =  3 points
    round 14 =  3 + (7 - 14) % 10 =  3 + 3 =  6 =  6 points
    round 16 =  6 + (7 - 16) % 10 =  6 + 1 =  7 =  7 points
    round 18 =  7 + (7 - 18) % 10 =  7 + 9 = 16 =  6 points
    round 20 =  6 + (7 - 20) % 10 =  6 + 7 = 13 =  3 points -> total 45
    -- repeat!
    ...

So this is actually the same as starting on 8, it's just that the first 5
scores and the second 5 scores are reversed.

    round |   p1 |  p2
      320 |  960 | 720
      330 |  990 | 740
      331 | 1000 | 740

    total rolls = 331 * 3 = 993
    answer = 745 * 993 = 734820
*/

-- Here's a non-analytical way to do it: just play the whole game :)

with recursive game(turn, pos1, score1, pos2, score2) as (
  select 0, pos1, 0, pos2, 0
  from game_start

  union all

  (
    with prev as (
      select * from game
      where score1 < 1000 and score2 < 1000
    ),
    die as (
      -- 7 - turn mod 10, but avoiding negatives
      select (1000007 - (turn + 1)) % 10 as roll
      from prev
    )
    select
      turn + 1,
      coalesce(next_pos1, pos1),
      score1 + coalesce(next_pos1, 0),
      coalesce(next_pos2, pos2),
      score2 + coalesce(next_pos2, 0)
    from prev
    cross join die
    cross join lateral (select case when (turn % 2) = 0 then die.roll end as roll1) _1
    cross join lateral (select case when (turn % 2) = 1 then die.roll end as roll2) _2
    cross join lateral (select (pos1 + roll1 - 1) % 10 + 1 as next_pos1) _3
    cross join lateral (select (pos2 + roll2 - 1) % 10 + 1 as next_pos2) _4
  )
),
last_turn as (
  select * from game
  where turn = (select max(turn) from game)
)
insert into answer(part, answer)
select 'part1', least(score1, score2) * 3 * turn
from last_turn
;

/***** Part 2 *****

Each roll creates 27 universes:

    (1,1,1) = 3 (1,1,2) = 4 (1,1,3) = 5
    (1,2,1) = 4 (1,2,2) = 5 (1,2,3) = 6
    (1,3,1) = 5 (1,3,2) = 6 (1,3,3) = 7
    (2,1,1) = 4 (2,1,2) = 5 (2,1,3) = 6
    (2,2,1) = 5 (2,2,2) = 6 (2,2,3) = 7
    (2,3,1) = 6 (2,3,2) = 7 (2,3,3) = 8
    (3,1,1) = 5 (3,1,2) = 6 (3,1,3) = 7
    (3,2,1) = 6 (3,2,2) = 7 (3,2,3) = 8
    (3,3,1) = 7 (3,3,2) = 8 (3,3,3) = 9

In total, that's

    roll | count
      3  |   1
      4  |   3
      5  |   6
      6  |   7
      7  |   6
      8  |   3
      9  |   1

So, we can make a table of possible transitions:

              roll -> |  3 |  4 |  5 |  6 |  7 |  8 |  9

    next from  1 =       4    5    6    7    8    9   10
    next from  2 =       5    6    7    8    9   10    1
    next from  3 =       6    7    8    9   10    1    2
    next from  4 =       7    8    9   10    1    2    3
    next from  5 =       8    9   10    1    2    3    4
    next from  6 =       9   10    1    2    3    4    5
    next from  7 =      10    1    2    3    4    5    6
    next from  8 =       1    2    3    4    5    6    7
    next from  9 =       2    3    4    5    6    7    8
    next from 10 =       3    4    5    6    7    8    9

*/

create temp table transition (
  pos int,
  roll int,
  next_pos int,
  universe_count int
);

with roll(roll, universe_count) as (
  values
    (3, 1),
    (4, 3),
    (5, 6),
    (6, 7),
    (7, 6),
    (8, 3),
    (9, 1)
)
insert into transition(pos, roll, next_pos, universe_count)
select
  pos,
  roll,
  case
    when pos + roll > 10 then pos + roll - 10
    else pos + roll
  end as next_pos,
  universe_count
from
  roll,
  lateral generate_series(1,10) as pos
;

-- With the transition table, simulating every game isn't so bad

with recursive game(turn, pos1, score1, pos2, score2, universe_count) as (
  select 0, 4, 0, 3, 0, 1::numeric

  union all

  (
    with prev as (
      select * from game
      where score1 < 21 and score2 < 21 and turn < 20
    ),
    next_game as (
      -- it's player 1's turn
      select
        prev.turn + 1 as turn,
        transition.next_pos as pos1,
        prev.score1 + transition.next_pos as score1,
        prev.pos2,
        prev.score2,
        prev.universe_count * transition.universe_count as universe_count
      from prev
      inner join transition on prev.pos1 = transition.pos
      where (prev.turn % 2) = 0

      union all

      select
        -- it's player 2's turn
        prev.turn + 1 as turn,
        prev.pos1,
        prev.score1,
        transition.next_pos as pos2,
        prev.score2 + transition.next_pos as score2,
        prev.universe_count * transition.universe_count as universe_count
      from prev
      inner join transition on prev.pos2 = transition.pos
      where (prev.turn % 2) = 1
    )
    -- the key to making this not explode: sum up the universe_count for games
    -- that have reached identical states
    select turn, pos1, score1, pos2, score2, sum(universe_count)
    from next_game
    group by 1,2,3,4,5
  )
),
winner as (
  select
    case
      when score1 >= 21 then 1
      when score2 >= 21 then 2
    end as player,
    universe_count
  from game
  where score1 >= 21 or score2 >= 21
),
winner_universe as (
  select player, sum(universe_count) as universe_count
  from winner
  group by 1
  order by 1
)
insert into answer(part, answer)
select 'part2', min(universe_count)
from winner_universe
;

-- Answers

select * from answer;
