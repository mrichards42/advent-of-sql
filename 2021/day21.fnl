(local {: view} (require :fennel))

(fn mk-die []
  (var last-roll 0)
  (fn []
    (match last-roll
      100 (set last-roll 1)
      _ (set last-roll (+ last-roll 1)))
    last-roll))

(var p1 {:score 0 :pos 4})
(var p2 {:score 0 :pos 8})
(var turn 0)
(var rolls 0)
(local die (mk-die))

(fn next-space [{: pos} roll]
  (let [spaces (% roll 10)
        ret (+ pos spaces)]
    (if (<= ret 10)
      ret
      (- ret 10))))

(while (and (< p1.score 1000) (< p2.score 1000))
  (print (view {: turn : rolls : p1 : p2}))
  (let [roll (+ (die) (die) (die))]
    (set rolls (+ 3 rolls))
    (if (= 0 (% turn 2))
      (let [pos (next-space p1 roll)]
        (set p1 {:score (+ p1.score pos) :pos pos}))
      (let [pos (next-space p2 roll)]
        (set p2 {:score (+ p2.score pos) :pos pos})))
    (set turn (+ 1 turn))))
