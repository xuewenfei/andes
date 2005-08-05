;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; interpret-equation.cl -- routines to handle getting interpretations of equations
;; Copyright (C) 2001 by <Linwood H. Taylor's Employer> -- All Rights Reserved.
;; Author(s):
;;  Linwood H. Taylor (lht) <lht@lzri.com>
;;  Collin Lynch (cl) <collinl@pitt.edu>
;; Modified:
;;  19 June 2001 - (lht) -- created
;;  12/6/2003 - (cl) -- fixing compiler warnings.
;;    1. Declared references to **dead-path-help**, **Forbidden-Help** and **Nogood-Help**
;;       in Interpret-equation to be special. 
;;    2. Declared references to **Premature-before-compo-eqn-help**, **Premature-subst-help**
;;       and **premature-entry-help** in get-premature-msg to be special.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
(defun interpret-equation (se		;student-entry
                           &optional (location 'equation)) ; vs 'answer if answer-box entry
  (declare (special **Dead-Path-Help** **Forbidden-Help** **Nogood-Help**))
  (sg-match-StudentEntry se) ;; fills in PossibleCInterps
  (let* ((interps (StudentEntry-PossibleCInterps se))
	 (correct-or-premature (find-all-correct-interpretations interps location))
	 (correct1 (find-most-cognitive-interpretation (car correct-or-premature)))
	 (premature1 (find-most-cognitive-interpretation (second correct-or-premature)))
	 (deadpath (find-all-interpretations 'dead-path interps))
	 (deadpath1 (find-most-cognitive-interpretation deadpath))
	 (forbidden (find-all-interpretations 'forbidden interps))
	 (forbidden1 (find-most-cognitive-interpretation forbidden))
	 (nogood (find-all-interpretations 'nogood interps))
	 (nogood1 (find-most-cognitive-interpretation nogood))
	 (shortest (find-most-cognitive-interpretation (get-all-interpretations interps)))
	 (result nil))
    (cond
     ((null interps)
      (setf (StudentEntry-CInterp se) nil)
      (format t "****HEY!!!! NO INTERPRETATIONS FROM ~W" se)
      (setf (StudentEntry-State se) **Incorrect**)
      (setf result (make-red-turn)))
     (correct1
      (setf (StudentEntry-CInterp se) correct1)
      (setf (StudentEntry-State se) **Correct**)
      (setf result (make-green-turn)))
     (deadpath1
      (setf (StudentEntry-CInterp se) deadpath1)
      (setf (StudentEntry-State se) **Dead-Path**)
      (setf result (chain-explain-more **Dead-Path-Help**)))
     (forbidden1
      (setf (StudentEntry-CInterp se) forbidden1)
      (setf (StudentEntry-State se) **Forbidden**)
      (setf result (chain-explain-more **Forbidden-Help**)))
     (premature1
      (setf (StudentEntry-CInterp se) premature1)
      ; changed to treat as correct, but with a warning message -- AW
      ;(setf (StudentEntry-State se) **Premature-Entry**)
      (setf (StudentEntry-State se) **Correct**)
      (setf result (get-premature-msg se))) ; now returns green + message turn
     (nogood1
      (setf (StudentEntry-CInterp se) nogood1)
      (setf (StudentEntry-State se) **NOGOOD**)
      (setf result (chain-explain-more **NOGOOD-Help**)))
     (t
      (format t "Don't know what to do with ~W~%" shortest)
      (setf (StudentEntry-CInterp se) shortest)
      (setf (StudentEntry-State se) **Correct**)
      (setf result (make-green-turn))))
    result))
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
(defun interpret-error (se) ;; student-entry
  (sg-match-StudentEntry se)
  (let* ((interps (StudentEntry-PossibleCInterps se))
	 (correct-or-premature (find-all-correct-interpretations interps))
	 (correct1 (find-most-cognitive-interpretation (car correct-or-premature)))
	 (premature1 (find-most-cognitive-interpretation (second correct-or-premature)))
	 (deadpath (find-all-interpretations 'dead-path interps))
	 (deadpath1 (find-most-cognitive-interpretation deadpath))
	 (forbidden (find-all-interpretations 'forbidden interps))
	 (forbidden1 (find-most-cognitive-interpretation forbidden))
	 (nogood (find-all-interpretations 'nogood interps))
	 (nogood1 (find-most-cognitive-interpretation nogood))
	 (shortest (find-most-cognitive-interpretation (get-all-interpretations interps))))
    (setf (StudentEntry-PossibleCInterps se) correct-or-premature)
    (cond
     ((null interps)
      (setf (StudentEntry-CInterp se) nil)
      (format t "****HEY!!!! NO INTERPRETATIONS FROM ~W" se)
      (setf (StudentEntry-State se) **Incorrect**))
     (correct1
      (setf (StudentEntry-CInterp se) correct1)
      (Tell :interpret-error "correct ~W" (StudentEntry-CInterp se))
      (setf (StudentEntry-State se) **Correct**))
     (deadpath1
      (setf (StudentEntry-CInterp se) deadpath1)
      (Tell :interpret-error "deadpath ~W" (StudentEntry-CInterp se))
      (setf (StudentEntry-State se) **Dead-Path**))
     (forbidden1
      (setf (StudentEntry-CInterp se) forbidden1)
      (Tell :interpret-error "Forbidden ~W" (StudentEntry-CInterp se))
      (setf (StudentEntry-State se) **Forbidden**))
     (premature1
      (setf (StudentEntry-CInterp se) premature1)
      (Tell :interpret-error "premature ~W" (StudentEntry-CInterp se))
      (setf (StudentEntry-State se) **Premature-Entry**))
     ;;(prematures1
     ;; (setf (StudentEntry-CInterp se) prematures1)
     ;; (Tell :interpret-equation "premature subst ~W" (StudentEntry-CInterp se))
     ;; (setf (StudentEntry-State se) **Premature-Subst**))
     (nogood1
      (setf (StudentEntry-CInterp se) nogood1)
      (Tell :interpret-equation "no good ~W" (StudentEntry-CInterp se))
      (setf (StudentEntry-State se) **NOGOOD**))
     (t
      (setf (StudentEntry-CInterp se) shortest)
      (Tell :interpret-error "Unknown ~W" (StudentEntry-CInterp se))
      (setf (StudentEntry-State se) **Incorrect**)))
    ;;(setf (ErrorEntry-Intended ee) se)
    (Tell :interpret-error "!! ~W" (StudentEntry-CInterp se))))
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
(defun find-all-interpretations (name interps)
  (let ((result nil))
    (dolist (obj interps)
      (if (equal name (car obj))
	  (setf result (append result (list (cdr obj))))))
    result))
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; New constraint-based prematurity checking for equation entries:
;;
;; Naming conventions used in this section:
;;  eqn = eqn struct used in problem equation index
;;  syseqn = system entry struct for an equation
;;  eqinfo = equation type information struct in ontology
;;  interp = an interpretation = plain list of syseqn's w/o correctness tag
;;  cinterp = candidate interp, car is correctness tag, cdr is interp


;; predicates of eqns (equation index entries):
(defun major-eqn-p (eqn)
"true if eqn struct represents a major principle" ; includes many that are definitions
   (let ((eqinfo (lookup-expression->equation (eqn-exp eqn))))
	 (and eqinfo (eq (equation-complexity eqinfo) 'major))))

(defun definition-eqn-p (eqn)
"true if eqn struct represents a definition"
   (let ((eqinfo (lookup-expression->equation (eqn-exp eqn))))
	 (and eqinfo (eq (equation-complexity eqinfo) 'definition))))

(defun compo-eqn-p (eqn)
"true if eqn struct represents a component-form vector equation"
   (eq (first (eqn-exp eqn)) 'compo-eqn))

(defun given-eqn-p (eqn)
"true if eqn struct specifies a given value equation"
   (eq (eqn-type eqn) 'given-eqn))

(defun eqn-English (eqn)
"return English name for eqn index entry, NULL if not found."
   ; wrong way to do it:
   ;(let ((eqinfo (lookup-expression->equation (eqn-exp eqn))))
   ;    (when eqinfo (equation-English eqinfo)))
   (nlg-equation (eqn-exp eqn)))

; We want to allow implicit removal of zero values at any time, so we 
; remove var=0 equations from interpretations before further testing 
; for illicit combinations. 
; Following tests whether equation sets a value to zero.
; Note this doesn't care whether the zero value is "given" or not.
; This also doesn't propagate "obviously" inherited zero values, e.g
; v = 0 GIVEN, KE = 0.5*m*v^2   => KE = 0
; h = 0 GIVEN, Ug = m*g*h => Ug = 0

(defun zero-eqn-p (eqn)
"true if eqn assigns zero to a variable"
  (let ((lhs (second (eqn-algebra eqn)))
        (rhs (third (eqn-algebra eqn))))
   (and (symbolp lhs)         
        (or (and (dimensioned-numberp rhs)   ; in kb/physics-funcs.cl
	         (= (second rhs) 0))
            (and (numberp rhs) 
                 (= rhs 0))))))

; We also want to allow most substitutions of equivalent variables licensed
; by "allowed" identity equations. Note an identity may come out
; (= netWork (+ W1)) if rhs is sum that has only one arg in this problem, and
; we want to allow that in this case.  More complicated forms that could 
; simplify to identities are not detected here.  (Ex: Kirchoff's Loop rule 
; for a simple circuit with one battery and one resistor) Probably OK,
; if the form is not simple A = B, probably want to require explicit.
(defun identity-eqn-p (eqn)
"true if eqn is an identity"
   (let ((lhs (second (eqn-algebra eqn)))
         (rhs (third (eqn-algebra eqn))))
     (and (symbolp lhs)        ; V1 = 
          (or (symbolp rhs)    ;      V2
              (and (listp rhs) ; or   (+ V2)
	           (= (length rhs) 2)
		   (eq (first rhs) '+)
		   (symbolp (second rhs)))))))


(defun combinable-identity-p (eqn)
"true if eqn is an identity allowed to be combined"
  (and (identity-eqn-p eqn)
       (not (required-identity-p eqn)))) ; in ontology.cl


; map sysentries to eqn:
(defun syseqn->eqn (syseqn)
"return eqn info for given system equation entry in current problem"
 (match-systementry->eqn SysEqn (problem-eqnindex *cp*)))

(defun given-eqn-entry-p (syseqn)
"true if system equation entry is step of writing a given equation"
  (given-eqn-p (syseqn->eqn syseqn)))

(defun syseqn-English (syseqn)
"map system equation to its English string name"
   (eqn-English (syseqn->eqn syseqn)))

; for dealing with interpretations = sets of syseqns:
(defun get-nonzero-eqns (interp)
"return list of non-zero equations in interp"
   (remove-if #'(lambda (syseqn) 
                  (zero-eqn-p (syseqn->eqn syseqn)))
	      interp))

; Identities and zero equations will be dubbed "trivial". User may
; permissibly combine them with fundamental equations in their heads,
; to drop obviously zero terms or use equivalent variables.
; Following gets all the other equations in an interp after these
; "trivial" (i.e. allowed to be combined) eqns are removed.
; Note this function is used by grading tests to detect required eqns.
(defun trivial-syseqn-p (syseqn)
   (or (zero-eqn-p (syseqn->eqn syseqn))
       (combinable-identity-p (syseqn->eqn syseqn))))

(defun get-nontrivial-eqns (interp)
   (remove-if #'trivial-syseqn-p interp))

; We will now allow equations marked "definitions" to be combined with principles.
; This is intended for the small number of definitions used in conservation laws,
; so that e.g., conservation of energy can be written out in terms of definition of 
; kinetic and potential energy, or not. 
; Note: This could lead to problems if many equations are tagged as definitions. 
; Note also: this allows substitutions of definitions into other principles,
; e.g. substituting 2*KE/m for vf^2 in vf^2 = v0^2 + 2*a*d. But this is unlikely to
; arise since kinetic energy will not be mentioned in the solution to such a problem.
;
; This is distinct from "trivial" equation predicate above since definitions are not "trivial". 
; Not clear if this matters -- depends on how "trivial-syseqn-p" is used by grading system.
(defun combinable-syseqn-p (syseqn)
   (or (trivial-syseqn-p syseqn)
       (definition-eqn-p (syseqn->eqn syseqn))))
     
(defun get-noncombinable-eqns (interp)
    (remove-if #'combinable-syseqn-p interp))

; Test whether a given system equation entry has been entered explicitly
; Look for a studententry with a singleton interpretation equal to this
; system entry or combined acceptably with others, e.g. combined with zero 
; givens so as to drop zero-valued terms from eqns.
(defun explicit-entry-of (studEntry syseqn)
"true if given studEntry is explicit (enough) entry of syseqn"
   (let ((interp (StudentEntry-Cinterp studEntry)))
     (and (member syseqn interp :test #'equal)
	  (or ; or only others are combinable equations 
	      (null (get-noncombinable-eqns (remove syseqn interp :test #'equal)))
	      ; or it combines given magnitude with projection 
              (and (given-eqn-entry-p syseqn)
	           (allowed-compo-mag-combo interp))))))

(defun studEqnEntry-p (studEntry)
"true if given student entry is an equation entry"
   (eq 'eqn (first (StudentEntry-Prop studEntry))))

(defun entered-explicitly (syseqn &optional (EntryList *StudentEntries*)) 
"true if syseqn is explicitly entered somewhere in given set of entries (default all entries)"
  (some #'(lambda (studEntry) 
            (or (explicit-entry-of studEntry syseqn)
		; also check among dangling entries for given equations
	        (some #'(lambda (ge) (explicit-entry-of ge syseqn))
		      (studentEntry-GivenEqns studEntry))))
        EntryList))

; might want this instead, if we care about order of solution equations:
(defun entered-explicitly-before (syseqn N)
"true if syseqn is explicitly entered in student entries before eqn N"
    (entered-explicitly syseqn (eqn-entries-before N)))

; Equation entries not necessarily in order in *StudentEntries* so have
; to filter out all equation entries with indices (=ids) < N 
(defun eqn-entries-before (N)
"return list of student equation entries before eqn N"
   (remove-if-not #'(lambda (studEnt)
	                   (and (numberp (StudentEntry-Id studEnt)) ; only equation entries
			        (< (StudentEntry-ID studEnt) N)))
	          *StudentEntries*))


; For use when detecting premature substitution of numerical values:
; Instructors also want to allow implicit combination of given magnitudes magV = K units
; with projection equation V_x = V cos (N deg - M deg) to get V_x = +/- K units in case where
; vector lies along an axis.  Here we use a cheap but easy-to-code test which just allows 
; *any* combination of a given vector magnitude and any projection equation.  This will 
; miss constraint violation where they have used value of sin or cos function to get a 
; component value from a magnitude.  It is unlikely they will do this in their heads, 
; though some might use a calculator.  It's tolerable if we miss some violations as long 
; as we allow what needs to be allowed.

(defun given-mag-eqn-p (eqn)
"true if eqn states given value of a vector magnitude"
   (and (given-eqn-p eqn)
	; eqn-exp for given-eqns is quantity expression
        ; look for (at (mag (...)) ?t)
	(and (eq (first (eqn-exp eqn)) 'at)
             (eq (first (second (eqn-exp eqn))) 'mag)))) 

(defun projection-eqn-p (eqn)
"true if eqn is a projection"
    (or (eq (first (eqn-exp eqn)) 'projection) ; as sub-equation within a vector psm
        (eq (first (eqn-exp eqn)) 'proj)))     ; as psm-level eqn in compo-form solution
     
(defun allowed-compo-mag-combo (interp)
"true if interp is allowed combination of projection along axis and given magnitude value"
  (and (= (length interp) 2)
       (some #'(lambda (syseqn) 
                   (given-mag-eqn-p (syseqn->eqn syseqn)))
	     interp)
       (some #'(lambda (syseqn) 
                   (projection-eqn-p (syseqn->eqn syseqn)))
	     interp)))


; the prematurity constraints: 

; premature substitution of givens:
; Note that even after student fixes by replacing numbers with variables,
; symbolic equation may still involve combination of fundamental equations.
; This doesn't depend on whether non-given equation combined with is major or not, 
; so effectively it is treating given equations like required-explicit principles,
; requiring them to be entered explicitly by themselves, but for few exceptions.
(defun is-premature-substitution-p (interp)
"true if interp combines non-zero given values with a non-entered equation"
 (let ((nz-eqns (get-nonzero-eqns interp)))
  (and (some #'given-eqn-entry-p nz-eqns)
       (some #'(lambda (syseqn)
                   (and (not (given-eqn-entry-p syseqn))
		        (not (entered-explicitly syseqn))))
	     nz-eqns)
       (not (allowed-compo-mag-combo interp)))))

;; Premature combination of equations:
;; We treat compo-form vector equations separately from other major equations
;; only so we can give a variant message that explicitly mentions component form
;; (Student may have written a true symbolic equation using only magnitudes, e.g.
;; so we want hint to remind them what is required for book form vector principles.)
;; Note: must test for this *first* because more general subsequent test
;; will also succeed on compo-form vector equations
;; Note: test is order-independent, only requires that fundamental equation exist
;; *somewhere* in their solution. 

(defun is-premature-before-compo-eqn-p (interp)
"true if interp combines non-explicitly-entered vector compo eqn with non-trivial eqn"
  (let ((nz-eqns (get-noncombinable-eqns interp)))
    (and (cdr nz-eqns)  ;; more than 1 eqn left in interp
         (some #'(lambda (syseqn)
		     (and (compo-eqn-p (syseqn->eqn syseqn))
			  (major-eqn-p (syseqn->eqn syseqn))
                          (not (entered-explicitly syseqn))))
	        nz-eqns)))) 

(defun is-premature-before-major-eqn-p (interp)
"true if interp combines non-explicitly-entered major eqn with non-trivial eqn"
  (let ((nz-eqns (get-noncombinable-eqns interp)))
    (and (cdr nz-eqns)  ; more than 1 eqn left in interp
         (some #'(lambda (syseqn)
		     (and (major-eqn-p (syseqn->eqn syseqn))
                          (not (entered-explicitly syseqn))))
	       nz-eqns)))) 

(defun get-needed-eqns (interp)
"return list of systentries for major eqns in interp not entered explicitly"
 (remove-if-not #'(lambda (syseqn)
                     (and (major-eqn-p (syseqn->eqn syseqn))
                          (not (entered-explicitly syseqn))))
                (get-noncombinable-eqns interp))) 

(defun get-needed-eqn-names (interp)
"return list of English forms for missing explicit eqns in interp"
  (mapcar #'syseqn-English (get-needed-eqns interp)))

;; switch -- whether to enforce prematurity constraints on equations
(defvar **Check-Eqn-Constraints**  T) ; off until we work them out


(defparameter **premature-predicates** '(
    ; For now, disable premature substitution, just test explicitness
    ; NB: must also comment out of get-premature-msg
    ;is-premature-substitution-p
    is-premature-before-compo-eqn-p
    is-premature-before-major-eqn-p
 ))

(defun is-premature-p (interp)
"true if interp is premature according to some test in **premature-predicates**"
(and **Check-Eqn-Constraints**
      (some #'(lambda(predicate) 
                 (apply predicate (list interp)))
             **premature-predicates**)))

(defun find-all-correct-interpretations (cinterps &optional (location 'equation))
"collect correct interpretations, splitting out those violating prematurity constraints"
; returns pair of (correct-list premature-list), each element a list of interps
 (let ((correct-result nil)
	(premature-result nil))
    (dolist (cinterp cinterps)
      (when (equal 'correct (car cinterp))
	 (if (and (eq location 'equation) ; don't test on answer box entries
	          (is-premature-p (cdr cinterp)))
	     (setf premature-result (append premature-result (list (cdr cinterp))))
           (setf correct-result (append correct-result (list (cdr cinterp)))))))
    ;(when correct-result (format t "Correct Interpretations:~%~W~%" correct-result))
    ;(when premature-result (format t "~%Correct but Premature:~%~W~%" premature-result))
    (list correct-result premature-result)))

; !! Might want a special message for premature answer entries to the effect
; that not all work has been shown yet.

; ! Urg, we must run tests *again* after interpretation choice to fetch message. Should 
; recode to be able to associate msg with entry at time we detect constraint violoation.
; Last hint lists principle(s) that should be explicit, so students get
; some idea of what we're looking for.

(defun get-premature-msg (se)
  "return appropriate hint sequence for equation entry interpreted as premature"
  ; some message text in HelpMessages.cl
  (declare (special **Premature-subst-help** **premature-entry-help**))
 ; (assert (eq (studententry-state se) **Premature-Entry**))
 (let* ((interp (studententry-cinterp se))
        (missing (get-needed-eqn-names interp)))
  (cond 
    ; For now, don't test premature substitution
    ; ((is-premature-substitution-p interp)
    ;    (chain-explain-more-green **Premature-Subst-help**))
    ; if missing exactly one and its a compo equation, mention component form in case that is their problem.
    ; !!! actually could give this message whenever *all* missing are compo-eqns
    ((and (null (cdr missing)) 
          (is-premature-before-compo-eqn-p interp)) 
       (chain-explain-more-green (list 
	   (format NIL "Although equation ~A is correct, you have not displayed a fundamental vector principle being used in component form on a line by itself." (1+ (studentEntry-ID se)))
           "It is good practice to identify the fundamental vector principles you are using by writing them purely symbolically in component form before combining them with other equations or given values. Select \"Review Physics Equations\" on the Help menu to view a list of principles and their standard forms."
	   (format NIL "A good solution would show the following in component form: ~A~{, ~A~}" (car missing) (cdr missing)))))
       
    (missing ; better have at least one missing to mention
       (chain-explain-more-green 
         (list 
          (format NIL "Although equation ~A is correct, you have not displayed a fundamental principle being used in symbolic form all by itself." (1+ (studentEntry-ID se)))
           "It is good practice to identify the fundamental principles you are using by writing them purely symbolically in standard form before combining them with other equations or given values. Select \"Review Physics Equations\" on the Help Menu to view  a list of principles and their standard forms."
	  (format NIL "A good solution would show the following in standard form: ~A~{, ~A~} " (car missing) (cdr missing)))))
       
    (T ; didn't find missing! shouldn't happen
       (format T "get-premature-msg called but couldn't find missing equations!~%")
       (make-green-turn)))))


;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
(defun calculate-cognitive-load (interps)
  (let ((sum 0))
    (dolist (obj interps)
      (if (SystemEntry-p obj)
	  (setf sum (+ sum (SystemEntry-CogLoad obj)))))
    sum))

(defun find-most-cognitive-interpretation (interps)
  (if (consp interps)
      (let* ((result (car interps))
	     (load (calculate-cognitive-load result)))
	(dolist (obj interps)
	  (let ((newload (calculate-cognitive-load obj)))
	    (cond
	     ((< newload load)
	      (setf load newload)
	      (setf result obj)))))
	result)
    interps))
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
(defun get-all-interpretations (interps)
  (let ((result nil))
    (dolist (obj interps)
      (setf result (append result (list (cdr obj)))))
    result))
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
(defun chain-explain-more (messages)
  (if messages
      (if (= (length messages) 1)
	  (make-dialog-turn (first messages) nil)
	(make-dialog-turn (first messages) 
			  'explain-more
			  :responder
			  #'(lambda (response)
			      (if (equal response 'explain-more)
				  (chain-explain-more (rest messages))))))))
	
; build a color-green turn with given message list
(defun chain-explain-more-green (messages)
  (if messages
      (if (= (length messages) 1)
	  (make-green-dialog-turn (first messages) nil)
	(make-green-dialog-turn (first messages) 
			  'explain-more
			  :responder
			  #'(lambda (response)
			      (if (equal response 'explain-more)
				  (chain-explain-more (rest messages))))))))
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; end of interpret-equation.cl
;; Copyright (C) 2001 by <Linwood H. Taylor's Employer> -- All Rights Reserved.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
