;; I ended up writing part 2 in Fennel before I went back to SQL just to
;; confirm that I wasn't totally missing the point and there wasn't some kind
;; of math trick. This takes something like half a second to run on LuaJIT.

;;; utils

(fn map [f xs]
  (icollect [_ x (ipairs xs)]
    (f x)))

(fn tmax [xs]
  (accumulate [m nil
               _ x (ipairs xs)]
    (if (= nil m)
      x
      (math.max x m))))

(fn into! [xs ys]
  (each [_ y (ipairs ys)]
    (table.insert xs y))
  xs)

(fn find-idx [f xs idx_]
  (let [idx (or idx_ 1)
        x (. xs idx)]
    (if
      (= nil x) nil
      (f (. xs idx)) idx
      :else (find-idx f xs (+ idx 1)))))

(macro tupdate [tbl ...]
  (let [path [...]
        f (table.remove path)
        result* (gensym :result)
        tset-args [(unpack path)]]
    (table.insert tset-args result*)
      `(let [v# (. ,tbl ,(unpack path))
             f# ,f
             ,result* (f# v#)]
         (tset ,tbl ,(unpack tset-args)))))

;;; parsing and stringifying

(fn parse [line]
  (local fennel (require :fennel))
  (fn parse* [snail level]
    (match snail
      [a b] (into! (parse* a (+ level 1))
                   (parse* b (+ level 1)))
      ;; all snail numbers must have at least 1 pair, but we want to count
      ;; the first level as 0, so decrement level at the innermost level
      val [{:level (- level 1) :value val}]))
  (let [line* (string.gsub line "," " ")]
    (parse* (fennel.eval line*) 0)))

(fn ->str [n]
  (table.concat
    (icollect [_ {: level : value} (ipairs n)]
      (string.format "[%s]@%s" value level))
    " "))

;;; reduce

;; going with mutation since it's way easier

(fn reduce-explode! [snail-num left-idx]
  (let [left-pair (table.remove snail-num left-idx)
        right-pair (table.remove snail-num left-idx)]
    ;; replace with 0
    (table.insert snail-num left-idx {:level (- left-pair.level 1) :value 0})
    ;; explode out to left and right
    (when (< 1 left-idx)
      (tupdate snail-num (- left-idx 1) :value #(+ $ left-pair.value)))
    (when (< left-idx (length snail-num))
      (tupdate snail-num (+ left-idx 1) :value #(+ $ right-pair.value)))
    snail-num))

(fn reduce-split! [snail-num idx]
  (let [{: level : value} (table.remove snail-num idx)]
    (table.insert snail-num idx
                  {:level (+ level 1) :value (math.floor (/ value 2))})
    (table.insert snail-num (+ idx 1)
                  {:level (+ level 1) :value (math.ceil (/ value 2))})
    snail-num))


(fn reduce-step! [snail-num]
  (print (->str snail-num))
  (match (find-idx #(= 4 $.level) snail-num)
    explode-idx (values :explode (reduce-explode! snail-num explode-idx))
    _ (match (find-idx #(< 9 $.value) snail-num)
        split-idx (values :split (reduce-split! snail-num split-idx))
        _ (values :done snail-num))))

(fn snail-reduce! [snail-num]
  (match (reduce-step! snail-num)
    (:done _) snail-num
    (_ next-snail) (snail-reduce! next-snail)))

;;; addition and final magnitude

(fn snail-add [a b]
  (snail-reduce!
    ;; we need to pass a copy into snail-reduce! since it mutates the input
    (into! (map #{:level (+ 1 $.level) :value $.value} a)
           (map #{:level (+ 1 $.level) :value $.value} b))))

(fn magnitude [snail-num]
  (let [parts [(unpack snail-num)]] ; copy so we can mutate
    (while (< 1 (length parts))
      (let [max-level (tmax (map #$.level parts))
            idx (find-idx #(= max-level $.level) parts)
            right (table.remove parts (+ idx 1))]
        (tupdate parts idx #{:level (- $.level 1)
                             :value (+ (* 3 $.value)
                                       (* 2 right.value))})))
    (. parts 1 :value)))

;;; wiring it all up

(fn all-pairs [xs]
  (let [ret []]
    (each [_ x (ipairs xs)]
      (each [_ y (ipairs xs)]
        (when (not= x y)
          (table.insert ret [x y]))))
    ret))

(fn read-input [filename]
  (with-open [input (io.open filename)]
    (icollect [line (input:lines)]
      (parse line))))

(let [number-pairs (all-pairs (read-input :2021/day18.txt))]
  (print
    :part2
    (tmax
      (icollect [i [a b] (ipairs number-pairs)]
        (magnitude (snail-add a b))))))
