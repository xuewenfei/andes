;;; script for regenerating all problem files
;;; grep minutes make-prbs.log | sort -g -k7
;;;  ls solutions/*.prb | sed "s/solutions\/\(.*\).prb/\1/"
;;; sbcl < make-prbs.cl >& make-prbs.log &
 (rkb)
 (defvar t0 (get-internal-run-time))
  (make-prbs '(dr2a dr2b dr3a dr4a dr5a dr6a dr6b dr7a dt2a dt3c momr3a s1c s1f)
)
;; time to do this is:
(format t "~F hours~%" (/ (- (get-internal-run-time) t0) 
			  (* 3600 internal-time-units-per-second)))
(quit)

