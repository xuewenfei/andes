;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Newtons2 -- Andes2 Physics problem solving operators
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ============== Top-level search support ===================
  
;; The top-level search for a solution is driven externally by the 
;; "Bubble Graph" generator written in Lisp. It aims to build a network
;; of quantities and applicable equations containing them that may be 
;; searched to find sets of equations sufficient to solve for the problem 
;; sought(s).  In the course of this process the bubble graph generator 
;; repeatedly invokes the problem solver as a subroutine whenever it needs 
;; to generate an an equation containing a given quantity (top-level sought or
;; intermediate sought). The problem solver then uses the KB operators to 
;; generate an applicable equation containing the requested quantity.
;; 
;; Each invocation of the problem solver applies one problem solving method 
;; (psm) to generate one result equation for a single sought quantity (although
;; subsidiary equations may be written as well.) No problem solver
;; state persists across invocations, so each invocation is entirely 
;; independent of any other. 
;; 
;; The Bubble-Graph generator invokes the problem-solver code to achieve a
;; top-level goal of applying a psm to generate an equation for
;; a sought quantity. This goal is represented by a proposition of the 
;; form (psm ?sought ?eqn-id ?eqn ?remaining-unknowns), with ?sought
;; bound to a quantity term coming in. Thus this goal represents the
;; main top-level entry point into the problem solver.
;;
;; The operators for applying specific psms should result in a statement of
;; the form (psm-applied ?sought ?eqn-id ?eqn-algebra) in wm. These
;; operators do the real psm-specific work of generating an equation.
;; The following operator encapsulates the common bookkeeping needed to
;; finish up the psm application after some equation has been so generated.
;; It posts the final psm statement the top-level driver keys on.
;; It does the following:
;;
;; 1. Sometimes a psm might get applied and generate an equation which does not
;; actually contain the sought quantity. This can happen because the 
;; applicability tests for some psms check only that the equation *might* 
;; contain the sought quantity.  A test here fails in these cases. Since the 
;; final psm statement is never posted, these blind alleys don't make it into 
;; the solution at all.
;;
;; 2. Here is common code to collect the residual unknowns from the equation 
;; for inclusion in the final "psm" statement as a service to the bubble-graph
;; generator.
;;
;; 3. Some vars in the equation such may become known as a side effect of 
;; applying the psm. For example, vector direction variables typically become 
;; known as the vectors are drawn by the relevant operators. In this case the
;; operator should add a "given" statement for them to wm since they are
;; now like the givens in not needing to be sought. ("given" is being
;; used to mean "known").  We write equations for all these new knowns here 
;; since these equations are required for algebraic completeness.
;;
;; Some of these equations correspond to steps the student will have to write; 
;; others, in particular those for angles of drawn vectors, need not be
;; written by the student although they may be. Issues pertaining to writing
;; equations for givens may have to be worked out later. For now we declare 
;; this operator unordered so that the given equation steps may occur in
;; any order with respect to the other steps.
;;
;; The hints pertaining to the top-level search for a solution must be
;; handled specially, because they should be questions: "What
;; quantity are you seeking?" and "What method should be used to find
;; it?"  These questions comprise the preamble discussed in the
;; proposal. The specification document works out how the preamble
;; will be generated from the bubble graph.  Thus, there are no hints on 
;; operators that exist to support this top-level search.

(defoperator find-by-psm (?sought ?eqn-id)
  :preconditions (
  	; save initially known quants for detecting changes below
	; This is initial givens plus quantities given as parameters
	(setof (in-wm (given ?quant ?dont-care))
	       ?quant ?initial-givens)
	(setof (in-wm (parameter ?quant ?dont-care))
	        ?quant ?parameters)
	(bind ?initial-knowns (union ?initial-givens ?parameters 
	                             :test #'equalp))
	
	; Main step: apply a psm to generate an equation for sought.
	(psm-applied ?sought ?eqn-id ?eqn-algebra)

	; collect list of quantities in the equation. Ignore predefined
	; constants like pi that don't need to be solved for
	(map ?v (remove-if #'physconstp (vars-in-eqn ?eqn-algebra))
	       (in-wm (variable ?v ?q))
               ?q ?quantities-in-eqn)
	; make sure sought quantity actually occurs in equation
	(test (member ?sought ?quantities-in-eqn :test #'equalp))

	; Some quantities in eqn may have become "given" -- known -- as side 
	; effects of applying the psm. Here we call them the new-knowns.
	; We get what's known now and figure out what's changed.
    	(setof (in-wm (given ?quant ?dont-care))
	        ?quant ?given-now)
	(bind ?known-now (union ?given-now ?parameters :test #'equalp))
	(bind ?new-knowns
	      (set-difference ?known-now ?initial-knowns :test #'equalp))
	; (debug "Made known inside psm: ~A~%" ?new-knowns)
	; Although the bubble driver won't have to seek them, for algebraic 
	; completeness we must put out equations giving values for 
	; the new-knowns. Could also do this at all the points they become 
	; known but it's simpler to have one bit of code to do this.
	; we distinguish them as implicit equations since the student will
	; not have to write them. The algebra module still needs them.
	(foreach ?quant ?new-knowns
	    (implicit-eqn ?new-eqn ?quant))

	; Collect residual unknowns from eqn to include in the final psm stmt 
	; This is a convenience to bubble-graph search driver, which will
	; see the equation and can easily get its variables but finds it 
	; inconvenient to map the variables to quantities.  Used to be:
    	; (bind ?new-unknowns
	;      (set-difference ?quantities-in-eqn ?known-now :test #'equalp))
        ; But removing problem givens and parameters is no longer wanted. Driver
	; now pre-enters problem givens and parameters into the graph before
	; calling solver to find soughts, so now wants them included in order 
	; to know to link nodes for these quants to this equation. Since 
	; givens and parameters are flagged known the driver won't seek them.  
	; We do exclude the quantities known by side effect since they 
	; shouldn't go into the bubble-graph. We get these by looking for
	; quantities for which implicit equations were written, either above
	; or in the operators -- for given vector dirs it happens in operators
	(setof (in-wm (implicit-eqn (= ?var (dnum . ?valunits)) ?imp-eq-quant))
	      ?imp-eq-quant ?imp-eq-quants)
	(bind ?new-unknowns 
	      (set-difference ?quantities-in-eqn ?imp-eq-quants :test #'equalp))
	)
  :effects
   	((psm ?sought ?eqn-id ?eqn-algebra ?new-unknowns)))


;;; =================== applying a scalar equation=================
;;; This is a generic "driver" operator for finding a problem solving 
;;; method (PSM) consisting of scalar equation containing the sought 
;;; quantity then writes the equation.  Whenever an author wants to define 
;;; a new scalar equation, such as speed=distance/duration, the author must 
;;; define operators for both the eqn-contains goal, which indicate which
;;; quantities are contained in the equation, and the eqn goal, which
;;; represents writing the equation on the Andes user interface.
;;; Because the reasoning done by this operator is covered by the
;;; preamble, it has no hints.

(defoperator apply-scalar-psm (?sought ?eqn-id)
   :specifications "If the goal is to apply a psm to find a quantity,
      and there is a scalar equation  that contains that quantity,
      then generate the equation."
   :preconditions (
      (eqn-contains ?eqn-id ?sought)
      ; make sure psm name not on problem's ignore list:
      (test (not (member (first ?eqn-id) (problem-ignorePSMS *cp*))))
      (not (eqn ?dont-care ?eqn-id))
      (debug "~&To find ~a,~%  will try writing ~a~%" ?sought ?eqn-id)
      (eqn ?eqn-algebra ?eqn-id)
      (debug "~&To find ~a via ~a, ~%   wrote ~a~%"
	     ?sought ?eqn-id ?eqn-algebra)
   )
   :effects
   ((psm-applied ?sought ?eqn-id ?eqn-algebra)))

;; For use by the help system, we need to indicate the difference between 
;; fundamental equations and derived equations that result from combinations 
;; of the fundamental equations.  This is done by the choice of "eqn" or
;; "derived-eqn" proposition. The following variant of "apply-scalar-psm"
;; searches for scalar psm's that result in derived eqns, rather than 
;; fundamental equations. (Currently this is only the net-work psm). These 
;; psms should post a derived-eqn-contains statement instead of eqn-contains.
(defoperator apply-scalar-psm2 (?sought ?eqn-id)
   :specifications "If the goal is to apply a psm to find a quantity,
      and there is a scalar equation  that contains that quantity,
      then generate the equation."
   :preconditions (
      (derived-eqn-contains ?eqn-id ?sought)
      ; make sure psm name not on problem's ignore list:
      (test (not (member (first ?eqn-id) (problem-ignorePSMS *cp*))))
      (not (derived-eqn ?dont-care ?eqn-id))
      (debug "~&To find ~a,~%  will try writing ~a~%" ?sought ?eqn-id)
      (derived-eqn ?eqn-algebra ?eqn-id)
      (debug "~&To find ~a via ~a, ~%   wrote ~a~%"
	     ?sought ?eqn-id ?eqn-algebra)
   )
   :effects
   ((psm-applied ?sought ?eqn-id ?eqn-algebra)))

;;; ================== entering givens =============================
;;; This operator corresponds to the step of entering an "assignment
;;; statement" equation for given values. Note there may be 
;;; prerequisite steps for defining the required variable; for example, 
;;; if the quantity is a vector magnitude the vector would have to be drawn.
;;;
;;; Since the main top-level driver never searches for ways to determine givens,
;;; there is currently no problem-solving goal in the main search that will 
;;; cause this operator to be invoked. As a separate step, the top-level 
;;; driver can invoke the problem solver to achieve the goal of writing an 
;;; equation for each of the givens.  The top-level has to go through the
;;; solver for this simple step because the operators encode the knowledge 
;;; of how to define the variables.
;;;

(defoperator write-known-value-eqn (?quantity)
  :specifications "If a quantity's value is known, then define a variable for it
    and write an equation giving its value"
  :preconditions 
  ((in-wm (given ?quantity ?value-expr))
					; Make sure expression is usable in equation, not special atom. 
					; Assume if a list its an algebraic expression
   (test (or (numberp ?value-expr) (listp ?value-expr)))
   (variable ?var-name ?quantity))
  :effects 
  ((given-eqn (= ?var-name ?value-expr) ?quantity))
  :hint
  ((point (string "You can find the value of ~A in the problem statement." ?quantity))
   (point (string "The value of ~A is given as ~A." ?quantity (?value-expr algebra)))
   (bottom-out (string "Enter the equation ~A = ~A." (?var-name algebra) (?value-expr algebra)))
   ))

;; This variant handles the case where the known value is a z-axis direction
;; specified by special atom 'into or 'out-of 
;; For purposes of equation, we convert it to a phi angle with the z-axis 
;; of zero or 180 degrees. The phi angle is used in writing projections.
(defoperator write-known-zdir-eqn (?vector ?t)
  :preconditions
  (
   (in-wm (given (at (dir ?vector) ?t) ?dir))
   (test (and (z-dir-spec ?dir)
	      (not (equal ?dir 'z-unknown))))
					; ? use in-wm for variable here ?
   (variable ?var-name (at (dir ?vector) ?t))
   (bind ?dir-degrees (if (equal ?dir 'into) 180 0))
   )
  :effects 
  ((given-eqn (= ?var-name (dnum ?dir-degrees |deg|)) (at (dir ?vector) ?t)))
  :hint
  ((point (string "You know the numerical direction of ~A." ?vector))
   (point (string "The numerical direction of ~A is ~A deg." ?vector ?dir-degrees))
   (teach (string "For algebraic purposes, the direction of ~A is represented numerically as the angle it makes with the z-axis. This will be 0 deg if the vector points out of the plane and 180 deg if it points into the plane." ?vector))
   (bottom-out (string "Enter the equation ~A = ~A deg." (?var-name algebra) ?dir-degrees))
   ))

;; following variants write implicit equations for quantities like vector
;; directions or zero-magnitudes that become known as side-effects of 
;; other steps. We don't attach hints to these since we don't want the help system
;; to prompt the student to enter them explicitly. They have to be printed out
;; as equations however for algebraic completeness of the set sent to algebra.
(defoperator write-implicit-eqn (?quantity)
  :specifications "If a quantity's value becomes known as a side effect of some other step, then define a variable for it and write an equation giving its value"
  :preconditions 
  ((in-wm (given ?quantity ?value-expr))
					; Make sure expression is usable in equation, not special atom. 
					; Assume if a list its an algebraic expression
   (test (or (numberp ?value-expr) (listp ?value-expr)))
					; variable should already be defined 
   (in-wm (variable ?var-name ?quantity))) 
  :effects 
  ((implicit-eqn (= ?var-name ?value-expr) ?quantity)))

;; This variant handles the case where the known value is a z-axis direction
;; specified by special atom 'into or 'out-of 
;; For purposes of equation, we convert it to a phi angle with the z-axis 
;; of zero or 180 degrees. The phi angle is used in writing projections.
(defoperator write-implicit-zdir-eqn (?vector ?t)
   :preconditions (
     (in-wm (given (at (dir ?vector) ?t) ?dir))
     (test (and (z-dir-spec ?dir)
	        (not (equal ?dir 'z-unknown))))
     ; variable should already be defined
     (in-wm (variable ?var-name (at (dir ?vector) ?t)))
     (bind ?dir-term (zdir-phi ?dir))
   )
   :effects (
     (implicit-eqn (= ?var-name ?dir-term) (at (dir ?vector) ?t))
   ))

;;; ================== applying vector equations ===================
;;; These operators are the second of the two main top level methods for
;;; finding a value for a variable.  They apply vector equations.
;;; The major steps are to draw a vector diagram, write the component
;;; equation, find expressions for each of the components, then write
;;; the final equation which is free of component variables.
;;; 
;;; The component equation is an equation where all the vector
;;; components are expressed in terms of component variables.  The
;;; component-free variable replaces each of the component variables
;;; with an algebraic expression.  The equations of the form
;;; <compo-var>=<expression> are called projection equations.
;;; 
;;; The author of a vector psm, such as Newton's law or Kinematics, must define
;;; operators for
;;; 
;;; *  vector-psm-contains -- indicates which quantities might be found with this
;;; *  vector-diagram -- procedure for drawing the appropriate diagram
;;; *  compo-eqn-contains -- which quantities various component eqns find
;;; 
;;; This operator takes care of the rest of the job of applying
;;; the vector equation.  
;;; 
;;; Kinematics is treated as one vector psm even though it has 5
;;; different component equations that can be used with it, all of
;;; which reference the same vector diagram.  This means that no
;;; matter which of the 5 equations the student will eventually write,
;;; the student must first draw all the kinematic vectors.  Hope this
;;; is OK with the instructors.
;;; 
;;; Because the reasoning done by these opearors is covered by the
;;; preamble, they have no hints.

(defoperator apply-vector-psm (?sought ?eq-args) 
   :specifications " If the goal is to apply a psm to find a quantity,
      and there is a vector equation that contains that quantity,
      then
      draw the vector diagram (including the axis),
      find a component equation that contains the quantity,
      generate the component equation, 
      and generate a component-free equation"
   :preconditions (
      ; This chunks projections so they don't appear at the bubble-graph level
      ; so don't use it if component-form solution is wanted (see below).
      (not (component-form)) 
      (vector-psm-contains ?vec-eqn-id ?sought)
      ; make sure psm name not on problem's ignore list:
      (test (not (member (first ?vec-eqn-id) (problem-ignorePSMS *cp*))))
      (debug "~&To find ~a,~%   drawing vectors ~a.~%" ?sought ?vec-eqn-id)
      (vector-diagram ?vec-eqn-id)
      (debug "Vectors drawn for ~a.~%" ?vec-eqn-id)
      (compo-eqn-selected ?vec-eqn-id ?sought (compo-eqn . ?eq-args))
      (debug "Start compo eqn ~a ~%  for ~a~%" ?eq-args ?sought)
      (eqn ?compo-eqn (compo-eqn . ?eq-args))
      ;; (assume (eqn-written (compo-eqn . ?eq-args)))
      (debug "Wrote compo eqn ~a. ~%" ?compo-eqn)
      (debug "   start compo-free eqn ~a~%" ?eq-args)
      (derived-eqn ?compo-free-eqn (compo-free . ?eq-args))
    )
   :effects (
      (psm-applied ?sought (compo-free . ?eq-args) ?compo-free-eqn)
   ))


;;
;; Following applies vector psms writing compo-equations only.
;; This is for use when we want "component-form" solutions, because the
;; problem is actually seeking a component value along standard axes.
;; We flag the problem with "(component-form)" proposition
;; to enable this form of solution.
;; Note that compo-eqn-contains will be asserted by a vector psm for
;; the *magnitude* of the relevant vector, so we have to temporarily
;; pretend we are seeking that when running through the generic equation
;; selection code. This avoids having to add new stuff to the existing
;; equation-contains stuff.
;;
(defoperator apply-vector-psm-compo-form (?sought ?eq-args) 
 :specifications " If the goal is to apply a psm to find a vector component,
      and there is a vector equation that contains the vector magnitude,
      then
      find a component equation that contains the quantity,
      and generate the component equation"
   :preconditions
     ((component-form) ; needed to filter method when sought is duration.
      ;(any-member ?sought ((at (compo x 0 ?vector) ?t)
      ;                     (at (compo y 90 ?vector) ?t)
      ;			   (duration ?t)))
      ; vector psms defined to seek vector magnitudes, so may need to 
      ; pretend we are seeking magnitude to hook into existing vector
      ; psm selecting code.  If sought is scalar, just leave it
      (bind ?vec-sought (if (componentp ?sought) 
                            (vector-mag (compo-base-vector ?sought))
                          ?sought))
      (vector-psm-contains ?vec-eqn-id ?vec-sought)
      ; make sure psm name not on problem's ignore list:
      (test (not (member (first ?vec-eqn-id) (problem-ignorePSMS *cp*))))
      (debug "~&To find ~a,~%   drawing vectors ~a.~%" ?sought ?vec-eqn-id)
      (vector-diagram ?vec-eqn-id)
      (debug "Vectors drawn for ~a.~%" ?vec-eqn-id)
      ; ! if sought is x-comp V, want to make sure we write in x direction
      ; not just any direction containing magV
      (compo-eqn-selected ?vec-eqn-id ?vec-sought (compo-eqn . ?eq-args))
      (debug "Writing compo eqn ~a ~%  for ~a~%" ?eq-args ?sought)
      (eqn ?compo-eqn (compo-eqn . ?eq-args))
      (debug "Wrote compo eqn ~a. ~a~%" ?compo-eqn ?eq-args)
     )
   :effects
   ((psm-applied ?sought (compo-eqn . ?eq-args) ?compo-eqn)))

;;;
;;; operators for applying vector psm's
;;;
;;; The next three operators decide which component equation to
;;; generate and which axis to generate it along.  They get
;;; ?vec-eqn-id and a quantity as the first and second arguments of
;;; the effect.  They "return" an identifier for the selected compo
;;; equation.  They are smart enough to know that one should not
;;; select an axis that is perpendicular to the sought quantity.
;;; However, that only applies if that quantity is the magnitude or
;;; direction of a vector, which is why we need 3 versions of this
;;; operator: for magnitudes, for directions and for other quantities.
;;; Eventually, they should check that the time of the axis is
;;; compatible with the time of the sought quantity.  Currently that
;;; is not done because the semantics of times for axes is messed up.
;;; In particular, if we have two time points and seek the velocity at
;;; one of them, then we want to use linear kinematics and an axis
;;; with (during 1 2) as the time.  But time point 1 is not included
;;; in time interval (during 1 2) because intervals are considered
;;; open, not closed.  However, it would be odd to change the
;;; semantics of (during 1 2) so that it measn a closed interval when
;;; used on an axis and an open interval when used elsewhere.  Thus,
;;; we just ignore the times on axes until this can all be sorted out.

(defoperator select-compo-eqn-for-magnitude (?vec-eqn-id ?compo-eqn-name ?vector ?t)
  :specifications 
   "If the sought quantity is the magnitude of a vector,
      and ?compo-eqn-name is a component equation for the given vector equation
        that could contain that quantity,
      and ?axis is an axis for the vector
      such that the axis is not perpendicular to the vector
   then select the component equation along that axis." 
  :preconditions
  (
   (debug "KAY~%")
   (compo-eqn-contains ?vec-eqn-id ?compo-eqn-name (at (mag ?vector) ?t))
   (debug "KAY~%")
   (vector ?b (at ?vector ?t) ?dir)
   (axis-for ?b ?t-axis ?xyz ?rot)
   ;;(test (tinsidep ?t ?t-axis))   needs to be a closed interval
   (test (non-zero-projectionp ?dir ?xyz ?rot)) ; = not known zero-projectionp
   (not (eqn ?dont-care (compo-eqn ?compo-eqn-name ?xyz ?rot ?vec-eqn-id)))
   ;;(debug "Selecting ~a rot ~a for mag of ~a at ~a.~%" ?xyz ?rot ?vector ?t)
   )
  :effects
  ((compo-eqn-selected ?vec-eqn-id 
		       (at (mag ?vector) ?t) 
		       (compo-eqn ?compo-eqn-name ?xyz ?rot ?vec-eqn-id))))

(defoperator select-compo-eqn-for-direction (?vec-eqn-id ?compo-eqn-name ?vector ?t)
  :specifications "
   If the sought quantity is the direction of a vector,
      and ?compo-eqn-name is a component equation for the given vector equation
        that could contain that quantity,
      and ?axis is an axis for the vector
      such that the axis is not perpendicular to the vector
   then select the component equation along that axis." 
  :preconditions
    ((vector ?b (at ?vector ?t) ?dir)
     (compo-eqn-contains ?vec-eqn-id ?compo-eqn-name (at (dir ?vector) ?t))
     (axis-for ?b ?t-axis ?xyz ?rot)
     ;;(test (tinsidep ?t ?t-axis))   needs to be a closed interval
     (test (non-zero-projectionp ?dir ?xyz ?rot)) ; = not known zero-projectionp
     (not (eqn ?dont-care (compo-eqn ?compo-eqn-name ?xyz ?rot ?vec-eqn-id)))
     ;;(debug "Selecting ~a rot ~a for direction ~a time ~a~%."  ?xyz ?rot ?vector ?t)
    )
  :effects
  ((compo-eqn-selected ?vec-eqn-id 
		       (at (dir ?vector) ?t) 
		       (compo-eqn ?compo-eqn-name ?xyz ?rot ?vec-eqn-id))))

;;; This operator suggests applying a vector equation in order to find
;;; a scalar.  
;;; One issue is how to prevent overgeneration in choice of
;;; axis to apply along.  For instance, on problem k9, the
;;; problem gives vf, vi and a and asks for t.  One of the choices
;;; might appear to be to generate lk-no-s along the axis perpendicular 
;;; to vf, vi and a.  That would yield a compo equation that has t but
;;; the rest of the terms will be zero.  
;;; Here we constrain choice of direction by verifying that the body 
;;; the vector equation is being applied to has at least one vector drawn 
;;; for it that is not perpendicular to the direction chosen. 
;;; Note this makes assumption about the form of the vector equation ids: 
;;; the ids must be body and time so we can pull them out by matching.
;;; If the time is an interval it should be packaged into a (during ..) term

(defoperator select-compo-eqn-for-scalar (?psm-id ?b ?t ?compo-eqn-name ?quantity)
  :specifications 
   "If the sought quantity is a scalar,
      and ?compo-eqn-name is a component equation for the given vector equation
        that could contain that quantity,
   then select the component equation along any axis." 
  :preconditions
   ((test (scalar-quantityp ?quantity))
    ; pull out body and time from inside vector eqn id to make sure we pick up
    ; axis for that body and vector on that body when testing projection.
    ; NB: this requires that main vector eqn ids contain just these args!!
    (compo-eqn-contains (?psm-id ?b ?t) ?compo-eqn-name ?quantity)
    (debug "choosing compo to apply ~A to find scalar ~A~%"   ?compo-eqn-name ?quantity) 
    (axis-for ?b ?t ?xyz ?rot)
    ;;(debug "select-compo: trying axis ~A rot ~A for ~A at ~A~%" ?xyz ?rot ?b ?t)
    (in-wm (vector ?b (at ?vector ?t) ?dir))
    ;;(debug "select-compo: trying vector ~A at ~A~%" ?vector ?dir)
    (test (non-zero-projectionp ?dir ?xyz ?rot)) ; = not known zero-projectionp
    ;;(debug "select-compo: rotation OK, checking if already used~%")
    (not (eqn ?dont-care (compo-eqn ?compo-eqn-name ?xyz ?rot (?psm-id ?b ?t))))
    ;;(debug "Selecting ~a rot ~a via scalar ~a~%" ?xyz ?rot ?quantity)
    )
  :effects
  ((compo-eqn-selected (?psm-id ?b ?t)
		       ?quantity 
		       (compo-eqn ?compo-eqn-name ?xyz ?rot (?psm-id ?b ?t)))))


;;; After the compo equation has been written, this operator writes
;;; the appropriate projection equations, then replaces the component
;;; variables with their equivalent expressions (from the projection
;;; equations via the second argument of projection), and writes the
;;; component-free equation.  One trick here are to get a set of
;;; component variables from the given equation.  Although we could
;;; use a fancy version of vars-in-eqn to read the equation, it would
;;; have to access WM in order to tell which variables denoted
;;; components.  Thus, we pass the component variables up from the
;;; equation-writing operator to here via the predicate (eqn-compos
;;; <compo eqn id> <variables>).  The second trick is to get an list
;;; of algebraic expressions that matches the list of component
;;; equations.  These are provided by the predicate (projections
;;; <variables> <expressions>) which has <varaibles> passed in and
;;; returns <expressions>.

(defoperator write-compo-free-eqn (?args)
  :specifications "
   If the goal is to write the equation without components,
   then get the component variables from the equation,
      write projections for all of them,
      substitute the expressions for the components in the equation,
      and write the equation."
  :preconditions
  ((in-wm (eqn-compos (compo-eqn . ?args) ?compo-vars))
    (in-wm (eqn ?compo-eqn (compo-eqn . ?args)))
    (projections ?compo-vars ?compo-exprs)
    ; (debug "Projections done~%")
    ; (debug "compo-vars: ~A~%compo-exprs~A~%" ?compo-vars ?compo-exprs)
    (bind ?compo-free-eqn (subst-parallel-lists ?compo-vars ?compo-exprs ?compo-eqn))
    (debug "wrote compo-free eqn ~a.~%"  ?args)
    )
  :effects
  ((assume using-compo-free ?args)
   (derived-eqn ?compo-free-eqn (compo-free . ?args))))


;;; ===================== projections ====================
;;; This operator writes projection equations for component
;;; variables, which are passed in via the effect.  It returns
;;; expressions that are equal to the component variables.  It make
;;; sure that the ordering of the two lists is the same, as that
;;; ordering is used later when the expressions are substituted for
;;; the variables.

(defoperator write-projections (?compo-vars)
  
  :specifications "
   If the goal is to write extra equations for component variables,
   then create subgoals, one for each, to write the equations,
   and remember what the expressions corresponding to each variable is."
  :preconditions
  (; convert list of compo vars to list of compo quants
   (map ?var ?compo-vars
        (in-wm (variable ?var ?quant))
     ?quant ?compo-quants)
   ; and generate projection for each component, saving rhs exprs
   (map ?compo ?compo-quants
	(eqn (= ?cvar ?expr) (projection ?compo))
     ?expr ?compo-exprs)
    )
  :effects
   ((projections ?compo-vars ?compo-exprs))
   :hint
   ((point (string
	    "Your next step should be to write equations for each of the component variables that express the variable in simpler form, as an expression of magnitude and direction variables." ))
    (bottom-out (string
		 "You need to write projection equations for the components you will use."))
    ))

;;; This operator represents writing a projection equation for a zero
;;; vector.  Obviously, the component along any axis of a zero length
;;; vector is zero.  The operator expects ?compo-var to be bound by
;;; unifying a goal with the effects.

(defoperator compo-zero-vector (?xyz ?rot ?vector ?t)
  :specifications "
   If the goal is to write a projection equation for a given component variable ?v,
      and the vector is zero,
   then write ?v = 0."
  :preconditions
   ((in-wm (variable ?compo-var (at (compo ?xyz ?rot ?vector) ?t)))
    (in-wm (vector ?b (at ?vector ?t) zero))
    ;;(debug "Zero projection of (at ~a ~a).~%" ?vector ?t)
    )
  :effects
   ((eqn (= ?compo-var 0)
	 (projection (at (compo ?xyz ?rot ?vector) ?t))))
  :hint
  ((point (string "Notice that the ~a has zero length ~a." ?vector (?t pp)))
   (teach (string "When a vector has zero length, then all its components are zero, too.")
	  (kcd "write_v_x=zero"))
   (bottom-out (string "Because ~a is a zero-length vector ~a, write an equation stating that its component along the ~a axis is zero: ~A" ?vector (?t pp) 
   ((axis ?xyz ?rot) symbols-label) ((= ?compo-var 0) algebra)))
   ))

#| ; unused experimental code -- these new operators would generate special case projection-writing hints
   ; 1. compo-trig-standard-axes*: leave out theta_x term if axes not tilted.
   ; 2. compo-parallel-axis -- use special case for parallel/anti-parallel axes.
   ; Hints need to be adjusted in these.

;; note following pair currently apply even in case of parallel or antiparallel to axes
(defoperator compo-trig-standard-axes (?xyz ?rot ?vector ?t)
  :preconditions
  (; require standard axes direction:
   (test (or (equal ?xyz 0) (equal ?xyz 90))
   (in-wm (variable ?compo-var (at (compo ?xyz ?rot ?vector) ?t)))
   ; use different special case op for z axis projections:
   (test (not (equal ?xyz 'z)))
   (in-wm (vector ?b (at ?vector ?t) ?dir))
   (test (non-zero-projectionp ?dir ?xyz ?rot))
   ;; test is passed if dir is not known to be orthogonal to axis dir
   ;; following makes sure has a known dir so we can plug in the numerical
   ;; degree value (this is important for generating the right equation).
   ;; Another operator will handle unknowns in terms of angle variables
   (test (not (or (equal ?dir 'unknown) (equal ?dir 'z-unknown))))
   ;; Note ?dir may be a z-axis spec or a (dnum n deg)
   (bind ?degrees (second (if (z-dir-spec ?dir) (zdir-phi ?dir) 
			    ?dir)))
   ;(in-wm (variable ?dir-var (at (dir ?vector) ?t)))
   (in-wm (variable ?mag-var (at (mag ?vector) ?t)))
   ; write y-axis projection as mag * sin (dir - x-axis rotation)
   (bind ?cos-or-sin (if (equal ?xyz 'y) 'sin 'cos))
   (bind ?x-rot      (if (equal ?xyz 'y) (- ?rot 90) ?rot))
   ;;(debug "projecting (at ~a ~a) onto axis ~a rot ~a.~%" ?vector ?t ?xyz ?rot)
   )
  :effects
  ((eqn (= ?compo-var (* ?mag-var (?cos-or-sin ((dnum ?degrees |deg|)))))
	(projection (at (compo ?xyz ?rot ?vector) ?t))))
  :hint
  ((point (string "Since ~A ~A is not perpendicular to the ~A axis, it has a non-zero component along that axis."  ?vector (?t pp) ((axis ?xyz ?rot) symbols-label)))
   (teach (string "In general, if a vector V is oriented at $qV and the positive x axis is oriented at $qx ccw from horizontal, the components of the vector along the axes are given by the {\\l projection equations}{\\v ProjectionEquations.html}\\n   V_x = V * cos($qV - $qx)\\n   V_y = V * sin($qv - $qx)" )
	  (kcd "write_x_trig_projection_equation"))
   (bottom-out (string "Since the direction of ~A ~A is $q~A (~A deg) and the orientation of the x axis is $q~A (~A deg), you can write the general formula ~A = ~A*~A($q~A - $q~A)."
	       ?vector (?t pp) (?mag-var algebra) (?degrees adj)
	       ; symbols-label gets x axis label -- could be x, x1, x2
	       ((axis x ?x-rot) symbols-label) (?x-rot adjective)
	       (?compo-var algebra) (?mag-var algebra) (?cos-or-sin adjective) 
	       (?mag-var algebra) ((axis x ?x-rot) symbols-label) ))
   ))

(defoperator compo-trig-standard-axes-unknown (?xyz ?rot ?vector ?t)
  :preconditions
  (; require standard axes direction:
   (test (or (equal ?xyz 0) (equal ?xyz 90))
   ; fetch the variables:
   (in-wm (vector ?b (at ?vector ?t) unknown))
   (in-wm (variable ?compo-var (at (compo ?xyz ?rot ?vector) ?t)))
   (in-wm (variable ?dir-var (at (dir ?vector) ?t)))
   (in-wm (variable ?mag-var (at (mag ?vector) ?t)))
   ; write y-axis projection as mag * sin (dir - x-axis rotation)
   (bind ?cos-or-sin (if (equal ?xyz 'y) 'sin 'cos))
   (bind ?x-rot      (if (equal ?xyz 'y) (- ?rot 90) ?rot))
   )
  :effects
   ((eqn (= ?compo-var (* ?mag-var (?cos-or-sin (- ?dir-var (dnum ?x-rot |deg|)))))
	 (projection (at (compo ?xyz ?rot ?vector) ?t))))
  :hint
  ((point (string "Since ~a ~a is not known to be perpendicular to the ~A axis, you should use a general formula for its component along that axis."  ?vector (?t pp) ((axis ?xyz ?rot) symbols-label)))
   (teach (string "In general, if a vector V is oriented at $qV and the positive x axis is oriented at $qx ccw from horizontal, the components of the vector along the axes are given by the {\\l projection equations}{\\v ProjectionEquations.html}\\n   V_x = V * cos($qV - $qx)\\n   V_y = V * sin($qv - $qx)" )
	  (kcd "write_x_trig_projection_equation"))
   (bottom-out (string "Since the direction of ~a ~a is ~a, and the rotation of the x axis is $q~A (~a deg), you can write the general formula ~a = ~a*~a(~a - $q~A)." 
		       ?vector (?t pp) (?dir-var algebra) 
		       ((axis x ?x-rot) symbols-label) (?x-rot adj)
		       (?compo-var algebra)
		       (?mag-var algebra)  (?cos-or-sin adj) 
		       (?dir-var algebra) ((axis x ?x-rot) symbols-label)))
   ))

(defoperator compo-parallel-axis (?compo-var)
  :specifications "
   If ?compo-var is the variable for a component of a vector,
      and the vector is at a known angle parallel or antiparallel to the axis,
   then write ?compo-var = +/- ?mag-var as appropriate"
  :preconditions
  ((in-wm (variable ?compo-var (at (compo ?xyz ?rot ?vector) ?t)))
   (in-wm (vector ?b (at ?vector ?t) ?dir))
   (test (not (or (equal ?dir 'unknown) (equal ?dir 'z-unknown))))
   (test (parallelp ?rot ?dir))
   ;; Note ?dir may be a z-axis spec or a (dnum n deg)
   (bind ?degrees (second (if (z-dir-spec ?dir) (zdir-phi ?dir) 
			    ?dir)))
   (in-wm (variable ?mag-var (at (mag ?vector) ?t)))
   ; write y-axis projection as mag * sin (dir - x-axis rotation)
   (bind ?sign (if (same-angle ?rot ?dir) '+ '-))
   )
  :effects
  ((eqn (= ?compo-var (?sign ?mag-var)) (projection (at (compo ?xyz ?rot ?vector) ?t))))
  :hint
  ((point (string "Since ~A ~A lies along to the ~A axis, it has a non-zero component along that axis."  ?vector (?t pp) ((axis ?xyz ?rot) symbols-label)))
   (teach (string "If a vector V lies along an axis x and points in the positive direction of that axis, then the component of the vector V_x along the axis is equal to the magnitude of the vector: V_x = V. This is a special case of the more general {\\l projection equations}{\\v ProjectionEquations.html} that will work in all cases")
	  (kcd "write_x_trig_projection_equation"))
   (bottom-out (string "Since ~A ~A points in the same direction as the positive ~a axis (~A deg), write the equation ~A." 
		       ?vector (?t pp) (?xyz adj) (?degrees adj)
		       ((= ?compo-var (?sign ?mag-var)) algebra)))
   ))

|# ; end unused experimental projection-writing operators

;;; This operator represents writing a projection equation for a
;;; non-zero vector that is not perpendicular to the axis.  It
;;; expects ?compo-var to be bound by unifying a goal with the
;;; effects, and it produces an equation.  It looks up the definition
;;; of the component variable, then looks up the vector in order to
;;; get its direction.

;;; This uses a simple treatement of geometry, wherein the directions of
;;; vectors and axes are specified by reference to the horizonal, rightward 
;;; screen axis system.  Thus, the projection onto an X axis is always the 
;;; cosine of the difference in their directions. Because it is conventionally
;;; written this way, we write projections along the y-axis using the sin
;;; of the angle made with the X axis.

(defoperator compo-general-case (?xyz ?rot ?vector ?t)
  :specifications "
   If ?compo-var is the variable for a component of a vector,
      and the vector is at a known angle not perpendicular to the axis,
   then the projection equation is ?compo-var = ?mag*cos(?dir - ?rot)
      where ?mag is the magnitude of the vector,
      ?dir is the direction in degrees of the vector,
      and ?rot is the rotation of the axes."
  :preconditions
  ((in-wm (variable ?compo-var (at (compo ?xyz ?rot ?vector) ?t)))
   ; use different special case op for z axis projections:
   (test (not (equal ?xyz 'z)))
   (in-wm (vector ?b (at ?vector ?t) ?dir))
   (test (non-zero-projectionp ?dir ?xyz ?rot))
   ;; test is passed if dir is not known to be orthogonal to axis dir
   ;; following makes sure has a known dir so we can plug in the numerical
   ;; degree value (this is important for generating the right equation).
   ;; Another operator will handle unknowns in terms of angle variables
   (test (not (or (equal ?dir 'unknown) (equal ?dir 'z-unknown))))
   ;; Note ?dir may be a z-axis spec or a (dnum n deg)
   (bind ?degrees (second (if (z-dir-spec ?dir) (zdir-phi ?dir) 
			    ?dir)))
   ;(in-wm (variable ?dir-var (at (dir ?vector) ?t)))
   (in-wm (variable ?mag-var (at (mag ?vector) ?t)))
   ; write y-axis projection as mag * sin (dir - x-axis rotation)
   (bind ?cos-or-sin (if (equal ?xyz 'y) 'sin 'cos))
   (bind ?x-rot      (if (equal ?xyz 'y) (- ?rot 90) ?rot))
   ;;(debug "projecting (at ~a ~a) onto axis ~a rot ~a.~%" ?vector ?t ?xyz ?rot)
   )
  :effects
  ((eqn (= ?compo-var (* ?mag-var (?cos-or-sin (- (dnum ?degrees |deg|) (dnum ?x-rot |deg|)))))
	(projection (at (compo ?xyz ?rot ?vector) ?t))))
  :hint
  ((point (string "Since ~A ~A is not perpendicular to the ~A axis, it has a non-zero component along that axis."  ?vector (?t pp) ((axis ?xyz ?rot) symbols-label)))
   (teach (string "In general, if a vector V is oriented at $qV and the positive x axis is oriented at $qx ccw from horizontal, the components of the vector along the axes are given by the {\\l projection equations}{\\v ProjectionEquations.html}\\n   V_x = V * cos($qV - $qx)\\n   V_y = V * sin($qv - $qx)" )
	  (kcd "write_x_trig_projection_equation"))
   (bottom-out (string "Since the direction of ~A ~A is $q~A (~A deg) and the orientation of the x axis is $q~A (~A deg), you can write the general formula ~A = ~A*~A($q~A - $q~A)."
	       ?vector (?t pp) (?mag-var algebra) (?degrees adj)
	       ; symbols-label gets x axis label -- could be x, x1, x2
	       ((axis x ?x-rot) symbols-label) (?x-rot adjective)
	       (?compo-var algebra) (?mag-var algebra) (?cos-or-sin adjective) 
	       (?mag-var algebra) ((axis x ?x-rot) symbols-label) ))
   ))

(defoperator compo-general-case-unknown (?xyz ?rot ?vector ?t)
  :specifications "
   If ?compo-var is the variable for a component of a vector,
      and the vector is drawn at an unknown direction,
   then the projection equation is ?compo-var = ?mag*cos((?dir - ?rot))
      where ?mag is the magnitude of the vector,
      ?dir is the variable for the direction of the vector,
      and ?rot is the rotation of the axes."
  :preconditions
  (; use different special case op for z axis projections:
   (test (not (equal ?xyz 'z)))
   (in-wm (vector ?b (at ?vector ?t) unknown))
   (in-wm (variable ?compo-var (at (compo ?xyz ?rot ?vector) ?t)))
   (in-wm (variable ?dir-var (at (dir ?vector) ?t)))
   (in-wm (variable ?mag-var (at (mag ?vector) ?t)))
   ; write y-axis projection as mag * sin (dir - x-axis rotation)
   (bind ?cos-or-sin (if (equal ?xyz 'y) 'sin 'cos))
   (bind ?x-rot      (if (equal ?xyz 'y) (- ?rot 90) ?rot))
   ;;(debug "projecting (at ~a ~a) onto axis ~a rot ~a.~%" ?vector ?t ?xyz ?rot)
   )
  :effects
   ((eqn (= ?compo-var (* ?mag-var (?cos-or-sin (- ?dir-var (dnum ?x-rot |deg|)))))
	 (projection (at (compo ?xyz ?rot ?vector) ?t))))
  :hint
  ((point (string "Since ~a ~a is not known to be perpendicular to the ~A axis, you should use a general formula for its component along that axis."  ?vector (?t pp) ((axis ?xyz ?rot) symbols-label)))
   (teach (string "In general, if a vector V is oriented at $qV and the positive x axis is oriented at $qx ccw from horizontal, the components of the vector along the axes are given by the {\\l projection equations}{\\v ProjectionEquations.html}\\n   V_x = V * cos($qV - $qx)\\n   V_y = V * sin($qv - $qx)" )
	  (kcd "write_x_trig_projection_equation"))
   (bottom-out (string "Since the direction of ~a ~a is ~a, and the rotation of the x axis is $q~A (~a deg), you can write the general formula ~a = ~a*~a(~a - $q~A)." 
		       ?vector (?t pp) (?dir-var algebra) 
		       ((axis x ?x-rot) symbols-label) (?x-rot adj)
		       (?compo-var algebra)
		       (?mag-var algebra)  (?cos-or-sin adj) 
		       (?dir-var algebra) ((axis x ?x-rot) symbols-label)))
   ))


;;; This operator represents writing a component equation for a vector whose
;;; angle is known numerically and it is perpendicular to the axis.  Thus,
;;; its component along the axis is zero.  We need this special case because
;;; it removes the vector's magnitude from the system of equations.

(defoperator compo-perpendicular (?xyz ?rot ?vector ?t)
  :specifications "
   If a vector is perpendicular to an axis,
   then its component along that axis is zero."
  :preconditions
   ((in-wm (variable ?compo-var (at (compo ?xyz ?rot ?vector) ?t)))
    (in-wm (vector ?b (at ?vector ?t) ?dir))
    (in-wm (variable ?dir-var (at (dir ?vector) ?t)))
    ; (test (perpendicularp ?dir ?rot)) -- AW: changed to use non-zero-projp
    (test (not (non-zero-projectionp ?dir ?xyz ?rot))) ; i.e. known zero projectionp
    ;;(debug "Perpendicular projection of (at ~a ~a) onto ~a rot ~a~%"  ?vector ?t ?xyz ?rot)
    )
  :effects
   ((eqn (= ?compo-var 0)
	 (projection (at (compo ?xyz ?rot ?vector) ?t))))
  :hint
  ((point (string  "Notice that ~a, ~a is perpendicular to the ~a axis." (?t pp) ?vector ((axis ?xyz ?rot) symbols-label)))
   (teach (kcd "write_v_x=v_zero")
	  (string "When a vector is perpendicular to an axis, its component along that axis is zero."))
   (bottom-out (string "Because ~a is perpendicular to the ~a axis ~a, write the equation ~a=0"
		       ?vector ((axis ?xyz ?rot) symbols-label) (?t pp) (?compo-var algebra)))
   ))

;; projection equations for z-axis vectors, which are guaranteed to
;; be parallel to the z axis. We also use phi angles for these rather 
;; than theta vars for these. When the phi var is known we put out the
;; value when vector is drawn, so there is really no need to use them 
;; in projections for known directions. We could use them with trig 
;; functions in case of unknown phi dirs, but currently the algebra system 
;; cannot solve for unknown phi variables (see apply-vector-psm-compo-form). 
;; So in this case we just write equivalent of V = abs(V_z) so mag value
;; will be determined. 

(defoperator compo-z-axis (?vector ?t)
  :preconditions
  ((in-wm (variable ?compo-var (at (compo z 0 ?vector) ?t)))
   (in-wm (vector ?b (at ?vector ?t) ?dir))
   (test (non-zero-projectionp ?dir 'z 0))
   ;; test is passed if dir is not known to be orthogonal to axis dir
   ;; following makes sure has a known dir so we can make use of direction.
   ;; Another operator will handle unknowns in terms of angle variables
   ;; ('unknown shouldn't happen, should mean x-y unknown, so perp. to z)
   (test (not (or (equal ?dir 'unknown) (equal ?dir 'z-unknown))))
   ;(bind ?degrees (second (if (z-dir-spec ?dir) (zdir-phi ?dir) ?dir)))
   (in-wm (variable ?mag-var (at (mag ?vector) ?t)))
   ; rhs is plus or minus mag:
   (bind ?rhs (if (eq ?dir 'out-of) ?mag-var `(- ,?mag-var)))
   )
  :effects
  ((eqn ;(= ?compo-var (* ?mag-var (cos (dnum ?degrees |deg|))))
        (= ?compo-var ?rhs) 
	(projection (at (compo z 0 ?vector) ?t))))
  :hint
  ((point (string "You should write an equation relating the ~A component of ~A ~A to its magnitude."  
                  ((axis z 0) symbols-label) ?vector (?t pp)))
   (teach (string "If a vector V lies entirely along an axis, its component along that axis will be + or - its magnitude, depending on whether the vector points in the positive or negative direction.  In a right-handed coordinate system, the positive z axis points out of the x-y plane of the diagram, and the negative z axis points into the plane.  Thus V_z = V if V points out of the plane and V_z = -V if into the plane." ))
  (bottom-out (string "Since ~A ~A points ~A, write the equation ~A" 
                      ?vector (?t pp) (?dir adj) ((= ?compo-var ?rhs) algebra)))
  ))


; !!! this doesn't actually work:
(defoperator compo-z-axis-unknown (?compo-var)
  :preconditions
  ((in-wm (variable ?compo-var (at (compo z 0 ?vector) ?t)))
   (in-wm (vector ?b (at ?vector ?t) z-unknown))
   (in-wm (variable ?mag-var (at (mag ?vector) ?t))))
  :effects
  ; note compo-var must be first so compo values can be picked up
  ; we write v_z = sign * v, where sign = v_z/abs(v_z)
  ((eqn (= ?compo-var (* (/ ?compo-var 
                            (abs ?compo-var)) 
			 ?mag-var))    (projection ?compo-var)))
  :hint (
   (bottom-out (string "Write the equation ~A" ; hint shows simpler eqn -- OK?
                       ((= ?mag-var (abs ?compo-var)) algebra)))
   ))

#| ; not used yet
;; pair of operators we would use if algebra could solve for phi:
;; when we know it's in the z direction but don't know which way it points
(defoperator compo-z-axis-unknown (?compo-var)
  :preconditions
  ((in-wm (variable ?compo-var (at (compo z 0 ?vector) ?t)))
   (in-wm (vector ?b (at ?vector ?t) z-unknown))
   (in-wm (variable ?mag-var (at (mag ?vector) ?t)))
   (in-wm (variable ?dir-var (at (dir ?vector) ?t)))
   ; following may be needed so algebra can solve for phi from components
   ; and projections for unknown angles. But then we have to prompt the
   ; student to write it as well
   (eqn (= ?mag-var (abs ?compo-var)) (z-axis-constraint ?compo-var ?mag-var))
   )
  :effects
  ((eqn (= ?compo-var (* ?mag-var (cos ?dir-var)))
	(projection ?compo-var))
   ; following needed so algebra can solve for phi
   (implicit-eqn (= 0 (sin ?dir-var)) (phi-constraint ?dir-var))
   )
  :hint
  ((point (string "You should write an equation relating the ~A component of ~A ~A to its magnitude and direction."  
                  ((axis z 0) symbols-label) ?vector (?t pp)))
   (teach (string "In general, if a vector V lies at an angle of $jV with respect to the z axis, its projection along the z axis will be given by V * cos($jV). In Andes, $jV is always either 0 degrees for a vector pointing in the positive z direction (out of the plane) or 180 deg for a vector in the negative z direction (into the plane). Thus V_z will equal V or -V, but if you don't know which, you should use the general formula so you can solve for ~qV if needed." ))
   (bottom-out (string "Since the angle of ~A ~A with respect to the z axis is represented by $q~A, you can write the general formula ~A = ~A*cos($q~A)."
	       ?vector (?t pp) (?mag-var algebra) 
	       (?compo-var algebra) (?mag-var algebra) (?mag-var algebra) ))
   ))
|#

(defoperator write-z-axis-constraint(?compo-var ?mag-var)
  :effects 
   ((eqn (= ?mag-var (abs ?compo-var)) (z-axis-constraint ?compo-var ?mag-var)))
  :hint (
    (teach (string "If a vector is constrained to lie along the z-axis, you know its magnitude is equal to the absolute value of its z-component. You can enter the equation ~A in order to represent this constraint."
    ((= ?mag-var (abs ?compo-var)) algebra)))
    (teach (string "Enter the equation ~A" ((= ?mag-var (abs ?compo-var)) algebra)))
  ))


; Following is the projection psm applied at the bubble-graph level 
; for component-form solutions, in which projections are not hidden inside
; psms. For example, if given mag and dir of v0, need projection to link to
; v0_x and v0_y which occur in component-form bubble-graph equations.
; We use a different eqn-id for this so we can reuse the existing equation
; writing operators as subroutines. Unfortunately we can't use the existing
; projection writing operators to achieve our final equation writing goal
; directly since as written they make assumptions about the context, viz
; that a diagram with vectors and axes has already been drawn and variables
; already been defined. When used as a top-level psm we have to generate
; that context ourself.  Until we fix that, we have to treat this operator
; as generating a derived-eqn -- though it is in fact identical 
; to the single sub-eqn we are wrapping.

; Even w/component form flag, it can be tricky to put out projection equation 
; by itself because writing it requires drawing vector and choosing axes 
; to enable compo variables to be used. But define-compo and some other 
; operators use in-wm for their preconds, on the assumption that a diagram 
; drawing step for some other method has already taken care of the necessary 
; drawing. See define-compo2 for a workaround for this problem.

(defoperator projection-contains (?sought)
  :preconditions (
   ; only allow this in problems tagged 'component-form
   (in-wm (component-form))
   (any-member ?sought ((at (mag ?vector) ?t)
		        (at (dir ?vector) ?t)
                        (at (compo ?xy ?rot ?vector) ?t)))
   (any-member ?xy (x y z))
   (bind ?rot (if (eq ?xy 'y) 90 0))
   )
  :effects (
   (derived-eqn-contains (proj (at (compo ?xy ?rot ?vector) ?t)) ?sought)
  ))

(defoperator write-projection (?vector ?t ?xy ?rot)
  :preconditions (
    ; Projection normally doesn't draw a body. projection-body stmt in problem
    ; gets alt version that does. Used to draw body in projection-only problem.
    (not (projection-body ?problem-body ?problem-time)) 
   
    ; have to make sure compo variable is defined (which requires drawing
    ; vector and axes), since the projection writing operators that do
    ; the work are written to assume it is already in wm as a result of
    ; drawing a vector diagram for a standard vector-psm.
    (variable ?compo-var (at (compo ?xy ?rot ?vector) ?t))
    ; then use existing operators to write projection equation:
    (eqn (= ?compo-var ?proj) (projection (at (compo ?xy ?rot ?vector) ?t)))
  ) :effects (
    ; exact copy of an existing equation is a simple case of a derived eqn.
    (derived-eqn (= ?compo-var ?proj) (proj (at (compo ?xy ?rot ?vector) ?t)))
  ))

(defoperator write-projection-with-body (?vector ?t ?xy ?rot)
  :preconditions (
    ; alt body-drawing version of write-projection, enabled by stmt in problem
    (in-wm (projection-body ?problem-body ?problem-time)) 
    (body ?problem-body ?problem-time)
    (variable ?compo-var (at (compo ?xy ?rot ?vector) ?t))
    (eqn (= ?compo-var ?proj) (projection (at (compo ?xy ?rot ?vector) ?t)))
  ) :effects (
    (derived-eqn (= ?compo-var ?proj) (proj (at (compo ?xy ?rot ?vector) ?t)))
  ))

;;; =============================== axes =========================
;;; Although the axis-drawing code is only called from vector-diagram
;;; code, it is included here because it is general, and doesn't
;;; depend on the particular kind of vector diagram being drawn.
;;; Because the Andes axis drawing tool always produces both x and y
;;; axes, even if only one is needed, this code always produces both.

;;; This first operator models drawing standard, unrotated axes.  That
;;; is, the x-axis has 0 direction and the y-axis has 90 direction.
;;; It applies only when there are no vectors whose angles are known
;;; numerically.  If there are such vectors, then another operator
;;; applies and draws axes alligned with one of the vectors.  This
;;; prevents drawing standard axes when there are no vertical or
;;; horizontal vectors.
;;;
;;; Vectors along the z-axis are used in rotational problems. Althought there is
;;; only one possible setting for the z-axis, Andes currently requires the 
;;; axes to be drawn before component notation is involved. We use a special
;;; case operator for this in order to give a custom hint.
;;; !!! We might need a new operator for this if ever needed an axis in case 
;;; where rotated vectors in the x-y plane had been drawn in addition 
;;; to the z-axis vectors on the goal body.

;;; !!! Currently this operator *only* applies in following cases:
;;;   - cons-linmom, to achieve axis for many-body system
;;;   [- rotational problems, to achieve z-axis for z-compo eqn ] -- taken out!
;;  But both of these uses ought to have specialized hints.

(defoperator draw-unrotated-axes ()
  :specifications 
   "If  there are no vectors with numerical directions,
   then draw unrotated coordinate axes"
  :preconditions (
    (not (component-form))
    ; don't draw axis for system part if system axis already chosen
    ; use-system-axes will choose axes in this case.
    (not (axis-for ?sys ?t ?dontcare1 ?dontcare2)
         (part-of-sys ?b ?sys))
    (not (vector ?b (at ?v ?t-vec) (dnum ?dir |deg|))
         (tinsidep ?t-vec ?t))
    )
  :effects (
   (draw-axes ?b ?t 0) ; action proposition for help system gives x dir
   (axis-for ?b ?t x 0)
   (axis-for ?b ?t y 90)
   ; (axis-for ?b ?t z 0) ; makes available z compos if needed, see rotkin 
   (assume axis-for ?b ?t x 0)
   (assume axis-for ?b ?t y 90)
  )
  :hint
  (;(point (string "Although one usually rotates the x-y coordinate system to align axes with vectors, there are no vectors on the system of interest with known directions in the x-y plane."))
   ;(teach (string "When you don't have any vectors in the x-y plane with which to align your coordinate system, you might as well draw a standard horizontal-vertical coordinate system."))
   (teach (string "In this problem there is no strong reason not to use a standard horizontal-vertical coordinate system."))
   (bottom-out (string "Draw a standard horizontal-vertical coordinate system setting the positive x axis at 0 degrees."))
   ))

;; following draws standard axes when problem seeks horizontal or vertical 
;; components. We don't want to draw vector-aligned axes in this case. It
;; is possible that draw-unrotated-axes could apply in the same case if it
;; applies when no vector is drawn; however, in order to always get this hint, 
;; we suppress that with test in draw-unrotated-axes.
;;
;; !!! Following not done yet, causes problems with multiple choices:
;; Include body and time parameters so can be applied as often as needed to
;; achieve axis-for any body and time. This means there will be multiple
;; draw-axes entries -- perhaps within a single operator! -- but they 
;; will all be marked done by the same entry since body and time are removed 
;; in forming entry propositions for use at help time.
;;
(defoperator draw-compo-form-axes ()
  :specifications 
   "If the problem is seeking horizontal or vertical components then use standard axes"
  :preconditions (
    (component-form)
    ; don't draw new axis for system part if system axis already chosen
    ; use-system-axes will choose axes in this case.
    (not (axis-for ?sys ?t ?dontcare1 ?dontcare2)
         (part-of-sys ?b ?sys))
    )
  :effects (
   (draw-axes ?b ?t 0) ; action proposition for help system gives x dir
   (axis-for ?b ?t x 0) (axis-for ?b ?t y 90) 
   (assume axis-for ?b ?t x 0) (assume axis-for ?b ?t y 90)
   ; added March 2004: also register z axis. Consequences of this for other problems
   ; unclear, may apply in same case as draw-unrotated-axes-for-zcomps
   (axis-for ?b ?t z 0)
  )
  :hint
  ((point (string "Although one usually rotates the x-y coordinate system to align axes with vectors, since this problem is seeking horizontal or vertical vector components, you should use a standard horizontal-vertical coordinate system."))
   (bottom-out (string "Draw a standard horizontal-vertical coordinate system setting the positive x axis at 0 degrees."))
   ))

; draw-compo-form axis only applies once to draw axes within a given call to
; the problem solver, registering those as the "axes-for" vectors on some
; original body. Following operator reports the standard axes as the "axes-for" 
; vectors on *another* body in case draw-compo-form axis has already been called
; to draw the axes.  This is needed in at least one case where we give the
; equality between components of two vectors on different bodies, and need
; to define compo vars for each via draw-compo2, hence need an axis for each.
(defoperator reuse-compo-form-axes (?b ?t)
:effects (
   (axis-for ?b ?t x 0) (axis-for ?b ?t y 90)
)
:preconditions (
   (component-form)
   (in-wm (draw-axes ?drawn-axes-body ?drawn-axes-time 0))
   ; don't need this in addition if already registered an axis for 
   ; vectors on ?b at ?t 
   (not (axis-for ?b ?t))
   ; don't return axis for system part if system axis already chosen
   ; use-system-axes will return axes in this case.
   (not (axis-for ?sys ?t ?dontcare1 ?dontcare2)
        (part-of-sys ?b ?sys))
   ; select-compo-eqn-for-magnitude/direction can call this with t unbound,
   ; so we must select a time to register the new axis in this case.
   (bind ?t (if (variable-p ?t) ?drawn-axis-time 
              ?t))
))

;; following applies for same purpose when not component-form
(defoperator reuse-other-body-axes (?b ?t)
:preconditions (
   (not (component-form))
   (in-wm (draw-axes ?drawn-axes-body ?drawn-axes-time ?x-rot))
   ; don't need this in addition if already registered an axis for 
   ; vectors on ?b at ?t 
   (not (axis-for ?b ?t))
   ; don't return axis for system part if system axis already chosen
   ; use-system-axes will return axes in this case.
   (not (axis-for ?sys ?t ?dontcare1 ?dontcare2)
        (part-of-sys ?b ?sys))
   (bind ?y-rot (+ ?x-rot 90))
)
:effects (
   (axis-for ?b ?t x ?x-rot) 
   (axis-for ?b ?t y ?y-rot)
))


; following draws standard axes because we are interested in z components for
; rotational problems.  currently if we are interested in z components we 
; never use x and y components, so we don't achieve those goals here.
(defoperator draw-unrotated-axes-for-zcomps ()
  :specifications 
   "If  there are no vectors with numerical directions,
   then draw unrotated coordinate axes"
  :preconditions (
    ; AW: Feb 2004: don't apply this if component form, since changed 
    ; draw-comp-form-axes to handle that case
    (not (component-form))
    ; don't draw axis for system part if system axis already chosen
    ; use-system-axes will choose axes in this case.
    (not (axis-for ?sys ?t ?dontcare1 ?dontcare2)
         (part-of-sys ?b ?sys))
    ; possible time is unbound coming in, pick any
    (time ?t)
    )
  :effects (
   (draw-axes ?b ?t 0) ; action proposition for help system gives x dir
   (axis-for ?b ?t z 0) 
  )
  :hint (
   (point (string "You need to draw coordinate axes in order for component variables to be defined."))
   (teach (string "Since you are concerned with components along the z axis in this problem, there is no special reason to tilt the axes in the x-y plane, so you might as well use a standard horizontal-vertical coordinate system."))
   (bottom-out (string "Draw a standard horizontal-vertical coordinate system setting the positive x axis at 0 degrees."))
   ))

;;; This operator draws axes so that they are alligned with some
;;; vector.  It chooses a vector whose direction is known numerically.
;;; The rotation of the x-axis is between 0 and 90 degrees, and of
;;; course the y-axis rotation is 90 more than that, and that is
;;; guaranteed to be less than 360.  This only works when the
;;; numerical angle of the vector is known.
;;; 
;;; The operator collects up all the vector's directions, removes
;;; duplicates, then uses any-member to non-deterministically pick one
;;; from the set.  This avoids producing two branches of the solution
;;; graph that have the same axis rotation even though the axis was
;;; alligned with different vectors. 
;;;
;;; The conditions must access the vectors via in-wm, which is satisfied
;;; only when its argument is already in working memory.  If vectors are
;;; accessed without in-wm, then they can be drawn in order to satisfy the
;;; condition.
;;;
;;; Although these operators achieve the goal of defining axes for a given
;;; body at a given time, the workbench currently provides no way of 
;;; associating drawn axes with any particular body or time. For this reason
;;; the action propositions posted for use by the help system leave out
;;; body and time, and the operators do not have body and time in their
;;; parameter lists. That means the axis drawing operators can only apply
;;; once to draw an axis at any particular rotation. This should be OK within
;;; the context of a single PSM application. However, if we needed axes for
;;; multiple bodies within a single psm application we could use variants
;;; that achieve the goal of choosing axes for a body by reusing existing 
;;; drawn axes for another body without drawing again.

;; don't be misled by name: really means "draw-vector-aligned-axes"
(defoperator draw-rotate-axes (?x-rotation)
  :specifications 
   "If the goal is to draw coordinate axes for use on some body's vectors,
       and there are any vectors on that body drawn at known angles
   then draw coordinate axes so that one of them is alligned with ?vector,"
  :preconditions (
   ; don't rotate axes if components are sought:
   (not (component-form))
   ; don't draw axis for system part if system axis already chosen
   ; use-system-axes will choose axes in this case.
   (not (axis-for ?sys ?t ?dontcare1 ?dontcare2)
        (part-of-sys ?b ?sys))
   ; (test (atom ?b))	; only for atomic bodies
   (setof (in-wm (vector ?b (at ?vector ?t) ?dir)) ?dir ?dirs)
   ; add 0 so standard axes always an option:
   (bind ?min-dirs (adjoin 0 (minimal-x-rotations ?dirs)))
   (any-member ?x-rotation ?min-dirs)
   (bind ?y-rotation (+ ?x-rotation 90))
   (debug "Setting axes for ~a at ~a: x=~a, y=~a~%" ?b ?t ?x-rotation ?y-rotation)
   )
  :effects (
   (draw-axes ?b ?t ?x-rotation) ; action proposition for helpsys gives x dir
   (axis-for ?b ?t x ?x-rotation)
   (axis-for ?b ?t y ?y-rotation)
   (assume axis-for ?b ?t x ?x-rotation)
   (assume axis-for ?b ?t y ?y-rotation)
  )
  :hint
  ((point (string "Can you think of a good direction to set the coordinate axes?"))
   (teach (minilesson "mini_choose_axes.htm")
          (kcd "draw-rotate-axes")
	  (string "Although you can choose any rotation for the axes and still get a correct answer, the algebra is much simpler if you rotate the axes so at least one vector is parallel to an axis.  The more vectors that are parallel to axes, the simpler the algebra.  More importantly, if the sought quantity is a vector, then making an axis parallel to it will usually simplify the math considerably."))
   (bottom-out (string "~:[Draw~;Rotate~] the coordinate axes setting the x axis at ~a degrees." (rotate-existing-axes) ?x-rotation))
   ))

(defun rotate-existing-axes ()
"TRUE at help time if should rotate axes rather than drawing new ones"
 (and (axes-drawnp)                   ; have already drawn at least one
      (not nsh-multi-axis-problemp))) ; only one is required for solution 

(defoperator use-system-axes (?b ?t ?x-rotation)
   :specifications 
   "If the goal is to choose an axis for a body b and we have already drawn an
   axis for a many-body system containing b, then use the system's axis
   as the axis for b."
  :preconditions (
    (in-wm (axis-for (system . ?bodies) ?t x ?x-rotation))
    (test (part-of-sys ?b `(system ,@?bodies)))
    (in-wm (axis-for (system . ?bodies) ?t y ?y-rotation))
  )
  :effects (
    (axis-for ?b ?t x ?x-rotation)
    (assume axis-for ?b ?t x ?x-rotation)
    (axis-for ?b ?t y ?y-rotation)
    (assume axis-for ?b ?t y ?y-rotation)
    (axis-for ?b ?t z 0)  ; z axis always has zero tilt (really = out-of).
  )
  ; no point to hints since no entry made by this operator
  ; :hint
  ;((point (string "You already have an axis for the system containing ~a." ?b))
  ; (teach (string "If you already have defined axes for a system of bodies, and you want axes for one of its constitutents, then the math is generally simpler if you use the same coordinate system.")))
   )

;;; =================== defining component variables =============
;;; When writing a compo equation, the code will call (variable <var>
;;; <quantity>) with <quantity> bound in order to fetch a variable
;;; that denotes that quantity.  This operator defines such variables.
;;;
;;; On the Andes interface, component variables are automatically
;;; defined whenever both an axis and a vector are drawn. Thus we
;;; ensure axes and vectors are drawn in the preconditions here.
;;;
;;; Because the component variables are defined automatically by the
;;; workbench, no hints are necessary on this operator.
;;;
;;; Normally, the psm that needs component variables will ensure that
;;; they have already been drawn before the component variable is needed,
;;; so these subgoals will usually be satisfied in working memory.
;;; But in component-form problems, some operator may have to be used 
;;; to enter the given components, and this will have to draw the vector 
;;; and axes to define the variables. To use this operator we would have
;;; to take out "in-wm" on these preconds. One issue is that it may
;;; is necessary to pick a time to associate with the axis if we have
;;; to draw it. [The time an axis is chosen "for" is not necessarily the
;;; time on the vector but more like the time on the main psm -- e.g
;;; in (lk block (1 2) time on the axis will be (1 2) while we still
;;; draw instantaneous vector at 1.] For this reason we define another op
;;; to achieve axes for writing given compos for component form problems.
;;; !!! we should just have a common set of operators that draw axes as needed
;;; in all cases rather than making assumptions about when they will be 
;;; called.

(defoperator define-compo (?var)
  :specifications "
   If there is an axis defined
      and there is a vector defined
   then define a component variable for the vector along the axis"
  :preconditions
  ((in-wm (vector ?b (at ?vector ?t) ?dir))
   (in-wm (axis-for ?b ?t-axis ?xyz ?rot)) ;; NB: may have different time than vector
   (not (variable ?dont-care (at (compo ?xyz ?rot ?vector) ?t)))
   ; fetch vector's mag var for building compo var name only. 
   (in-wm (variable ?v-var (at (mag ?vector) ?t)))  
   (bind ?var (format-sym "~Ac_~A_~A" ?xyz ?v-var ?rot))
   ;;(debug "Defining var for (at (compo ~a ~a ~a) ~a).~%" ?xyz ?rot ?vector ?t)
   )
  :effects
  ((variable ?var (at (compo ?xyz ?rot ?vector) ?t))))

; following is needed to introduce compo vars when writing equations for 
; given vector components in compo-form solutions.  It doesn't require that
; vectors and axes be drawn earlier but draws them as needed. We restrict it 
; to compo-form solutions to keep from overdtermining the compo-var-defining 
; in other problems. It could perhaps replace define-compo entirely though.
(defoperator define-compo2 (?var)
  :specifications 
   "If you need a compo variable and no axis and vector have been drawn,
   then draw an axis, draw the vector  
   and use a component variable for the vector along the axis"
  :preconditions
   ((component-form) ; limit to component-form  stuff
   ; need to bind body for following, so get it from vector term. !!! assumes
   ; principal body can always be found first after vectype
   ; change -- just get it from drawn vector
   ;(bind ?b (second ?vector))
   ; draw the vector
   (vector ?b (at ?vector ?t) ?dir)
   ; get axes to use for vector's body and time, most likely by drawing them
   (axis-for ?b ?t ?xyz ?rot)
   ; fetch vector's mag var for building compo var name only. 
   (in-wm (variable ?v-var (at (mag ?vector) ?t)))  
   (bind ?var (format-sym "~Ac_~A_~A" ?xyz ?v-var ?rot))
   ;;(debug "Defining var for (at (compo ~a ~a ~a) ~a).~%" ?xyz ?rot ?vector ?t)
   )
  :effects
  ((variable ?var (at (compo ?xyz ?rot ?vector) ?t))))

;;; =================== Generic: Optional steps =============================
;;;
;;; A goal of form (optional ?goal-form) is one that can be skipped.
;;; The help system will likely want to deal with these subgoals specially
;;; when giving help.  Here we define two generic operators, do-optional-step 
;;; and skip-optional-step, to provide two ways of achieving one of these 
;;; forms: one by achieving the embedded goal, the other by just asserting it 
;;; achieved without doing it. 
;;;
;;; Note ?goal will be bound to some more determinate proposition by 
;;; unification with effects when these operators are invoked. It must
;;; be fully grounded so it can be added to wm in the skip case.

(defoperator do-optional-step (?goal)
  :specifications "If you have an optional step to do then do it"
  :preconditions ( 
      ?goal ; embedded goal proposition to be achieved
  )
  :effects ( (optional ?goal) ))

(defoperator skip-optional-step (?goal)
  :specifications "let's not and say we did"
   :effects ( (optional ?goal) ))

;;; =================== Generic: Draw each requested vector =============================
;;;
;;; A goal of form (draw-vectors . ?vector-list) gives a list of vector quantities
;;; to draw. This is a convenience used for batching a list of vectors
;;; into a single goal to be the sought for a non-quantititive problem. That
;;; is needed by our implementation so we can have a single "done" button to
;;; mean that all parts are done, since our implementation associates buttons
;;; with soughts.  May not be needed if we fix our implementation to 
;;; understand a button meaning "done-all-parts".
;;; Used on qualitative magnetism problems mag1a, mag1b
(defoperator draw-required-vectors (?vector-list)
   :preconditions ( (foreach ?vector ?vector-list
                         (vector ?b ?vector ?dir)) )
   :effects ( (draw-vectors ?vector-list) ))


;;; =================== Generic: Multiple choice answer =============================
;;;
;;; This is just a hack to enable simple multiple choice questions within our 
;;; problem/solution graph format. Multiple choice questions coded this way
;;; will not have any help.  The problem soughts will just be the goals of
;;; picking the correct multiple choice answers, of the form
;;;      (choose-answer question-id correct-choice)
;;; Different questions can be distinguished by ordinal position within
;;; list of soughts.
;;; !!! Someday we may want to extend this to enable some helpful feedback on 
;;; some wrong answers, say.
(defoperator select-mc-answer (?question-id)
  ; no preconditions!
  :effects ((choose-answer ?question-id ?correct-choice)))

;; ===== Generic knowledge about times and constant values ========

;; Equal quantities: this is a generic operator that writes the
;; equality between scalar quantities in cases where it can be determined
;; that two differently-defined quantities are equal. In some problems
;; this may be given or derived by special rules from the problem situation, 
;; e.g.  in a round trip, distance travelled out = distance travelled back.
;; We use the generic "equals" rather than writing out the specific equality
;; first, so this info can be put in the givens; and second, so that it can
;; be used to mark cases where the substitution of equal quantities may be 
;; made by the student in the head. In cases where the equality is based on a 
;; fundamental principle like Newton's Third Law we label it as such and
;; do not use the (equals ...) proposition.
;; Although most hints for equations are hung off the operator whose
;; effects include (eqn...), in this case, the hints are hung off the operator
;; whose effects include (equals ...).

(defoperator equality-contains (?quant)
  :preconditions 
   ((equals ?quant1 ?quant2)
   (test (not (equalp ?quant1 ?quant2))) ; i.e. different defs.
   (any-member ?quant (?quant1 
                       ?quant2))
   ; sort quants in id so A=B and B=A get same id.
   (bind ?quants (sort (list ?quant1 ?quant2) #'expr<)))
   :effects
   ((eqn-contains (equals . ?quants) ?quant)))

(defoperator write-equality (?quant1 ?quant2)
  :preconditions 
  ((variable ?v1 ?quant1)
   (variable ?v2 ?quant2))
  :effects 
  ((eqn (= ?v1 ?v2) (equals ?quant1 ?quant2)))
  :hint
  ((point (string "What do you know about the relation of ~A and ~A?" ?quant1 ?quant2))
   (bottom-out (string "You can write the equation ~A = ~A." (?v1 algebra) (?v2 algebra)))
  ))

; generic principle when given one quantity as a fraction of another
; Totally generic (like equals), can be used for any quantities
; Problem givens should specify
;     (fraction-of ?quant1 ?fraction ?quant2) 
; to mean quant1 = fraction*quant2

(def-psmclass given-fraction (given-fraction ?q1 ?q2)
  :complexity minor
  :english ("one quantity as given fraction of another")
  :eqnFormat ("val1 = fraction*val2"))

(defoperator given-fraction-contains (?sought)
  :preconditions (
		  ;; typically, this means fraction-of must be in
		  ;; the givens when defining a problem
		  (in-wm (fraction-of ?q1 ?fraction ?q2))
		  (any-member ?sought (?q1 ?q2))
		  )
  :effects ( (eqn-contains (given-fraction ?q1 ?q2) ?sought)
	     ))

(defoperator given-fraction (?q1 ?q2)
  :preconditions (
		  (in-wm (fraction-of ?q1 ?fraction ?q2))
		  (variable ?v1 ?q1)
		  (variable ?v2 ?q2)
		  (bind ?fracmult (if (> ?fraction 1) "multiple" "fraction"))
		  )
   :effects ( (eqn (= ?v1 (* ?fraction ?v2)) (given-fraction ?q1 ?q2)) )
   :hint (
	  (point (string "You can determine ~a as a ~a of ~a from the problem statement" ?q1 (?fracmult 'adj) ?q2)) ;declare as adjective in nlg.
	  (bottom-out (string "Write the equation ~A" 
			      ((= ?v1 (* fraction ?v2)) algebra)))
	  ))

;;
;; Summing of time intervals: 
;; duration (t02) = duration(t01) + duration (t12)
;;
(defoperator sum-times-contains (?quant)
  :preconditions (
  (time (during ?t0 ?t1))
  (time (during ?t1 ?t2))
  (time (during ?t0 ?t2))
  (any-member ?quant ((duration (during ?t0 ?t1))
  		      (duration (during ?t1 ?t2))
		      (duration (during ?t0 ?t2))))
  )
  :effects (
    (eqn-contains (sum-times ?t0 ?t1 ?t2) ?quant)
  ))

(defoperator write-sum-times (?t0 ?t1 ?t2)
  
  :preconditions (
   (variable ?t01-var (duration (during ?t0 ?t1)))
   (variable ?t12-var (duration (during ?t1 ?t2)))
   (variable ?t02-var (duration (during ?t0 ?t2)))
  )
  :effects (
   (eqn (= ?t02-var (+ ?t01-var ?t12-var)) (sum-times ?t0 ?t1 ?t2))
   )
  :hint
  ((point (string "There are three time intervals involve the points ~a, ~a and ~a.  The durations of these intervals are inter-related." (?t0 time) (?t1 time) (?t2 time)))
   (teach (kcd "write-sum-times")
          (string "Since the time interval [~a,~a] is equal to the union of time intervals [~a,~a] and [~a,~a], its duration must be the sum of their durations." 
		  (?t0 time) (?t2 time) (?t0 time) (?t1 time) (?t1 time) (?t2 time)))
   (bottom-out (string "Since ~a consists of the union of ~a and ~a, write the equation ~a."
		       (?t01-var algebra) (?t12-var algebra) (?t02-var algebra) 
		        ((= ?t02-var (+ ?t01-var ?t12-var)) algebra)))
   ))

;;; Following uses constancy of a quantity over a containing interval to
;;; propagate equality to any contained time.  Quantity may be anything.
;;; Equation asserts the value at any contained time is equal to the value 
;;; over the interval declared constant. 
;;; For this to be useful, the value of the quantity must be determinable 
;;; over the same interval as the one over which it is declared constant. 
;;; I.e. if you declare it constant over an interval then give the value at 
;;; some point inside the interval, this rule won't help.  We do this 
;;; to reduce the number of possible equalities to search for.
;;; Note also that endpoints are not included because intervals are open.
;;; Although the operator is generic, it is mainly to be used for acceleration, 
;;; over a time, which is the only thing we currently assert to be constant.
(defoperator inherit-constant-value (?quant ?t-constant ?t1)
  :preconditions (
    (constant ?quant ?t-constant)
    (time ?t1)
    (test (and (not (equalp ?t1 ?t-constant))
               (tinsidep ?t1 ?t-constant)))
  )
  :effects (
     (equals (at ?quant ?t1) (at ?quant ?t-constant))
     )
  :hint
  ((point (string "Notice that ~a is constant ~a." ?quant ?t-constant))
   (teach (string "If a quantity is constant over a time interval, then its value at any time inside the interval is equal to its value over the whole interval.")
	  (kcd "inherit-constant-value"))
   (bottom-out (string "Since ~a is constant ~a, and ~a is inside ~a, write the equation ~a=~a" 
		       ?quant ?t-constant (?t1 pp) ((at ?quant ?t-constant)) ((at ?quant ?t1))))
   ))

; this variant allows us to include endpoints in the interval over which the value is declared constant
; Specify (constant ?quant ?time inclusive) in givens for this form.
(defoperator inherit-constant-value2 (?quant ?t-constant ?t1)
  :preconditions (
    (in-wm (constant ?quant ?t-constant inclusive))
    (time ?t1)
    (test (and (not (equalp ?t1 ?t-constant))
               (tinsidep-include-endpoints ?t1 ?t-constant)))
  )
  :effects (
     (equals (at ?quant ?t1) (at ?quant ?t-constant))
     )
  :hint
  ((point (string "Notice that ~a is constant ~a." ?quant ?t-constant))
   (teach (string "If a quantity is constant over a time interval, then its value at any time inside the interval is equal to its value over the whole interval.")
	  (kcd "inherit-constant-value"))
   (bottom-out (string "Since ~a is constant ~a, and ~a is inside ~a, write the equation ~a=~a" 
		       ?quant ?t-constant (?t1 pp) ((at ?quant ?t-constant)) ((at ?quant ?t1))))
   ))

;; Following expands (constant (accel ?b) ?t) to derive constancy of 
;; magnitude and direction attributes. This rule functions a bit like a macro 
;; expansion, it exists to let us write more concise statements in terms of 
;; the vector quantity which are used in constant acceleration preconds and
;; then make use of it where needed to propagate values of vector magnitude 
;; or direction. 
;; Could be revised to work for any vector quantity.
(defoperator use-constant-accel (?b ?t-constant)
  :preconditions (
   (constant (accel ?b) ?t-constant)
   (object ?b)
  )
  :effects (
   (constant (mag (accel ?b)) ?t-constant)
   (constant (dir (accel ?b)) ?t-constant)
  ))

;;; ================= speed distance duration ===================
;;; These operators represent knowledge of the speed=distance/duration
;;; equation, which is often abbreviated sdd.  The first few operators
;; define the quantities and the other define the equations.

;;; this operator defines a variable for the duration of an interval.
;;; It expects to be given the interval via unification with its
;;; effect.  The author controls which times are relevant by including
;;; only the relevant ones in a 'time' proposition.

(defoperator define-duration (?interval)
  :specifications "
   If there is a time interval defined,
   then define a duration variable for it."
  :preconditions
   ((time ?interval)
    (test (time-intervalp ?interval))
    (not (variable ?dont-care (duration ?interval)))
    (bind ?var (format-sym "t_~A" (time-abbrev ?interval))))
  :effects (
    (variable ?var (duration ?interval))
    (define-var (duration ?interval))
  )
  :hint
  ((bottom-out (string "Use the variable definition tool (under 'variable' on the top menu bar) to define a variable for the duration of ~A." ?interval))
   ))

;;; This operator defines a speed variable.  Its only restriction is
;;; that there be an object and and an interval for it.  It expects to
;;; get these given to it by unification of a goal with its effects.
;;; Thus, it only produces a speed variable when there is a goal to
;;; have one.  

(defoperator define-speed (?b ?interval)
  :specifications "
   If there is time interval and an object,
   then you can define a speed of the object"
  :preconditions
   ((time ?interval)
    (test (time-intervalp ?interval))
    (object ?b)
    (not (variable ?dont-care (at (speed ?b) ?interval)))
    (bind ?var (format-sym "sp_~A_~A~A" ?b (second ?interval) (third ?interval))))
  :effects
  ((variable ?var (at (speed ?b) ?interval))
   (define-var (at (speed ?b) ?interval)))
  :hint
  ((bottom-out (string "Use the speed menu item under the Variables menu to define a variable for the speed of ~a ~a." ?b ?interval))
   ))

;; This operator defines a distance-travelled variable.  Same comments
;; as for the speed variable.

(defoperator define-distance (?b ?interval)
  :specifications "
   If there is a time interval and an object,
   then you can define a distance variable for the object."
  :preconditions
  ((time ?interval)
   (test (time-intervalp ?interval))
   (object ?b)
   (not (variable ?dont-care (at (distance ?b) ?interval)))
   (bind ?var (format-sym "dist_~A_~A~A" ?b (second ?interval) (third ?interval))))
  :effects
  ((variable ?var (at (distance ?b) ?interval))
   (define-var (at (distance ?b) ?interval)))
  :hint
  ((bottom-out (string "Use the distance menu item under the Variables menu to define a variable for the distance travelled by ~a ~a." ?b ?interval))
   ))

;;; This operator represents knowing what kinds of quantities occur in
;;; the speed-distance-duration (sdd) equation.  Like all equations,
;;; this knowledge needs to be represented explicitly so that the seek
;;; operator can choose an equation that might contain the quantity it
;;; is seeking.

(defoperator sdd-contains (?quantity)
  :specifications "
   the speed-distance-duration equation (sdd) contains
      the speed of ?b and the distance it travelled during ?t,
      and the duration of ?t,
   where ?b is an object and ?t is a time interval."
  :preconditions
  ((any-member ?quantity 
	       ((at (speed ?b) ?t)
		(at (distance ?b) ?t)
		(duration ?t)))
   (object ?b)
   (time ?t)
   (test (time-intervalp ?t)))
  :effects
  ((eqn-contains (sdd ?b ?t) ?quantity)))


;;; This operator represents the procedure for writing the sdd
;;; equation.  The procedure is simply to define the 3 variables
;;; needed then write the equation. The body of interest may optionally be 
;;; drawn even though no vector diagram is being drawn on it for
;;; consistency with standard Andes problem-solving procedure.

(defoperator write-sdd (?b ?t)
  :specifications "
   If the goal is to write the sdd equations,
   then the subgoals are to define variables for speed, distance and duration,
   then write speed = distance / duration. "
  :preconditions
  ((variable ?s-var (at (speed ?b) ?t))
   (variable ?d-var (at (distance ?b) ?t))
   (variable ?t-var (duration ?t))
   ; nsh now requires body and axes if you ask for help, so there's little point
   ; making these 'optional' any more. At end so psm graph branches at end only.
   (optional (body ?b ?t))
   (optional (axis-for ?b ?t x 0))
   )
  :effects
  ((eqn (= ?s-var (/ ?d-var ?t-var)) (sdd ?b ?t)))
  :hint
  ((point (string "Can you write an equation in terms of speed, distance travelled and duration?"))
   (point (string "You need to write an equation for the speed of ~a ~a in terms of the distance travelled by ~a ~a and the duration of the interval ~a." ?b (?t pp) ?b (?t pp) ?t))
   (teach (string "The speed of an object is defined to be the distance traveled by the object divided by the duration of its trip.")
	  (kcd "speed"))
   (bottom-out (string "Because ~a is the speed of ~a ~a, and ~a is the distance travelled, and ~a is the duration of the trip, write ~a=~a/~a." 
		       (?s-var algebra) ?b (?t pp) (?d-var algebra) (?t-var algebra)
		       (?s-var algebra) (?d-var algebra) (?t-var algebra)))
   ))

;; Pythagorean theorem for distance, currently only used in Exkt6a. 
;; We use relative positions to specify the givens. 
;; We recognize it for displacement of b from points whose relative 
;; positions from some origin o are given and rbo1 and sb12 form a 
;; right angle so |rbo2|^2 = |rbo1|^2 + |db12|^2
;; That is not the most general form we could try but I'm not going to worry 
;; about it until we get a second problem that needs it.
(defoperator pyth-thm-contains (?sought)
   :preconditions (
     (any-member ?sought (
       (at (mag(relative-position ?b ?o)) ?t1)
       (at (mag(relative-position ?b ?o)) ?t2) 
       (at (mag(displacement ?b)) (during ?t1 ?t2))
                         ))
     ; angle r1 must be given, and must be able to determine angle d12
     (given (at (dir(relative-position ?b ?o)) ?t1) ?dir-r1)
     (displacement-dir ?b (during ?t1 ?t2) ?dir-d12)
     (test (perpendicularp ?dir-r1 ?dir-d12))
   )
   :effects ( 
     (eqn-contains (pyth-thm ?b ?o ?t1 ?t2) ?sought) 
   ))

(defoperator get-displacement-dir-from-given (?b ?t1 ?t2)
    :effects ( (displacement-dir ?b (during ?t1 ?t2) ?dir-d12) )
    :preconditions ( (given (at (dir(displacement ?b)) (during ?t1 ?t2)) ?dir-d12) ))

(defoperator get-displacement-dir-from-motion (?b ?t1 ?t2)
    :effects ( (displacement-dir ?b (during ?t1 ?t2) ?dir-d12) )
    :preconditions ( (motion ?b (during ?t1 ?t2) (straight ?dont-care ?dir-d12)) ))

(defoperator write-pyth-thm (?b ?o ?t1 ?t2)
  
  :preconditions (
    (variable ?r1 (at (mag(relative-position ?b ?o)) ?t1))
    (variable ?r2 (at (mag(relative-position ?b ?o)) ?t2)) 
    (variable ?d12 (at (mag(displacement ?b)) (during ?t1 ?t2)))
  )
  :effects (
    (eqn (= (^ ?r2 2) (+ (^ ?r1 2) (^ ?d12 2))) (pyth-thm ?b ?o ?t1 ?t2))
  )
  :hint
  ((point (string "Notice that there is a right triangle you can make use of."))
   (bottom-out (string "Write the equation ~A." 
		       ((= (^ ?r2 2) (+ (^ ?r1 2) (^ ?d12 2))) algebra)))
  ))

;;; Sum of two distances making up a line segment:
;;;
;;; If have collinear points A,B,C such that B is between A and C, then 
;;; distAC = distAB + distBC.  Since we now give spatial layout information
;;; in terms of relative position vectors, this equation is written in terms
;;; of magnitudes of relative position vectors.
;;;
;;; Right now this is only used in one problem (Exdt17a), so rather then
;;; spend time on geometry rules, we cheat and rely on a given proposition 
;;;       (distance-sum (?b3 ?b1) (?b2 ?b1) (?b2 ?b3))
;;; We write the equation using the following relative positions:
;;;          b1--------->b3
;;;          b1--->b2<---b3
;;; because those are what we need for the Earth-probe-moon problem. 
;;; We can spend time on a general operator when we encounter a need for it.
(defoperator sum-distance-contains (?sought)
  :preconditions (
     (in-wm (distance-sum (?b3 ?b1) (?b2 ?b1) (?b2 ?b3)))
     (any-member ?sought (
		      (at (mag(relative-position ?b3 ?b1)) ?t)
                      (at (mag(relative-position ?b2 ?b1)) ?t)
		      (at (mag(relative-position ?b2 ?b3)) ?t)
                  ))
  )
  :effects ( (eqn-contains (sum-distance ?b1 ?b2 ?b3 ?t) ?sought) )
)
(defoperator write-sum-distance (?b1 ?b2 ?b3 ?t)
  :preconditions (
    (variable ?r21 (at (mag(relative-position ?b2 ?b1)) ?t))
    (variable ?r23 (at (mag(relative-position ?b2 ?b3)) ?t))
    (variable ?r31 (at (mag(relative-position ?b3 ?b1)) ?t))
  )
  :effects (
    (eqn (= ?r31 (+ ?r21 ?r23)) (sum-distance ?b1 ?b2 ?b3 ?t))
  )
  :hint (
    (point (string "Because ~a, ~a and ~a lie along a line, you can use the fact that the total distance from ~a to ~a is the sum of the distance from ~a to ~a and the distance from ~a to ~a."
          ?b1 ?b2 ?b3   ?b1 ?b3    ?b1 ?b2     ?b3 ?b2))
    (bottom-out (string "Write the equation ~A"
                        ((= ?r31 (+ ?r21 ?r23)) algebra)))
  ))


;;; =============== bodies =======================================


;;; This  models using the Andes body tool.  The body tool both draws a body
;;; which is represented by the "body" predicate, and it defines a variable
;;; for the body's mass, which is represented by the "variable" predicate.
;;; The operator can be validly applied to any object and time, so those are
;;; specified in the conditions.  However, it will usually be called by
;;; unifying the (body ?b ?t) effect with a goal that provides bindings for
;;; the body and time.  Thus, most frequently, ?b and ?t will be bound at the
;;; conditions are subgoalled on. 
;;; 
;;; Because Andes won't let students define two variables for the same quantity,
;;; this operator checks to make sure that a mass variable has not already been defined
;;; for this body, either by the body tool or the variable definition tool. 

;; This assumes you can draw a body at *any* defined time, something which might be done to achieve
;; the goal of defining a (timeless) mass variable for a body. But this is not right for compound
;; bodies in momentum problems with splits or joins, in which the compound doesn't really exist
;; at all times in the problem. So we have a separate operator to draw compound bodies that checks
;; to make sure the time is not ruled out by specificiation of a split or join collision (see linmom).

(defoperator draw-body (?b ?t)
   :specifications " 
    If ?b is an object, 
       ?t is a time, 
       and there is no mass variable for ?b at ?t yet,
    then let ?b at ?t be a body, and 
       define a mass variable for ?b at time ?t."
  :preconditions
    ((object ?b)
     (test (atom ?b)) ; don't apply this to draw compound bodies.
     (time ?t)
     (not (variable ?dont-care (mass ?b)))
     (bind ?var (format-sym "m_~A" (body-name ?b))))
  :effects
   ((variable ?var (mass ?b))
    (body ?b ?t)) 	
  :hint
  ((point (string "It is a good idea to begin by choosing the body or system of bodies you are going to focus on."))
   (teach (string "First figure out which object you want to apply the principle to, and if necessary, what time or time interval to analyze.  Then use the body tool (looks like a dot) to indicate your selections."))
   (bottom-out (string "You should use the body tool to draw a body choosing ~a as the body and ~a as the time." ?b (?t moment)))
   ))

(defoperator draw-compound-body (?b ?t)
 :preconditions
    ((bind ?b `(compound ,@?bodies)) ; shorthand
     (object ?b)
     (time ?t)
     ; make sure body time not invalidated by split or join collision. We take compound's existence
     ; to include the appropriate endpoint of the collision open interval but not inside.
     (not (collision ?bodies (during ?t1 ?t2) ?type) 
          ; such that either:
          (or (and (eq ?type 'split) 
	           (not (tearlierp ?t `(during ,?t1 ,?t2)))) ; t is inside or after split
	      (and (eq ?type 'inelastic)
	           (tearlierp ?t ?t2)))) ; t is before or inside join 
     (not (variable ?dont-care (mass ?b)))
     (bind ?var (format-sym "m_~A" (body-name ?b))))
  :effects
   ((variable ?var (mass (compound . ?bodies)))
    (body (compound . ?bodies) ?t)) 	
  :hint
  ((point (string "It is a good idea to begin by choosing the body or system of bodies you are going to focus on."))
   (teach (string "First figure out which object you want to apply the principle to, and if necessary, what time or time interval to analyze.  Then use the body tool (looks like a dot) to indicate your selections."))
   (bottom-out (string "You should use the body tool to draw a body choosing ~a as the body and ~a as the time." ?b (?t moment)))
   ))

;;; ================================= Displacement =========

;; The operator draws displacement in the case where the object is
;; moving in a straight line during a time that includes the desired
;; time.  The desired time, ?t, is passed in via unification with the
;; effects.  It must be a time interval. 
;; 
;; As per the email discussion during the week of 10/16/2000, all vector drawing
;; tools will write an equation setting the direction variable to the value 
;; given in the box on the vector drawing tool.  This value should be either a 
;; number of degrees, a parameter or the constant unknown.  That constant 
;; unknown stands for the case where the student erases the number in the 
;; vector drawing dialog box and leaves it blank.
;; 
;; Because this should only write the direction variable equation when the 
;; value is not unknown, we'd need either two versions of this operator or 
;; conditional effects.  For now, only one version of the operator is 
;; supplied, and it  will only work when the direction value is known.
;; 

(defoperator draw-displacement-straight (?b ?t)
  :specifications "
   If an object is moving in a straight line over a time interval
   then draw a displacement vector for it in the direction of its motion."
  :preconditions
   ((time ?t)
    (test (time-intervalp ?t))
    (motion ?b ?t-motion (straight ?dontcare ?dir))
    (test (not (equal ?dir 'unknown)))  ; until conditional effects are implemented
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (displacement ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "s_~A_~A~A" (body-name ?b) (second ?t) (third ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var)))
  :effects
   ((vector ?b (at (displacement ?b) ?t) ?dir)
    (variable ?mag-var (at (mag (displacement ?b)) ?t))
    (variable ?dir-var (at (dir (displacement ?b)) ?t))
    (given (at (dir (displacement ?b)) ?t) ?dir)) 
  :hint
  ((point (string "Notice that ~a is moving in a straight line ~a." ?b (?t pp)))
   (teach (string "Whenever an object is moving in a straight line over a time interval, it has a displacement which is parallel to the direction of motion.")
	  (kcd "draw_displacement"))
   (bottom-out (string "Because ~a is moving in a straight line ~a, use the displacement tool to draw a displacement vector for it in direction ~a" ?b (?t pp) ?dir))
   ))


(defoperator draw-displacement-unknown (?b ?t)
  :specifications "
   If an object is moving in a straight line over a time interval in an unknown direction,
   then draw a displacement vector for it in the direction of its motion."
  :preconditions
   ((time ?t)
    (test (time-intervalp ?t))
    (motion ?b ?t-motion (straight ?dontcare unknown))
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (displacement ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "s_~A_~A~A" (body-name ?b) (second ?t) (third ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var)))
  :effects
   ((vector ?b (at (displacement ?b) ?t) unknown)
    (variable ?mag-var (at (mag (displacement ?b)) ?t))
    (variable ?dir-var (at (dir (displacement ?b)) ?t)))
  :hint
  ((point (string
	 "Notice that ~a is moving in a straight line ~a." ?b (?t pp)))
   (teach (string
	 "Whenever an object is moving in a straight line over a time interval, it has a displacement which is parallel to the direction of motion.  In this problem the exact direction of the displacement vector requires calculation to determine, so you can draw the vector at an approximately correct angle and leave the exact angle unspecified."))
   (bottom-out (string
		 "Draw the displacement of ~a ~a at an approximately correct angle, then erase the number in the direction slot to indicate that the exact direction is not specified." ?b (?t pp)))
    ))

; Might want rule to put out equation thetaD = thetaV for unknown 
; directions  if needed.

;; This operator draws a zero-length displacement vector for an object
;; that is at rest over an interval.  This would seldom be useful in practice.

(defoperator draw-displacement-at-rest (?b ?t)
  :specifications "If an object is at rest,
   then draw a zero displacement vector."
  :preconditions
   ((time ?t)
    (test (time-intervalp ?t))
    (motion ?b ?t-motion at-rest)
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (displacement ?b) ?t) ?dont-care))
    (bind ?mag-var (format-sym "s_~A_~A~A" (body-name ?b) (second ?t) (third ?t))))
  :effects
   ((vector ?b (at (displacement ?b) ?t) zero)
    (variable ?mag-var (at (mag (displacement ?b)) ?t)))
  :hint
  ((point (string "Notice that ~a is at rest ~a." ?b (?t pp)))
   (teach (string "Whenever an object is at rest during a time interval, it has a displacement of zero.")
	  (kcd "draw_zero_displacement"))
   (bottom-out (string "Because ~a is at rest ~a, use the displacement tool to draw zero length vector for it." ?b (?t pp)))
   ))

;; Following draws a zero-mag displacement vector for case where it is
;; given to be zero. This is given in cases of a round-trip where the body
;; returns to its original position. We don't have any special motion
;; specifier to entail this, it is just specified by zero displacement.

(defoperator draw-zero-displacement (?b ?t)
  :specifications 
   "If an object has no net change of position over an interval, then
   draw a zero displacement vector"
  :preconditions
   ((in-wm (given (at (mag(displacement ?b)) ?t) (dnum 0 ?units)))
    (not (vector ?b (at (displacement ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "s_~A_~A~A" (body-name ?b) (second ?t) (third ?t))))
  :effects
   ((vector ?b (at (displacement ?b) ?t) zero)
    (variable ?mag-var (at (mag (displacement ?b)) ?t)))
   :hint
   ((bottom-out (string "Since the problem specifies that the displacement of ~a is zero, just draw a zero-length vector for it." ?b))
    ))

;; This operator draws displacement at a given direction. This is needed
;; for problems like the bumblebee where the trajectory over the interval
;; is irregular but the net displacement direction is known.

(defoperator draw-displacement-given-dir (?b ?t)
  :specifications 
   "If you are given the direction of a net displacement over an interval
   then draw a displacement vector for it in the direction of its motion."
  :preconditions
   ((in-wm (given (at (dir(displacement ?b)) ?t) ?dir))
    (test (not (equal ?dir 'unknown)))  
    (test (time-intervalp ?t))
    (not (vector ?b (at (displacement ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "s_~A_~A~A" (body-name ?b) (second ?t) (third ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var)))
  :effects
   ((vector ?b (at (displacement ?b) ?t) ?dir)
    (variable ?mag-var (at (mag (displacement ?b)) ?t))
    (variable ?dir-var (at (dir (displacement ?b)) ?t))
    (given (at (dir (displacement ?b)) ?t) ?dir)
    ; Because dir is problem given, find-by-psm won't ensure implicit eqn
    ; gets written. Given value may not be used elsewhere so ensure it here.
    (implicit-eqn (= ?dir-var ?dir) (at (dir (displacement ?b)) ?t))
    ) 
   :hint
   ((point (string "The problem specifies the displacement of ~a ~a." ?b (?t pp)))
    (teach (kcd "draw_displacement")
	   (string "The displacement of an object is a vector from its starting point to its ending point.  It doesn't matter what path the object took.  Only the two points matter.  The problem gives you that information."))
    (bottom-out (string "The problem specifies that the displacement of ~a ~a is at ~a, so just draw a displacment vector oriented at ~a." ?b (?t pp) ?dir ?dir))
    ))

;; This operator draws net displacement at an unknown angle for a 2D 
;; projectile trajectory if the direction of net displacement is 
;; not given. 

(defoperator draw-displacement-projectile (?b ?t)
  :specifications 
   "If you don't know the direction of a net displacement over an interval
   then draw a displacement vector for it at an unspecified direction"
  :preconditions
   ((motion ?b ?t (curved projectile . ?dontcare))
    (not (given (at (dir(displacement ?b)) ?t) ?dir))
    (test (time-intervalp ?t))
    (not (vector ?b (at (displacement ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "s_~A_~A~A" (body-name ?b) (second ?t) (third ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var)))
  :effects
   ((vector ?b (at (displacement ?b) ?t) unknown)
    (variable ?mag-var (at (mag (displacement ?b)) ?t))
    (variable ?dir-var (at (dir (displacement ?b)) ?t)))
   :hint
   ((point (string "You need to introduce a term for the displacement of ~a ~a." ?b (?t pp)))
    (teach (string "The displacement of an object is a vector from its starting point to its ending point.  It doesn't matter what path the object took.  Only the two points matter. In this problem the exact direction of the net displacement vector requires calculation to determine, so you can draw the vector at an approximately correct angle and leave the exact angle unspecified."))
    (bottom-out (string "Draw the displacement of ~a ~a at an approximately correct angle, then erase the number in the direction slot to indicate that the exact direction is not specified."
			?b (?t pp)))
    ))

;; This operator draws a net displacement vector at an unknown angle when we have no other
;; information about it -- no given net displacement direction and no motion spec that we can
;; use to apply a more specific operator. Needed if net displacement is the sought as in Exvec1a.
;; No simple way to make sure this applies when nothing else does short of negating all other's 
;; preconditions.  For now just trigger by complete absence of motion spec for object.
;; !!! We could try to use the same operator for this case as the projectile case.
(defoperator draw-unknown-net-displacement (?b ?t)
  :preconditions 
   ((not (motion ?b ?t-motion . ?dontcare))
    (not (given (at (dir(displacement ?b)) ?t) ?dir))
    (not (vector ?b (at (displacement ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "s_~A_~A~A" (body-name ?b) (second ?t) (third ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var)))
  :effects
   ((vector ?b (at (displacement ?b) ?t) unknown)
    (variable ?mag-var (at (mag (displacement ?b)) ?t))
    (variable ?dir-var (at (dir (displacement ?b)) ?t)))
   :hint
   ((point (string "You need to introduce a term for the displacement of ~a ~a." ?b (?t pp)))
    (teach (string "The displacement of an object is a vector from its starting point to its ending point.  It doesn't matter what path the object took.  Only the two points matter. In this problem the exact direction of the net displacement vector requires calculation to determine, so you can draw the vector at an approximately correct angle and leave the exact angle unspecified."))
    (bottom-out (string "Draw the displacement of ~a ~a at an approximately correct angle, then erase the number in the direction slot to indicate that the exact direction is not specified."
			?b (?t pp)))
   ))


;;; ================================= Velocity ===================
;;; These operators translate the motion of the object, which is given
;;; in the problem statement, into a velocity vector.

;; This operator draws a zero velocity vector because the object is at
;; rest during a time period that incloses the desired time period.  This
;; assumes that the desired time period and body are passed in via
;; unification with an effect. 

(defoperator draw-velocity-at-rest (?b ?t)
  :specifications 
   "If there is an object,
     and it is at rest at a certain time,
   then its velocity at that time is zero."
  :preconditions
   ((time ?t)
    (motion ?b ?t-motion at-rest)
    (test (tinsidep ?t ?t-motion))
    (bind ?mag-var (format-sym "v_~A_~A" ?b (time-abbrev ?t))))
  :effects
   ((vector ?b (at (velocity ?b) ?t) zero)
    (variable ?mag-var (at (mag (velocity ?b)) ?t))
    (given (at (mag (velocity ?b)) ?t) (dnum 0 |m/s|)))
  :hint
   ((point (string "Notice that ~a is at rest ~a." ?b (?t pp)))
    (teach (kcd "draw_zero_velocity")
           (string "When an object is at rest, its velocity is zero.")) ; too simple for a kcd
    (bottom-out (string "Because ~a is at rest ~a, use the velocity tool to draw a zero-length velocity vector for it." ?b (?t pp)))
    ))

;;
;; This draws zero velocity for object momentarily at rest at an instant
;; This is a weaker statement than "at-rest" since it doesn't entail
;; anything about the acceleration at the instant. We use this for
;; objects like tossed objects at the apex which have zero velocity
;; are accelerating, so that we don't derive accel zero for them.
;; In the future might want projectile motion rule to handle this case.
;;
(defoperator draw-velocity-momentarily-at-rest (?b ?t)
  :specifications 
   "If there is an object,
     and it is momentarily at rest at a certain instant,
   then its velocity at that time is zero."
  :preconditions
   ((time ?t)
    (motion ?b ?t-motion momentarily-at-rest)
    (test (tinsidep ?t ?t-motion))
    (bind ?mag-var (format-sym "v_~A_~A" ?b (time-abbrev ?t))))
  :effects
   ((vector ?b (at (velocity ?b) ?t) zero)
    (variable ?mag-var (at (mag (velocity ?b)) ?t))
    (given (at (mag (velocity ?b)) ?t) (dnum 0 |m/s|)))
  :hint
   ((point (string "Notice that ~a is momentarily at rest ~a." ?b (?t pp)))
    (teach (string "When an object is at rest even momentarily, its velocity at that moment is zero.")
	   (kcd "draw_zero_velocity"))
    (bottom-out (string "Because ~a is at rest ~a, use the velocity tool to draw a zero-length velocity vector for it." ?b (?t pp)))
    ))

;; This operator draws a non-zero velocity vector along the line of
;; motion because the object is moving in a straight line during a time
;; period that includes the desired time, which was passed in via the
;; effects. 

(defoperator draw-velocity-straight (?b ?t)
  :specifications 
  "If an object is moving in a straight line at a certain time,
   then its velocity at that time is non-zero and in the same direction
     as its motion."
  :preconditions
  ((time ?t)
   (motion ?b ?t-motion (straight ?dontcare ?dir))
   (test (not (equal ?dir 'unknown)))	; until conditional effects are implemented
   (test (tinsidep ?t ?t-motion))
   (not (vector ?b (at (velocity ?b) ?t) ?dir))
   (bind ?mag-var (format-sym "v_~A_~A" (body-name ?b) (time-abbrev ?t)))
   (bind ?dir-var (format-sym "O~A" ?mag-var)))
  :effects
  ((vector ?b (at (velocity ?b) ?t) ?dir)
   (variable ?mag-var (at (mag (velocity ?b)) ?t))
   (variable ?dir-var (at (dir (velocity ?b)) ?t))
   (given (at (dir (velocity ?b)) ?t) ?dir))
  :hint
  ((point (string "Notice that ~a is moving in a straight line ~a." ?b (?t pp)))
   (teach (string "Whenever an object is moving in a straight line, it has a velocity in the same direction as its motion.")
	  (kcd "draw_nonzero_velocity"))
   (bottom-out (string "Because ~a is moving in a straight line ~a, draw a non-zero vector in direction ~a." ?b (?t pp) (?dir adj)))
   ))

(defoperator draw-velocity-straight-unknown (?b ?t)
  :specifications 
  "If an object is moving in a straight line at a certain time,
   then its velocity at that time is non-zero and in the same direction
     as its motion."
  :preconditions
  ((time ?t)
   (motion ?b ?t-motion (straight ?dontcare unknown))
   (test (tinsidep ?t ?t-motion))
   (not (vector ?b (at (velocity ?b) ?t) ?dir))
   (bind ?mag-var (format-sym "v_~A_~A" (body-name ?b) (time-abbrev ?t)))
   (bind ?dir-var (format-sym "O~A" ?mag-var)))
  :effects
  ((vector ?b (at (velocity ?b) ?t) unknown)
   (variable ?mag-var (at (mag (velocity ?b)) ?t))
   (variable ?dir-var (at (dir (velocity ?b)) ?t)))
  :hint
  ((point (string "Notice that ~a is moving in a straight line ~a, although the exact direction of motion is unknown." ?b (?t pp)))
   (teach (string "Whenever an object is moving in a straight line, it has a non-zero velocity in the same direction as its motion.")
	  (kcd "draw_nonzero_velocity"))
   (bottom-out (string
		"Because ~a is moving in a straight line ~a in an unknown direction, draw a non-zero velocity vector for it in an approximately correct direction, then erase the number in the direction box to indicate that the exact direction is unknown." ?b (?t pp)))
   ))

;; This operator draws velocities for curved motion, where curved
;; motion includes both projectile, circular and other kinds of curves.
;; If the motion proposition in the problem statement mentions a time
;; point, then the direction of motion is tangent to the circle at that point.
;; Thus, that direction is also the velocity's direction. 

(defoperator draw-velocity-curved (?b ?t)
  :specifications 
   "If an object is moving along a curved at a certain time point,
   then its velocity is tangent to the curve at that time."
  :preconditions
   ((time ?t)
    (motion ?b ?t (curved ?dontcare (?dir ?dir-accel)))
    (test (not (equal ?dir 'unknown)))  ; until conditional effects are implemented
    (test (time-pointp ?t))
    (not (vector ?b (at (velocity ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "v_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var)))
  :effects
   ((vector ?b (at (velocity ?b) ?t) ?dir)
    (variable ?mag-var (at (mag (velocity ?b)) ?t))
    (variable ?dir-var (at (dir (velocity ?b)) ?t))
    (given (at (dir (velocity ?b)) ?t) ?dir))
  :hint
  ((teach (string "When an object is moving in a curve, its velocity at an instant of time is tangent to the curve.")
	  (kcd "draw-velocity-curved"))
   (bottom-out (string "Because ~a is moving in a curve ~a, and the tangent to the curve at that point is ~a, draw a non-zero velocity in direction ~a." ?b (?t pp) (?dir adj) (?dir adj)))
   ))

; This draws velocity for a 2d projectile trajectory at a point for which velocity
; direction is not given.
(defoperator draw-velocity-projectile-unknown (?b ?t)
  :preconditions
   ((time ?t)
    (motion ?b ?t-motion (curved projectile (unknown ?dontcare)))
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (velocity ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "v_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var)))
  :effects
   ((vector ?b (at (velocity ?b) ?t) unknown)
    (variable ?mag-var (at (mag (velocity ?b)) ?t))
    (variable ?dir-var (at (dir (velocity ?b)) ?t)))
  :hint
   ((point (string "You need to introduce a term for the velocity of ~a ~a." ?b (?t pp)))
    (teach (string "The velocity of a projectile is tangential to its parabolic trajectory. In this problem the exact direction of the velocity vector requires calculation to determine, so you can draw the vector at any angle and leave the exact angle unspecified."))
    (bottom-out (string "Draw the velocity of ~a ~a, then erase the number in the direction slot to indicate that the exact direction is not being specified." ?b (?t pp)))
    ))

; Following draws horizontal velocity for a 2D projectile at its maximum height.
; !!! Note we assume the curve is going from left to right. Should have this 
; in motion specs somehow but don't currently.
(defoperator draw-velocity-apex(?b ?t)
  :specifications "if a projectile is at the apex of parabolic flight then its velocity is horizontal at that point"
  :preconditions (
     ; make sure it's 2d motion, we might use "apex" for 1d toss as well.
     (motion ?b ?t-trajectory (curved projectile . ?dontcare))
     (apex ?b ?t)
     (test (tinsidep ?t ?t-trajectory))
     (not (vector ?b (at (velocity ?b) ?t) ?dir))
     (bind ?mag-var (format-sym "v_~A_~A" (body-name ?b) (time-abbrev ?t)))
     (bind ?dir-var (format-sym "O~A" ?mag-var))
     (bind ?dir '(dnum 0 |deg|))
  )
  :effects (
    (vector ?b (at (velocity ?b) ?t) ?dir)
    (variable ?mag-var (at (mag (velocity ?b)) ?t))
    (variable ?dir-var (at (dir (velocity ?b)) ?t))
    (given (at (dir (velocity ?b)) ?t) ?dir)
  )
  :hint (
    (point (string "Notice that ~A is at its maximum height ~A" ?b (?t pp)))
    (teach (string "When the height of a projectile is at its maximum, the vertical component of its velocity will be zero. Therefore it's velocity must lie entirely in the horizontal direction"))
    (bottom-out (string "Use the velocity tool to draw the velocity of ~a ~a at ~A" ?b (?t pp) ?dir))
  ))

;; Special to average velocity vector = displacement / t
;;
;; Average velocity is little used in our problems, it's mainly defined for 
;; basic problems like the bumblebee problem that test understanding the
;; difference between speed and avg. velocity.  In linear kinematics with 
;; constant acceleration, v_avg = (v0 + vf)/2 could be used with s = v_avg * t, 
;; but our solutions don't use this form of that equation so don't introduce 
;; this term.

;; Following operator draws the average velocity vector based on known 
;; direction of net displacement over the interval.  This is needed for case 
;; of irregular non-straight-line motion as in the bumblebee problem. 

(defoperator draw-avg-vel-from-displacement (?b ?t1 ?t2)
  :preconditions (
    ; only apply if no other motion spec for object?
    ; (not (motion ?b ?t-motion . ?motion-spec))
    (in-wm (given (at (dir (displacement ?b)) (during ?t1 ?t2)) ?dir))
    (test (not (equal ?dir 'unknown)))  
    (not (vector ?b (at (velocity ?b) (during ?t1 ?t2)) ?dontcare))
    (bind ?mag-var (format-sym "v_~A_~A" (body-name ?b) 
                                (time-abbrev (list 'during ?t1 ?t2))))
    (bind ?dir-var (format-sym "O~A" ?mag-var)))
  :effects
   ((vector ?b (at (velocity ?b) (during ?t1 ?t2)) ?dir)
    (variable ?mag-var (at (mag (velocity ?b)) (during ?t1 ?t2)))
    (variable ?dir-var (at (dir (velocity ?b)) (during ?t1 ?t2)))
    (given (at (dir (velocity ?b)) (during ?t1 ?t2)) ?dir)
    ; ensure implicit eqn comes out when dir is a problem given 
    (implicit-eqn (= ?dir-var ?dir) (at (dir (velocity ?b)) (during ?t1 ?t2)))
    )
  :hint
  ((teach (kcd "average_velocity_drawn")
	  (string "The average velocity during a time interval is just the displacement of the body over that time interval divided by the duration of the time interval.  Since displacement is a vector, so is average velocity, and they have the same direction."))
   (bottom-out (string "Draw an ~a average velocity vector for ~a ~a."
		       ?dir ?b ((during ?t1 ?t2) pp)))
   ))


;;
;; Average Velocity vector = Displacement over time.
;; Following operators find average velocity as a vector PSM.
;; These are mainly for problems that test understanding of definition
;; of average velocity. Still it could be used to find components of
;; average velocity if we want.

(defoperator avg-vel-vector-contains (?sought)
  :preconditions 
    ((any-member ?sought
	        ((at (mag (velocity ?b)) (during ?t1 ?t2))
		 (at (dir (velocity ?b)) (during ?t1 ?t2))
		 (at (mag (displacement ?b)) (during ?t1 ?t2))
		 (at (dir (displacement ?b)) (during ?t1 ?t2))
		 (duration (during ?t1 ?t2))))
    (object ?b)
    (time (during ?t1 ?t2)))
  :effects 
  ((vector-psm-contains (avg-velocity ?b (during ?t1 ?t2)) ?sought)
  ; since only one compo-eqn under this vector psm, we can just
  ; select it now, rather than requiring further operators to do so
  (compo-eqn-contains (avg-velocity ?b (during ?t1 ?t2)) avg-vel ?sought)))

(defoperator draw-avg-vel-diagram (?b ?t1 ?t2)
  
  :preconditions 
  ((not (vector-diagram (avg-velocity ?b (during ?t1 ?t2))))
   (body ?b (during ?t1 ?t2))
   (vector ?b (at (displacement ?b) (during ?t1 ?t2)) ?dir2)
   (vector ?b (at (velocity ?b) (during ?t1 ?t2)) ?dir1)
   (axis-for ?b (during ?t1 ?t2) x ?rot))
  :effects 
  ((vector-diagram (avg-velocity ?b (during ?t1 ?t2)))))

(defoperator write-avg-vel-compo (?b ?t1 ?t2 ?xy ?rot)
  
  :preconditions 
   ((variable ?d12_x  (at (compo ?xy ?rot (displacement ?b)) (during ?t1 ?t2)))
    (variable ?v12_x  (at (compo ?xy ?rot (velocity ?b)) (during ?t1 ?t2)))
    (variable ?t12    (duration (during ?t1 ?t2))))
  :effects (
   (eqn (= ?v12_x (/ ?d12_x ?t12))
            (compo-eqn avg-vel ?xy ?rot (avg-velocity ?b (?during ?t1 ?t2))))
   (eqn-compos 
            (compo-eqn avg-vel ?xy ?rot (avg-velocity ?b (?during ?t1 ?t2)))
             (?v12_x ?d12_x)))
  :hint (
   (point (string "What is the relationship between average velocity, displacement and duration?"))
    (teach (kcd "write_average_velocity_eqn")
	   (string "The average velocity vector is defined as the displacement vector divided by the duration. This can be applied component-wise to relate the components of average velocity to the components of displacement."))
    (bottom-out (string "Write the equation ~a"
			((= ?v12_x (/ ?d12_x ?t12)) algebra)))
  ))

#|
;; Magnitude of avg velocity: |V_avg| = |s| / t
;; This is a scalar equation for the magnitude only; however, writing
;; it will still require drawing the vectors in the right directions to define 
;; the variables.  We could make it a vector equation if we ever needed to 
;; solve by component equations vavg_x = d_x/t, vavg_y = d_y /t but we 
;; currently have no need of that. If we were linking to component equations 
;; for the displacement we're probably using linear kinematics anyway.
;; !!! should still allow students to use components here

(defoperator avg-velocity-contains (?sought)
   :preconditions 
    ((any-member ?sought  
                ((at (mag (displacement ?b)) (during ?t1 ?t2))
	         (at (mag (velocity ?b)) (during ?t1 ?t2))
	         (duration (during ?t1 ?t2)) ))
      (object ?b))
   :effects
    ((eqn-contains (avg-velocity ?b (during ?t1 ?t2)) ?sought)))

(defoperator write-avg-velocity (?b ?t1 ?t2)
   
   :preconditions (
     (optional (body ?b (during ?t1 ?t2)))
     (variable ?d-var (at (mag (displacement ?b)) (during ?t1 ?t2)))
     (variable ?v-var (at (mag (velocity ?b)) (during ?t1 ?t2)))
     (variable ?t-var (duration (during ?t1 ?t2)))
   )
   :effects ( 
	     (eqn (= ?v-var (/ ?d-var ?t-var)) (avg-velocity ?b (during ?t1 ?t2))))
   :hint
   ((point (string "Can you think of an equation that relates average velocity, displacement and duration?"))
    (teach (kcd "write_average_velocity_eqn")
	   (string "The average velocity is equal to the displacement divided by the duration."))
    (bottom-out (string "Write the equation ~a=~a/~a"
			(?v-var algebra) (?d-var algebra) (?t-var algebra)))
   ))
|#

;;; ============================ acceleration ====================================
;;; This section contains operators for determining whether acceleration is zero
;;; or non-zero, and what direction the non-zero accelerations are.

;; This operator draws a zero acceleration vector for a body that is
;; at rest during a time period that includes the desired time.  Because
;; the vector has zero length, no direction variable is defined for it.
;; Note this means "at-rest" should only be used for a time instant if
;; the acceleration is zero at that instant.

(defoperator accel-at-rest (?b ?t)
  :specifications 
   "If a body is a rest,
   then it has zero acceleration."
  :preconditions
   ((time ?t)
    (motion ?b ?t-motion at-rest)
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (accel ?b) ?t) zero))
    (bind ?mag-var (format-sym "a_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (debug "~&Drawing zero accel for at-rest ~a at ~a.~%" ?b ?t)
    )
  :effects
  ((vector ?b (at (accel ?b) ?t) zero)        
   (variable ?mag-var (at (mag (accel ?b)) ?t))
   (given (at (mag (accel ?b)) ?t) (dnum 0 |m/s^2|)))
  :hint
  ((point (string "Notice that ~a is at rest ~a." ?b (?t pp)))
   (teach (kcd "draw_accel_when_at_rest")
          (string "If a body is at rest throughout some time interval, its average acceleration during that interval is zero."))
   (bottom-out (string "Because ~a is at rest ~a, use the acceleration tool to draw a zero-length acceleration vector for it." ?b (?t pp)))
   ))


;; This operator draws a zero acceleration vector for a body that is
;; moving in a straight line at constant speed during a time period that
;; includes the desired time.  

(defoperator accel-constant-speed (?b ?t)
  :specifications 
   "If ?body is moving in a straight line with constant speed during ?time,
   then its acceleration during ?time is zero."
  :preconditions
   ((time ?t)
    (motion ?b ?t-motion (straight constant ?dontcare))
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (accel ?b) ?t) zero))
    (bind ?mag-var (format-sym "a_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (debug "Drawing zero accel vector for constant-speed ~b at ~t.~%" ?b ?t)
    )
  :effects
   ((vector ?b (at (accel ?b) ?t) zero)
    (variable ?mag-var (at (mag (accel ?b)) ?t))
    (given (at (mag (accel ?b)) ?t) (dnum 0 |m/s^2|)))
  :hint
  ((point (string "Notice that ~a is moving in a straight line at constant speed ~a" ?b (?t pp)))
   (teach (minilesson "mini_zero_accel.htm")
          (kcd "draw_accel_straight_constant_speed")
	  (string "When a body is moving in a straight line at constant speed, then it has constant velocity, and thus it has zero acceleration."))
   (bottom-out (string "Because ~a has constant velocity ~a, use the acceleration tool to draw a zero-length acceleration vector for it." ?b (?t pp)))
   ))


;; This operator draws an non-zero acceleration vector for a body that is moving
;; in a straight line and speeding up.  The motion descriptor's third argument is
;; the direction of the object's velocity. 

(defoperator draw-accelerating (?b ?t)
  :specifications 
   "If ?body is moving in a straight line during ?time,
      and it is speeding up,
      and the direction of motion ?direction,
   then draw a non-zero acceleration in ?direction during ?time."
  :preconditions
   ((time ?t)
    (motion ?b ?t-motion (straight speed-up ?dir))
    (test (not (equal ?dir 'unknown)))  ; until conditional effects are implemented
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (accel ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "a_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing ~a accel for ~a at ~a.~%" ?dir ?b ?t)
    )
  :effects
   ((vector ?b (at (accel ?b) ?t) ?dir)
    (variable ?mag-var (at (mag (accel ?b)) ?t))
    (variable ?dir-var (at (dir (accel ?b)) ?t))
    (given (at (dir (accel ?b)) ?t) ?dir))
   :hint
   ((point (string "Notice that ~a is moving in a straight line and speeding up ~a" ?b (?t pp)))
    (teach (minilesson "mini_speedup_accel.htm")
           (kcd "draw_accel_straight_speeding_up")
	   (string "When a body is moving in a straight line and speeding up, its acceleration is parallel to the line of motion."))
    (bottom-out (string "Because ~a is speeding up while moving in a straight line with direction ~a, you should use the acceleration tool to draw an acceleration for it ~a at direction ~a." ?b ?dir (?t pp) ?dir))
    ))

;; This draws an acceleration vector at an unknown direction for an object when we are given that there are at least two
;; forces acting on it (Exdt12b), but the exact direcction of net force will not be known until calculated.
;; in exact direction is unknown until components are calculated. !!! Might want operator and
;; hint specific to case where existence of more than one force in different directions is given. As it is it
;; will appear you are just given that there is acceleration in some straight line.
;; !!! For now, only applies if more than one *given* force. Could apply if more than one force simpliciter
;; Also doesn't check if they are in the same direction, in which case direction could be known.
(defoperator accel-unknown-net-force (?b ?t)
  :specifications 
   "If ?body is moving in a straight line during ?time,
      and it is subject to more than one given force,
   then draw a non-zero acceleration in ?direction during ?time."
  :preconditions
   ((time ?t)
    ; following tells us forces are not balanced, else would have at-rest
    (motion ?b ?t-motion (straight speed-up unknown))
    (test (tinsidep ?t ?t-motion))
    (setof (in-wm (given (at (dir (force ?b ?agent ?type)) ?t) ?force-dir))
           (force ?b ?agent ?type) ?given-forces)
    (test (>= (length ?given-forces) 2))
    ; !!! verify not all in same direction
    (not (vector ?b (at (accel ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "a_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing ~a accel for ~a at ~a.~%" ?dir ?b ?t)
    )
  :effects
   ((vector ?b (at (accel ?b) ?t) unknown)
    (variable ?mag-var (at (mag (accel ?b)) ?t))
    (variable ?dir-var (at (dir (accel ?b)) ?t)))
   :hint
   ((point (string "Can you tell whether the acceleration of ~a will be zero or non-zero?" ?b))
    (teach (string "When a body is subject to a net force it will have an acceleration parallel to the vector sum of all forces. In this problem you should be able to see that there will be a net force on ~A so it will have a non-zero acceleration. The exact direction of the acceleration vector requires calculation to determine, so you can draw the acceleration at an approximate angle and leave the exact angle unspecified." ?b))
    (bottom-out (string "Use the acceleration tool to draw the acceleration for ~a ~A an an approximately correct direction and erase the direction value in the dialog box to leave the exact direction unspecified." ?b (?t pp)))
    ))


(defoperator avg-accel-unknown (?b ?t)
  :specifications 
   "If ?body is moving in a straight line during ?time,
   then draw a non-zero acceleration in ?direction during ?time."
  :preconditions
   ((time ?t)
    ; following tells us forces are not balanced, else would have at-rest
    (motion ?b ?t-motion (straight speed-up unknown))
    (test (tinsidep ?t ?t-motion))
    ;next line to force rule to only work for vec3a
    (component-form)
    ; !!! verify not all in same direction
    (not (vector ?b (at (accel ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "a_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing ~a accel for ~a at ~a.~%" ?dir ?b ?t)
    )
  :effects
   ((vector ?b (at (accel ?b) ?t) unknown)
    (variable ?mag-var (at (mag (accel ?b)) ?t))
    (variable ?dir-var (at (dir (accel ?b)) ?t)))
   :hint
   ((point (string "Can you tell whether the acceleration of ~a will be zero or non-zero?" ?b))
    (teach (string "When a body is subject to a net force it will have an acceleration parallel to the vector sum of all forces. In this problem you should be able to see that there will be a net force on ~A so it will have a non-zero acceleration. The exact direction of the acceleration vector requires calculation to determine, so you can draw the acceleration at an approximate angle and leave the exact angle unspecified." ?b))
    (bottom-out (string "Use the acceleration tool to draw the acceleration for ~a ~A an an approximately correct direction and erase the direction value in the dialog box to leave the exact direction unspecified." ?b (?t pp)))
    ))



;; draw acceleration when all we are given is its direction, and have no
;; other specification about the motion. Used in simple vector problems.
(defoperator draw-accel-given-dir (?b ?t)
  :specifications 
   "If you are given the direction of acceleration at some time
   then draw an acceleration vector for it in the given direction."
  :preconditions
   ((in-wm (given (at (dir(accel ?b)) ?t-given) ?dir))
    (test (not (equal ?dir 'unknown)))  
    (test (tinsidep ?t ?t-given))
    ; make sure no other motion specification in problem for time
    ; !! Too strict, some motion specs leave accel dir out.
    (not (motion ?b ?t-motion . ?dontcare)
         (tinsidep ?t ?t-motion))
    (not (vector ?b (at (accel ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "a_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var)))
  :effects
   ((vector ?b (at (accel ?b) ?t) ?dir)
    (variable ?mag-var (at (mag (accel ?b)) ?t))
    (variable ?dir-var (at (dir (accel ?b)) ?t))
    (given (at (dir (accel ?b)) ?t) ?dir)
    ; Because dir is problem given, find-by-psm won't ensure implicit eqn
    ; gets written. Given value may not be used elsewhere so ensure it here.
    (implicit-eqn (= ?dir-var ?dir) (at (dir (accel ?b)) ?t))
    ) 
   :hint
   ((point (string "The problem specifies the direction of the acceleration of ~a ~a." ?b (?t pp)))
    (bottom-out (string "The problem specifies that the acceleration of ~a ~a is at ~a, so just draw an acceleration vector oriented at ~a." ?b (?t pp) ?dir ?dir))
    ))


;; This operator draws an non-zero acceleration vector for a body that is moving
;; in a straight line and slowing down.  The motion descriptor's third argument is
;; the direction of the object's velocity.  We reverse it here because the object
;; acceleration is in the opposite direction from its motion.

;; Note: we write out structured direction term in effects and to prevent
;; effect from unifying with NTL precond (vector ?b (at (accel ?b) ?t) zero). 
;; When we had (vector ... ?dir) this operator would be tried
;; with ?accel-dir bound to 'zero coming in, causing error when we 
;; attempt to bind ?accel-dir.
(defoperator draw-decelerating (?b ?t)
 :specifications 
   "If ?body is moving in a straight line and slowing down during ?time,
   then its acceleration is opposite its direction of motion."
  :preconditions
   ((time ?t)
    (motion ?b ?t-motion (straight slow-down (dnum ?motion-dir |deg|)))
    (test (not (equal ?motion-dir 'unknown)))  ; until conditional effects are implemented
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (accel ?b) ?t) ?dont-care))
    (bind ?mag-var (format-sym "a_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (bind ?accel-dir (mod (+ ?motion-dir 180) 360))
    (debug "~&Drawing ~a vector for accel of ~a at ~a.~%" ?accel-dir-val ?b ?t)
    )
  :effects
   ((vector ?b (at (accel ?b) ?t) (dnum ?accel-dir |deg|))
    (variable ?mag-var (at (mag (accel ?b)) ?t))
    (variable ?dir-var (at (dir (accel ?b)) ?t))
    (given (at (dir (accel ?b)) ?t) (dnum ?accel-dir |deg|)))
  :hint
  ((point (string "Notice that ~a is slowing down as it moves in a straight line ~a" ?b (?t pp)))
   (teach (minilesson "mini_slowdown_accel.htm")
          (kcd "draw_accel_straight_slowing_down")
	  (string "When a body is slowing down as it moves in a straight line, it is decelerating, which means that its acceleration is in the opposite direction from its motion."))
   (bottom-out (string "Because ~a is slowing down as it moves in a straight line, draw an acceleration vector for it ~a.  It should have a direction of ~a because that is the opposite direction from its motion." ?b (?t pp) ?accel-dir))
   ))
  

;; This operator draws the acceleration vector for a freely falling body. 
;; This must be given in the problem statement as (free-fall body time)
;; The acceleration is non-zero straight down, on the assumption that
;; the relevant planet is always straight down in the diagram.
;; The free-fall law will specify an equation for the magnitude of the 
;; acceleration
(defoperator draw-free-fall-acceleration (?b ?t)
  :specifications 
   "If ?body is in free-fall during ?time,
   then draw a non-zero acceleration straight down during ?time."
  :preconditions
   ((free-fall ?b ?t-motion)
    (time ?t)
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (accel ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "a_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing free-fall accel at 270 for ~a at ~a.~%" ?b ?t)
    )
  :effects
   ((vector ?b (at (accel ?b) ?t) (dnum 270 |deg|))
    (variable ?mag-var (at (mag (accel ?b)) ?t))
    (variable ?dir-var (at (dir (accel ?b)) ?t))
    (given (at (dir (accel ?b)) ?t) (dnum 270 |deg|))
    (constant (accel ?b) ?t)
    ;; can't mkae use of this easily, endpoints not included in interval
    ;; and we only inherit constant values from wider intervals to sub-interval
    ;; (constant (compo x 0 (velocity ?b)) ?t)
   )
   :hint
   ((point (string "Notice that ~a is a freely falling body ~a" ?b (?t pp)))
    (teach (kcd "draw_accel_freefall")
	   (string "When a body is in free fall, it undergoes acceleration due to gravity directed toward the center of the planet exerting the gravitational force on it. This will be straight down in the diagrams for Andes problems."))
    (bottom-out (string "Because ~a is accelerating due to gravity, you should use the acceleration tool to draw an acceleration for it ~a in the direction 270 degrees." ?b (?t pp)))
    ))

;;
;; free-fall equation: acceleration = g
;;
(defoperator free-fall-accel-contains (?quantity)
  :specifications 
  "if an object is in free-fall near a planet during an interval, 
  then the equation for free-fall acceleration may be used to relate
  the body's acceleration and the gravitational acceleration for the planet"
  :preconditions
  ((any-member ?quantity
	       ((at (mag (accel ?b)) ?t)
		(gravitational-acceleration ?planet)))
   (free-fall ?b ?t)
   (near-planet ?planet))
  :effects
  ((eqn-contains (free-fall-accel ?b ?t) ?quantity)))

;;; This operator writes the equation a = g, where a is the magnitude of the 
;;; acceleration of the body. g is a variable for the gravitational accel
;;; of the relevant planet.
(defoperator write-free-fall-accel (?b ?t)
  
  :specifications 
  "if an object is in free-fall near a planet during an interval, 
  then for any interior time period,
     the magnitude of its acceleration equals the gravitational acceleration for
     that planet"
  :preconditions
  ((free-fall ?b ?t)
   (near-planet ?planet)
   (variable ?accel-var (at (mag (accel ?b)) ?t))
   (variable ?g-var (gravitational-acceleration ?planet))
   )
  :effects
  ((eqn (= ?accel-var ?g-var) (free-fall-accel ?b ?t)))
  :hint
  ((teach (string "If an object is in free-fall near a planet, its acceleration equals the acceleration due to gravity for that planet. The variable g is predefined in Andes to denote the magnitude of the gravitational acceleration, so you don't have to define g before you use it. However, you will ultimately have to enter an equation giving the value of g."))
   (bottom-out (string "Write the equation ~A." ((= ?accel-var ?g-var) algebra)))
   ))


;; This operator draws the instantaneous acceleration vector for a body in 
;; uniform circular motion.  This must be given in the problem statement as 
;; (motion body time-point (curved circular (tangent-dir accel-dir)))
;; where tangent-dir is the direction of the velocity at that time.
;; The acceleration is orthogonal to the velocity towards the center of the
;; circle; we include this direction in the motion spec because velocity
;; direction alone doesn't suffice to fully characterize the motion.
;; The centripetal acceleration law will specify an equation for the magnitude 
;; of the acceleration.
(defoperator draw-centripetal-acceleration (?b ?t)
  :specifications 
   "If ?body is in uniform circular motion during ?time,
   then draw a non-zero acceleration perpendicular to the velocity at ?time."
  :preconditions
   ((time ?t)
    (motion ?b ?t-motion (curved circular (?vel-dir
    					      (dnum ?accel-dir |deg|))))
    (test (tinsidep ?t ?t-motion))
    (test (time-pointp ?t))
    (not (vector ?b (at (accel ?b) ?t) ?dontcare))
    (bind ?mag-var (format-sym "a_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing centripetal accel at ~A for ~a at ~a.~%" ?b ?t ?accel-dir)
    )
  :effects
   ((vector ?b (at (accel ?b) ?t) (dnum ?accel-dir |deg|))
    (variable ?mag-var (at (mag (accel ?b)) ?t))
    (variable ?dir-var (at (dir (accel ?b)) ?t))
    (given (at (dir (accel ?b)) ?t) (dnum ?accel-dir |deg|)))
   :hint
   ((point (string "Notice that ~a is in uniform circular motion ~a" ?b (?t pp)))
    (teach (kcd "draw_accel_circular_constant_speed")
	   (string "When a body is in uniform circular motion, its acceleration is directed towards the center of the circle."))
    (bottom-out (string "Because ~a is in uniform circular motion you should use the acceleration tool to draw an acceleration for it ~a at direction ~A degrees." ?b (?t pp) ?accel-dir))
    ))


; for Pyrenees missle problem
; draw acceleration for a curved projectile trajectory when we are given its direction.
; This differs from draw-accel-given-dir since the dir is in the projectile motion spec
; Like draw-centripetal-accel in pulling dir from curved motion spec, differing only
; in that it does not assume uniform circular motion.
(defoperator draw-accel-projectile-given (?b ?t)
   :preconditions 
   ((time ?t)
    (motion ?b ?t-motion (curved projectile (?vel-dir
    					      (dnum ?accel-dir |deg|))))
    (test (tinsidep ?t ?t-motion))
    ; should we test that free-fall is not specified? Assume we won't
    ; have this motion spec in that case.
    (not (vector ?b (at (accel ?b) ?t) ?dontcare))
    (bind ?mag-var (format-sym "a_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing projectile accel at ~A for ~a at ~a.~%" ?b ?t ?accel-dir)
    )
  :effects
   ((vector ?b (at (accel ?b) ?t) (dnum ?accel-dir |deg|))
    (variable ?mag-var (at (mag (accel ?b)) ?t))
    (variable ?dir-var (at (dir (accel ?b)) ?t))
    (given (at (dir (accel ?b)) ?t) (dnum ?accel-dir |deg|)))
   :hint
    ((point (string "The problem specifies the direction of the acceleration of ~a ~a." ?b (?t pp)))
    (bottom-out (string "The problem specifies that the acceleration of ~a ~a is at ~a, so just draw an acceleration vector oriented at ~a." ?b (?t pp) ?dir ?dir))
    ))

;;
;; centripetal acceleration law: acceleration = v^2/r
;;
(defoperator centripetal-accel-contains (?quantity)
  :specifications 
  "if an object is in uniform circular motion during an interval, 
  then the equation for centripetal acceleration may be used to relate
  the body's acceleration and its velocity and radius of circular motion"
  :preconditions
  ((any-member ?quantity
	        ((at (mag (accel ?b))       ?t)
		 (at (mag (velocity ?b))    ?t)
		 (at (revolution-radius ?b) ?t)))
   (motion ?body ?t-motion (curved circular ?dontcare))
   (test (tinsidep ?t ?t-motion))
   )
  :effects
  ((eqn-contains (centripetal-accel ?b ?t) ?quantity)))

;;; This operator writes the equation a = v^2/r, where a is the magnitude of the
;;; acceleration of the body. 
(defoperator write-centripetal-accel (?b ?t)
  
  :specifications 
  "if an object is in uniform circular motion during an interval, 
  then for any interior time instant,
     the magnitude of its acceleration equals the velocity squared 
     divided by the radius of circular motion"
  :preconditions
   (
   (variable ?accel-var    (at (mag (accel ?b)) ?t))
   (variable ?vel-var      (at (mag (velocity ?b)) ?t))
   (variable ?radius-var   (at (revolution-radius ?b) ?t))
   )
  :effects
  ((eqn (= ?accel-var (/ (^ ?vel-var 2)
                         ?radius-var)) 
	(centripetal-accel ?b ?t)))
  :hint
  ((point (string "Notice that ~a is moving in uniform circular motion." ?b))
   (teach (kcd "centripetal_psm")
	  (string "If an object is in uniform circular motion, its acceleration equals the velocity squared divided by the radius of circular motion."))
   (bottom-out (string "Because ~a is moving in a circle of radius ~a with velocity ~a, its acceleration is ~a = ~a^2/~a."  ?b (?radius-var algebra) (?vel-var algebra) (?accel-var algebra) (?vel-var algebra) (?radius-var algebra)))
   ))

; define a variable for the revolution radius = radius of uniform circular
; motion. Note no time on this quantity in the workbench; OK, all our
; problems use the default time instant.
(defoperator define-revolution-radius (?b ?t)
  :preconditions (
  	(object ?b)
  	(time ?t)
	(bind ?radius-var (format-sym "r_~A_~A" ?b (time-abbrev ?t)))
  ) :effects (
  	(variable ?radius-var (at (revolution-radius ?b) ?t))
  	(define-var (at (revolution-radius ?b) ?t))
  ) : hint (
    (bottom-out (string "Use the Add Variable command to define a radius variable for ~A" ?b))
  ))

; Can optionally introduce variable for revolution radius by using a tool
; to put a radius graphic on the diagram. This is a special purpose tool, 
; not one of the vector drawing tools.  No properties of the drawing are 
; checkable.  It's just a graphic way of introducing the radius variable.
; Since we don't care about the difference, we just assimilate a drawn
; radius and a defined radius variable as the same entry. 

;;
;; period of uniform circular motion = 2*pi*r/v  
;;
;; Period is time to make one revolution. This equation is just a 
;; special case of sdd: time = distance/speed. But to use the sdd rule 
;; for this we would need to define a starting and ending time, and represent
;; the fact that the object makes one revolution in this interval, then add 
;; a rule to deduce that the distance travelled in this interval = 2*pi*r.
;; We would also need a rule that avg speed = mag velocity at any time for 
;; an object in circular motion.
;;
;; Note "period" quantity may also be used with respect to other sorts 
;; of periodic functions.  For waves, period = 1/f. 
;;
;; We don't have time on a period. The definition in terms of velocity 
;; allows it to be an instantaneous quantity -- time it *would* take object to 
;; make a complete revolution at its instantaneous speed at t. So period 
;; could change over time as speed does and object never needs to actually 
;; make a complete revolution in its period at a time.  In uniform circular
;; motion velocity is constant, so period could be defined for the interval 
;; of uniform circular motion.  However, in our circular motion problems we 
;; usually represent this constant state by analyzing a representative instant 
;; which is usually the only instant in the problem.  So we just assume that 
;; and leave out time.
;;
(defoperator period-circular-contains (?sought)
  :preconditions (
     (motion ?b ?t-circular (curved circular ?dontcare))
     (any-member ?sought (
                       (period ?b)
		       (at (revolution-radius ?b) ?t)
		       (at (mag (velocity ?b)) ?t)
                         ))
    (time ?t)
    (test (tinsidep ?t ?t-circular))
  )
  :effects (
   (eqn-contains (period ?b ?t circular) ?sought)
  ))

(defoperator write-period-circular (?b ?t)
   :preconditions (
      ; make sure body is drawn if it hasn't been drawn for something else
      (body ?b ?t)   ; time to choose is unclear, but probably only one
      (variable ?T-var    (period ?b))
      (variable ?r    (at (revolution-radius ?b) ?t))
      (variable	?v    (at (mag (velocity ?b)) ?t))
   )
   :effects (
     (eqn (= ?T-var (/ (* 2 $P ?r) ?v)) (period ?b ?t circular))
   )
   :hint (
      (teach (string "The period of an object in circular motion is the time to make one complete revolution. This time is equal to the distance travelled, which is 2*$p times the radius of the circle, divided by the speed."))
      (bottom-out (string "Write the equation ~A" 
                          ((= ?T-var (/ (* 2 $P ?r) ?v)) algebra)))
   )
)

(defoperator define-period-var (?b)
  :preconditions ( 
        (bind ?T-var (format-sym "T_~a" (body-name ?b)))
  )
  :effects (
      (variable ?T-var (period ?b))
      (define-var (period ?b))
   )
 :hint
  ((bottom-out (string "Use the Add Variable command located under 'variable' on the top menu bar and select Period to define a variable for the period of the motion of ~A." ?b))
   ))

;;; =========== For Simple Vector Arithmetic problems ==========================
;;;
;;; Following apply to any vectors for the purpose of our simple vector 
;;; arithmetic problems, which give vectors by components in unit vector
;;; notation and show a grid to enable drawing them at the right orientation 
;;; by counting grid boxes.  We have to put the numerical degree value in the 
;;; entry rounded to nearest integral degrees because the workbench sends that.
;;;
;;; It can be tricky to write reliable generic rules to operate on any 
;;; vector quantity if we need to destructure the vector term because 
;;; different quantities have different numbers of arguments. 
;;; We are pretty consistent in putting the principal body in the first 
;;; position, though, so (at (?vectype ?body . ?rest) ?time) should work
;;; with possibly empty ?rest, though it will also match non-vectors as well.  
;;; The following code works for kinematic properties of a body at 
;;; a time as used in our problems (velocity and accel), could have problems
;;; on other vectors if body is not in first position.
;;; The first arg of the vector proposition associates a vector with a body
;;; for the purposes of choosing axes to use for that vector's components.
;;;
(defoperator draw-vector-given-compos (?b ?vectype ?args ?t)
   :specifications "if you are given the components of a vector property of a body at a time and the vector grid is on in this problem, then draw it at atan2(vy, vx)"
   :preconditions (
     (vector-grid)
     (component-form)
     (given (at (compo x 0 (?vectype ?b . ?args)) ?t) (dnum ?xc ?units))
     (given (at (compo y 90 (?vectype ?b . ?args)) ?t) (dnum ?yc ?units))
     ; note we can only apply to vector attributes of body and time.
     (bind ?vector `(at (,?vectype ,?b . ,?args) ,?t)) ; for use in hints
     (not (vector ?b ?vector ?dir))
     ; !!! variable name may not be consistent with those generated elsewhere
     ; problem if this has to match up with name generated anywhere else.
     ; Also, generated name makes no use of ?args. 
     (bind ?mag-var (format-sym "~A_~A_~A" ?vectype (body-name ?b) (time-abbrev ?t)))
     (bind ?dir-var (format-sym "O~A" ?mag-var))
     (bind ?dir `(dnum ,(dir-from-compos ?xc ?yc) |deg|))
   )
   :effects (
    (vector ?b (at (?vectype ?b . ?args) ?t) ?dir)
    (variable ?mag-var (at (mag (?vectype ?b . ?args)) ?t))
    (variable ?dir-var (at (dir (?vectype ?b . ?args)) ?t))
    ;; Don't put out equation for thetaV since value is not exact, could 
    ;; lead to errors if given to algebraic solver with other equations.
    ;;(given (at (dir (?vectype ?b . ?args)) ?t) ?dir)
   )
   :hint (
    (point (string "You were given ~A in terms of its components." ?vector))
    (teach (string " Andes checks the direction of a drawn vector if it should be known.  The direction $qV of any vector V is related to its components by the formula tan($qV) = V_y / V_x.  Since you were given the horizontal and vertical components of the vector, can choose a scale and count lines on the grid to draw the vector with a slope equal to the ratio of the y component to the x component."))
    (bottom-out (string "Choose some scale and draw ~A by moving ~A units horizontally and ~A units vertically." ?vector ?xc ?yc))
   ))

;; following draws the sought vector in one of these grid-using problems
;; NB: As written, only works for one-argument vector types
(defoperator draw-sought-vector-unknown (?b ?vectype ?t)
   :preconditions (
    (vector-grid)
    (component-form)
    ; build expressions for vector and its attributes:
    (bind ?vector `(at (,?vectype ,?b) ,?t))
    (bind ?vector-xc (vector-xc ?vector))
    (bind ?vector-dir (vector-dir ?vector))
    ;; we test whether xc of vector is a problem sought. NOTE: This relies
    ;; on *cp* as always holding the current problem. This is not guaranteed
    ;; if problem solver is not invoked through sgg interface functions.
    ;; But there should be some way to access this info from the environment.
    (test (member ?vector-xc (problem-soughts *cp*) :test #'equal))
    ; make sure no motion spec that might enable vector to be drawn
    ; tighter test than actually correct, but should work for our problems.
    (not (motion ?b ?t-motion . ?dontcare))
    ; make sure vector dir not given, as in simple projection-only problems
    (not (given ?vector-dir (dnum ?dir |deg|)))
    (bind ?mag-var (format-sym "~A_~A_~A" ?vectype (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
   )
   :effects (
    (vector ?b (at (?vectype ?b) ?t) unknown)
    (variable ?mag-var (at (mag (?vectype ?b)) ?t))
    (variable ?dir-var (at (dir (?vectype ?b)) ?t))
   )
   :hint
   ((teach (string "In this problem the exact direction of the sought vector, ~A, requires calculation to determine. When a vector angle is not given, you should draw the vector at an unspecified angle. You do this by drawing the vector making your best approximation to the correct angle, then erasing the number in the direction slot of the subsequent dialog box to indicate that the exact angle is being sought." ?vector))
    (bottom-out (string "Draw ~a ~a at your best approximation to the correct angle, then erase the number in the direction slot to indicate that the exact direction is not specified."
			?b (?t pp)))
    ))


;;; ===================== linear kinematics ===================

(defoperator LK-vector-contains (?quantity)
  :specifications 
   "The lk equation potentially contains the duration and the
   the magnitude and direction of the initial and final velocity,
   acceleration and displacement."
  :preconditions
  ((any-member ?quantity
	       ((at (mag (velocity ?b)) ?t1)
		 (at (dir (velocity ?b)) ?t1)
		 (at (mag (velocity ?b)) ?t2)
		 (at (dir (velocity ?b)) ?t2)
		 (at (mag (accel ?b)) (during ?t1 ?t2))
		 (at (dir (accel ?b)) (during ?t1 ?t2))
		 (at (mag (displacement ?b)) (during ?t1 ?t2))
		 (at (dir (displacement ?b)) (during ?t1 ?t2))
		 (duration (during ?t1 ?t2))))
    (object ?b)
    (time (during ?t1 ?t2))
    ; only apply if accel known constant within interval we are using
    (constant (accel ?b) ?t-constant)
    (test (tinsidep `(during ,?t1 ,?t2) ?t-constant))
    )
  :effects
   ((vector-psm-contains (lk ?b (during ?t1 ?t2)) ?quantity)))



;;; ===================== linear kinematics fbd ================

;;; This unordered-and operator gets all/5 quantities needed for
;;; linear kinematics (lk) defined.  Even though only 4 of the 5
;;; quantities are usually needed for solving the problem, all 5 are
;;; defined anyway.  It's good practice for the student.  Since the
;;; drawing actions can be done in any order, they all have to be in
;;; the same condition.  However, the axis drawing condition has to be
;;; last because the code can only define component variables in the
;;; axis-drawing operator, and not in the vector drawing operators
;;; (Andes will define component variables with either tool, whichever
;;; comes second).  Moreover, we only request an x-axis since the
;;; other axes are drawn at the same time.

(defoperator draw-lk-fbd (?b ?t1 ?t2 ?rot)
  
  :specifications "
   If the goal is to draw a lk fbd,
   then draw the body, the initial and final velocity, 
      the acceleration, the displacement and axes"
  :preconditions
  ((not (vector-diagram (lk ?b (during ?t1 ?t2))))
   (body ?b (during ?t1 ?t2))
   (vector ?b (at (velocity ?b) ?t1) ?dir1)
   (vector ?b (at (velocity ?b) ?t2) ?dir2)
   (vector ?b (at (accel ?b) (during ?t1 ?t2)) ?dir3)
   (vector ?b (at (displacement ?b) (during ?t1 ?t2)) ?dir4)
   ;; (variable ?t-var (duration (during ?t1 ?t2)))
   (axis-for ?b (during ?t1 ?t2) x ?rot))
  :effects
   ((vector-diagram (lk ?b (during ?t1 ?t2))))
)

;;; =============== linear kinematics compo equations ==============
;;; The physicist do not want Andes to hint s=vf*t-0.5*a*t^2 (leaves
;;; out vi), so that equation is left out.  The other four are here,
;;; expressed with two operators each.  One lists the quantities
;;; contained in the equation, and the other writes the equation.


;;; This operator writes vf=vi+a*t.  That is, it leaves out displacement (s).

;;; Acceleration over an interval is interpreted as average acceleration.
;;; This is consistent with the labels in the Andes dialog boxes.
;;; We use the proposition (constant (accel ?b) (during ?t1 ?t2)) to 
;;; assert that the *instantaneous* acceleration is constant over each instant 
;;; in an interval. This can be deduced from the fact that the object is given 
;;; to be free-fall during an interval. In other cases it must often be given. 
;;;
;;; Where acceleration is known to be constant, as in most kinematics problems,
;;; the average acceleration will of course equal the constant instantaneous 
;;; acceleration at each point in the interval. However a few problems test the 
;;; application of the definition of average acceleration over intervals where 
;;; it is not known to be constant.
;;;
;;; All the other "lk" equations only apply where acceleration is constant thus 
;;; have to test for constancy of the acceleration over the interval before 
;;; applying.  But this equation defines average acceleration so can be applied 
;;; even if acceleration is not constant over interval, hence does not use any 
;;; such test. 
;;; 
;;; We have to be able to apply this equation in either case. However, if we
;;; are just using it to find average acceleration we shouldn't draw the
;;; displacement as required for an "lk" diagram. Therefore we use it as
;;; a child compo-eqn of two different vector psms -- as a child of the
;;; lk psm when accel is known constant, and as a child of the avg-accel psm
;;; when accel is not known constant.

(defoperator LK-no-s-contains (?quantity)
  :specifications 
   "Lists the quantities contained in vf = vi + a * t"
  :preconditions
  ((any-member ?quantity 
	       ((at (mag (velocity ?b)) ?t1)
		 (at (dir (velocity ?b)) ?t1)
		 (at (mag (velocity ?b)) ?t2)
		 (at (dir (velocity ?b)) ?t2)
		 (at (mag (accel ?b)) (during ?t1 ?t2))
		 (at (dir (accel ?b)) (during ?t1 ?t2))
		 ;;(at (mag (displacement ?b)) (during ?t1 ?t2))
		 ;;(at (dir (displacement ?b)) (during ?t1 ?t2))
		 (duration (during ?t1 ?t2))
		 ))
   ; only applies if accel is constant within interval we are using
   ; sought may not bind both times, so must choose endpoints of interval to try
   (constant (accel ?b) ?t-constant)
   (time (during ?t1 ?t2))	; ensure both endpoints to try bound
   (test (tinsidep `(during ,?t1 ,?t2) ?t-constant))
   )
  :effects
   ((compo-eqn-contains (lk ?b (during ?t1 ?t2)) lk-no-s ?quantity)))

(defoperator write-lk-no-s-compo (?b ?t1 ?t2 ?xyz ?rot)
  :specifications "
   writes vf=vi+a*t.  That is, it leaves out displacement (s)."
  
  :preconditions
   (; for 2D case, make sure accel compo doesn't vanish
    (in-wm (vector ?b (at (accel ?b) (during ?t1 ?t2)) ?accel-dir))
    (test (non-zero-projectionp ?accel-dir ?xyz ?rot))
    (variable ?vi-compo (at (compo ?xyz ?rot (velocity ?b)) ?t1))
    (variable ?vf-compo (at (compo ?xyz ?rot (velocity ?b)) ?t2))
    (variable ?a-compo  (at (compo ?xyz ?rot (accel ?b)) (during ?t1 ?t2)))
    (variable ?t (duration (during ?t1 ?t2))))
  :effects
  ((assume using lk-eqn ?b ?t1 ?t2 ?xyz ?rot)
   (eqn (= ?vf-compo (+ ?vi-compo (* ?a-compo ?t)))
	 (compo-eqn lk-no-s ?xyz ?rot (lk ?b (during ?t1 ?t2))))
    (eqn-compos (compo-eqn lk-no-s ?xyz ?rot (lk ?b (during ?t1 ?t2)))
		(?vi-compo ?vf-compo ?a-compo)))
  :hint
   ((point (string "Can you think of an equation that relates the components of average acceleration to those of the initial velocity, final velocity, and duration?"))
    (teach (kcd "write_lk_without_displacement")
	   (string "Acceleration is the rate of change of velocity. The average acceleration vector over some time is defined as the difference between initial and final velocity vectors divided by the duration. This definition can be be applied component-wise to relate ~A, ~A, ~A and ~A" (?vf-compo algebra) (?vi-compo algebra) (?a-compo algebra) (?t algebra)))
    (bottom-out (string "Write the equation ~a = ~a + ~a*~a" (?vf-compo algebra) (?vi-compo algebra) (?a-compo algebra) (?t algebra)))
    ))

;#| ; NOT in physics-lite  used in Pyrenees eval

;;; Writes the equation vf^2 = vi^2 + 2*a*s, which is lacking a duration.

(defoperator LK-no-t-contains (?quantity)
  :specifications "
   Lists the quantities contained in vf^2 = vi^2+2*a*s"
  :preconditions
  ((any-member ?quantity 
	       ((at (mag (velocity ?b)) ?t1)
		 (at (dir (velocity ?b)) ?t1)
		 (at (mag (velocity ?b)) ?t2)
		 (at (dir (velocity ?b)) ?t2)
		 (at (mag (accel ?b)) (during ?t1 ?t2))
		 (at (dir (accel ?b)) (during ?t1 ?t2))
		 (at (mag (displacement ?b)) (during ?t1 ?t2))
		 (at (dir (displacement ?b)) (during ?t1 ?t2))
		 ;;(duration (during ?t1 ?t2))
		 ))
   ; only applies if accel is constant within interval we are using
   ; sought may not bind both times, so must choose endpoints of interval to try
   (constant (accel ?b) ?t-constant)
   (time (during ?t1 ?t2))	; ensure both endpoints to try bound
   (test (tinsidep `(during ,?t1 ,?t2) ?t-constant))
   )
  :effects
   ((compo-eqn-contains (lk ?b (during ?t1 ?t2)) lk-no-t ?quantity)))

(defoperator write-lk-no-t-compo (?b ?t1 ?t2 ?xyz ?rot)
  :specifications "
   Writes the equation vf^2 = vi^2 + 2*a*s, which is lacking a duration."
  :preconditions
   (; for 2D case, make sure accel compo doesn't vanish
    (in-wm (vector ?b (at (accel ?b) (during ?t1 ?t2)) ?accel-dir))
    (test (non-zero-projectionp ?accel-dir ?xyz ?rot))
    (variable ?vi-compo (at (compo ?xyz ?rot (velocity ?b)) ?t1))
    (variable ?vf-compo (at (compo ?xyz ?rot (velocity ?b)) ?t2))
    (variable ?a-compo  (at (compo ?xyz ?rot (accel ?b)) (during ?t1 ?t2)))
    (variable ?s-compo  (at (compo ?xyz ?rot (displacement ?b)) (during ?t1 ?t2))))
  :effects
  ((assume using lk-eqn ?b ?t1 ?t2 ?xyz ?rot)
   (eqn (= (^ ?vf-compo 2) (+ (^ ?vi-compo 2) (* 2 ?a-compo ?s-compo)))
	        (compo-eqn lk-no-t ?xyz ?rot (lk ?b (during ?t1 ?t2))))
    (eqn-compos (compo-eqn lk-no-t ?xyz ?rot (lk ?b (during ?t1 ?t2)))
		(?vi-compo ?vf-compo ?a-compo ?s-compo)))
  :hint (
    (point (string "Do you know an equation relating the components of initial velocity, final velocity, acceleration, and displacement when acceleration is constant?"))
    (bottom-out (string "Write the equation ~A" ((= (^ ?vf-compo 2) (+ (^ ?vi-compo 2) (* 2 ?a-compo ?s-compo))) algebra)))
  ))

;;; Writes the equation s = vi*t + 0.5*a*t^2, which lacks vf

(defoperator LK-no-vf-contains (?quantity)
  :specifications "
   Lists the quantities contained in s = vi*t + 0.5*a*t^2"
  :preconditions
  ((any-member ?quantity 
	        ((at (mag (velocity ?b)) ?t1)
		 (at (dir (velocity ?b)) ?t1)
		 ;;(at (mag (velocity ?b)) ?t2)
		 ;;(at (dir (velocity ?b)) ?t2)
		 (at (mag (accel ?b)) (during ?t1 ?t2))
		 (at (dir (accel ?b)) (during ?t1 ?t2))
		 (at (mag (displacement ?b)) (during ?t1 ?t2))
		 (at (dir (displacement ?b)) (during ?t1 ?t2))
		 (duration (during ?t1 ?t2))
		 ))
   ; only applies if accel is constant within interval we are using
   ; sought may not bind both times, so must choose endpoints of interval to try
   (constant (accel ?b) ?t-constant)
   (time (during ?t1 ?t2))	; ensure both endpoints to try bound
   (test (tinsidep `(during ,?t1 ,?t2) ?t-constant))
   )
  :effects
   ((compo-eqn-contains (lk ?b (during ?t1 ?t2)) lk-no-vf ?quantity)))

(defoperator write-lk-no-vf-compo (?b ?t1 ?t2 ?xyz ?rot)
  :specifications 
  "Writes the equation s = vi*t + 0.5*a*t^2, which lacks vf"
  
  :preconditions
   (; for 2D case, make sure accel compo doesn't vanish
    (in-wm (vector ?b (at (accel ?b) (during ?t1 ?t2)) ?accel-dir))
    (test (non-zero-projectionp ?accel-dir ?xyz ?rot))
   
    (variable ?vi-compo (at (compo ?xyz ?rot (velocity ?b)) ?t1))
    (variable ?a-compo  (at (compo ?xyz ?rot (accel ?b)) (during ?t1 ?t2)))
    (variable ?s-compo  (at (compo ?xyz ?rot (displacement ?b)) (during ?t1 ?t2)))
    (variable ?t-var    (duration (during ?t1 ?t2))))
  :effects
  ((assume using lk-eqn ?b ?t1 ?t2 ?xyz ?rot)
   (eqn (= ?s-compo (+ (* ?vi-compo ?t-var) (* 0.5 ?a-compo (^ ?t-var 2))))
	 (compo-eqn lk-no-vf ?xyz ?rot (lk ?b (during ?t1 ?t2))))
    (eqn-compos (compo-eqn lk-no-vf ?xyz ?rot (lk ?b (during ?t1 ?t2)))
		(?vi-compo ?a-compo ?s-compo)))
  :hint (
    (point (string "Do you know an equation relating the components of displacement to those of initial velocity, time, and acceleration when acceleration is constant?"))
    (bottom-out (string "Write the equation ~A" ((= ?s-compo (+ (* ?vi-compo ?t-var)
								(* 0.5 ?a-compo (^ ?t-var 2))))
						 algebra)))
  ))

;;#| ;; for commenting out LK-no-a since instructors don't consider it fundamental
   
;;; Writes the equation s = 0.5*(vi + vf)*t, which lacks a

(defoperator LK-no-a-contains (?quantity)
  :specifications "
   Lists the quantities contained in s = 0.5*(vi + vf)*t, which lacks a"
  :preconditions
  ((any-member ?quantity 
	        ((at (mag (velocity ?b)) ?t1)
		 (at (dir (velocity ?b)) ?t1)
		 (at (mag (velocity ?b)) ?t2)
		 (at (dir (velocity ?b)) ?t2)
		 ;;(at (mag (accel ?b)) (during ?t1 ?t2))
		 ;;(at (dir (accel ?b)) (during ?t1 ?t2))
		 (at (mag (displacement ?b)) (during ?t1 ?t2))
		 (at (dir (displacement ?b)) (during ?t1 ?t2))
		 (duration (during ?t1 ?t2))
		 ))
   ; only applies if accel is constant within interval we are using
   ; sought may not bind both times, so must choose endpoints of interval to try
   (constant (accel ?b) ?t-constant)
   (time (during ?t1 ?t2))	; ensure both endpoints to try bound
   (test (tinsidep `(during ,?t1 ,?t2) ?t-constant))
   )
  :effects
   ((compo-eqn-contains (lk ?b (during ?t1 ?t2)) lk-no-a ?quantity)))

(defoperator write-lk-no-a-compo (?b ?t1 ?t2 ?xyz ?rot)
  :specifications "
   Writes the equation s = 0.5*(vi + vf)*t, which lacks a"
  
  :preconditions
   (; for 2D case, make sure accel compo doesn't vanish
    (in-wm (vector ?b (at (accel ?b) (during ?t1 ?t2)) ?accel-dir))
    (test (non-zero-projectionp ?accel-dir ?xyz ?rot))
    (variable ?vf-compo (at (compo ?xyz ?rot (velocity ?b)) ?t2))
    (variable ?vi-compo (at (compo ?xyz ?rot (velocity ?b)) ?t1))
    (variable ?s-compo  (at (compo ?xyz ?rot (displacement ?b)) (during ?t1 ?t2)))
    (variable ?t-var    (duration (during ?t1 ?t2))))
  :effects
  ((assume using lk-eqn ?b ?t1 ?t2 ?xyz ?rot)
   (eqn (= ?s-compo (*  0.5 (+ ?vi-compo ?vf-compo) ?t-var))
	 (compo-eqn lk-no-a ?xyz ?rot (lk ?b (during ?t1 ?t2))))
    (eqn-compos (compo-eqn lk-no-a ?xyz ?rot (lk ?b (during ?t1 ?t2)))
		(?vi-compo ?vf-compo ?s-compo)))
   :hint (
     (point (string "Do you know an equation relating the components of displacement to that of initial velocity, final velocity and time when acceleration is constant?"))
     (bottom-out (string "Write the equation ~A"
			 ((= ?s-compo (* 0.5 (+ ?vi-compo ?vf-compo) ?t-var))
			  algebra)))
   ))

;;|# ;; end commented-out lk-no-a

;|# ;; end not in physics-lite used in Pyrenees eval

;;
;; LK equations special to projectile motion
;;

;; Following two write component equations for components with constant 
;; velocity motion.  This is used for horizontal motion of a projectile.
;; Note they apply only to one component, since v_y need not be constant, 
;; so can't be derived as instances of a general vector equation. 

;; Following writes s_x = v0_x * t when a_x is zero so v_x is constant.
;; (This is a special case of lk-no-vf, so could possibly use same eq id
;; to treat it as a special case --  not clear if this would be useful.)
;; V0 is most commonly given, but other constant velocity rule should permit 
;; equating v0_x to v1_x, v2_x if needed. Vavg_x could also be used but we 
;; don't introduce Vavg ;; all unless the problem asks for it. 
;; The test for vanishing acceleration compo must be deferred until we actually 
;; write the equation since the axis is not chosen at the time of trying 
;; compo-eqn-contains.
;;
;; Because this is defined as a subsdiary compo-eqn under the lk method
;; writing it will require drawing all the lk vectors over the interval. This 
;; could be a nuisance if you wish to apply it over a sub-interval of 
;; projectile motion but for now it suffices. The const-vx shows how to
;; work around it if we need to.
(defoperator sdd-constvel-compo-contains (?quantity)
  :specifications 
   "Lists the quantities contained in s_x = v0_x*t when a_x = 0" 
  :preconditions
  ((any-member ?quantity 
	        ((at (mag (velocity ?b)) ?t1)
		 (at (dir (velocity ?b)) ?t1)
		 (at (mag (displacement ?b)) (during ?t1 ?t2))
		 (at (dir (displacement ?b)) (during ?t1 ?t2))
		 (duration (during ?t1 ?t2))
		 ))
   ; only applies if accel is constant so child of lk.
   ; sought may not bind both times, so must choose endpoints of interval to try
   (constant (accel ?b) ?t-constant)
   (time (during ?t1 ?t2))	; ensure both endpoints to try bound
   (test (tinsidep `(during ,?t1 ,?t2) ?t-constant))
   )
  :effects
   ((compo-eqn-contains (lk ?b (during ?t1 ?t2)) sdd-constvel ?quantity)))

(defoperator sdd-constvel-compo (?b ?t1 ?t2 ?xyz ?rot)
  :specifications 
  "Writes the component equation s_x = vi_x*t when a_x = 0"
  
  :preconditions
   (; make sure accel compo vanishes
    (in-wm (vector ?b (at (accel ?b) (during ?t1 ?t2)) ?accel-dir))
    (test (not (non-zero-projectionp ?accel-dir ?xyz ?rot)))
    ; and write it 
    (variable ?vi-compo (at (compo ?xyz ?rot (velocity ?b)) ?t1))
    (variable ?s-compo  (at (compo ?xyz ?rot (displacement ?b)) (during ?t1 ?t2)))
    (variable ?t-var    (duration (during ?t1 ?t2)))
    ; following only used for implicit eqn so a_x can be accepted if used
    (variable ?a_x   (at (compo ?xyz ?rot (accel ?b)) (during ?t1 ?t2))))
  :effects
  ((assume using lk-eqn ?b ?t1 ?t2 ?xyz ?rot)
   (eqn (= ?s-compo (* ?vi-compo ?t-var))
	 (compo-eqn sdd-constvel ?xyz ?rot (lk ?b (during ?t1 ?t2))))
    (eqn-compos (compo-eqn sdd-constvel ?xyz ?rot (lk ?b (during ?t1 ?t2)))
     (?vi-compo ?s-compo))
    (implicit-eqn (= ?a_x 0)
                  (at (compo ?xyz ?rot (accel ?b)) (during ?t1 ?t2))))
  :hint (
    (point (string "Can you think of an equation relating the components of displacement to those of initial velocity and time?"))
    (point (string "What do you know about the ~A component of the velocity of ~A ~A?" ((axis ?xyz ?rot) symbols-label) ?b ((during ?t1 ?t2) pp)))
    (teach (string "Because the acceleration of ~A ~A is perpendicular to the ~A axis, is has no component in the ~A direction. Therefore, the ~A component of velocity remains constant ~A. You can use this to relate ~A to ~A and ~A." 
		   ?b ((during ?t1 ?t2) pp) ((axis ?xyz ?rot) symbols-label)((axis ?xyz ?rot) symbols-label) 
		   ((axis ?xyz ?rot) symbols-label) ((during ?t1 ?t2) pp) 
		   (?s-compo algebra) (?vi-compo algebra) (?t-var algebra)))
    (bottom-out (string  "Write the equation ~A"
		   ((= ?s-compo (* ?vi-compo ?t-var)) algebra)))
  ))

;; Following writes vi_x = vj_x when v_x is constant because a_x = 0
;; Note we may need to apply this within a sub-interval of a larger lk 
;; application, e.g. from given v2_x at apex of flight (Exkt17a) to v_x3 
;; end of flight, without having to draw all lk vectors such as d for the 
;; sub-segment. Thus we need both the two times and the containing lk time
(defoperator const-vx-contains (?quantity)
 :specifications 
   "Lists the quantities contained in v1_x = v2_x when a_x = 0"
  :preconditions (
   (any-member ?quantity 
	        ((at (mag (velocity ?b)) ?t1)
		 (at (dir (velocity ?b)) ?t1)
	         (at (mag (velocity ?b)) ?t2)
		 (at (dir (velocity ?b)) ?t2)
		 ))
   ; pick a pair of times:
   (time (during ?t1 ?t2))
   ; make sure vx is constant within containing time
   ; for now just use free-fall time, assume it uses widest possible interval.
   ; We also assume that is the same as the lk application time.
   ; we still have to pass the particular times we want to the eqn writing op
   (free-fall ?b ?t-free-fall) 
   (test (tinsidep `(during ,?t1 ,?t2) ?t-free-fall))
   )
   :effects (
    (compo-eqn-contains (lk ?b ?t-free-fall) (const-vx ?t1 ?t2) ?quantity)
   ))

(defoperator use-const-vx (?b ?t1 ?t2 ?t-lk)
  :specifications "Writes the component equation v1_x = v2_x when a_x = 0"
  
  :preconditions
   (; if time is inside lk time, then vector may not have been drawn on the lk 
    ; diagram. Can give hairy problems defining compo vars -- define-compo 
    ; only works if vector and axes both drawn.  Define-compo2 was added to
    ; work in other cases, but can fail if it has has already been applied 
    ; once to draw axes for body at different time!
    ; Ensuring vector is drawn allows define-compo to work, since axes have
    ; been drawn on the body in the containing lk application.  
    (vector ?b (at (velocity ?b) ?t1) ?dir1)
    (vector ?b (at (velocity ?b) ?t2) ?dir2)
    (variable ?v1-compo (at (compo x 0 (velocity ?b)) ?t1))
    (variable ?v2-compo (at (compo x 0 (velocity ?b)) ?t2)))
  :effects
  ((eqn (= ?v1-compo ?v2-compo) 
               (compo-eqn (const-vx ?t1 ?t2) x 0 (lk ?b ?t-lk)))
   (eqn-compos (compo-eqn (const-vx ?t1 ?t2) x 0 (lk ?b ?t-lk))
        (?v1-compo ?v2-compo)))
  :hint
  ((point (string "What do you know about the x component of the velocity of ~A ~A?"  ?b (?t-lk pp)))
   (teach (string "Because the acceleration of ~A ~A is perpendicular to the x axis, is has no component in the x direction. Therefore, the x component of velocity remains constant ~A. You can use this to relate ~A to ~A. " 
		  ?b (?t-lk pp)  (?t-lk pp) (?v1-compo algebra) (?v2-compo algebra)))
   (bottom-out (string "Write the equation ~A" ((= ?v1-compo ?v2-compo) algebra)))
   ))

;; TODO: Need some principles for problems like Exkt17a. Which?
;;
;; 1. Could add principle that v_y = 0 at max-height.
;; 2. Could use s12_y = -s23_y if (same-height ?b ?t1 ?t3)
;; 3. Could use more general vector relation s12 + s23 = s13
;; for case where s13_y = 0. 
;; 4. Could add principle about v1_y = -v3_y if (same-height ?b ?t1 ?t3)
;; although this should be derivable from lk equations.

#|
(defoperator vy-apex-contains (?sought)
  :preconditions 
    ((any-member ?sought ((at (compo y 90 (velocity ?b)) ?t)))
    (apex ?b ?t))
  :effects ((eqn-contains (vy-apex ?b ?t) ?sought)))

(defoperator write-vy-apex(?b ?t)
  :preconditions 
  ((variable ?v_y (at (compo y 90 (velocity ?b)) ?t)))
  :effects ((eqn (= ?v_y 0) (vy-apex ?b ?t)))
  :hint
  ((bottom-out (string "Write the equation ~A" ((= ?v_y 0) algebra)))
   ))
|#

;;; ===================== average acceleration =================
;;;
;;; This is a vector psm to find average acceleration when the
;;; acceleration is not known to be constant. It uses the same
;;; compo equation lk-no-s that is used under the constant acceleration
;;; equation method "lk". We want avg-accel/lk-no-s to apply only 
;;; when lk/lk-no-s doesn't to keep down multiplication of solutions.
;;; Since we use the same child equation id lk-no-s in both cases, 
;;; if the student ever selects avg-accel as a psm when accel is constant
;;; we can match on the child id only to find it as part of the appropriate
;;; containing parent method.
;;; 
;;; LK attempts to prove that acceleration is constant. Since we don't 
;;; have true negation-by-failure we can't complement that with 
;;; (not (constant (accel ?b) ?t)) which only means "not-in-wm". 
;;; But the only ways we can currently derive that accel is constant is 
;;; if it's or free-fall is given, so we just test for the absence of those.
;;;
(defoperator avg-accel-contains (?quantity)
  :specifications
"The average acceleration equation potentially contains the duration and the
the magnitude and direction of the initial and final velocity and acceleration."
  :preconditions
  ((any-member ?quantity
	       ((at (mag (velocity ?b)) ?t1)
		 (at (dir (velocity ?b)) ?t1)
		 (at (mag (velocity ?b)) ?t2)
		 (at (dir (velocity ?b)) ?t2)
		 (at (mag (accel ?b)) (during ?t1 ?t2))
		 (at (dir (accel ?b)) (during ?t1 ?t2))
		 (duration (during ?t1 ?t2))))
    (object ?b)
    (time (during ?t1 ?t2))
    ; only apply this method if lk/lk-no-s doesn't apply
    (not (constant (accel ?b) ?t-constant)
         (tinsidep `(during ,?t1 ,?t2) ?t-constant))
    (not (free-fall ?b ?t-free-fall))
    )
  :effects
   ((vector-psm-contains (avg-accel ?b (during ?t1 ?t2)) ?quantity)))

(defoperator draw-avg-accel-diagram (?b ?t1 ?t2 ?rot)
  
  :specifications 
   "If the goal is to draw vectors for average acceleration,
   then draw the body, the initial and final velocity, 
      the acceleration and axes"
  :preconditions
  ((not (vector-diagram (avg-accel ?b (during ?t1 ?t2))))
   (body ?b (during ?t1 ?t2))
   (vector ?b (at (velocity ?b) ?t1) ?dir1)
   (vector ?b (at (velocity ?b) ?t2) ?dir2)
   (vector ?b (at (accel ?b) (during ?t1 ?t2)) ?dir3)
   (axis-for ?b (during ?t1 ?t2) x ?rot))
  :effects
   ((vector-diagram (avg-accel ?b (during ?t1 ?t2)))))

;; following writes LK-no-s in context of avg-accel method.
;; duplicates lk/lk-no-s pair of operators.
;; We could generalize them with variables in place of parent-psm-id, since
;; id is always bound coming in.  Then the same operators would apply in
;; both instances.  These are separate for now only so don't have to 
;; regenerate existing problem files for the change.
(defoperator avg-accel-compo-contains (?quantity)
  :specifications 
   "Lists the quantities contained in vf = vi + a * t"
  :preconditions
  ((any-member ?quantity 
	       ((at (mag (velocity ?b)) ?t1)
		 (at (dir (velocity ?b)) ?t1)
		 (at (mag (velocity ?b)) ?t2)
		 (at (dir (velocity ?b)) ?t2)
		 (at (mag (accel ?b)) (during ?t1 ?t2))
		 (at (dir (accel ?b)) (during ?t1 ?t2))
		 (duration (during ?t1 ?t2))
		 ))
   )
  :effects
   ((compo-eqn-contains (avg-accel ?b (during ?t1 ?t2)) lk-no-s ?quantity)))

(defoperator write-avg-accel-compo (?b ?t1 ?t2 ?xyz ?rot)
  :specifications " writes vf=vi+a*t where accel not constant"
  
  :preconditions
   (; for 2D case, make sure accel compo not known to vanish
    (in-wm (vector ?b (at (accel ?b) (during ?t1 ?t2)) ?accel-dir))
    (test (non-zero-projectionp ?accel-dir ?xyz ?rot))
    (variable ?vi-compo (at (compo ?xyz ?rot (velocity ?b)) ?t1))
    (variable ?vf-compo (at (compo ?xyz ?rot (velocity ?b)) ?t2))
    (variable ?a-compo  (at (compo ?xyz ?rot (accel ?b)) (during ?t1 ?t2)))
    (variable ?t (duration (during ?t1 ?t2))))
  :effects
  ((eqn (= ?vf-compo (+ ?vi-compo (* ?a-compo ?t)))
	        (compo-eqn lk-no-s ?xyz ?rot (avg-accel ?b (during ?t1 ?t2))))
    (eqn-compos (compo-eqn lk-no-s ?xyz ?rot (avg-accel ?b (during ?t1 ?t2)))
		(?vi-compo ?vf-compo ?a-compo)))
  :hint
   ((point (string "Can you think of an equation that relates the components of average acceleration to those of the initial velocity, final velocity, and duration?"))
    (teach (kcd "write_avg_accel")
	   (string "Acceleration is the rate of change of velocity. The average acceleration vector over some time is defined as the difference between initial and final velocity vectors divided by the duration. This definition can be be applied component-wise to relate ~A, ~A, ~A and ~A" (?vf-compo algebra) (?vi-compo algebra) (?a-compo algebra) (?t algebra)))
    (bottom-out (string "Write the equation ~a = ~a + ~a*~a" (?vf-compo algebra) (?vi-compo algebra) (?a-compo algebra) (?t algebra)))
    ))

#|; following experimental for 2D vector kinematics using relative positions

;;; ======================= Constant Velocity =========================
;;;
;;; This defines the vector relation sb01 = Vb0 * t01 where Vb constant.
;;; The parent vector psm is called constvel, the equation sdd-constvel.
;;; sdd-constvel can also occur for the x-component under lk.
;;; !!! We also need rule to use the constancy of V to get it at any time 
;; we need.

(defoperator const-vel-vector-contains (?sought)
  :preconditions 
    ((any-member ?sought
	        ((at (mag (velocity ?b)) ?t1)
		 (at (dir (velocity ?b)) ?t1)
		 (at (mag (displacement ?b)) (during ?t1 ?t2))
		 (at (dir (displacement ?b)) (during ?t1 ?t2))
		 (duration (during ?t1 ?t2))))
    (object ?b)
    (time (during ?t1 ?t2))
    ; must be given straight-line constant v motion interval we are using
    (in-wm (motion ?b ?t-constant (straight constant ?dir)))
    (test (tinsidep `(during ,?t1 ,?t2) ?t-constant)))
  :effects 
  ((vector-psm-contains (const-vel ?b (during ?t1 ?t2)) ?sought)
  ; since only one compo-eqn under this vector psm, we can just
  ; select it now, rather than requiring further operators to do so
  (compo-eqn-contains (const-vel ?b (during ?t1 ?t2)) sdd-const-vel ?sought)))

(defoperator draw-const-vel-diagram (?b ?t1 ?t2)
  
  :preconditions 
  ((not (vector-diagram (const-vel ?b (during ?t1 ?t2))))
   (body ?b (during ?t1 ?t2))
   (vector ?b (at (velocity ?b) ?t1) ?dir1)
   (vector ?b (at (displacement ?b) (during ?t1 ?t2)) ?dir2)
   (axis-for ?b (during ?t1 ?t2) x ?rot))
  :effects 
  ((vector-diagram (const-vel ?b (during ?t1 ?t2)))))

(defoperator write-sdd-const-vel-compo (?b ?t1 ?t2 ?xy ?rot)
  
  :preconditions 
   ((variable ?d12_x  (at (compo ?xy ?rot (displacement ?b)) (during ?t1 ?t2)))
    (variable ?v1_x   (at (compo ?xy ?rot (velocity ?b)) ?t1))
    (variable ?t12    (duration (during ?t1 ?t2))))
  :effects (
   (eqn (= ?d12_x (* ?v1_x ?t12))
            (compo-eqn sdd-const-vel ?xy ?rot (const-vel ?b (?during ?t1 ?t2))))
   (eqn-compos 
            (compo-eqn sdd-const-vel ?xy ?rot (const-vel ?b (?during ?t1 ?t2)))
             (?d12_x ?v1_x))))

;;; To make use of position vectors:

;;; ================= Position and displacement =====================
;;;
;;; This defines the vector relation sb01 = rbo2 - rbo1 where o is "origin",
;;; which is the definition of displacement.
;;; This will relate displacements of a body over time to relative positions 
;;; with respect to some specified origin. We don't use relative positions
;;; in most problems however, just displacements. Without some constraints 
;;; this rule could generate the equation for every possible origin any time
;;; the displacement of a body is mentioned, and then recurse to generate
;;; displacements of other bodies that don't move during problem. We
;;; require an origin to be defined with (origin ?body) in the problem
;;; statement to use this rule. 
;;;
;;; Note relative positions are used in other problems without specifying a
;;; distinguished origin. This is mainly for use in torque problems in 
;;; giving the location of a force wrt axis. It is also used in giving some
;;; spatial layout information for other problems, used by pythagorean
;;; theorem rules and also for giving distance of rotating point from center.
;;; We could have two types, positions wrt implicit origin and 
;;; relative-positions but using a single type is simpler for now.

(defoperator displacement-vector-contains (?sought)
  :preconditions (
    ; requires an origin to have been declared in the problem. 
    ; Note this lets us avoid including a second body in the psm id.
     (origin ?o)
     (any-member ?sought (
		 (at (mag (relative-position ?b ?o)) ?t1)
		 (at (dir (relative-position ?b ?o)) ?t1)
		 (at (mag (relative-position ?b ?o)) ?t2)
		 (at (dir (relative-position ?b ?o)) ?t2)
		 (at (mag (displacement ?b)) (during ?t1 ?t2))
		 (at (dir (displacement ?b)) (during ?t1 ?t2))))
    (object ?b)
    (time (during ?t1 ?t2)))
  :effects 
  ((vector-psm-contains (displacement ?b (during ?t1 ?t2)) ?sought)
  ; since only one compo-eqn under this vector psm, we can just
  ; select it now, rather than requiring further operators to do so
  (compo-eqn-contains (displacement ?b (during ?t1 ?t2)) displacement ?sought)))

(defoperator draw-displacement-diagram (?b ?t1 ?t2)
  
  :preconditions 
  ((not (vector-diagram (displacement ?b (during ?t1 ?t2))))
   (body ?b (during ?t1 ?t2))
   (origin ?o)
   (vector ?b (at (relative-position ?b ?o) ?t1) ?dir1)
   (vector ?b (at (relative-position ?b ?o) ?t2) ?dir2)
   (vector ?b (at (displacement ?b) (during ?t1 ?t2)) ?dir3)
   (axis-for ?b (during ?t1 ?t2) x ?rot))
  :effects 
  ((vector-diagram (displacement ?b (during ?t1 ?t2)))))

(defoperator write-displacement-compo (?b ?t1 ?t2 ?xy ?rot)
  
  :preconditions 
   ((origin ?o)
    (variable ?r1_xy (at (compo ?xy ?rot (relative-position ?b ?o)) ?t1))
    (variable ?r2_xy (at (compo ?xy ?rot (relative-position ?b ?o)) ?t2))
    (variable ?d12_xy (at (compo ?xy ?rot (displacement ?b)) (during ?t1 ?t2))))
  :effects (
   (eqn (= ?d12_xy (- ?r2_xy ?r1_xy))
         (compo-eqn displacement ?xy ?rot (displacement ?b (?during ?t1 ?t2))))
   (eqn-compos 
         (compo-eqn displacement ?xy ?rot (displacement ?b (?during ?t1 ?t2)))
          (?d12_xy ?r2_xy ?r1_xy))))

; to draw relative positions:

(defoperator draw-zero-position-at-origin (?b ?t)
  :preconditions
  ((at-origin ?b ?t)
   (origin ?o)
   (not (vector ?b (at (relative-position ?b ?o) ?t) ?dont-care))
   (bind ?mag-var (format-sym "r_~A_~A_~A" ?b ?o (time-abbrev ?t)))
   (debug "~&Drawing zero-length relative position of ~a wrt ~a at ~a.~%" ?b ?o ?t))
  :effects 
    ((vector ?b (at (relative-position ?b ?o) ?t) zero)
    (variable ?mag-var (at (mag (relative-position ?b ?o)) ?t))
    (given (at (mag (relative-position ?b ?o)) ?t) (dnum 0 |m|))))

; we could also use special rules to draw relative position 
; in motion dir if know it moved from origin.


|#; end experimental block 

; Following draws a relative position vector of ?b1 from ?b2 at ?t
; using a direction given in the problem statement. 
;
; taking ?b2 as "origin" we tag this as a vector property of b1. This
; association is used only by axis-drawing and component writing operators,
; when looking for vectors on an object, but shouldn't matter for rotational
; problems.
(defoperator draw-relative-position (?b1 ?b2 ?t)
  :specifications 
  "if you are given that one body is at a certain direction with respect to another,
  then draw the relative position vector from one to the other in that direction"
  :preconditions ( 
    (given (at (dir (relative-position ?b1 ?b2)) ?t-given) ?dir-expr)
    (test (not (equal ?dir-expr 'unknown)))
    (time ?t)
    (test (tinsidep ?t ?t-given))
    ; make sure this vector not already drawn
    (not (vector ?b2 (at (relative-position ?b1 ?b2) ?t) ?dont-care))
    (bind ?mag-var (format-sym "r_~A_~A_~A" ?b1 ?b2 (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing ~a relative position from ~a to ~a at ~a.~%" ?dir-expr ?b1 ?b2 ?t)
    )
  :effects (
    (vector ?b1 (at (relative-position ?b1 ?b2) ?t) ?dir-expr)
    (variable ?mag-var (at (mag (relative-position ?b1 ?b2)) ?t))
    (variable ?dir-var (at (dir (relative-position ?b1 ?b2)) ?t))
     ; Because dir is problem given, find-by-psm won't ensure implicit eqn
    ; gets written. Given value may not be used elsewhere so ensure it here.
    (implicit-eqn (= ?dir-var ?dir-expr) (at (dir (relative-position ?b1 ?b2)) ?t))
   )
  :hint (
    (point (string "You know the direction of the relative position of ~a with respect to ~a." ?b1 ?b2))
    (bottom-out (string "Use the relative position drawing tool (labeled R) to draw the relative position from ~a to ~a ~a at ~a."
	  ?b2 ?b1 (?t pp) ?dir-expr))
  ))

#| ; might use this someday. must modify draw-relative-position-unknown if include this
(defoperator draw-opp-relative-position (?b1 ?b2 ?t)
  :specifications 
  "if you are given that body b1 is at a certain direction with respect to b2,
  then draw the relative position vector of b2 wrt b1 in the opposite direction"
  :preconditions ( 
    ; make sure can't use plain draw-relative-position:
    (not (given (at (dir (relative-position ?b1 ?b2)) ?t-given) ?dont-care))
    ; but opposite dir is given
    (given (at (dir (relative-position ?b2 ?b1)) ?t-given) ?dir-expr)
    (test (not (equal ?dir-expr 'unknown)))
    (time ?t)
    (test (tinsidep ?t ?t-given))
    (bind ?opp-dir (opposite ?dir-expr))
    ; make sure this vector not already drawn
    (not (vector ?b1 (at (relative-position ?b2 ?b1) ?t) ?dont-care))
    (bind ?mag-var (format-sym "r_~A_~A_~A" ?b2 ?b1 (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing ~a relative position from ~a to ~a at ~a.~%" ?dir-expr ?b2 ?b1 ?t)
    )
  :effects (
    (vector ?b1 (at (relative-position ?b2 ?b1) ?t) ?opp-dir)
    (variable ?mag-var (at (mag (relative-position ?b2 ?b1)) ?t))
    (variable ?dir-var (at (dir (relative-position ?b2 ?b1)) ?t))
    (given (at (dir (relative-position ?b2 ?b1)) ?t) ?opp-dir)
   )
  :hint (
    (point (string "You know the direction of the relative position of ~a with respect to ~a." ?b2 ?b1))
    (bottom-out (string "Use the relative position drawing tool (labeled R) to draw the relative position from ~a to ~a ~a at ~a."
	  ?b1 ?b2 (?t pp) ?dir-expr))
  ))
|#

(defoperator draw-relative-position-unknown (?b1 ?b2 ?t)
  :specifications 
  "if the direction of the relative position of one body with respect to 
  another is not given, you can introduce the relative position vector by drawing it with an unknown direction"
  :preconditions ( 
    (not (at-origin ?b1 ?t))
    (not (given (at (dir (relative-position ?b1 ?b2)) ?t) (dnum ?dir |deg|)))
    ; uncomment this if we enable draw-opp-relative-position
    ; (not (given (at (dir (relative-position ?b2 ?b1)) ?t) (dnum ?dir |deg|)))
    ; make sure this vector not already drawn
    (not (vector ?b2 (at (relative-position ?b1 ?b2) ?t) ?dont-care))
    (bind ?mag-var (format-sym "r_~A_~A_~A" ?b1 ?b2 (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing relative position ~A wrt ~a at ~a at unknown angle.~%" ?b1 ?b2 ?t)
    )
  :effects (
    (vector ?b1 (at (relative-position ?b1 ?b2) ?t) unknown)
    (variable ?mag-var (at (mag (relative-position ?b1 ?b2)) ?t))
    (variable ?dir-var (at (dir (relative-position ?b1 ?b2)) ?t))
   )
  :hint (
    (bottom-out (string "Use the relative position drawing tool (labeled R) to draw the relative position from ~a to ~a ~a, at an approximately correct angle, then erase the number in the direction box to indicate that its exact direction is unknown. "
	  ?b2 ?b1 (?t pp)))
  ))

;;;
;;; Vector sum of displacements
;;; We compute displacement over several times as sum of succesive 
;;; displacements over all contained times. Doesn't handle other 
;;; decompositions of time interval to avoid multiplying possibilities.
;;; 
(defoperator sum-disp-vector-contains (?sought)
  :preconditions 
    ((any-member ?sought (
		 (at (mag (displacement ?b)) (during ?t1 ?t2))
		 (at (dir (displacement ?b)) (during ?t1 ?t2))))
    (object ?b)
    (time (during ?ti ?tf))
    (test (> (- ?tf ?ti) 1))) ; must span more than one subinterval
  :effects 
  ((vector-psm-contains (sum-disp ?b (during ?ti ?tf)) ?sought)
  ; since only one compo-eqn under this vector psm, we can just
  ; select it now, rather than requiring further operators to do so
  (compo-eqn-contains (sum-disp ?b (during ?ti ?tf)) sum-disp ?sought)))

(defoperator draw-sum-disp-diagram (?b ?t1 ?t2)
  
  :preconditions 
  ((not (vector-diagram (displacement ?b (during ?t1 ?t2))))
   ; 1. draw body.
   (body ?b (during ?t1 ?t2))
   ; 2. draw each constituent displacement. Note we want to do this before
   ; drawing the net displacement, so have some cue to drawing an accurate
   ; net displacment.
   (bind ?intervals (successive-intervals ?t1 ?t2))
   (foreach ?interval ?intervals
      (vector ?b (at (displacement ?b) ?interval) ?dir-di))
   ; then draw the net displacement
   (vector ?b (at (displacement ?b) (during ?t1 ?t2)) ?dir-dnet)
   ; !!! Following is a hack to work around the following problem: 
   ; If dnet is sought, there may be no vectors drawn with known dir on b for the time 
   ; during ti tf -- the known constituent displacements will all be for different 
   ; times: (ti t1) (t1 t2) ... (tn tf). So only possibility is to draw default 
   ; axes via draw-unrotated-axes.  That would be fine, but this operator also 
   ; defines the z-axis, since it is also applied to draw axes for rotational problems.  
   ; But then it comes out looking as if z-axis can be chosen as a possible component direction 
   ; along which to apply our principle. 
   ; Until we implement a proper fix for this problem, we just choose axis for body 
   ; at first interval. It doesn't matter which we choose, since rules require
   ; standard axis whenever component-form flag is set in the problem.
   (bind ?t1+ (1+ ?t1))
   (axis-for ?b (during ?t1 ?t1+) x ?rot))
  :effects 
  ((vector-diagram (sum-disp ?b (during ?t1 ?t2)))))

(defoperator write-sum-disp-compo (?b ?t1 ?t2 ?xy ?rot)
  
  :preconditions 
   ((variable ?dnet_xy (at (compo ?xy ?rot (displacement ?b)) (during ?t1 ?t2)))
   (bind ?intervals (successive-intervals ?t1 ?t2))
   (map ?interval ?intervals
      (variable ?di_xy (at (compo ?xy ?rot (displacement ?b)) ?interval))
      ?di_xy ?di_compos))
  :effects 
   ((eqn (= ?dnet_xy (+ . ?di_compos))
               (compo-eqn sum-disp ?xy ?rot (sum-disp ?b (?during ?t1 ?t2))))
   (eqn-compos (compo-eqn sum-disp ?xy ?rot (sum-disp ?b (?during ?t1 ?t2)))
          (?dnet_xy . ?di_compos)))
   :hint
   ((point (string "Think about the relationship between the net displacement of ~A ~A and the individual displacements over each of the times making up the interval." ?b (?t1 pp)))
    (point (string "The net displacement vector over a time interval represents the net change in position over that interval. This will be the vector sum of the individual displacements making up the net change. This can be applied component-wise to write an equation for the components of the net displacement in terms of the components of the individual displacements."))
    (bottom-out (string "Write the equation ~A" ((= ?dnet_xy (+ . ?di_compos)) algebra)))))

#|
(defoperator sum-net-force-vector-contains (?sought)
  :preconditions 
    ((any-member ?sought (
		 (at (mag (net-force ?b)) ?t1)
		 (at (dir (net-force ?b)) ?t1)))
    (object ?b))  
    
  :effects 
  ((vector-psm-contains (sum-net-force ?b $t1) ?sought)
  ; since only one compo-eqn under this vector psm, we can just
  ; select it now, rather than requiring further operators to do so
   (compo-eqn-contains (sum-net-force ?b ?t1) sum-net-force ?sought)))

(defoperator draw-sum-net-force-diagram (?b ?t1)
  
  :preconditions 
  ((not (vector-diagram (net-force ?b ?t1)))
   ; 1. draw body.
   (body ?b ?t1)
   (object ?b1)
   (object ?b2)
   (test (not (equal ?b1 ?b2)))
   ; 2. draw each constituent displacement. Note we want to do this before
   ; drawing the net displacement, so have some cue to drawing an accurate
   ; net displacment.
   ;(bind ?intervals (successive-intervals ?t1 ?t2))
   ;(foreach ?interval ?intervals
   (vector ?b (at (force ?b ?b1 applied) ?t1) ?dir-b1)
   (vector ?b (at (force ?b ?b2 applied) ?t1) ?dir-b2)
   ; then draw the net displacement
   (vector ?b (at (net-force ?b) ?t1) ?dir-nfnet)
   ; !!! Following is a hack to work around the following problem: 
   ; If dnet is sought, there may be no vectors drawn with known dir on b for the time 
   ; during ti tf -- the known constituent displacements will all be for different 
   ; times: (ti t1) (t1 t2) ... (tn tf). So only possibility is to draw default 
   ; axes via draw-unrotated-axes.  That would be fine, but this operator also 
   ; defines the z-axis, since it is also applied to draw axes for rotational problems.  
   ; But then it comes out looking as if z-axis can be chosen as a possible component direction 
   ; along which to apply our principle. 
   ; Until we implement a proper fix for this problem, we just choose axis for body 
   ; at first interval. It doesn't matter which we choose, since rules require
   ; standard axis whenever component-form flag is set in the problem.
   ;(bind ?t1+ (1+ ?t1))
   (axis-for ?b ?t1  x ?rot))
  :effects 
  ((vector-diagram (sum-net-force ?b ?t1 ))))

(defoperator write-sum-net-force-compo (?b ?t1 ?xy ?rot)
  
  :preconditions 
   ((variable ?dnet_xy (at (compo ?xy ?rot (net-force ?b)) ?t1))
    ;  (bind ?intervals (successive-intervals ?t1 ?t2))
    (object ?b1)
    (object ?b2)
    (bind ?agents (list ?b1 ?b2))
   (map ?interval ?agents
      (variable ?di_xy (at (compo ?xy ?rot (force ?b  ?interval applied)) ?t1))
      ?di_xy ?di_compos))
  :effects 
   ((eqn (= ?dnet_xy (+ . ?di_compos))
               (compo-eqn sum-net-force ?xy ?rot (sum-net-force ?b ?t1)))
    (eqn-compos (compo-eqn sum-net-force ?xy ?rot (sum-net-force ?b ?t1))
		(?dnet_xy . ?di_compos)))
   :hint
   ())

|#

;;; ========================== mass  ======================

;;; Andes has mass on the variables menu even though mass is also
;;; defined as a side-effect of drawing a body.  This means that
;;; whenever a student just wants a variable for mass and doesn't want
;;; to draw a body, there are two ways to do it.  Thus, the solution
;;; graph builder must construct both solutions.
;;;
;;; Andes interface currently doesn't associate times with masses.
;;; The mass of a body is assumed to be constant over the course of the 
;;; problem so carries no time.  

(defoperator define-mass (?b)
  :specifications "If ?b is an object, then you can define a mass for ?b"
  :preconditions
  ((object ?b)
   (not (variable ?dont-care (mass ?b)))
   (bind ?var (format-sym "m_~A" (body-name ?b))))
  :effects
  ((variable ?var (mass ?b))
   (define-var (mass ?b)))
  :hint
  ((bottom-out (string "You can use the variable definition tools, which are under the variables menu, in order to define a variable for mass."))
   ))

;;; ========================== forces =====================================

;;; For each basic force type we have an operator called find-TYPE-force
;;; which derives a proposition of the form
;;;      (force ?body ?agent ?type ?time ?direction ?action-or-reaction)
;;; This means that the relevant force exists.  These "force-exists" rules
;;; are broken out because there are cases in which we need to know whether
;;; certain forces exist but don't necessarily want the student to draw them.  
;;; There are also operators for drawing force vectors of the different types.  
;;; The hints for the force types are actually associated with these drawing 
;;; operators, because that is where we will have to give help if the 
;;; student fails to draw a needed force. 
;;; The 'action or 'reaction tag is for heuristic purposes: 'reaction forces
;;; are those the explanation of which should appeal to Newton's Third Law.
;;; We have a single rule that derives the existence of a "reaction" force 
;;; from any "action" force, so this tag also limits the search to find action
;;; forces and so prevents looping which caused problems with other ways of
;;; writing Newton's Third Law.
;;; Forces on a compound body are also derived from these basic forces on
;;; the simple bodies without having to draw the basic forces.


;;; This operator models drawing a weight force using the Andes force
;;; tool.  The tool not only draws the vector but also defines
;;; variables for the magnitude and the direction of the force.  The
;;; vector predicate contains the information that the student can see
;;; in the vector drawing tool.  In particular, it contains the
;;; direction of the weight vector, 270 degrees.  This is information
;;; is needed by the axis drawing operators in order to rotated the
;;; axes to match the vectors.  All dimensioned numbers are
;;; represented by (dnum <value> <unit>), so the weight force's
;;; direction is (dnum 270 |deg|).

(defoperator find-weight-force (?b ?t ?planet)
  :preconditions 
   ((object ?b)
    ; In rigid body problems, parts of rigid body may be conidered objects
    ; via use-part-as-object.  We don't want to apply this rule to parts of a 
    ; larger rigid body, or to the whole rigid body.  Rather an alt op 
    ; will treat weight of whole body as force acting at cm
    (not (part-of ?b ?rigid-body))
    (not (part-of ?part ?b))
    (time ?t)
    (not (massless ?b))
    (near-planet ?planet)
    (not (force ?b ?planet weight ?t . ?dont-care)))
  :effects (
     (force ?b ?planet weight ?t (dnum 270 |deg|) action)
  ))

(defoperator draw-weight (?b ?t ?planet)
  :specifications "
    If ?body is not massless, and
       it is near a ?planet,
    then draw a weight vector for it pointing straight down,
       define a magnitude variable and an direction variable for it."
  :preconditions
   ((force ?b ?planet weight ?t ?dir action)
    (not (vector ?b (at (force ?b ?planet weight) ?t) ?dont-care))
    (bind ?mag-var (format-sym "Fw_~A_~A_~A" (body-name ?b) ?planet 
                                             (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing weight of ~a at ~a.~%" ?b ?t))
  :effects
   ((vector ?b (at (force ?b ?planet weight) ?t) ?dir)
    (variable ?mag-var (at (mag (force ?b ?planet weight)) ?t))
    (variable ?dir-var (at (dir (force ?b ?planet weight)) ?t))
    (given (at (dir (force ?b ?planet weight)) ?t) ?dir))
  :hint
  ((point (string "Notice that ~a is near ~a." ?b ?planet))
   (teach (string "When an object is near a planet, the planet exerts a weight force on the object."))
   (bottom-out (string "Because ~a is near the planet ~a, the planet exerts a weight force on it, so use the force drawing tool to draw a force on ~a due to ~a of type weight ~a." ?b ?planet ?b ?planet (?t pp)))
   ))

; For rigid body problems: treat weight of body as force acting at body's
; center of mass
; note this operator bypasses the (force ...) statement, so won't contribute
; to operators that use that to collect all forces on a body. Should
; be OK, if those uses all involve treating object as particle.
(defoperator draw-weight-at-cm (?b ?t ?planet)
  :specifications "
    If rigid body is not massless, and it is near a planet,
    then draw a weight force vector acting at the center of mass, pointing straight down,
       define a magnitude variable and an direction variable for it."
  :preconditions
   ( (object ?b)
    ; !!! cheap hack: for now, cm identified by special atom. 
    ; Better would be term (cm-of body) or relation (is-cm-of part body)
    (in-wm (part-of cm ?b))
    (time ?t)
    (not (massless ?b))
    (near-planet ?planet)
    (not (vector cm (at (force cm ?planet weight) ?t) ?dont-care))
    (bind ?mag-var (format-sym "Fw_~A_~A_~A" 'cm ?planet 
                                             (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing weight of ~a at ~a acting at cm.~%" ?b ?t))
  :effects
   ((vector cm (at (force cm ?planet weight) ?t) (dnum 270 |deg|))
    (variable ?mag-var (at (mag (force cm ?planet weight)) ?t))
    (variable ?dir-var (at (dir (force cm ?planet weight)) ?t))
    (given (at (dir (force cm ?planet weight)) ?t) (dnum 270 |deg|)))
  :hint
  ((point (string "Notice that ~a is near ~a." ?b ?planet))
   (teach (string "When a rigid body is near a planet, each portion of the body is acted on by the force of gravity. The net effect of all these forces is equivalent to that of a single weight force of magnitude m * g acting at a single point called the center of gravity, which normally is the same as the center of mass."))
   (bottom-out (string "Because ~a is near the planet ~a, the planet exerts a weight force on it which can be treated as acting at the center of mass, so use the force drawing tool to draw a weight force vector acting at cm due to ~a ~a pointing straight down (270 deg)." ?b ?planet ?planet (?t pp)))
   ))


;;; draw-tension This op models draws a tension force.  It draws the
;;; vector and defines magnitude and direction vars.  It only draws
;;; vectors for the time and body specified in a body predicate.
;;; 
;;; The direction of the tension force is given in the problem
;;; statement by the 4th argument of the tied-to predicate.  It can
;;; either be "unknown" if the problem says nothing about the
;;; orientation of the string, or (dnum ?x |deg|) if the direction
;;; of the string is given numerically, or (parameter ?name) if it is
;;; given as a parameter like theta.
;;; 
;;; In the future, the code should let the 4th argument of tied-to be
;;; an algebraic expression of numbers and parameters.  For instance,
;;; it might be theta+90 to indicate that one vector is orthogonal to
;;; another, without specifying the direction of either numerically.
;;; 
;;; Parameters are different from variables.  Variables are the things
;;; in the Andes variable window, so only students can define them.
;;; However, parameters can appear in the problem statement and the
;;; equations. 

(defoperator find-tension-force (?b ?string ?t)
  :preconditions (
    (object ?b)
    (time ?t)
    (tied-to ?string ?b ?t-tied-to ?dir-expr)
    (test (tinsidep ?t ?t-tied-to))
    (not (force ?b ?string tension ?t . ?dont-care))
  )
  :effects (
    (force ?b ?string tension ?t ?dir-expr action)
  ))

(defoperator draw-tension (?b ?string ?t)
  :specifications "
   If there is a string tied to a body with the direction known,
   then draw a tension force on the body due to the string,
     with its direction being the given string-body connection,
     and define vectors for the magnitude and direction of the force."
  :preconditions
   ((force ?b ?string tension ?t ?dir-expr action)
    (test (not (equal ?dir-expr 'unknown)))
    (not (vector ?b (at (force ?b ?string tension) ?t) ?dont-care))
    (bind ?mag-var (format-sym "Ft_~A_~A_~A" (body-name ?b) (body-name ?string)                                              (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing ~a tension on ~a due to ~a at ~a.~%" ?dir-expr ?b ?string ?t)
    )
  :effects
   ((vector ?b (at (force ?b ?string tension) ?t) ?dir-expr)
    (variable ?mag-var (at (mag (force ?b ?string tension)) ?t))
    (variable ?dir-var (at (dir (force ?b ?string tension)) ?t))
    (given (at (dir (force ?b ?string tension)) ?t) ?dir-expr))
  :hint
   ((point (string "Notice that ~a is tied to ~a." ?string ?b))
    (teach (string "Whenever something has a taut string, or something like a string, attached to it, then the string exerts a tension force on it."))
    (bottom-out (string "Because ~a is tied to ~a, you should use the force drawing tool to draw a force on ~a due to ~a of type tension ~a." ?string ?b ?b ?string (?t pp)))
    ))

;;; Need a second version of the operator for drawing tension forces
;;; to cover the case where the direction is unknown.  This should be
;;; done with a conditional effect, but we don't have those yet.

(defoperator draw-tension-unknown-dir (?b ?string ?t)
  :specifications "
   If there is a string tied to a body with the direction unknown,
   then draw a tension force on the body due to the string,
     with its direction being the given string-body connection,
     and define vectors for the magnitude and direction of the force."
  :preconditions
   ((force ?b ?string tension ?t unknown action)
    (not (vector ?b (at (force ?b ?string tension) ?t) ?dont-care))
    (bind ?mag-var (format-sym "Ft_~A_~A_~A" (body-name ?b) (body-name ?string)                                               (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing tension on ~a due to ~a at ~a of unknown direction.~%" ?b ?string ?t)
    )
  :effects
   ((vector ?b (at (force ?b ?string tension) ?t) unknown)
    (variable ?mag-var (at (mag (force ?b ?string tension)) ?t))
    (variable ?dir-var (at (dir (force ?b ?string tension)) ?t)))
  :hint
   ((point (string "Notice that ~a is tied to ~a." ?string ?b))
    (teach (string "Whenever something has a string, or something like a string, tied to it, then the string exerts a tension force on it."))
    (bottom-out (string "Because ~a is tied to ~a, you should use the force drawing tool to draw a force on ~a due to ~a of type tension ~a." ?string ?b ?b ?string (pp ?t)))
    ))

;;; This operator models drawing a normal force.  The problem
;;; statement should contain a proposition of the form (supports
;;; <surface> <obj> <time> <direction>) where the direction is chosen
;;; so that <direction>+90 points away from the surface.  Currently,
;;; this only works when the surface's direction is numerical, so we
;;; simply don't handle normal vectors for surfaces whose direction is
;;; parametric or unknown.  Need to fix that someday.  Perhaps it
;;; would be easly to make it work with algebraic expresson that
;;; include parameters.

(defoperator find-normal-force (?b ?surface ?t)
   :preconditions (
    (object ?b)
    (time ?t)
    (supports ?surface ?b ?t-supports (dnum ?dir |deg|))
    (test (tinsidep ?t ?t-supports))
    (not (force ?b ?surface normal ?t . ?dont-care))
    (bind ?normal-dir (mod (+ ?dir 90) 360))
  ) 
  :effects (
    (force ?b ?surface normal ?t (dnum ?normal-dir |deg|) action)
  ))

(defoperator draw-normal (?b ?surface ?t)
  :specifications 
  "If an object slides along a plane,
      and the plane has a known direction ?dir,
   then there is normal force on the object due to the plane,
      and it is perpendicular to the plane"
  :preconditions
   ((force ?b ?surface normal ?t (dnum ?normal-dir |deg|) action)
    (not (vector ?b (at (force ?b ?surface normal) ?t) ?dont-care))
    (bind ?mag-var (format-sym "Fn_~A_~A_~A" (body-name ?b) ?surface 
                                             (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing ~a normal on ~a due to ~a at ~a.~%" ?normal-dir ?b ?surface ?t)
    )
  :effects
   ((vector ?b (at (force ?b ?surface normal) ?t) (dnum ?normal-dir |deg|))
    (variable ?mag-var (at (mag (force ?b ?surface normal)) ?t))
    (variable ?dir-var (at (dir (force ?b ?surface normal)) ?t))
    (given (at (dir (force ?b ?surface normal)) ?t) (dnum ?normal-dir |deg|)))
  :hint
   ((point (string "Notice that ~a is supported by a surface: ~a." ?b ?surface))
    (teach (minilesson "mini_normal_force.htm")
           (kcd "normal_force_direction")
	   (string "When an object is supported by a surface, the surface exerts a normal force on it.  The normal force is perpendicular to the surface."))
    (bottom-out (string "Because ~a supports ~a, draw a normal force on ~a due to ~a at an angle of ~a degrees." ?surface ?b ?b ?surface ?normal-dir))
    ))

; Applied force is specified in problem statement by given force direction 
; which may be unknown

(defoperator find-applied-force (?b ?agent ?t)
  :preconditions (
    (object ?b)
    (time ?t)
    (in-wm (given (at (dir (force ?b ?agent applied)) ?t-force) ?dir-expr))
    (test (tinsidep ?t ?t-force))
    (not (force ?b ?agent applied ?t . ?dont-care))
  )
  :effects (
    (force ?b ?agent applied ?t ?dir-expr action)
  ))

; Draw a applied ("given") force at a certain direction. 
(defoperator draw-applied-force (?b ?agent ?t)
  :specifications 
  "if you are given that there is an applied force on an object at a time
   at a certain direction,
  then draw the force at that direction"
  :preconditions
   ((force ?b ?agent applied ?t ?dir-expr action)
    (test (not (equal ?dir-expr 'unknown)))
    (not (vector ?b (at (force ?b ?agent applied) ?t) ?dont-care))
    ; Prefix "Fg" for "given" or "generic" forces
    (bind ?mag-var (format-sym "Fg_~A_~A_~A" (body-name ?b) ?agent (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing ~a applied force on ~a due to ~a at ~a.~%" ?dir-expr ?b ?agent ?t)
    )
  :effects
   ((vector ?b (at (force ?b ?agent applied) ?t) ?dir-expr)
    (variable ?mag-var (at (mag (force ?b ?agent applied)) ?t))
    (variable ?dir-var (at (dir (force ?b ?agent applied)) ?t))
    ; Ensure implicit eqn is written because dir is problem given
    (implicit-eqn (= ?dir-var ?dir-expr) (at (dir (force ?b ?agent applied)) ?t))
   )
  :hint
   ((point (string "You were given that there is an applied force on ~a." ?b))
    (bottom-out (string "Use the force drawing tool to draw the applied force on ~a due to ~a ~a at ~a." ?b ?agent (?t pp) ?dir-expr))
    ))

; draw-applied-force-unknown-dir -- would be needed if wanted to
; solve for the angle of an applied force -- reasonable, but
; not currently used in any of our problems.

; draw kinetic friction force on ?b due to ?surface
; requires a (slides-against ?surface ?b ?t) statement in the problem 
; This form is only to be used where there is a frictional interaction, 
; just leave it out for frictionless contact.
; ! might still want to include "frictionless/frictional" tag somewhere
; to explicitly indicate when friction is to be neglected (helpsys might use).
; This only handles friction for objects given to be in straight
; line motion in known direction. We could add another version for object given
; in curved motion. We could also change to derive direction from the velocity 
; vector direction instead. This would be a more general rule; however, as 
; operators are structured now this would require a step of drawing the 
; velocity vector before you could draw the friction direction.
(defoperator find-kinetic-friction-force (?b ?surface ?t)
  :preconditions (
    (object ?b)
    (time ?t)
    (slides-against ?b ?surface ?t-slides)
    (test (tinsidep ?t ?t-slides))
    (not (force ?b ?surface kinetic-friction ?t . ?dont-care))
    (motion ?b ?t-motion (straight ?dont-care32 (dnum ?motion-dir |deg|)))
    (bind ?friction-dir (mod (+ 180 ?motion-dir) 360))
   )
  : effects (
    (force ?b ?surface kinetic-friction ?t (dnum ?friction-dir |deg|) action)
  ))

(defoperator draw-kinetic-friction (?b ?surface ?t)
  :specifications 
   "If an object slides along a surface in direction ?dir,
   then there is a kinetic friction force on the object due to the surface,
      and it is opposite the direction of motion"
  :preconditions
   ((force ?b ?surface kinetic-friction ?t (dnum ?friction-dir |deg|) action)
    (not (vector ?b (at (force ?b ?surface kinetic-friction) ?t) ?dont-care))
    (bind ?mag-var (format-sym "Ff_~A_~A_~A" (body-name ?b) ?surface 
                                             (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing ~a kinetic-friction for ~a due to ~a at ~a.~%" ?friction-dir ?b ?surface ?t)
    )
  :effects
   ((vector ?b (at (force ?b ?surface kinetic-friction) ?t) (dnum ?friction-dir |deg|))
    (variable ?mag-var (at (mag (force ?b ?surface kinetic-friction)) ?t))
    (variable ?dir-var (at (dir (force ?b ?surface kinetic-friction)) ?t))
    (given (at (dir (force ?b ?surface kinetic-friction)) ?t) (dnum ?friction-dir |deg|)))
  :hint
   ((point (string "Notice that ~a is sliding against a surface ~a." ?b ?surface))
    (teach (minilesson "Mini_kinetic_friction.HTM")
           (kcd "dynamic_friction_force_direction")
	   (string "When an object is moving in contact with a surface and the surface exerts a kinetic friction force on it.  The friction force is opposite to the direction of motion."))
    (bottom-out (string "Because ~a is moving in contact with ~a, draw a kinetic friction force on ~a due to ~a at an angle of ~a." ?b ?surface ?b ?surface ?friction-dir))
    ))

(defoperator kinetic-friction-law-contains (?quantity)
  :preconditions(
    (any-member ?quantity (
	           (at (mag (force ?b ?surface kinetic-friction)) ?t)
		   (at (mag (force ?b ?surface normal)) ?t)
		   (coef-friction ?b ?surface kinetic)
                 	  ))
    (slides-against ?b ?surface ?t-slides)
    (time ?t)
    (test (tinsidep ?t ?t-slides))
  )
  :effects(
    (eqn-contains (kinetic-friction ?b ?surface ?t) ?quantity)
  ))

(defoperator kinetic-friction-law (?b ?surface ?t)
  
  :preconditions (
    (variable ?ff-var (at (mag (force ?b ?surface kinetic-friction)) ?t))
    (variable ?N-var   (at (mag (force ?b ?surface normal)) ?t))
    (variable ?mu-var (coef-friction ?b ?surface kinetic))
  )
  :effects (
    (eqn (= ?ff-var (* ?mu-var ?N-var)) (kinetic-friction ?b ?surface ?t))
  ))

; draw a static friction force
; The direction of static friction opposes the motion that would occur if there 
; were no static friction. The magnitude can take on any value up to a maximum 
; determined by the coefficient of static friction.  For now, the existence of 
; static friction must just be given in the problem statement by a 
; "static-friction" statement which also gives its direction.  
; Some problems may make use of the 'max tag in the given static-friction 
; statement to apply the static friction law Fsf_max = mu_sf * N.
(defoperator find-static-friction-force (?b ?surface ?t)
   :preconditions
   ((object ?b)
    (time ?t)
    (static-friction ?b ?surface ?t-friction ?friction-dir ?max)
    (test (tinsidep ?t ?t-friction))
    (not (force ?b ?surface static-friction ?t . ?dont-care)))
   :effects (
    (force ?b ?surface static-friction ?t ?friction-dir action)
   ))

(defoperator draw-static-friction (?b ?surface ?t)
  :specifications 
   "If it is known that there is a static friction force in a given directoin, draw it"
  :preconditions
   ((force ?b ?surface static-friction ?t ?friction-dir action)
    (not (vector ?b (at (force ?b ?surface static-friction) ?t) ?dont-care))
    (bind ?mag-var (format-sym "Fsf_~A_~A_~A" (body-name ?b) ?surface 
                                              (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing ~a static-friction for ~a due to ~a at ~a.~%" ?friction-dir ?b ?surface ?t)
    )
  :effects
   ((vector ?b (at (force ?b ?surface static-friction) ?t) ?friction-dir)
    (variable ?mag-var (at (mag (force ?b ?surface static-friction)) ?t))
    (variable ?dir-var (at (dir (force ?b ?surface static-friction)) ?t))
    (given (at (dir (force ?b ?surface static-friction)) ?t) ?friction-dir))
  :hint
   ((point (string "Notice that ~a is not moving with respect to ~a." ?b ?surface))
    (teach (string "If an object is in contact with a surface and not moving with respect to it, the surface exerts a static friction force on it.  The friction force is opposite to the direction of incipient motion."))
    (bottom-out (string "Because ~a is in contact with but not moving with respect to ~a, draw a static friction force on ~a due to ~a at an angle of ~a." ?b ?surface ?b ?surface ?friction-dir))
    ))

; requires we are given that static friction takes on its max value
(defoperator static-friction-law-contains (?quantity)
  :preconditions(
    (static-friction ?b ?surface ?t-friction ?dir max)
    (time ?t)
    (test (tinsidep ?t ?t-friction))
    (any-member ?quantity (
	           (at (mag (force ?b ?surface static-friction)) ?t)
		   (at (mag (force ?b ?surface normal)) ?t)
		   (coef-friction ?b ?surface static)
                 	  ))
  )
  :effects(
    (eqn-contains (static-friction ?b ?surface ?t) ?quantity)
  ))

(defoperator static-friction-law (?b ?surface ?t)
  
  :preconditions (
    (variable ?ff-var (at (mag (force ?b ?surface static-friction)) ?t))
    (variable ?N-var   (at (mag (force ?b ?surface normal)) ?t))
    (variable ?mu-var (coef-friction ?b ?surface static))
  )
  :effects (
    (eqn (= ?ff-var (* ?mu-var ?N-var)) (static-friction ?b ?surface ?t))
  )
  :hint (
    (point (string "You know that the static friction takes on its maximum value in this problem"))
    (teach 
        (kcd "dynamic_friction_psm")
        (string "When static friction is at its maximum, the magnitude of the static friction force a surface exerts on an object is equal to the coefficient of static friction times the normal force on the object from the surface"))
    (bottom-out (string "Write the equation ~A" ((= ?ff-var (* ?mu-var ?N-var)) algebra)))
  ))

; Define a variable for coefficient of friction, either static or kinetic
; Here assuming it doesn't vary with time.
; Expect all variables will be bound coming in.
; !!! Note args are ordered. Body must come first, then supporting surface.
;; could be confusing if between two bodies.
(defoperator define-coef-friction (?b ?surface ?type)
  :preconditions (
   (bind ?mu-var (format-sym "mu~A_~A_~A" (if (equalp ?type 'static) "s" "k") 
                                  ?b ?surface ))
  )
  :effects (
    (define-var (coef-friction ?b ?surface ?type))
    (variable ?mu-var (coef-friction ?b ?surface ?type))
  ))

; draw drag force on ?b due to ?medium
; requires a (drag ?b ?medium ?t) statement in the problem 
; Drawing rules essentially similar to kinetic-friction force. 
; Drag force opposes straight-line motion direction.
(defoperator find-drag-force (?b ?medium ?t)
  :preconditions (
    (object ?b)
    (time ?t)
    (drag ?b ?medium ?t-slides)
    (test (tinsidep ?t ?t-slides))
    (not (force ?b ?medium drag ?t . ?dont-care))
    (motion ?b ?t-motion (straight ?dont-care32 (dnum ?motion-dir |deg|)))
    (bind ?drag-dir (mod (+ 180 ?motion-dir) 360))
   )
  : effects (
    (force ?b ?medium drag ?t (dnum ?drag-dir |deg|) action)
  ))

(defoperator draw-drag (?b ?medium ?t)
  :specifications 
   "If an object moves in a fluid medium in direction ?dir,
   then there is a drag force on the object due to the medium,
      and it is opposite the direction of motion"
  :preconditions
   ((force ?b ?medium drag ?t (dnum ?drag-dir |deg|) action)
    (not (vector ?b (at (force ?b ?medium drag) ?t) ?dont-care))
    (bind ?mag-var (format-sym "Fd_~A_~A_~A" (body-name ?b) ?medium 
                                             (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing ~a drag for ~a due to ~a at ~a.~%" ?drag-dir ?b ?medium ?t)
    )
  :effects
   ((vector ?b (at (force ?b ?medium drag) ?t) (dnum ?drag-dir |deg|))
    (variable ?mag-var (at (mag (force ?b ?medium drag)) ?t))
    (variable ?dir-var (at (dir (force ?b ?medium drag)) ?t))
    (given (at (dir (force ?b ?medium drag)) ?t) (dnum ?drag-dir |deg|)))
  :hint
   ((point (string "Notice that ~a is moving in a fluid medium ~a." ?b ?medium))
    (teach (string "When an object is moving in a fluid medium, the fluid offers resistance to the motion of the object.  This is represented by a drag force directed opposite to the direction of motion."))
    (bottom-out (string "Because ~a is moving in fluid medium ~a, draw a drag force on ~a due to ~a at an angle of ~a." ?b ?medium ?b ?medium ?drag-dir))
    ))

; Spring force
;
; Spring forces by Hooke's Law not fully implemented in Andes (no deep
; reason for this). We currently only use springs in energy problems.
; We need to know that a spring force exists so that we can include it
; in the net work done on an object. Can add Hooke's Law problems later
;
; spring-contact statement includes direction of the force. Note we may
; include this statement even for times at which compression is zero,
; so that zero-valued term for spring energy is included in total energy
(defoperator find-spring-force (?b ?spring ?t)
  :preconditions(
     (object ?b)
     (time ?t)
     ; make sure in contact with spring at t and dir is not zero
     (spring-contact ?b ?spring ?t-contact (dnum ?force-dir |deg|))
     (test  (tinsidep ?t ?t-contact))
  )
  :effects (
    (force ?b ?spring spring ?t (dnum ?force-dir |deg|) action)
  ))

(defoperator draw-spring-force (?b ?spring ?t)
  :preconditions 
   ((force ?b ?spring spring ?t (dnum ?force-dir |deg|) action)
    (not (vector ?b (at (force ?b ?spring spring) ?t) ?dont-care))
    (bind ?mag-var (format-sym "Fs_~A_~A_~A" (body-name ?b) ?spring (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "~&Drawing ~a spring force on ~a due to ~a at ~a.~%" ?force-dir ?b ?spring ?t)
    )
  :effects
   ((vector ?b (at (force ?b ?spring spring) ?t) (dnum ?force-dir |deg|))
    (variable ?mag-var (at (mag (force ?b ?spring spring)) ?t))
    (variable ?dir-var (at (dir (force ?b ?spring spring)) ?t))
    (given (at (dir (force ?b ?spring spring)) ?t) (dnum ?force-dir |deg|)))
  :hint
   ((point (string "Notice that ~a is in contact with a compressed spring ~a." ?b (?t pp)))
    (teach (string "A compressed spring exerts a restorative force on an object in contact with it.  The spring force opposes the compression of the spring from its equilibrium length."))
    (bottom-out (string "Because ~a is in contact with compressed ~a, draw a spring force on ~a due to ~a at an angle of ~a." ?b ?spring ?b ?spring ?force-dir))
    ))

; UG -- Newton's Law of Universal Gravitation
;
; We use "near-planet" statements when problem takes place within a region 
; near the surface of a planet throughout which gravitational force can be 
; treated as m*g. For greater distances we need the general law of UG in 
; terms of the gravitational constant G. This is enabled by a statement
;   (gravity ?body1 ?body2 ...)
; to mean there is a gravitational interaction between any pair of bodies
; in the list.  No time on this statement, significant gravity is assumed 
; to exist throughout the problem (though it may have different values at
; different times if relative position of bodies changes, of course.)
;
; We normally treat the r in the law of universal gravitation as the
; magnitude of the relative position vector from the center of the body 
; exerting the force to the center of the body experiencing the force.
; Referring to centers of bodies: though the kb can employ
; functional terms like center-of(b1), there is currently no way to specify
; complex terms like this in the workbench. So we need to use
; atomic names like center_of_Earth and include propositions like
;   (center-of Earth center_of_Earth)
; to enable the rules to map object names to names of their center points. 
; Note if an object is treated as a point we have to include the statement
;   (center-of person1 person1)  
; for these rules to work.
;
; The equation is scalar equation containing vector magnitudes only.
(defoperator ug-contains (?sought)
   :preconditions (
     ; first make sure a gravitational interaction exists in problem
     (gravity . ?grav-bodies)
     (any-member ?sought (
		    ; if sought is a mass, can use either equation for force
		    ; on b1 from b2 or force on b2 from b1, so need both:
                    (mass ?b1) (mass ?b2) 
		    (at (mag (force ?b1 ?b2 gravitational)) ?t)
		    (at (mag (relative-position ?c1 ?c2)) ?t)
                         ))
     (object ?b1)
     (object ?b2)
     (test (and (member ?b1 ?grav-bodies :test #'equal) 
                (member ?b2 ?grav-bodies :test #'equal)))
     ; in case sought is relative position:
     (center-of ?b1 ?c1)
     (center-of ?b2 ?c2)
     (time ?t)
   )
   :effects (
    (eqn-contains (ug ?b1 ?b2 ?t rel-pos) ?sought)
   ))

(defoperator write-ug (?b1 ?t ?b2) 
  :preconditions (
      (body ?b1 ?t)
      (variable ?m1 (mass ?b1))
      (variable ?m2 (mass ?b2))
      ; force is on b1 due to b2, so want relative position of center of
      ; b1 wrt center of b2. 
      (center-of ?b1 ?c1)
      (center-of ?b2 ?c2)
      (variable ?r  (at (mag (relative-position ?c1 ?c2)) ?t))
      (variable ?F  (at (mag (force ?b1 ?b2 gravitational)) ?t))
      (variable ?G  (grav-constant))
  )
  :effects (
      (eqn (= ?F (/ (* ?G ?m1 ?m2) (^ ?r 2))) (ug ?b1 ?b2 ?t rel-pos))
  )
  :hint (
     (teach (string "Newton's Law of universal gravitation states that the magnitude of the gravitational force between two bodies is equal to the gravitational constant G times the masses of the bodies divided by the square of the distance between the bodies."))
     (bottom-out (string "Write the equation ~A" 
                          ((= ?F (/ (* G ?m1 ?m2) (^ ?r 2))) algebra)))
  ))

;; When gravity is applied to an object in circular motion, it is
;; much more natural to use the radius of motion for the "r" in the law of
;; UG. So we have a variant form to apply in that case, which uses radius
;; instead of rel-pos. The last argument in the eqn id is 'rel-pos or 'radius
;; depending on which quantity is used to represent the r.

(defoperator ug-circular-contains (?sought)
   :preconditions (
     ; first make sure gravitational interaction exists in problem
     (gravity . ?grav-bodies)
     ; make sure body1 is in circular motion for this form
     (motion ?b1 ?t-circular (curved circular ?dontcare))
     (any-member ?sought (
                    (mass ?b1) (mass ?b2)
		    (at (mag (force ?b1 ?b2 gravitational)) ?t)
		    (at (revolution-radius ?b1) ?t)
			 ))
     (object ?b2)
     (time ?t)
     (test (tinsidep ?t ?t-circular))
     (test (and (member ?b1 ?grav-bodies :test #'equal) 
                (member ?b2 ?grav-bodies :test #'equal)))
   )
   :effects (
    (eqn-contains (ug ?b1 ?b2 ?t radius) ?sought)
   ))

(defoperator write-ug-circular (?b1 ?t ?b2) 
  :preconditions (
      (body ?b1 ?t)
      (variable ?m1 (mass ?b1))
      (variable ?m2 (mass ?b2))
      ; force is on b1 due to b2, so want relative position of center of
      ; b1 wrt center of b2. Implicit for now that positions are wrt centers.
      (variable ?r  (at (revolution-radius ?b1) ?t))
      (variable ?F  (at (mag (force ?b1 ?b2 gravitational)) ?t))
      (variable ?G  (grav-constant))
  )
  :effects (
      (eqn (= ?F (/ (* ?G ?m1 ?m2) (^ ?r 2))) (ug ?b1 ?b2 ?t radius))
  )
  :hint (
     (teach (string "Newton's Law of universal gravitation states that the magnitude of the gravitational force between two bodies is equal to the gravitational constant G times the masses of the bodies divided by the square of the distance between the bodies."))
     (bottom-out (string "Write the equation ~A" 
                          ((= ?F (/ (* G ?m1 ?m2) (^ ?r 2))) algebra)))
  ))

;; need an operator to draw the gravitational force
;; In order for the force to be drawn, the givens must contain the
;; direction of the relative position vector from the center of
;; b2 to the center to b1, or its inverse. Note that a center-of
;; statement specifying the center of an object is required for
;; all objects subject to a gravitational force, even if the object
;; is treated as a particle. It is permitted to say
;;      (center-of astronaut astronaut)
;; in which case the required relative position will wind up 
;; specified as that of astronaut with respect to center_of_Earth, say.
;;
;; In keeping with other force-detecting rules, we need a "force" statement
;; to report the existence of a force without drawing it. Because the
;; force-inferring rule for gravity is symmetrical, we don't declare either
;; force the "action" force for an action-reaction pair, but just put NIL
;; in that slot in the force proposition. Thus Newton's Third Law will never
;; be cited in inferring the existence of a gravitational force. 

(defoperator find-grav-force (?b1 ?b2 ?t)
  :preconditions (
    (gravity . ?grav-bodies)
    ; ?b1 probably bound coming in if finding all forces on it,
    ; but agent ?b2 is probably not bound:
    (object ?b1)
    (object ?b2)
    (test (and (member ?b1 ?grav-bodies :test #'equal)
               (member ?b2 ?grav-bodies :test #'equal)))
    ; We get force direction as oppposite of relative position direction. 
    ; Don't require r to be drawn -- ug-circular form doesn't use it.
    (grav-direction ?b1 ?b2 ?t ?dir)
  )
  :effects ((force ?b1 ?b2 gravitational ?t ?dir NIL)))

(defoperator grav-dir-from-rel-pos (?b1 ?b2 ?t)
  :preconditions (
    (in-wm (center-of ?b1 ?c1))
    (in-wm (center-of ?b2 ?c2))
    (in-wm (given (at(dir(relative-position ?c1 ?c2)) ?t-given) ?r-dir))
    (test (not (equal ?r-dir 'unknown)))
    (test (tinsidep ?t ?t-given))
    (bind ?grav-dir (opposite ?r-dir))
  )
  :effects ((grav-direction ?b1 ?b2 ?t ?grav-dir)))
     
(defoperator grav-dir-from-inverse-rel-pos (?b1 ?b2 ?t)
  :preconditions (
    (in-wm (center-of ?b1 ?c1))
    (in-wm (center-of ?b2 ?c2))
    (in-wm (given (at(dir(relative-position ?c2 ?c1)) ?t-given) ?r-dir))
    (test (not (equal ?r-dir 'unknown)))
    (test (tinsidep ?t ?t-given))
  )
  :effects ((grav-direction ?b1 ?b2 ?t ?r-dir)))

(defoperator draw-grav-force (?b1 ?b2 ?t)
  :preconditions (
    (force ?b1 ?b2 gravitational ?t ?dir ?dontcare)
    (bind ?mag-var (format-sym "Fg_~A_~A_~A" (body-name ?b1) (body-name ?b2)
                                             (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
  )
  :effects (
    (vector ?b1 (at (force ?b1 ?b2 gravitational) ?t) ?dir)
    (variable ?mag-var (at (mag(force ?b1 ?b2 gravitational)) ?t))
    (variable ?dir-var (at (dir(force ?b1 ?b2 gravitational)) ?t))
    (given (at (dir (force ?b1 ?b2 gravitational)) ?t) ?dir)
  )
  :hint (
    (point (string "Notice that ~a is subject to a gravitational force due to ~A." 
                   ?b1 ?b2))
    (teach (string "Every massive particle in the universe attracts every other massive particle with a gravitational force acting along a line joining the two particles. In the case of uniform spheres, the gravitational force acts along a line joining the centers of the two spheres."))
    (bottom-out (string "Draw the gravitational force on ~a due to ~a at a direction of ~a" ?b1 ?b2 ?dir))
  )
)

; Other basic force types in current ANDES: 
; 	"contact force" -- meaning unclear, trying to do without it.

; draw-reaction-force -- draws equal and opposite force of same type
;
; Our "primary" force finding rules are usually asymmetrical -- they derive only
; one side of an action-reaction pair of forces from a force-determining
; proposition: 
;        supports s b => Normal force on b from s 
;        tied-to str b => tension force on b from str
;        slides-against b s => kinetic friction on b from s
;        static-friction b s => static friction on b from s
;        given (dir (force b a applied)) => applied force on b from a
; This operator can draw the reaction to any of these "action" forces on 
; the other body when needed.  We also have an NTL PSM to put out the equation 
; equating the magnitudes.  Currently we only use NTL for forces at known 
; directions, so the direction of the reaction force becomes known ("given") 
; here.
;
; A conceptually purer alternative would be to make all our force-inferring 
; rules symmetrical, so an interaction statement would directly entail *both* 
; forces in the action-reaction pair.  The asymmetrical method used here 
; implicates Newton's Third Law in one direction only.  This seems to 
; correspond more to the reasoning we want to tutor on the forces: If a table 
; supports a block, we probably want a different hint or dialog for the 
; Normal force the table exerts on the block than for the Normal force the 
; block exerts on the table, with NTL only mentioned in the second.
;
; Another way to achieve this heuristic goal would be to write a pair of 
; rules for each force, one for each direction; but the current method is 
; more economical in treating Newton's Third Law with a single rule.
;
; A question is whether the "action" force ought to be drawn before 
; drawing the "reaction" force. If we are analyzing the forces on block1 
; with block2 on top of it, we might want to draw the downward normal force 
; before drawing the upward one.  So here we consult the "force" statement to
; test for existence of the action force but don't require drawing it.
;
; We prevent this operator from applying to interactions involving compound 
; bodies to prevent the following problem: two blocks are stacked on
; table. The table exerts a normal force on the lower block and also on
; the compound. Therefore two reaction forces will be found on the table:
; one from the lower block and one from the table. If we were interested in
; all forces on the table for applying Newton's Law, this would give us 
; the wrong set of forces on the table -- we don't want to count both the force
; from the compound and the one from its part. This will have to be fixed,
; but for now we just don't apply NTL to compound bodies. That is OK in our
; problems since we are usually interested in the dynamics of the compound
; body and the external forces on it.

(defoperator find-reaction-force (?b1 ?b2 ?type ?t)
   :preconditions (
    ; We have been allowing some force agents to be implicitly defined by 
    ; occurrence of their names in arguments of forms like tied-to or supports. 
    ; Following imposes the requirement that these must be declared in an 
    ; object proposition if forces on them are to be found. 
    (object ?b1)
    (test (not (compound-bodyp ?b1))) ; ignore compound bodies here
    (object ?b2)
    (test (not (compound-bodyp ?b2))) ; ignore compound bodies here
    (test (not (equal ?b1 ?b2)))
    (time ?t)
    ; We look for "action" force exerted *on* object b1 from b2.
    ; reaction force we seek is on b2 = body of interest from b1. 
    ; Note dir part matches numerical degree value only
    (force ?b1 ?b2 ?type ?t (dnum ?f1-dir |deg|) action)
    (not (force ?b2 ?b1 ?type ?t . ?dontcare))
    (bind ?opposite-dir (mod (+ ?f1-dir 180) 360))
   )
   :effects (
     (force ?b2 ?b1 ?type ?t (dnum ?opposite-dir |deg|) reaction)
   ))

(defoperator draw-reaction-force (?b1 ?b2 ?type ?t)
  :preconditions(
    (force ?b2 ?b1 ?type ?t ?dir reaction)
    (not (vector ?b2 (at (force ?b2 ?b1 ?type) ?t) ?junk))
    (bind ?mag-var (format-sym "F~A_~A_~A_~A" (ftype-prefix ?type) 
                               (body-name ?b2) (body-name ?b1) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
  )
  :effects (
    (vector ?b2 (at (force ?b2 ?b1 ?type) ?t) ?dir) 
    (variable ?mag-var (at (mag (force ?b2 ?b1 ?type)) ?t))
    (variable ?dir-var (at (dir (force ?b2 ?b1 ?type)) ?t))
    (given (at (dir (force ?b2 ?b1 ?type)) ?t) ?dir)
  )
  :hint (
    (point (string "Notice that ~a and ~a are exerting forces on each other." ?b1 ?b2))
    (teach 
        (kcd "third_law_psm")
        (string "Newton's Third Law states that forces always come in pairs: whenever one body exerts a force on a second body, the second body exerts a force of the same type back on the first body. The members of these action/reaction pairs are equal in magnitude and opposite in direction"))
    (bottom-out (string "Because there is a ~A force on ~A due to ~a, draw the reaction force, namely, a ~A force on ~A due to ~A at ~A" (?type adjective) ?b1 ?b2 (?type adjective) ?b2 ?b1 ?dir))
    ))

; In theory NTL should apply to any force at all. However, we don't declare
; every force agent an "object" (particle with kinematic properties), E.g. 
; planes or ground or Earth are not usually declared objects, so can't 
; actually use introduce reaction forces on these. This may have to change
; but then it will multiply solutions since then could draw them and write 
; NSL in terms of reaction force magnitudes. That would be odd though correct.
(defoperator NTL-contains (?quantity)
  :preconditions (
  (any-member ?quantity (
  		(at (mag (force ?b1 ?b2 ?type)) ?t)
  		; (at (mag (force ?b2 ?b1 ?type)) ?t)
                        ))
  ; no need to test if action/reaction pair definable; fail later if not
  ; (force ?b1 ?b2 ?type ?t ?dir1 action) 
  ; (force ?b2 ?b1 ?type ?t ?dir2 reaction) 
  ; sort body names in id so NTL(b1, b2) gets same id as NTL(b2, b1)
  (bind ?body-pair (sort (list ?b1 ?b2) #'expr<))
  )
  :effects ( 
  	(eqn-contains (NTL ?body-pair ?type ?t) ?quantity) 
  ))

(defoperator NTL (?b1 ?b2 ?type ?t)
  :preconditions (
  (variable ?mag1-var (at (mag (force ?b1 ?b2 ?type)) ?t))
  (variable ?mag2-var (at (mag (force ?b2 ?b1 ?type)) ?t))
  )
  :effects (
    	(eqn (= ?mag1-var ?mag2-var) (NTL (?b2 ?b1) ?type ?t)) 
  )
  :hint
  ((point (string "What does Newton's Third Law tell you about the relation of ~A and ~A" (?mag1-var algebra) (?mag2-var algebra)))
   (teach 
      (kcd "third_law_psm")
      (string "Newton's Third Law states that forces come in pairs: whenever A exerts a force of some type on B, B exerts a force of equal magnitude and opposite direction on A. You can use that to equate the magnitudes of this pair of forces."))
   (bottom-out (string "Write the equation ~A" ((= ?mag1-var ?mag2-var) algebra)))
  ))

;;
;; Vector form of NTL writes component equation F12_x = -F21_x
;;
;; Note the vector equation ID for this is incompatible with convention required
;; by select-compo-eqn-for-scalar, according to which vector args start with
;; body and time. Should be OK, since NTL doesn't contain any scalars.
;;

(defoperator NTL-vector-contains (?sought)
  :preconditions (
   (any-member ?sought ( (at (mag(force ?b1 ?b2 ?type)) ?t)
  		         (at (dir(force ?b1 ?b2 ?type)) ?t) ))
   (bind ?body-pair (sort (list ?b1 ?b2) #'expr<))
   )
   :effects (
   (vector-psm-contains (NTL-vector ?body-pair ?type ?t) ?sought) 
    ; since only one compo-eqn under this vector psm, we can just
    ; select it now, rather than requiring further operators to do so
    (compo-eqn-contains (NTL-vector ?body-pair ?type ?t) NTL ?sought)
   ))

(defoperator draw-NTL-vector-diagram (?b1 ?b2 ?type ?t)
  :preconditions (
    ; Draw both bodies. 
    (body ?b1 ?t)
    (body ?b2 ?t)
    (vector ?b1 (at (force ?b1 ?b2 ?type) ?t) ?dir1)
    (vector ?b2 (at (force ?b2 ?b1 ?type) ?t) ?dir2)
    ; we need axis-for each body, since component defining operators will 
    ; lookup axis-for principal body of each vector. Our operators that
    ; draw axes only apply once, so there is no danger of drawing two
    ; axes. In order to reuse the axes drawn for body1 as axes used
    ; for vectors on body2, we added reuse-other-body-axis in axes section.
    (axis-for ?b1 ?t x ?x-rot)
    (axis-for ?b2 ?t y ?y-rot)
  )
  :effects (
    (vector-diagram (NTL-vector (?b1 ?b2) ?type ?t))
  ))
  
(defoperator write-NTL-vector (?b1 ?b2 ?type ?t ?xy ?rot)
   :preconditions (
      (variable ?F12_xy (at (compo ?xy ?rot (force ?b1 ?b2 ?type)) ?t))
      (variable ?F21_xy (at (compo ?xy ?rot (force ?b2 ?b1 ?type)) ?t))
   )
   :effects (
    (eqn (= ?F12_xy (- ?F21_xy)) (compo-eqn NTL ?xy ?rot (NTL-vector (?b1 ?b2) ?type ?t)))
    (eqn-compos (compo-eqn NTL ?xy ?rot (NTL-vector (?b1 ?b2) ?type ?t))
          (?F12_xy ?F21_xy))
   )
   :hint (
     ;; !!! TODO
     (point (string "What does Newton's Third Law tell you about the relation of ~A and ~A" (?F12_xy algebra) (?F21_xy algebra)))
   (teach 
    (kcd "third_law_psm")
    (string "Newton's Third Law states that the members of an action/reaction pair of forces are equal in magnitude and opposite in direction. This entails that the components of each force vector are the negations of the corresponding components of the other: F12_x = -F21_x and F12_y = -F21_y."))
     (bottom-out (string "Write the equation ~A" 
                         ((= ?F12_xy (- ?F21_xy)) algebra)))
   ))

;;
;; Compound bodies = (compound body1 body2 ... bodyn)
;;
;; Bodies given as moving together may be treated as a single unit.
;; This is specified in a (move-together (b1 b2 ...) ?t) proposition.
;; We don't make any other use of the move-together proposition beyond
;; forming compounds; we could use it directly in the future for things 
;; like carried objects but it is not currently used for that.
;;
;; The time of moving together is not used in forming compound bodies.
;; We could try saying that the compound only exists at certain times, e.g.
;; after merging in a collision, but our object statement doesn't have a 
;; time slot.  In effect we pretend that objects *exist* at all times. 
;; This is OK since it may be that their kinematic attributes may not be 
;; determinable at all times, e.g.  can't expect to find a velocity for
;; the resulting compound at times before the merge. 
;;
;; With compounds, motion attributes might in principle have to propagate 
;; from part to whole, from whole to part, or from part to other part.
;; 1. The compound object inferring operators require a motion spec for 
;; at least one of the parts and assert the qualitative motion of the 
;; compound to be the same. This motion spec is needed for drawing kinematic 
;; vectors for the compound. 
;; 2. There can also be cases where qualitative motion is given for a compound 
;; and must be propagated to the parts. This is natural in some problems with 
;; splits/joins of bodies, in which the givens describe motion of a 
;; compound before or after.  In this case the compound object should be 
;; asserted to exist in the problem statement, and another operator will 
;; propagate the motion description to the parts.
;; 3. Ought to be able to propagate motion properties including given values
;; from one part directly to another if they are given to move together, but
;; currently the only way to effect this is by an equation going through the 
;; compound.
;;
;; These operators make an entry drawing the compound body. This is necessary
;; on the workbench before any attributes of a compound may be defined. 
;; However, in some cases these operators are not used because we are either
;; given the existence of a compound in the problem statement or are given
;; some attribute, e.g. velocity, of a compound in the problem statement.
;;

; #| this had been commented out to suppress compound body solutions to 
;    Exdt2a, Exdt14a, Exdt15a which lead to too many solution paths
; Now change to selectively enable with (allow-compound) in givens
(defoperator form-compound-moving (?bodies)
  :preconditions (
    (allow-compound)
    (move-together ?body-list ?t-coupled) ; args should be atomic bodies
    (bind ?bodies (sort ?body-list #'expr<))
    (not (object (compound . ?bodies)))
    (in-wm (motion ?b1 ?t-motion ?motion-spec)) 
    (test (member ?b1 ?body-list :test #'equal))
    (test (tinsidep ?t-coupled ?t-motion))
  )
  :effects (
     (object (compound . ?bodies))
     (motion (compound . ?bodies) ?t-coupled ?motion-spec)
     (body (compound . ?bodies) ?t-coupled)
  )
  :hint
  ((point (string "Notice that ~A move together as a unit ~A."
		  (?bodies conjoined-defnp) (?t-coupled pp)))
   (teach 
      (kcd "draw_compound_lk_body")
      (string "When two bodies move together you can often simplify your solution by treating the two of them as a single body. This is called a compound body."))
   (bottom-out (string "Use the body drawing tool and select a list of bodies to introduce the compound body consisting of ~a ~A." (?bodies conjoined-defnp) (?t-coupled pp)))
  ))
;|# ; end formerly commented out

;; if two bodies are in contact and both are at rest they may be treated
;; as a compound. 
;; !!! Currently only applies to exactly two bodies
;; Could use function so search would aggregate existing bodies including
;; compounds into progressively larger compounds, but would be tricky. 
(defoperator form-compound-at-rest (?bodies)
  :preconditions (
   (in-wm (motion ?b1 ?t at-rest))
   (supports ?b1 ?b2 ?t ?dont-care) ; should only be written for atomic b1, b2 
   (in-wm (motion ?b2 ?t at-rest))
   (bind ?bodies (sort (list ?b1 ?b2) #'expr<))
   (not (object (compound . ?bodies)))
  )
  :effects (
    (object (compound . ?bodies))
    (motion (compound . ?bodies) ?t at-rest)
    (body (compound . ?bodies) ?t)
  )
  :hint
  ((point (string "Notice that ~A stay together as a unit ~A." 
		  (?bodies conjoined-defnp) (?t pp)))
   (teach 
      (kcd "draw_conpound_lk_body")
      (string "When two bodies move together you can often simplify your solution by treating the two of them as a single body. This is called a compound body."))
   (bottom-out (string "Use the body drawing tool and select a list of bodies to introduce the compound body consisting of ~a ~A." (?bodies conjoined-defnp) (?t pp)))
   ))

; motion of a part is same as that of a compound
; this is useful if we are given the motion of a compound in the problem
; It also enables motion description to propagate from one part up through
; compound back down to other part so only needed for one part in givens.
; !!! currently only works if compound body motion is given -- doesn't
; search to derive compound body motion from move-together statement.
(defoperator get-part-motion-from-compound (?b ?bodies)
  :preconditions (
     (in-wm (motion (compound . ?bodies) ?t ?c-motion))
     (any-member ?b ?bodies)
     (not (motion ?b ?t ?b-motion))
  )
  :effects (
     (motion ?b ?t ?c-motion)
  ))


(defoperator mass-compound-contains (?sought)
  :preconditions (
   (any-member ?sought ((mass ?b-sought)))
   ; compound must exist
   (object (compound . ?bodies))
   ; applies if sought is mass of compound or one of its parts
   (test (or (member ?b-sought ?bodies)
             (equal ?b-sought `(compound ,@?bodies))))
  )
  :effects (
    (eqn-contains (mass-compound ?bodies) ?sought)
  ))

(defoperator write-mass-compound (?bodies)
  
  :preconditions (
    (variable ?mwhole-var (mass (compound . ?bodies)))
    (map ?body ?bodies
         (variable ?mpart-var (mass ?body)) 
	 ?mpart-var ?mpart-vars) 
  )
  : effects (
     (eqn (= ?mwhole-var (+ . ?mpart-vars)) (mass-compound ?bodies))
  )
  : hint
  ((point (string "How does the mass of a compound body relate to the masses of its parts?"))
   (teach (string "The mass of a compound body is equal to the sum of the masses of its parts."))
   (bottom-out (string "Write the equation ~A" ((= ?mwhole-var (+ . ?mpart-vars)) algebra)))
   ))
 
; mag of kinematic vector (displacement, velocity, acceleration) of compound 
; is same as vector on parts. mag equal ; equation
; This also applies to rotational vectors
(defoperator kine-compound-contains (?sought)
   :preconditions (
   (any-member ?sought ( 
                        (at (mag (velocity ?b1)) ?t)
			(at (mag (velocity (compound . ?bodies))) ?t)
                        (at (mag (accel ?b1)) ?t)
			(at (mag (accel (compound . ?bodies))) ?t)
                        (at (mag (displacement ?b1)) ?t)
			(at (mag (displacement (compound . ?bodies))) ?t)
			(at (mag (ang-velocity ?b1)) ?t)
			(at (mag (ang-velocity (compound . ?bodies))) ?t)
                        (at (mag (ang-accel ?b1)) ?t)
			(at (mag (ang-accel (compound . ?bodies))) ?t)
                        (at (mag (ang-displacement ?b1)) ?t)
			(at (mag (ang-displacement (compound . ?bodies))) ?t)
                        ))
   (object (compound . ?bodies))
   (object ?b1)
   (test (member ?b1 ?bodies :test #'equal))
   (bind ?vec-type (first (second (second ?sought))))
   )
   :effects (
      (eqn-contains (kine-compound ?vec-type ?b1 ?bodies ?t) ?sought)
   ))

(defoperator write-kine-compound (?vec-type ?b1 ?bodies ?t)
   :preconditions (
      (variable ?c-var (at (mag (?vec-type (compound . ?bodies))) 
                            ?t))
      (variable ?b-var (at (mag (?vec-type ?b1)) 
                           ?t))
   )
   :effects (
      (eqn (= ?c-var ?b-var) (kine-compound ?vec-type ?b1 ?bodies ?t))
   )
   :hint
   ((teach (string "If an object is part of a compound body, then ~a of the object is the same as ~a of the compound body." ?vec-type ?vec-type))
    (bottom-out (string "Write the equation ~A" ((= ?c-var ?b-var) algebra)))
   ))

; compound body force rules
; if there is a forceful interaction between a compound body part and
; an object outside the compound (i.e. an external force) then there is
; an interaction of the same type between the compound and the object.
; The general rule is that the magnitude of a force of type T on the compound 
; from a is the sum of the magnitudes of the forces of type T from that agent 
; on the parts.  This sum rule is needed to handle cases where the same agent 
; may have an interaction of the same type with several of the bodies.  
; For ex, if two blocks are pushed side by side along a plane, the net normal 
; force from the plane on the compound is the sum of the normal forces from 
; the plane on each of the blocks; similarly for kinetic friction on the 
; compound. However:
; -In the case of weight, Wc = m1 * g + m2 * g simplifies to the simple 
; weight law applied to the compound Wc = mc * g where mc = m1 + m2
; so we can also get it this way (this is one advantage of compounding.)
; -Applied or tension force will typically act at a point on only one of 
; the parts so there can only be one such force on the compound. 
; Thus the sum rule will really only be needed for normal and friction forces
; from a surface. But if there is more than one unknown force of this type
; then the problem is not much simplified by treating the objects as a compound 
; body anyway.  So we could just ignore this case and only write a rule to 
; handle the case where there is a single force of the given type. 
; Still it doesn't seem to hurt to write the general rule.
;
; Note this means there are now two operators to draw the weight force on 
; a compound, one using the weight operator and the other using the
; force on compound operator . There are also two corresponding 
; equations for the magnitude of the weight on the compound. We could
; filter in the force-compound rule to exclude weight, but since this is 
; physically correct, we leave it.

; draw a force on a compound body
(defoperator draw-force-compound (?bodies ?agent ?type ?t)
  ; if a force on a part of the compound due to a exists,
  ; force in same direction exists on compound from a.
  :preconditions (
    (in-wm (object (compound . ?bodies)))
    (bind ?c `(compound ,@?bodies)) ; just shorthand
    ; pick any body in compound
    (any-member ?b ?bodies)
    ; find an external force on the body = one with agent not in compound.
    (force-on-body ?b ?agent ?type ?t ?dir)
    (test (not (member ?agent ?bodies :test #'equal)))
    ; make sure this force hasn't been drawn already
    (not (vector ?c (at (force ?c ?agent ?type) ?t) ?dir))
    (bind ?mag-var (format-sym "F~A_~A_~A_~A" (ftype-prefix ?type) (body-name ?c) 
                                (body-name ?agent) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    (debug "drawing ~A net ~A force on ~A due to ~A~%" ?dir ?type ?c ?agent)
  )
  :effects (
   (vector (compound . ?bodies) (at (force (compound . ?bodies) ?agent ?type) 
                                    ?t) ?dir)
   (variable ?mag-var (at (mag (force ?c ?agent ?type)) ?t))
   (variable ?dir-var (at (dir (force ?c ?agent ?type)) ?t))
   (given (at (dir (force ?c ?agent ?type)) ?t) ?dir)
   )
  :hint ;; already received the hint "try drawing a force for the compound ..."
  ((point (string "Notice that ~a, which is a part of the compound body, has a ~a force on it."
		  (?b def-np) (?type adjective)))
   (teach (string "When a force exists on a part of a compound and the force is due to an object outside the compound, then a similar force acts on the compound body itself."))
   (bottom-out (string "Draw ~a at ~a." ((at (force ?c ?agent ?type) ?t) indef-np) ?dir))
   ))

; Urgh to handle pressure forces defined acting on surfaces, we need two cases to 
; return forces on component bodies to draw-force-compound.
(defoperator simple-force-on-body-exists (?b ?agent ?type ?t)
   :preconditions ( (force ?b ?agent ?type ?t ?dir ?dontcare) )
   :effects (   (force-on-body ?b ?agent ?type ?t ?dir) ))  

#|
; if a pressure force is defined on the surface, list this as a force on a body
; !!! Compound body solutions cannot handle two forces on a compound body 
; with the same type and same agent -- as could happen w/pressure force on two surfaces.
(defoperator pressure-force-on-body-exists (?b ?fluid ?t)
    :preconditions ( (in-wm (fluid-contact ?body ?surface ?fluid ?point ?t-pressure ?dir))
                     (test (tinsidep ?t ?t-pressure)) )
    :effects ( (force-on-body ?b ?fluid pressure ?t ?dir) ))
|#

(defoperator force-compound-contains (?sought)
   :preconditions (
    (any-member ?sought ( (at (mag (force ?b ?agent ?type)) ?t) ))
    (object (compound . ?bodies))
    (test (or (member ?b ?bodies)
	      (equal ?b `(compound ,@?bodies))))
    (test (not (member ?agent ?bodies :test #'equal)))
   )
   :effects (
    (eqn-contains (force-compound ?type ?agent ?bodies ?t) ?sought)
   ))

(defoperator write-force-compound (?type ?agent ?bodies ?t)
   :preconditions (
     (bind ?c `(compound ,@?bodies)) ; for shorthand
     ; draw net force of given type on compound, will use draw-force-compound
     (debug "write-force-compound: drawing ~A force on compound~%" ?type)
     (vector ?c (at (force ?c ?agent ?type) ?t) ?dir) 
     ; find set of atomic parts subject to this type force from agent.
     ; tricky: we use setof inside the map since force subgoal can fail
     ; body-set from each step of map is a singleton (b) or NIL 
     ; body-sets is then a list of these results which must be flattened
     (debug "write-force-compound: finding parts subject to ~A force from ~A~%" ?type ?agent)
     (map ?b ?bodies
         (setof (force-on-body ?b ?agent ?type ?t . ?dont-care)
	         ?b ?body-set)
	?body-set ?body-sets)
     (bind ?parts-affected (remove NIL (flatten ?body-sets)))
     (debug "write-force-compound: parts contributing: ~A~%" ?parts-affected)
     ; define variables for each of the force parts making up the net
     ; unfortunately this can only be done by drawing them, although we
     ; avoided drawing them when finding the force.
     (map ?b1 ?parts-affected
         (variable ?f-part (at (mag (force ?b1 ?agent ?type)) ?t))
	 ?f-part ?f-parts)
     (variable ?f-compound (at (mag (force (compound . ?bodies) ?agent ?type)) 
                                ?t)) 
   )
   :effects (
     (eqn (= ?f-compound (+ . ?f-parts)) (force-compound ?type ?agent ?bodies ?t))
	     )
   :hint
   ((point (string "What is the relationship between the magnitudes of the ~a force on the compound body and the ~a force(s) on ~a?" (?type adjective) (?type adjective) (?parts-affected conjoined-defnp)))
    (teach (string "Even though a force on a compound body corresponds directly with the force(s) on its part(s), you need to write an equation relating the magnitudes of the variables, because the variables refer to different bodies and thus denote different quantities."))
    (bottom-out (string "Write ~a" ((= ?f-compound (+ . ?f-parts)) algebra)))
    ))


;; Net force is only used in a few problems in which it is the sought. 
;; Other NL problems work only in terms of the sum of forces on the assumption
;; that introducing a net force term in addition to the individual forces
;; might be confusing since it may look like an extra force.
;; Thus net force quantity is inferentially isolated from sum of forces.
;;
;; Here we draw the net force in the same direction as the known acceleration
;; direction. This requires that the acceleration be drawn first so that it's 
;; direction has been derived from the motion description. 
;; A net-force form problem might in principle give the net force mag and 
;; direction and ask for some kinematic property, but we don't currently 
;; have any problems of this form; this would require another operator and
;; possibly something to determine accel dir as well if not given by motion.
(defoperator draw-net-force-from-accel (?b ?t)
  :preconditions (
     (object ?b)
     (time ?t)
     (not (vector ?b (at (net-force ?b) ?t) ?dont-care))
     (in-wm (vector ?b (at (accel ?b) ?t-accel) ?dir-accel))
     (not (equal ?dir-accel 'unknown))
     (test (tinsidep ?t ?t-accel))
     (bind ?mag-var (format-sym "Fnet_~A_~A" ?b (time-abbrev ?t)))
     (bind ?dir-var (format-sym "O~A" ?mag-var))
     (debug "~&Drawing ~a net force for ~a at ~a.~%" ?dir-accel ?b ?t)
    )
  :effects (
    (vector ?b (at (net-force ?b) ?t) ?dir-accel)
    (variable ?mag-var (at (mag (net-force ?b)) ?t))
    (variable ?dir-var (at (dir (net-force ?b)) ?t))
    (given (at (dir (net-force ?b)) ?t) ?dir-accel)
  )
  :hint (
    (bottom-out (string "Draw the net force in the same direction as the acceleration"))
  ))

 
;;; =============================  nl fbd  =============================================

;;; This operator represents the procedure for drawing all forces on a
;;; given body.  The procedure is simply to draw each of them.  Duh.
;;; Because (forces ?b ?t ?forces) can be a top level goal, it must
;;; first get the time and body selected.  Can't put these inside
;;; (in-wm ...).

;;; Because this operator is so simple, I'm not sure what the hints
;;; should be for it.  After Andes has hinted the goal with e.g., "You
;;; should draw forces", then its next hint should be for a specific
;;; force.  So I guess this operator shouldn't have any hints.


(defoperator draw-forces (?b ?t)
   :specifications 
    "If there are some forces on ?body at ?time,
     then make them the set of forces on ?body at ?time"
   :preconditions
   ((time ?t)
    (body ?b ?t)
    (setof (vector ?b (at (force ?b ?agent1 ?type1) ?t) ?dir1) 
	   (force ?b ?agent1 ?type1) 
	   ?forces1)
    ; in fluids problems, pressures forces on body are defined as acting on
    ; surfaces of the body. Must collect all of these as forces on body as
    ; well.  Could generalize this to rely on our part-of statement to 
    ; collect forces on all parts of body.  Unclear what the ramifications
    ; of that would be (could affect torque problems?). So for now, just
    ; look for pressure forces found on a body's surfaces:
    (setof (vector ?b (at (force ?surface ?fluid pressure) ?t) ?dir2)
	  (force ?surface ?fluid pressure)
	  ?pressure-forces)
    ;(debug "Adding pressure forces:  ~A~%" ?pressure-forces)
    ;(debug "To other forces: ~A~%" ?forces1)
    ; Note: two sets can overal if problem overloads object name as surface name as well 
    ; (which can be convenient, for piston, say, to avoid introducing surfaces)
    (bind ?forces (union ?forces1 ?pressure-forces :test #'equal)) 
    )
   :effects
    ((forces ?b ?t ?forces)))

; The "num-forces" scalar equation exists to put out an equation answering the 
; question "how many forces on ?b at ?t". This will likely be one part of
; a larger Newton's Law problem though it could be asked all alone.

(defoperator num-forces-contains (?b ?t)
  :preconditions ()
  :effects ( (eqn-contains (num-forces ?b ?t) (at (num-forces ?b) ?t)) ))

(defoperator write-num-forces (?b ?t)
  :preconditions 
   ((forces ?b ?t ?forces)
    (bind ?count (length ?forces))
    (variable ?n-var (at (num-forces ?b) ?t)) )
  :effects 
  ( (eqn (= ?n-var ?count) (num-forces ?b ?t)) ))
 
(defoperator define-num-forces (?b ?t)
   :preconditions 
   ((bind ?n-var (format-sym "nforces_~A_~A" (body-name ?b) (time-abbrev ?t))))
   :effects ( 
       (define-var (at (num-forces ?b) ?t)) 
       (variable ?n-var (at (num-forces ?b) ?t)) 
   ))

;;; This operator draws a free-body diagram consisting of the forces,
;;; acceleration and axes. Unlike draw-fbd-lk (linear kinematics), it
;;; doesn't draw velocity and displacement.  This is an unordered And
;;; operator.

;;; Unfortunately, the Andes vector drawing tools will add component
;;; variables if the axes are already drawn.  The operators for vector
;;; drawing don't do this.  Only the axis drawing operators define
;;; component variables.  Thus, we must insure that axis goal is posed
;;; *after* all the vectors are drawn.  Even though this operator is
;;; unordered in that it doesn't force the student to do the
;;; conditions in the specified order, the interpreter must achieve
;;; those conditions in the specified order for the code to work.

;;; In the last condition, only the x axis is requested. Drawing it
;;; causes the other axes to be draw as well.

;;; there are two mutually exclusive operators depending on whether
;;; net force is to be shown or not. We only show net force if the
;;; problem explicitly mentions it (i.e. seeks it.)
(defoperator draw-nl-fbd (?b ?t)
  
  :specifications 
   "If the goal is to draw a fbd for newton's law,
   then draw a body, draw the forces, the acceleration and the axes,
   in any order."
  :preconditions
  ((not (vector-diagram (nl ?b ?t)))
   (not (use-net-force))
   (body ?b ?t)
   (forces ?b ?t ?forces)
   (test ?forces)	; fail if no forces could be found
   (vector ?b (at (accel ?b) ?t) ?accel-dir)
   (axis-for ?b ?t x ?rot))
  :effects
   ((vector-diagram (nl ?b ?t)))
  :hint
   ((bottom-out (string "In order to draw a free-body diagram, which is the first step to applying Newton's law, draw (1) a body, (2) the forces on the body, (3) the acceleration of the body, and (4) coordinate axes."))))

;; 
;; Following draws a free-body diagram for the net-force variant of NL
;;
(defoperator draw-nl-net-fbd (?b ?t)
  
  :specifications 
   "If the goal is to draw a fbd for newton's law in terms of net force,
   then draw a body, draw the acceleration, draw the net force vector and the axes,
   in any order."
  :preconditions
  ((not (vector-diagram (nl ?b ?t)))
   (in-wm (use-net-force))
   (body ?b ?t)
   ; we draw accel first so it's known at time of drawing net force
   (vector ?b (at (accel ?b) ?t) ?accel-dir)
   (vector ?b (at (net-force ?b) ?t) ?force-dir) 
   (axis-for ?b ?t x ?rot))
  :effects
   ((vector-diagram (nl ?b ?t)))
  :hint
   ((bottom-out (string "In order to draw a free-body diagram when working in terms of Net force, draw (1) a body, (2) the acceleration of the body (3) the net force on the body, and (4) coordinate axes."))))


;; following draws a standard free-body-diagram, for qualititative problems that ask for 
;; fbd's only.  This shows a body and all forces on it. It differs from the "NL" vector diagram 
;; preparatory to applying Newton's Laws in that NL diagram also includes acceleration and axes.
;; we make axes optional here.
(defoperator draw-standard-fbd (?b ?t)
   :preconditions 
           ((body ?b ?t)
	    (forces ?b ?t ?forces)
	    (optional (axis-for ?b ?t x 0)))
   :effects ((fbd ?b ?t)))

;;; ==================== The gravitational force ==============================

;;; This operator and the next represent writing W=m*g.  Because
;;; weight is treated as a magnitude in this equation, it is a scalar
;;; equation and not a vector equation.  Thus, students are not required
;;; to draw some kind of vector diagram.  However, because the Andes tools
;;; currently force students to draw a weight vector in order to define a
;;; variable for the magnitude of a weight, the students will still be
;;; required to draw at least that one vector.
;;; 
;;; Like all scalar equations,
;;; we use one operator (this one) to represent knowledge of what quantities might be
;;; in the equation if it is written.  In this case, all three quantities (w, m and g) are certain
;;; to be in the equation, but things are not so certain for other equations.  At any rate,
;;; the second operator does the actual process of preparing to write the equation then
;;; writing it.

(defoperator wt-law-contains (?quantity)
  :specifications "
   If a body is near a planet,
   then the weight law for the body potentially contains
     the magnitude of the weight force,
     the mass of the body, and
     the gravitational constant for the planet."
  :preconditions
  ((any-member ?quantity
	        ((at (mag (force ?b ?planet weight)) ?t)
		 (mass ?b)
		 (gravitational-acceleration ?planet)))
   ; make sure this is not case where ?b is cm of rigid body. For that
   ; we need the mass of the whole body, plus special hint.
   (not (part-of ?b ?rigid-body))
   (time ?t)
   (near-planet ?planet)
   (not (massless ?b))) 
  :effects
  ((eqn-contains (wt-law ?b ?t) ?quantity)))
  
;;; This operator models writing the W=m*g equation.  The variable for
;;; the relevant quantities will be either defined either via
;;; subgoaling or recalled if they have already been defined.
;;; 
;;; Current Andes predefines g in problems that use it but does not provide 
;;; a way for the student to define a variable for gravitational acceleration.  
;;; One possibility would be to represent g as a parameter.  Parameters are 
;;; symbolic quantities that are given in the problem statement.  If a 
;;; parameter appears in an equation, the code in the top level section knows 
;;; not to create a subgoal for it.  In fact, it will not be returned by 
;;; vars-in-eqns because a parameter is not a variable.
;;;
;;; However, for consistency we now treat g as any other variable and will 
;;; have to add a means to the interface to define it or to specify predefined
;;; variables in the problem statement somehow.

(defoperator wt-law (?b ?t)
  
  :specifications "
   If a body is near a planet,
     and it is not massless,
     and you can find the appropriate variables,
   then write W=m*g where W is the magnitude of the weight force
     on the body, m is the body's mass and g is the gravitational
     acceleration of the planet."
  :preconditions
   ((near-planet ?planet)
    (not (massless ?b))
    (variable ?m-var (mass ?b))
    (variable ?w-var (at (mag (force ?b ?planet weight)) ?t))
    (variable ?g-var (gravitational-acceleration ?planet))
    )
  :effects
   ((eqn (= ?w-var (* ?m-var ?g-var)) (wt-law ?b ?t)))
  :hint
  ((point (string "Try applying the weight law."))
   (teach 
       (kcd "write_w_is_mg")
       (string "The weight law for a body is W=m*g, where W is the magnitude of the weight force acting on the body, m is the body's mass and g is the gravitational acceleration of earth or whatever planet is nearby."))
   (bottom-out (string "Write ~a=~a*~a" (?w-var algebra) (?m-var algebra) (?g-var algebra)))))

;; variant applies weight to a rigid body. In this case the quantity is
;; specified as a force acting on the cm, not on the whole body.
(defoperator wt-law-cm-contains (?quantity)
  :specifications "
   If a rigid body is near a planet,
   then the weight law for the body potentially contains
     the magnitude of the weight force acting at the cm,
     the mass of the body, and
     the gravitational constant for the planet."
  :preconditions
  ((any-member ?quantity
	        ((at (mag (force ?b ?planet weight)) ?t)
		 (mass ?b)
		 (gravitational-acceleration ?planet)))
   ; make sure this is case where ?b is cm of rigid body. 
   (in-wm (part-of ?b ?rigid-body))
   (time ?t)
   (near-planet ?planet)
   (not (massless ?rigid-body))) 
  :effects
  ((eqn-contains (wt-law ?rigid-body ?t) ?quantity)))

(defoperator wt-law-cm (?b ?t)
  :preconditions
   ((near-planet ?planet)
    (not (massless ?b))
    (variable ?m-var (mass ?b))
    ; !!! temp hack: presuppose cm of body is named 'cm
    (variable ?w-var (at (mag (force cm ?planet weight)) ?t))
    (variable ?g-var (gravitational-acceleration ?planet))
    )
  :effects
   ((eqn (= ?w-var (* ?m-var ?g-var)) (wt-law ?b ?t)))
  :hint
  ((point (string "Try applying the weight law."))
   (teach 
       (string "The weight law for a body is W=m*g, where W is the magnitude of the weight force acting on the body, m is the body's mass and g is the gravitational acceleration of earth or whatever planet is nearby."))
   (bottom-out (string "Write ~a=~a*~a" (?w-var algebra) (?m-var algebra) (?g-var algebra)))))


;;; This operator models writing the Fs = k * compression/extension equation.  
;;;The variable for
;;; the relevant quantities will be either defined either via
;;; subgoaling or recalled if they have already been defined.
;;; 
	       
(def-psmclass spring-law (spring-law ?body ?time)
  :complexity minor
  :english ("Hooke's Law")
  :expformat ("applying Hooke's Law to ~a " (nlg ?body))
  :EqnFormat ("Fs = k*d" ))

(defoperator spring-law-compression (?b ?t)
  
  :specifications "
   If a body is near a planet,
     and it is not massless,
     and you can find the appropriate variables,
     then write Fs=k*d where Fs is the magnitude of the spring force
     on the body, k is the spring constant and d is the compression or
     extension distance of the spring."
  :preconditions(
                 (near-planet ?planet)
                 (variable ?s-var (at (mag (force ?b ?spring spring)) ?t))
                 (variable ?k-var (spring-constant ?spring))
                 (variable ?d-var (at (compression ?spring) ?t))
                 )
  :effects (
            (eqn (= ?s-var (* ?k-var ?d-var)) (spring-law ?b ?t)))
)

#|
(defoperator spring-law-extension (?b ?t)
  
  :specifications "
   If a body is near a planet,
     and it is not massless,
     and you can find the appropriate variables,
     then write Fs=k*d where Fs is the magnitude of the spring force
     on the body, k is the spring constant and d is the compression or
     extension distance of the spring."
  :preconditions(
                 (near-planet ?planet)
                 (variable ?s-var (at (mag (force ?b ?spring spring)) ?t))
                 (variable ?k-var (spring-constant ?spring))
                 (variable ?d-var (at (extension ?spring) ?t))
                 )
  :effects (
            (eqn (= ?s-var (* ?k-var ?d-var)) (spring-law ?b ?t)))
)
|#
  ;; variant applies weight to a rigid body. In this case the quantity is
;; specified as a force acting on the cm, not on the whole body.
(defoperator spring-law-contains (?quantity)
  :specifications "
   If a rigid body then the spring law for the body potentially contains
     the magnitude of the spring force,the spring constant, and
     the compression/extension."
  :preconditions (
                  (any-member ?quantity (
                                         (at (mag (force ?b ?spring spring)) ?t)
                                         (at (spring-constant ?s) ?t)
                                         (at (compression ?s) ?t)
                                         )
                              )
                  ; make sure this is case where ?b is cm of rigid body. 
               ;   (in-wm (part-of ?b ?rigid-body))
                  (time ?t)
                  (uses-k-and-d) ;Forces rule to fire only if k and d are needed to solve problem
                  (variable ?var (mass ?b))
                  (near-planet ?planet)
               ;   (not (massless ?rigid-body))
                  ) 
  :effects (
            (eqn-contains (spring-law ?b ?t) ?quantity))
  )

;;; gravitational acceleration
;;; This represents entering the known constant value 9.807 m/s^2 for the 
;;; gravitational acceleration near the surface of the Earth.
;;; g is not expected to be known for other planets so will have to be 
;;; given in the problem statement or treated as a parameter.
;;;
;;; The "std-constant" equation ID is used so the bubble-graph driver
;;; can give this special treatment: if a quantity is determined because
;;; it is a standard constant, there is no need to try to seek it by any
;;; other equations.
(defoperator g-on-earth-contains(?quantity)
  :preconditions 
    ( (any-member ?quantity ((gravitational-acceleration earth))) )
  :effects
    ( (eqn-contains (std-constant g) ?quantity) )
    )

(defoperator write-g-on-earth ()
  :preconditions 
    ( (variable ?g-var (gravitational-acceleration earth)) )
  :effects ( 
    (eqn (= ?g-var (dnum 9.8 |m/s^2|)) (std-constant g)) 
   )
  :hint
  ((point (string "You should know the value of g for the Earth"))
   (teach (string "You can use 9.8 m/s^2 for the value of g near the surface of the Earth"))
   (bottom-out (string "Write the equation ~A" ((= ?g-var (dnum 9.8 |m/s^2|)) algebra)))
    ))

; This models defining a variable for gravitational acceleration. In
; current Andes this step is not needed since g is predefined as a
; student variable in problems that need it, however we expect to
; use something like this in the future for consistency. We could model 
; the ability to use terms for certain predefined constants without defining
; them by adding a (variable g ...) in the problem statement for any problem
; that uses them. Perhaps a pre-processing phase could add the set of 
; predefined constants to every problem's givens. But until we sort out
; how to handle predefined terms, this is the consistent method to use.
(defoperator define-grav-accel (?planet)
 :preconditions 
 	( (bind ?g-var (format-sym "g_~A" ?planet)) )
 :effects 
 	( (variable ?g-var (gravitational-acceleration ?planet)) ))

;;
;; Following handles the gravitational constant G (upper-case!).
;; Currently the rules for this work the same way as for little g.
;; What students have to do on the interface wrt constants doesn't really 
;; depend on the rules here but on the help system per-problem initialization. 
;; If students don't have to enter G then the help system should predefine 
;; the variable G. If students don't have to enter the value
;; then it should pre-enter the equation giving its value.
;;
(defoperator G-contains()
  :effects ( (eqn-contains (std-constant grav-constant) (grav-constant)) ))

(defoperator write-value-of-G ()
  :preconditions 
    ( (variable ?G-var (grav-constant)) )
  :effects ( 
    (eqn (= ?G-var (dnum 6.67E-11 |N.m^2/kg^2|)) (std-constant grav-constant)) 
   )
  :hint
  ((point (string "You can find the value of the gravitational constant G in your textbook. The value to three significant figures should be used in Andes problems."))
   (teach (string "You can use 6.67E-11 N.m/kg^2 as the value of G."))
   (bottom-out (string "Write the equation ~A" ((= ?G-var (dnum 6.67E-11 |N.m^2/kg^2|)) algebra)))
    ))

(defoperator define-G ()
 :effects ( (variable |G| (grav-constant)) ))

;;; ========================== Newton's law ================================ 

;;; NL is newton's second law.  It is represented by several operators.  
;;; 
;;; The first one indicates what quantities might be contained in the
;;; equation if it should be written.  Note that the quantities are
;;; not guaranteed to be contained in the ultimate equation.  For
;;; instance, if the body is not accelerating, then the variables for
;;; mass and acceleration will not be in the equation.  When the
;;; solver unifies with one of the quantities in the list, some
;;; variables in the vector equation's identifier are bound.  For NL,
;;; the body and time are always bound.
;;; 
;;; The other operators expects to get a vector equation identifier
;;; that has some arguments bound, and they do all the work to write
;;; the equation.  So the vector equation identifier is a way of
;;; passing info (e.g., the body and the time) from the sought
;;; quantity to the hard working operator.
;;; 
;;; I'm not sure if hints on this operator will ever by used, but if
;;; so, it would be better to have the sought quantity available, as
;;; that would make the hint message nicer.
;;;


(defoperator NL-vector-contains (?quantity)
  :specifications 
   "Newton's law potentially contains the body's mass, 
     the magnitude of its acceleration, and
     the direction of its acceleration"
  :preconditions 
  ((any-member ?quantity
	        ((mass ?b)
		 (at (mag (accel ?b)) ?t)
		 (at (dir (accel ?b)) ?t)
		 (at (mag (force ?b ?agent ?type)) ?t)
		 (at (dir (force ?b ?agent ?type)) ?t)))
   (not (unknown-forces))
   (object ?b)
   (time ?t))
  :effects
   ((vector-psm-contains (NL ?b ?t) ?quantity)))

#|
; URGH, hack for pressure forces. Our force quantity doesn't contain a slot for
; place of application, so pressure forces are defined as acting on surfaces. 
; But we have to know that Newton's Law applied to a body can find one of these
; forces on a body's surface.
(defoperator NL-vector-contains-pressure (?surface ?fluid ?t)
  :preconditions 
   ((in-wm (fluid-contact ?b ?surface ?fluid ?point ?t-pressure ?dir))
   (test (tinsidep ?t ?t-pressure))
   (not (unknown-forces))) 
   :effects
   ((vector-psm-contains (NL ?b ?t) (at (mag(force ?surface ?fluid pressure)) ?t) )))
|#

;;; We have to define a special NL-net variant psm to use net force rather 
;;; than sum F1 + F2 ...  for those few problems that work in terms of net 
;;; force only without determining how net force is decomposed into individual
;;; forces. Net force is the sought in these; it could be given as well.
;;; In other problems net force is not introduced. This is not just a
;;; a specific choice of component equation under the NL method, on par 
;;; with choice of NFL or NSL, since it also requires a slightly different 
;;; type of free body diagram. 
;;;
;;; Note that as we have it NSL can't find net force and NSL-net can't find
;;; anything *but* net force, so should be mutually exclusive: 
;;;      if zero accel => NL/NFL
;;;      else if not net force => NL/NSL
;;;      else net force => NL/NSL-net
;;;
(defoperator NL-net-vector-contains (?quantity)
  :specifications 
   "Newton's law potentially contains the body's mass, 
     the magnitude of its acceleration, and
     the direction of its acceleration"
  :preconditions (
   (any-member ?quantity
	        (
		 (at (mag (net-force ?b)) ?t)
		 (at (dir (net-force ?b)) ?t)
		 ; for now, only use this method when seeking net force
		 ; to keep down dead-path equations in other problems.
		 ; uncomment the following if we ever add net-force 
		 ; problems that seek mass or accel.
		 ;(mass ?b)
		 ;(at (mag (accel ?b)) ?t)
		 ;(at (dir (accel ?b)) ?t)
		 ))
   (object ?b)
   (time ?t)
   ; only use this if non-zero acceleration, no NFL form of this.
   (not (motion ?b ?t-motion at-rest)
        (tinsidep ?t ?t-motion))
  )
  :effects (
    (vector-psm-contains (NL ?b ?t) ?quantity)
    ; since we know which compo-eqn we'll be using, we can 
    ; select it now, rather than requiring further operators to do so
    (compo-eqn-contains  (NL ?b ?t) NSL-net ?quantity)
    ; Further nl operators, esp diagram drawing, will test the following
    ; in wm to tell whether net-force version should be drawn
    (use-net-force)
  ))


;;; The work of writing NL is divided into drawing the fbd, selecting
;;; an NL equation and writing the NL in component form.  An operator
;;; defined earlier draws the fbd.  These operators just select a
;;; component equation.  There are just two to select from: Newton's
;;; first and second law.  This operator selects NFL.
  
(defoperator NFL-zero-accel (?quantity)
  :specifications "
   If the object has zero acceleration over a time period,
      and that time perid includes the one we're useing for NL,
   then NFL applies and it potentially contains
     the magnitude and direction of any force acting on the body"
  :preconditions 
  ((any-member ?quantity
	        ((at (mag (force ?b ?agent ?type)) ?t)
		 (at (dir (force ?b ?agent ?type)) ?t)))
   (object ?b)
   (time ?t)
   (not (unknown-forces))
   (vector ?b (at (accel ?b) ?t-accel) zero)
   (test (tinsidep ?t ?t-accel)))
  :effects
   ((compo-eqn-contains (NL ?b ?t) nfl ?quantity))
)

#|
;; Urgh, hack for pressure forces, see above
(defoperator NFL-zero-accel-for-pressure (surface ?fluid ?t)
  :preconditions 
   ((in-wm (fluid-contact ?b ?surface ?fluid ?point ?t-pressure ?dir))
   (test (tinsidep ?t ?t-pressure))
   (not (unknown-forces))
   (vector ?b (at (accel ?b) ?t-accel) zero)
   (test (tinsidep ?t ?t-accel))) 
   :effects
   ((compo-eqn-contains (NL ?b ?t) nfl (at (mag(force ?surface ?fluid pressure)) ?t) )))
|#

;;; I've never seen a problem where NL is applied to a massless object
;;; but it could occur, so here is an operator to select NFL for that
;;; case.

(defoperator NFL-massless (?quantity)
  :specifications "
   If a body is massless,
   Then NFL applies and it potentially contains
     the magnitude and direction of any force acting on the body"
  :preconditions 
  ((any-member ?quantity
	        ((at (mag (force ?b ?agent ?type)) ?t)
		 (at (dir (force ?b ?agent ?type)) ?t)))
   (object ?b)
   (time ?t)
   (massless ?b))
  :effects
   ((compo-eqn-contains (NL ?b ?t) nfl ?quantity))
)

;;; This operator indicates when Newton's second law (NSL) is
;;; applicable.  It should be applicable exactly when NFL is not applicable.
;;; That could be easily expressed if we could have goals with priorities,
;;; but we don't right now.  So we write out the condition: If an object is 
;;; massless or has zero acceleration during a time period containing 
;;; the target time, then NSL is prevented from applying. This makes use
;;; of the optional second test clause in the "not" condition, in case
;;; the time of zero acceleration might be wider than the target time.
;;;
;;; Also, to handle cases where a problem describes an acceleration 
;;; but does not determine the forces causing it, we test for the
;;; statement "unknown-forces" to block the attempt to apply Newton's Law.
;;;
;;; Time may be an interval or an instant. In case of interval, we
;;; make sure endpoints are consecutive, to avoid applying this accross
;;; two sub-segments with different forces. [necessary? Could also 
;;; fail to determine forces applying over this composite segment]

(defoperator NSL (?quantity)
  :specifications "
   If the acceleration is not zero during the target time period
      and the body is not massless during the target time period,
   then NSL applies and it potentially contains
     the mass of the body,
     the magnitude and direction of its acceleration"
  :preconditions 
  ((any-member ?quantity
	        ((at (mag (force ?b ?agent ?type)) ?t)
		 (at (dir (force ?b ?agent ?type)) ?t)
		 (mass ?b)
		 (at (mag (accel ?b)) ?t)
		 (at (dir (accel ?b)) ?t)))
   (object ?b)
   (time ?t)
   (debug "problem~%.")
   (not (unknown-forces))
   ; Can't apply over interval if variable forces during interval.
   ; if time is an interval, make sure endpoints are consecutive,
   ; else forces might be different between sub-segments
   (test (not (and (time-intervalp ?t)
                   (> (- (third ?t) (second ?t)) 1))))
   ; Force from expanding spring will be variable.  NSL would still apply over
   ; interval for average spring force, though we have no way to compute that if
   ; it isn't given. For now we just rule out Newton's Law if there's any spring 
   ; contact during time of application.  This would have to change if we wanted to 
   ; handle spring forces at an instant as for objects in static equilibrium.
 ;  (not (spring-contact ?b ?spring ?t-contact (dnum ?sforce-dir |deg|)) 
 ;       (tintersect2 ?t-contact ?t))
   ; accel would have been drawn when drew NL fbd. Make sure it's non-zero
   (not (vector ?b (at (accel ?b) ?t-accel) zero)
        (tinsidep ?t ?t-accel))
   (not (massless ?b)))
  :effects
   ((compo-eqn-contains (NL ?b ?t) nsl ?quantity))
 )
 
;;; This operator writes newton's first law in component form for all
;;; forces.  This operator expects to get the body, time, axis label,
;;; axis rotation via the equation identifier in the effects.  It
;;; fetches the set of forces from working memory and the component
;;; variables for all forces.  It writes the equations and also leaves
;;; behind a proposition indicating which component variables are in
;;; the equation.  For now, the hints repeat ones given by the
;;; equation selection operator, as I don't know which one will be
;;; targetted by the help system yet.

(defoperator write-NFL-compo (?b ?t ?xyz ?rot)
  :specifications 
   "If the goal is to write newton's first law in component form 
      for ?body at ?time along ?axis at ?rot,
      ensure there are component variables ?compo-vars for the components 
      of each of the forces on ?b at ?t,
   then write ?f1-compo + ?f2-compo + ... = 0, where 
     ?fi-compo are the forces' component variables."
  :preconditions
  ((in-wm (forces ?b ?t ?forces))
   (map ?f ?forces 
   	(variable ?compo-var (at (compo ?xyz ?rot ?f) ?t))
	?compo-var ?f-compo-vars)
   ; we want Fi = m * a to be accepted if it is written. But also
   ; need to write Sum Fi = 0 as final eqn so won't appear to contain m, a
   ; so we make sure we have a compo var and put implicit eqn in effects.
    (variable ?a-compo (at (compo ?xyz ?rot (accel ?b)) ?t))
  )
  :effects
   ((eqn (= (+ . ?f-compo-vars) 0)
	 (compo-eqn nfl ?xyz ?rot (nl ?b ?t)))
    (eqn-compos (compo-eqn nfl ?xyz ?rot (nl ?b ?t)) ?f-compo-vars)
    (implicit-eqn (= ?a-compo 0) (at (compo ?xyz ?rot (accel ?b)) ?t)))
  :hint
   ((point (string "Because the acceleration of ~a is zero ~a, you can apply Newton's first law to it." ?b (?t pp)))
    (teach (string 
    "Newton's second law F = m*a states that the net force on an object = the object's mass times its acceleration. In this case the acceleration is zero so you know the sum of all forces on the object must be zero. This vector principle can be applied component-wise to require that the the force components in any direction sum to zero."
    ))
    (bottom-out (string "Because ~a is not accelerating ~a, write Newton's first law as ~A" ?b (?t pp) ((= (+ . ?f-compo-vars) 0) algebra)))))


;;; This operator writes Newton's second law in component form.  It
;;; expects to get the body, time, axis label (?xyz) and axis rotation
;;; (?rot) via the equation identifier in the effects, and it fetches
;;; the relevant vectors from wm.  It just looks up the appropriate
;;; variables and writes the equation.  It also leaves behind a
;;; proposition recording the component variables that appear in the
;;; equation.  

(defoperator write-NSL-compo (?b ?t ?xyz ?rot)
  :specifications 
   "If the goal is to write newton's second law in component form,
      ensure there are component variables ?compo-vars for the components 
      of each of the forces on ?b at ?t,
   then write ?f1c + ?f2c + ... = ?m * ?ac, where ?fic and ?ac
      are the appropriate component variables for ?fi and ?a,
      respectively."
  :preconditions
  ((in-wm (forces ?b ?t ?forces))
   ; for each force on b at t, define a component variable, 
   ; collecting variable names into ?f-compo-vars
   ; (debug "write-NSL-compo(~A ~A ~A): defining force compo vars~%" ?b ?xyz ?rot)
   (map ?f ?forces 
    (variable ?f-compo-var (at (compo ?xyz ?rot ?f) ?t))
   	?f-compo-var ?f-compo-vars)
   ; (debug "write-NSL-compo: set of force compo-vars = ~A~%" ?force-compo-vars)
   ; add acceleration compo var to form list of all compo vars in equation
   (variable ?a-compo (at (compo ?xyz ?rot (accel ?b)) ?t))
   (bind ?eqn-compo-vars (cons ?a-compo ?f-compo-vars))
   (debug "write-NSL-compo: eqn-compo-vars = ~A~%" ?eqn-compo-vars)
   (variable ?m (mass ?b)))
  :effects
   ((eqn (= (+ . ?f-compo-vars) (* ?m ?a-compo))
	 (compo-eqn nsl ?xyz ?rot (nl ?b ?t)))
    (eqn-compos (compo-eqn nsl ?xyz ?rot (nl ?b ?t)) ?eqn-compo-vars))
  :hint
   ((point (string "Because the acceleration of ~a is non-zero ~a, you can apply Newton's Second law to it." (?b def-np) (?t pp)))
    (teach (string "Newton's second law F = m*a states that the net force on an object = the object's mass times its acceleration. Because the net force is the vector sum of all forces on the object, this can be applied component-wise to relate the sum of the force components in any direction to the mass times the component of acceleration in that direction."))
    (bottom-out (string "Write Newton's Second Law in terms of component variables along the ~A axis as ~A" ((axis ?xyz ?rot) symbols-label) ((= (+ . ?f-compo-vars) (* ?m ?a-compo)) algebra)))
    ))

;;; 
;;; This operator writes the net force version of Newton's second law in 
;;; component form.  
;;;
(defoperator write-NSL-net-compo (?b ?t ?xyz ?rot)
  :specifications 
   "If the goal is to use newton's second law for net force in component form,
      define component variables for the net force and acceleration,
   then write ?fnet_c = ?m * ?ac"
  :preconditions
  ((variable ?fnet-compo-var (at (compo ?xyz ?rot (net-force ?b)) ?t))
   (variable ?a-compo        (at (compo ?xyz ?rot (accel ?b)) ?t))
   (bind ?eqn-compo-vars (list ?a-compo ?fnet-compo-var))
   (variable ?m (mass ?b)))
  :effects (
    (eqn (= ?fnet-compo-var (* ?m ?a-compo))
	 (compo-eqn nsl-net ?xyz ?rot (nl ?b ?t)))
    (eqn-compos (compo-eqn nsl-net ?xyz ?rot (nl ?b ?t)) ?eqn-compo-vars)
  )
  :hint (
    (point (string "Because the acceleration of ~a is non-zero ~a, you can apply Newton's Second law." (?b def-np) (?t pp)))
    (teach (string "Newton's second law F = m*a states that the net force on an object = the object's mass times its acceleration. This can be applied component-wise to relate the net force in any direction to the mass times the component of acceleration in that direction."))
    (bottom-out (string "Write Newton's Second Law along the ~a axis in terms of component variables, namely, ~a" ((axis ?xyz ?rot) symbols-label) ((= ?fnet-compo-var (* ?m ?a-compo)) algebra)))
   )
)


;;; ====================== tensions equal  =================

;;; These two operators are for pulley systems, wherein a string connects two
;;; objects.  They assert that the magnitude fo the tension forces on
;;; the ends of a string are equal.  I'm not sure what kind of hint to
;;; give for these equation-contains operators.

(defoperator tensions-equal-contains (?quantity)
  :specifications "
   If the same string is attached to two objects,
   then the tensions-equal law can be applied,
     and it mentions the magnitudes of the tension forces on the objects."
  :preconditions
  ((any-member ?quantity
	        ((at (mag (force ?b1 ?string tension)) ?t)))
   ; can apply if string is connected to another body
   (tied-to ?string ?b2 ?t ?dir2)
   (test (not (equal ?b2 ?b1)))
   ; sort bodies in id so we don't generate both Tb = Tb2 and Tb2 = Tb
   (bind ?bodies (sort (list ?b1 ?b2) #'expr<))
   )
  :effects
  ((eqn-contains (tensions-equal ?string ?bodies ?t) ?quantity))
  )

;;; This operator writes the simple equation t1=t2, where t1 and t2
;;; are the magnitudes of the tension forces on the two bodies
;;; connected by the string. 
;;; ?bodies should have been set in tensions-equal-contains

(defoperator write-tensions-equal (?string ?bodies ?t)
  
  :specifications 
   "If a string is tied to two blocks,
   then the tension forces on them are equal."
  :preconditions
  ((bind ?b1 (first ?bodies))
   (bind ?b2 (second ?bodies))
   (variable ?t1-var (at (mag (force ?b1 ?string tension)) ?t))
   (variable ?t2-var (at (mag (force ?b2 ?string tension)) ?t)))
  :effects
  ((eqn (= ?t1-var ?t2-var) (tensions-equal ?string ?bodies ?t)))
  :hint
  ((teach 
      (kcd "tension=magnitude_of_tension_force")
      (string "When a string connects two objects, then the tension forces that it exerts on them have the same magnitude."))
   (bottom-out (string "Because ~a connects ~a and ~a, the tension forces it exerts on them have the same magnitude, so write ~a=~a." ?string ?b1 ?b2 (?t1-var algebra) (?t2-var algebra)))))

;;; ======================== connected bodies =====================
;;; Two bodies are said to be connected if the magnitudes of their
;;; kinematic variables are all equal.  This occurs when they are
;;; connected by a taut string, by one pushing on the other, by one
;;; carrying the other, etc.  Thus, we write the equation-producing
;;; operators to depend on a proposition (connected ?b1 ?b2 ?t) that
;;; is inferred from propositions describing taut strings, pushing,
;;; etc.
;;;
;;; Note: we ensure arguments to "connected" are sorted so only assert
;;; and use connections in a canonical order. This blocks writing both 
;;; vb1 = vb2  and vb2 = vb1.

(defoperator string-connects (?string ?b1 ?b2 ?t)
  :specifications "
  If a string connects two objects,
  then they are connected."
  :preconditions
  (
   ;;(debug "Trying connections ~a ~a ~a~%" ?b1 ?b2 ?t)
   (tied-to ?string ?b1 ?t ?dir1)
   (tied-to ?string ?b2 ?t ?dir2)
   ; Only apply to bodies in canonical order. 
   ; Note this test ensures they are distinct as well.
   (test (expr< ?b1 ?b2))   
   (not (connected ?b1 ?b2 ?t))
   (debug "found connected ~A %" ?bodies)
   )
  :effects
  ((connected ?b1 ?b2 ?t))
  )


(defoperator connected-accels-contains (?quantity)
  :specifications "
  If two objects are connected over a time period
  then for any interior time period,
     you can infer that magnitudes of their accelerations are equal,
     which is an equation that mentions the mags of the accels of the bodies."
  :preconditions (
   (any-member ?quantity
	        ((at (mag (accel ?b1)) ?t)
		 (at (mag (accel ?b2)) ?t)))
   (connected ?b1 ?b2 ?t-connected)
   (time ?t)
   (test (tinsidep ?t ?t-connected))
   ; this rule doesn't apply to connected points on rotating objects
   ; so make sure both bodies in straight line motion during sought time
   (in-wm (motion ?b1 ?t-straight1 (straight . ?dontcare1)))
   (test (tinsidep ?t ?t-straight1))
   (in-wm (motion ?b2 ?t-straight2 (straight . ?dontcare2)))
   (test (tinsidep ?t ?t-straight2))
  )
  :effects
  ((eqn-contains (connected-accels ?b1 ?b2 ?t) ?quantity)))

;;; This operator writes the equation a1=a2, where a1 and a2 are the
;;; magnitudes of the accelerations of two bodies.  This operator
;;; should not use in-wm to fetch the variables, because the need to
;;; define a second bodies acceleration variable causes that
;;; acceleration to be drawn.

(defoperator write-connected-accels (?b1 ?b2 ?t)
  
  :specifications "
  If two objects are connected over a time period
  then for any interior time period,
     their magnitudes are equal."
  :preconditions
  ((connected ?b1 ?b2 ?t)
   (variable ?a1-var (at (mag (accel ?b1)) ?t))
   (variable ?a2-var (at (mag (accel ?b2)) ?t)))
  :effects
  ((eqn (= ?a1-var ?a2-var) (connected-accels ?b1 ?b2 ?t)))
  :hint
  ((teach 
     (kcd "draw_compound_lk_body")
     (string "When two objects are connected, their accelerations have equal magnitude."))
   (bottom-out (string "Write ~a" ((= ?a1-var ?a2-var) algebra)))))

;;
;; Following uses the equality of velocities of connected objects. 
;; This applies in same conditions as connected-accels but also represents
;; a crucial condition needed for linked rotating objects such as the
;; two pulleys linked by a belt in Exkr6a that the linear velocities of
;; the points on the rims are equal. We do *not* want connected-accels
;; to apply in this case, since the centripetal acceleration of the two
;; points need not be the same, owing to the differing radii of the pulleys.
;; We could use a different proposition than "connected" for the case
;; of chained rotations; but currently we block this by including a restriction
;; to straight line motion in connected-accels.
;;
(defoperator connected-velocities-contains (?quantity)
  :specifications "
  If two objects are connected over a time period
  then for any interior time period,
     you can infer that magnitudes of their velocities are equal,
     which is an equation that mentions the mags of the velocities of the bodies."
  :preconditions
  ((any-member ?quantity
	        ((at (mag (velocity ?b1)) ?t)
		 (at (mag (velocity ?b2)) ?t)))
   (debug "trying connected b1 b2 for mag v b1=~A b2=~A~%" ?b1 ?b2)
   (connected ?b1 ?b2 ?t))
  :effects
  ((eqn-contains (connected-velocities ?b1 ?b2 ?t) ?quantity)))

;;; This operator writes the equation v1=v2, where v1 and v2 are the
;;; magnitudes of the velocities of two bodies.  This operator
;;; should not use in-wm to fetch the variables, because the need to
;;; define a second body's velocity variable causes that
;;; velocity to be drawn.

(defoperator write-connected-velocities (?b1 ?b2 ?t)
  
  :specifications "
  If two objects are connected over a time period
  then for any interior time period,
     their magnitudes are equal."
  :preconditions
  ((connected ?b1 ?b2 ?t)
   (variable ?v1-var (at (mag (velocity ?b1)) ?t))
   (variable ?v2-var (at (mag (velocity ?b2)) ?t)))
  :effects
  ((eqn (= ?v1-var ?v2-var) (connected-velocities ?b1 ?b2 ?t)))
  :hint
  ((teach 
      (kcd "draw_compound_lk_body")
      (string "When two objects are connected, their velocities have equal magnitude."))
   (bottom-out (string "Write ~a" ((= ?v1-var ?v2-var) algebra)))))


;================ Conservation of Energy ===============

; This method applies conservation of mechanical energy to a single body 
; at different times to find the sought quantity. It writes the top-level 
; equality of ; total mechanical energy, writes equations for all the 
; constituent terms (kinetic and potential) making up total mechanical energy 
; at each time, and plugs in the terms to get the final equation. 
;
; We look for gravitational potential energy due to nearby planet and 
; elastic potential energy stored in a compressed massless spring in contact 
; with the body at some time.  Properly speaking, the total energy is a 
; property of the body-planet-spring system, but that is implicit here. 
; For the future we should generalize this method to choose a system of objects 
; and sum the energies of all its constitutents, but this simple method 
; suffices to solve for the energy problems in Andes 1.
;
; Note: Many problems could in principle be solved either by kinematics or
; conservation of energy or a combination. However, our energy solution 
; requires use of the "height" quantity for gravitational pe, which specifies
; the height of the body with respect to a zero-level stipulated in the 
; problem givens.  Since the "height" of the body at various times is only 
; explicitly specified in the givens when we want energy methods to be used, 
; this functions to restrict the problems in which energy solutions will be found.  
; We don't have fully general rules that relate "height" to any other quantities 
; such as displacement, distance travelled, or distance between points, even 
; though change in height is in fact related to these. (Also, even if we could
; get the *change* in height from these, we still wouldn't know which height 
; was the zero-level.) 
; Moreover, if we *don't* specify displacement and time then kinematics solutions 
; cannot be found. 
; Specify both height and the kinematics quantities in the givens if you want 
; both kinematics and energy solutions to be found.
;
; These problems also rely on the expedient used in the CLIPS solutions of 
; simply stipulating the reference-point used as the zero of gravitational pe,
; so that height is a one-argument quantity.  This should probably be changed 
; in the future. The ANDES interface could change to provide some way for the 
; student to choose the zero level, and their equations would have to be translated.

; Note we need time parameters in the operator because one of the times is
; going to be chosen, and might be chosen multiple ways. For example, if our
; sought is height at 3 (as in Exe1a) we want different op-apps for 
; cons-energy 2 3 and cons-energy 1 3 because these are different equations
; in the solution graph.
(defoperator cons-energy-contains (?sought)
 :preconditions (
  ; check sought is one of cons-energy quants at timepoint t
  (any-member ?sought 
              ((at (mag (velocity ?b)) ?t)
	       (mass ?b) 
	       (at (height ?b) ?t)
	       (at (spring-const ?s) ?t)
	       (at (compression ?s) ?t)
	       (gravitational-acceleration ?planet)
	      ))
  ; Sought mass doesn't bind t; sought spring property doesn't bind b. 
  ; Following ensures we choose one. If it isn't appropriate e.g. chosen 
  ; body doesn't contact spring whose spring-constant is sought at times,
  ; this psm will still be applied but the resulting equation will fail to 
  ; contain the sought, so it will be rejected further on.
  (object ?b)   
  (time ?t)   
  (test (time-pointp ?t))
  ; choose a distinct time point other-t
  ; and bind t1 to earlier, t2 to later of the two times
  (time ?other-t)
  (test (and (time-pointp ?other-t)
   	     (not (equal ?other-t ?t))))
  (bind ?t1 (min ?t ?other-t))
  (bind ?t2 (max ?t ?other-t))
  ; need to ensure all forces conservative so energy is in fact conserved.
  ; Cheap way would be to assert it in problem statement. For now, test no 
  ; friction or drag, external applied or tension force on body. We test
  ; by testing for the situation descriptions that entail these forces.
  (not (given (at (dir (force ?b ?agent1 applied)) ?t-applied) ?dir1)
       (tinsidep ?t-applied `(during ,?t1 ,?t2)))
  (not (tied-to ?string1 ?b                        ?t-tension ?dir2)
       (tinsidep ?t-tension `(during ,?t1 ,?t2)))
  (not (slides-against ?b ?surface1                ?t-friction)
       (tinsidep ?t-friction `(during ,?t1 ,?t2)))
  (not (drag    ?b ?medium                         ?t-drag)
       (tinsidep ?t-drag `(during ,?t1 ,?t2)))
  ; Also not conserved if an external work source is given (may not
  ; be able to find force in this case, but still told it is doing work).
  (not (does-work-on ?agent ?b ?t-work)
       (tinsidep ?t-drag `(during ,?t1 ,?t2)))
  ; make sure we can determine all forces:
  (not (unknown-forces))
  )
 :effects (
    (derived-eqn-contains (cons-energy ?b ?t1 ?t2) ?sought)
    ; set flag to choose standard axes because energy problem
    (use-energy-axes)
 ))

(defoperator apply-energy-cons (?b ?t1 ?t2)
 :preconditions (
  ; Draw the boda planet y
  (body ?b (during ?t1 ?t2))
  (energy-axes ?b (during ?t1 ?t2))
  ; write equation ME_i = ME_f 
  (eqn ?te12eqn (total-energy-cons ?b ?t1 ?t2))
  ; write equation ME_i = K_i + Ug_i [+ Us_i]
  ; plus sub-eqns for all terms on the rhs, getting combined result
  (derived-eqn (= ?te1 ?te1-exp) (total-energy ?b ?t1))
  ; write equation ME_f = K_f + Ug_f [+ Us_f]
  ; plus sub-eqns for terms on the rhs, getting combined result
  (derived-eqn (= ?te2 ?te2-exp) (total-energy ?b ?t2))
  ; write total mech. energy equivalence with all energy terms plugged in
  (bind ?eqn-algebra `(= ,?te1-exp ,?te2-exp))
  (debug "final cons-energy eq: ~A~%" ?eqn-algebra)
 )
 :effects (
  (derived-eqn ?eqn-algebra (cons-energy ?b ?t1 ?t2))
 )
 ; no hints here because effect is summary derived-equation -- students write
 ; only the subsidiary equations, so only ops for those have hints
)

; generate equation TME_1 = TME_2
; currently only used as subsidiary equation in cons-energy psm
; !!! Could also use formulation: K1 + U1 = K2 + U2 
; !!! where Ui is total potential energy at i
(defoperator write-energy-cons (?b ?t1 ?t2)
  :preconditions (
   (variable ?te1-var (at (total-energy ?b) ?t1))
   (variable ?te2-var (at (total-energy ?b) ?t2))
  )
  :effects (
  (eqn (= ?te1-var ?te2-var) (total-energy-cons ?b ?t1 ?t2))
  )
  :hint (
  (point (string "Think about what you can conclude about the total mechanical energy in the system throughout this problem."))
  (point (string "Notice that all forces doing work on ~a in this problem are conservative." ?b ))
  (teach (string "When the only forces doing work on a body are conservative, then the law of conservation of energy states that the total mechanical energy remains constant.  That is, the total mechanical energy at one time is equal to the total mechanical energy at another time, for any two time points."))
  (bottom-out (string "Write ~a" ((= ?te1-var ?te2-var) algebra)))
  ))

; Following writes an equation for total mechanical energy and also fills in
; expressions for all of the constituent terms that occur in it, returning
; the appropriate combination as a derived equation.  Ex:
;       TME = K + Ug + Us                       (total-energy-top)
;         K = 1/2 m*v^2
;        Ug = m*g*h
;        Us = 1/2 k*x^2 
;       ------------------------------------
;       TME = 1/2 m*v^2 + m*g*h [+ 1/2*k*x^2]    (total-energy)
; The spring term is omitted for problems without a spring. Other forms of
; potential energy (e.g. electrical) might be added in the future.
;
; This operation similar to writing a component equation then plugging in 
; projections for all of the components in it.  Rather than use the technique
; used for projections, we rely on a naming convention for the equations for 
; the constituent terms, s.t. an expression for (at (energy-type ?b) ?t) can 
; be obtained by writing the equation named (energy-type ?b ?t)
(defoperator write-total-energy (?b ?t)
 :preconditions (
   ; first get top-level equation summing constituents of total energy
   (eqn (= ?te-var (+ . ?energy-vars)) (total-energy-top ?b ?t))
   ; map list of constituent energy vars from rhs to list of energy quants
   (map ?var ?energy-vars
        (in-wm (variable ?var ?quant))
     ?quant ?energy-quants)
   ; convert list of quantities to list of equation ids, using transform
   ; (at (energy-type ?arg1 ...) ?t) ==> (energy-type ?arg1 ...  ?t)
   ; NB: requires that pe-quant-name and pe-equation id must be the same!
   (bind ?energy-eqn-ids (mapcar #'(lambda(q) (cdr (flatten q)))
                                 ?energy-quants))
   ; generate equation for each constituent quantity, saving rhs exprs
   (map ?eqn-id ?energy-eqn-ids
	(eqn (= ?var ?expr) ?eqn-id)
     ?expr ?energy-exprs)
 )
 :effects (
  (derived-eqn (= ?te-var (+ . ?energy-exprs)) (total-energy ?b ?t))
 ))

; equation TME = Kinetic Energy + Grav PE + Spring PE
; !!! spring PE term could just be omitted if spring not extended at t
(defoperator write-total-energy-top (?b ?t)
  :preconditions (
   (variable ?te-var (at (total-energy ?b) ?t))
   (variable ?ke-var (at (kinetic-energy ?b) ?t))
   ; define variable for each type of pe that applies in this problem
   (setof (pe-var ?b ?t ?var) 
              ?var ?pe-vars)
   (debug "Set of pe-vars = ~A~%" ?pe-vars)
  )
  :effects (
  (eqn (= ?te-var (+ ?ke-var . ?pe-vars)) (total-energy-top ?b ?t))
  )
  :hint (
   (point (string "Try writing an equation defining the total mechanical energy of the system containing ~a ~a" (?b def-np)(?t pp)))
   (teach (string "The total mechanical energy is the sum of the kinetic energy and the potential energy. Potential energy consists of the gravitational potential energy and the elastic potential energy in any spring in the system."))
   (bottom-out (string "Write ~a" ((= ?te-var (+ ?ke-var . ?pe-vars)) algebra)))
   ))

; these operators achieve (pe-var ?b ?t ?var) by defining a variable needed for 
; applicable constituents of the potential energy of body at t in this problem
(defoperator define-grav-pe-var (?b ?t)
    :preconditions (
	  ; use this for gravity near surface of a planet only
          (near-planet ?planet) ; 
	  (variable ?var (at (grav-energy ?b ?planet) ?t))
    )
    :effects ( (pe-var ?b ?t ?var) ))

(defoperator define-spring-pe (?b ?t)
    :preconditions (
       ; use this form if spring contact present anywhere in problem -- 
       ; spring pe may be zero at some times but still use a term for it.
       (in-wm (spring-contact ?b ?spring . ?dontcare))
       (variable ?var (at (spring-energy ?b ?spring) ?t))
    )
    :effects ( (pe-var ?b ?t ?var) ))


;;
;; equations for constituents of total energy:
;;

; equation KE = 1/2 * m * v^2

#| ; would be needed if a psm, but currently used as subsidiary eqn only
(defoperator kinetic-energy-contains (?sought)
 :preconditions (
   (any-member ?sought ((at (mag(velocity ?body)) ?t)
                        (mass ?body)))
   (time ?t)
 )
 :effects (
   (eqn-contains (kinetic-energy ?body ?t) ?sought)
 ))
|# 

(defoperator write-kinetic-energy (?body ?t)
  :preconditions (
   (variable ?ke-var (at (kinetic-energy ?body) ?t))
   (variable ?m-var (mass ?body))
   (variable ?v-var (at (mag (velocity ?body)) ?t))
  )
  :effects (
   (eqn (= ?ke-var (* 0.5 ?m-var (^ ?v-var 2)))
        (kinetic-energy ?body ?t))
   )
  :hint (
  (point (string "Try writing the definition of kinetic energy of ~a ~a" (?body def-np)(?t pp)))
  (teach (string "The translational kinetic energy of an object is defined as one half its mass times its velocity squared.  That is, 0.5*m*v^2."))
  (bottom-out (string "Write the equation ~a" ((= ?ke-var (* 0.5 ?m-var (^ ?v-var 2))) algebra)))
  ))

; equation PE_grav = m * g * h
; Note relies on problem statement stipulating zero level. 
(defoperator write-grav-energy (?body ?planet ?t)
  :preconditions (
  (near-planet ?planet)
  (variable ?PE-var (at (grav-energy ?body ?planet) ?t))
  (variable ?m-var  (mass ?body))
  (variable ?h-var  (at (height ?body) ?t))
  (variable ?g-var (gravitational-acceleration ?planet))
  )
  :effects (
  (eqn (= ?PE-var (* ?m-var ?g-var ?h-var)) (grav-energy ?body ?planet ?t))
  )
  :hint (
   (point (string "Try writing an equation for gravitational potential energy of ~a ~a" (?body def-np) (?t pp)))
   (teach (string "The gravitational potential energy of a body near the surface of a planet is m*g*h, its mass times the gravitational acceleration times its height above the stipulated zero level."))
   (bottom-out (string "Write ~a" ((= ?PE-var (* ?m-var ?g-var ?h-var)) algebra)))
   ))

#| ; want to give this versoin a different equation id from the mgh version
   ; so that it is a different choice on the equation menu.
   ; But also need it to function as a way of writing equation
   ; for grav-energy in large-scale gravitation case. Need to change
   ; the way write-total-energy gets from set of energy-quants to
   ; writing sub-equations for those quants. This would not be an issue
   ; if we broke out 
(defoperator write-grav-energy-large (?body ?planet ?t)
  :preconditions (
  (gravity ?body ?planet)
  (variable ?UG (at (grav-energy ?body ?planet) ?t))
  (variable ?m1  (mass ?body))
  (variable ?m2  (mass ?planet))
  (center-of ?body ?c1)
  (center-of ?planet ?c2)
  (variable ?r  (at (mag (relative-position ?c1 ?c2)) ?t))
  (variable ?G  (grav-constant))
  )
  :effects (
      (eqn (= ?UG (/ (* ?G ?m1 ?m2) r)) (grav-energy ?body ?planet ?t))
  )
  :hint (
   (point (string "Try writing an equation for gravitational potential energy of ~a ~a" (?body def-np) (?t pp)))
   (teach (string "The gravitational potential energy of a body at a large distance from a planet is G*m1*m2/r, the product of the the gravitational constant, the mass of the body and the mass of the planet, divided by the body's distance from the center of the planet."))
   (bottom-out (string "Write the equation ~a" ((= ?UG (/ (* ?G ?m1 ?m2) r)) algebra)))
   ))
|#

; equation PE_spring = 1/2 * k * d^2 
; where k = spring const, d = compression distance.
; This only applies if spring in contact with object with non-zero compression, as
; given in the spring-contact statement. We allow spring-contact to be asserted 
; even when spring is uncompressed so that the general equation for spring PE is
; used even when d=0 -- but could have special case to just write Us=0 in this case.
; !!! PE-var should include slot for the spring in definition, but this
; would block use in write-null-spring-energy below.
(defoperator write-spring-energy (?body ?spring ?t)
  :preconditions (
  (spring-contact ?body ?spring ?t-contact ?sforce-dir)
  (test (tinsidep ?t ?t-contact))
  (variable ?PE-var (at (spring-energy ?body ?spring) ?t))
  (variable ?k-var  (spring-constant ?spring))
  (variable ?d-var  (at (compression ?spring) ?t))
  )
  :effects (
  (eqn (= ?PE-var (* 0.5 ?k-var (^ ?d-var 2)))
       (spring-energy ?body ?spring ?t))
  )
  :hint (
  (point (string "Try writing an equation for the elastic potential energy due to the interaction between ~a and the spring ~a." (?body def-np) (?t pp)))
  (teach (string "The elastic potential energy due to the interaction of a body with a compressed spring is 0.5*k*x^2 where  k is the spring constant and x is the distance the spring is compressed or extended from its equilibrium length."))
  (bottom-out (string "Write ~a" ((= ?PE-var (* 0.5 ?k-var (^ ?d-var 2))) algebra)))
  ))
	 
; equation PE_spring = 0 for case where spring in problem but not in contact 
; !!! PE-var should include slot for spring, but then quantity can't be 
; introduced and stated to be zero if no spring exists or body not in contact 
; with a spring. In fact this is true in Andes interface.
(defoperator write-null-spring-energy (?b ?spring ?t)
 :preconditions (
 ; must be spring-contact at some time in problem:
  (spring-contact ?body ?spring ?sometime ?dontcare)
 ; but must NOT be spring-contact at time we are called for
  (not (spring-contact ?body ?spring ?t-contact ?s-force-dir) 
       (tinsidep ?t ?t-contact))
  (variable ?PE-var (at (spring-energy ?body ?spring) ?t))
  )
  :effects (
  (eqn (= ?PE-var 0) (spring-energy ?b ?spring ?t))
  )
  :hint (
  (point (string "Notice that ~A is not in contact with a spring ~A 
that could transfer elastic potential energy to ~A." ?b (?t pp) ?b))
  (bottom-out (string "Write ~A" ((= ?PE-var 0) algebra)))
  ))

; ops to define variables for energy quantities:
(defoperator define-total-energy (?b ?t)
 :preconditions (
 (object ?b)
 (bind ?TE-var (format-sym "TE_~A_~A" ?b (time-abbrev ?t)))
 ) 
 :effects ( 
  (define-var (at (total-energy ?b) ?t))
  (variable ?TE-var (at (total-energy ?b) ?t))
  )
 :hint (
  (bottom-out (string "Define a variable for total mechanical energy by using the Add Variable command on the Variable menu and selecting Energy."))
  ))
(defoperator define-kinetic-energy (?b ?t)
 :preconditions (
 (object ?b)
 (bind ?ke-var (format-sym "KE_~A_~A" ?b (time-abbrev ?t)))
 ) 
 :effects ( 
  (define-var (at (kinetic-energy ?b) ?t))
  (variable ?ke-var (at (kinetic-energy ?b) ?t))
  )
 :hint (
	(bottom-out (string "Define a variable for kinetic energy by using the Add Variable command on the Variable menu and selecting Energy."))
	))
(defoperator define-grav-energy (?b ?planet ?t)
 :preconditions (
 (object ?b)
 (bind ?ge-var (format-sym "Ug_~A_~A" ?b (time-abbrev ?t)))
 ) 
 :effects ( 
 (define-var (at (grav-energy ?b ?planet) ?t)) 
 (variable ?ge-var (at (grav-energy ?b ?planet) ?t)) 
  )
 :hint (
	 (bottom-out (string "Define a variable for gravitational potential energy by selecting Energy from the Variables menu on the top menu bar."))
       ))
(defoperator define-spring-energy (?b ?spring ?t)
 :preconditions ( 
   (object ?b)
   (bind ?se-var (format-sym "Us_~A_~A" ?b (time-abbrev ?t)))
 ) 
 :effects ( 
   (define-var (at (spring-energy ?b ?spring) ?t))
   (variable ?se-var (at (spring-energy ?b ?spring) ?t))
   )
 :hint (
	(bottom-out (string "Define a variable for elastic potential energy by selecting Energy from the Variables menu on the top menu bar."))
	))
(defoperator define-height (?b ?t)
 :preconditions ( 
   (object ?b)
   (bind ?h-var (format-sym "h_~A_~A" ?b (time-abbrev ?t)))
 ) 
 :effects ( 
  (define-var (at (height ?b) ?t))
  (variable ?h-var  (at (height ?b) ?t))
   )
 :hint (
	(bottom-out (string "Define a height variable using the Variables menu on the top menu bar."))
	))
(defoperator define-spring-constant (?spring)
 :preconditions ( 
   (bind ?k-var (format-sym "k_~A" ?spring))
 ) 
 :effects ( 
  (define-var (spring-constant ?spring))
  (variable ?k-var  (spring-constant ?spring))
  )
 :hint (
	 (bottom-out (string "Define a spring constant variable using the Variables menu on the top menu bar."))
	))
(defoperator define-compression (?spring ?t)
 :preconditions ( 
   (bind ?d-var (format-sym "comp_~A_~A" ?spring (time-abbrev ?t)))
 ) 
 :effects (
  (define-var (at (compression ?spring) ?t))
  (variable ?d-var  (at (compression ?spring) ?t))
  )
 :hint (
	(bottom-out (string "Define a variable for the compression of the spring using the Variables menu on the top menu bar."))
	))


(defoperator define-extension (?spring ?t)
 :preconditions ( 
   (bind ?d-var (format-sym "comp_~A_~A" ?spring (time-abbrev ?t)))
 ) 
 :effects (
  (define-var (at (extension ?spring) ?t))
  (variable ?d-var  (at (extension ?spring) ?t))
  )
 :hint (
	(bottom-out (string "Define a variable for the extension of the spring using the Variables menu on the top menu bar."))
	))

; Change in height is y component of displacement 
; We code this as a vector equation so that the projection equation will 
; automatically be packed into the method. However, it is not really true
; that it is a vector equation which could be projected along x or y axes.
;
; Also, the generic code that chooses axis to apply along (e.g. 
; select-compo-eqn-for-scalar) would prevent this from ever being used to get 
; that change in height is zero in case of horizontal displacement. The reason 
; is that that code will not select a vector equation along the y axis if the 
; vector points along the x axis, to prevent writing degenerate equations that 
; can't be used to solve for the scalar when zero projections are used. 
;
; For those reasons we post a compo-eqn-selected result -- see below.
(defoperator height-dy-contains (?quantity)
   :preconditions (
   (any-member ?quantity (
		 (at (mag (displacement ?b)) (during ?t1 ?t2))
		 (at (dir (displacement ?b)) (during ?t1 ?t2))
		 (at (height ?b) ?t1)
		 (at (height ?b) ?t2)
		 ))
   (time ?t1)
   (time ?t2)
   )
   :effects (
    (vector-psm-contains (height-dy ?b (during ?t1 ?t2)) ?quantity)
    ; since we know which compo-eqn we'll be using, we can select
    ; it now, rather than requiring further operators to do so
    ; We also select the axis, normally done by select-compo-eqn* ops
    (compo-eqn-selected (height-dy ?b (during ?t1 ?t2)) ?quantity 
        (compo-eqn height-dy y 90 (height-dy ?b (during ?t1 ?t2))))
    ; post this to make sure we will use standard axes
    (use-energy-axes)
   ))

(defoperator draw-height-dy-diagram (?b ?t)
  :preconditions (
   (body ?b ?t)
   (vector ?b (at (displacement ?b) ?t) ?dir)
   ; Must use standard axes for this. We put this before drawing displacement
   ; so don't get vector-aligned axes from existing operators.  !!! OP Hint is
   ; bad, though, doesn't explain why need standard axes in this case.
   (energy-axes ?b ?t)
  )
  :effects (
   (vector-diagram (height-dy ?b ?t))
  ))

(defoperator draw-energy-axes ()
  :preconditions ( 
	; only use this if have chosen energy method
  	(in-wm (use-energy-axes)) 
  )
  :effects (
   (draw-axes ?b ?t 0) ; action proposition for help system gives x dir
   (axis-for ?b ?t x 0)
   (axis-for ?b ?t y 90)
   (assume axis-for ?b ?t x 0)
   (assume axis-for ?b ?t y 90)
   (energy-axes ?b ?t)
  )
  :hint (
   (point (string "Can you think of a good direction to set the coordinate axes?"))
   (teach (string "Gravitational potential energy depends on the height above the stipulated zero level. Because that is the vertical component of the displacement, you should use standard horizontal-vertical coordinate axes."))
   (bottom-out (string "Draw standard horizontal-vertical coordinate axes by setting the x axis at 0 degrees." ))
  ))

(defoperator write-height-dy-compo (?b ?t1 ?t2)
  :preconditions (
    (variable ?h2 (at (height ?b) ?t2))
    (variable ?h1 (at (height ?b) ?t1))
    (variable ?d12_y  (at (compo y 90 (displacement ?b)) (during ?t1 ?t2)))
  )
  :effects (
    (eqn (= (- ?h2 ?h1) ?d12_y)
	        (compo-eqn height-dy y 90 (height-dy ?b (during ?t1 ?t2))))
    (eqn-compos (compo-eqn height-dy y 90 (height-dy ?b (during ?t1 ?t2))) 
                (?d12_y))
  )
  :hint (
    (point (string "You should relate the change in height of ~A ~A to the displacement during that period." 
                   ?b ((during ?t1 ?t2) pp)))
    (teach (string "The change in height will be equal to the vertical component of the displacement."))
    (bottom-out (string "Write the equation ~A" ((= (- ?h2 ?h1) ?d12_y) algebra)))
  ))

;;=============================================================================
;; Work
;;
;; Note (use-work) is required in problem statement to enable work and
;; work-energy principles to be applied. This is to suppress generating 
;; these entries on earlier problems. 
;; This should be replaced by use of a more general facility to specify which
;; principles may be used when it is implemented at the bubble graph level
;;=============================================================================

; Work is defined in terms of a force, but following the idiom used in verbal
; problem descriptions, our quantity specifies work done by *agent* of force.
; Note: this requires there to be a unique force done by a given agent, so 
; couldn't handle work done by friction and normal force from floor

; The "work" scalar equation psm computes work done by a single force over 
; a time interval as F * d * cos(theta) where theta is angle between F and d.
; We use a variant operator to write work = 0 for forces known to be orthogonal
; to the displacement. 
;
; Note: if coordinate axes are drawn this quantity can also be computed 
; component-wise as F_x * d_x + F_y * d_y. We will have to define another psm 
; to calculate the work done by a single force in this way.
;
; ! This only applies if the force is constant over the interval. That is
; true of almost all forces in Andes problems except the force from a
; compressed spring. But we don't test against that here.
(defoperator work-contains (?sought)
 :preconditions (
    (in-wm (use-work))
    (any-member ?sought (
		  (at (work ?b ?agent) ?t)
                  (at (mag (force ?b ?agent ?type)) ?t)
		  (angle-between (at (displacement ?b) ?t)
		                 (at (force ?b ?agent ?type) ?t))
		  ; For now, can't use this to seek displacement, since this
		  ; quantity doesn't bind force agent.  Could pick any one, 
		  ; but can't use (object ?agent) since agents need only be
		  ; implicitly declared (may change). Would have to look at 
		  ; all force-determining interaction descriptions to choose. 
		  ; Rare anyway to be given work and force and asked to compute 
		  ; displacement, though could be done.
                  ; (at (mag (displacement ?b)) ?t)
    			))
    (object ?b)
    (time ?t)
    (test (time-intervalp ?t))
    ; will require that ?agent exerts force on ?body when writing equation
 )
 :effects (
    (eqn-contains (work ?b ?agent ?t) ?sought)
 ))

(defoperator write-work (?b ?agent ?t)
 
 :preconditions (
    ; !!! could be more than one force from agent, e.g. normal and friction
    ; from floor.  This should be fixed by adding type slot to work argument.
    ; Until then, just ignore normal force if there's more than one, since
    ; it does not contribute to the work done by this agent. Leave it if it's
    ; the only one in frictionless problems so we can write Wa = 0.
    (setof (force ?b ?agent ?type1 ?t ?dir1 ?action) 
	   ?type1 ?agent-force-types)
    (debug "write-work: agent ~a exerts forces of type ~A~%" ?agent ?agent-force-types)
    (bind ?type (first (if (not (cdr ?agent-force-types)) ?agent-force-types
                           (remove 'Normal ?agent-force-types))))
    (debug "write-work: choosing force of type ~A for work by ~A~%" ?type ?agent)
    ; don't apply this to spring force which varies over interval
    (test (not (eq ?type 'spring)))
    ; must draw body, force and displacement vectors
    (body ?b ?t)
    ; make sure standard axis is allowed, even if unused
    (axis-for ?b ?t x 0) 
    (vector ?b (at (force ?b ?agent ?type) ?t) ?dir-f)
    (vector ?b (at (displacement ?b) ?t) ?dir-d)
    ; make sure they are not perpendicular. If so, variant write-zero-work 
    ; operator will write workF = 0
    (test (not (perpendicularp ?dir-f ?dir-d)))
    (in-wm (variable ?F-var (at (mag (force ?b ?agent ?type)) ?t)))
    (in-wm (variable ?d-var (at (mag (displacement ?b)) ?t)))
    (variable ?theta-var (angle-between (at (displacement ?b) ?t)
                                        (at (force ?b ?agent ?type) ?t)))
    (variable ?work-var (at (work ?b ?agent) ?t))
 )
 :effects (
    (eqn (= ?work-var (* ?F-var ?d-var (cos ?theta-var)))
         (work ?b ?agent ?t))
 )
 :hint (
  (point (string "You need the value of the work done on ~a by ~a ~A" ?b ?agent (?t pp)))
  (teach (string "The work done on a body by a constant force of magnitude F acting through a displacement of magnitude d is given by F * d * cos ($q), where $q is the angle between the force and displacement vectors."))
  (bottom-out (string "Write ~A"  
                ((= ?work-var (* ?F-var ?d-var (cos ?theta-var))) algebra)))
 ))

; Following operator writes work = 0 for work done by forces known to be 
; orthogonal to the displacement.
; When work done by an individual force, one or the other of 
; work or zero-work equations should apply
; !!! If agent exerts more than one force this should not apply.
(defoperator zero-work-contains (?sought)
 :preconditions 
    ((in-wm (use-work))
    (any-member ?sought ( (at (work ?b ?agent) ?t)))
    (test (time-intervalp ?t)))
    ; will require that ?agent exerts force on ?b when writing equation
 :effects ( (eqn-contains (work ?b ?agent ?t) ?sought)))

(defoperator write-zero-work (?b ?agent ?t)
 
 :preconditions 
    ; must draw force and displacement vectors
    ; to make sure they are perpendicular. 
   (
    ; !!! could be more than one force from agent, e.g. normal and friction
    ; from floor.  This should be fixed by adding type slot to work argument.
    ; Until then, only apply this rule if there is a unique force. 
    (setof (force ?b ?agent ?type1 ?t ?dir1 ?action) 
	   ?type1 ?agent-force-types)
    (test (not (cdr ?agent-force-types)))
    (vector ?b (at (force ?b ?agent ?type) ?t) ?dir-f)
    (vector ?b (at (displacement ?b) ?t) ?dir-d)
    (test (perpendicularp ?dir-f ?dir-d))
    (variable ?work-var (at (work ?b ?agent) ?t)))
 :effects ( (eqn (= ?work-var 0) (work ?b ?agent ?t)))
 :hint (
  (point (string "Notice that the only force exerted by ~a on ~b is perpendicular to the direction of the displacement of ~A." ?agent ?b ?b))
  (teach (string "If a force has no component in the direction of the displacement of an object, then the force does no work on that object through the displacement."))
  (bottom-out (string "Write the equation ~A" ((= ?work-var 0) algebra)))
 ))

; Following defines a variable for the angle between two vectors
; for the case where the angle of the two vectors is known.
; The angle between is always defined as the smaller of two possible angles.
; In this case a side-effect of the definition is to make the 
; angle-between known as well so it won't be sought further.
; Vector quantities are identified in this quant by expressions of the form 
; 	(at (vec ?b ...) ?t)  
; which include the times of each of the two vectors. These could in principle
; be different if you were defining the angle between a vector at one time
; and the same vector at another.
;
; So that angle between v1 and v2 gets the same representation as angle between v2 and v1,
; we require the vector expressions in any angle-between expression to be sorted. Any goal 
; to be achieved by this operator will know the major type of the vectors needed, so can 
; sort the vector expressions in the goal to be achieved.
;
; On the ANDES interface an angle can also be introduced on the diagram 
; by labelling the angle between the drawn vectors using the angle label tool.
; A separate operator should handle that.
(defoperator define-angle-between-known (?vec1 ?vec2)
 :preconditions (
 ; vectors must be drawn first, with known angles
 ; note vector's axis owner bodies need not be the same
 (vector ?b1 ?vec1 (dnum ?v1-dir |deg|))
 (vector ?b2 ?vec2 (dnum ?v2-dir |deg|))
 ; fetch vector mag vars for forming angle variable name only
 (bind ?v1-mag-exp (vector-mag ?vec1))
 (bind ?v2-mag-exp (vector-mag ?vec2))
 (in-wm (variable ?v1-var ?v1-mag-exp))
 (in-wm (variable ?v2-var ?v2-mag-exp))
 (bind ?theta-var (format-sym "theta_~A_~A" ?v1-var ?v2-var))
 ; compute angle between vectors to make it known as side-effect.
 (bind ?angle (min (mod (- ?v1-dir ?v2-dir) 360)
                   (mod (- ?v2-dir ?v1-dir) 360)))
 (debug "angle between ~A and ~A = ~A~%" ?v1-var ?v2-var ?angle)
 )
 :effects (
   (define-var (angle-between ?vec1 ?vec2))
   (variable ?theta-var (angle-between ?vec1 ?vec2))
   (given (angle-between ?vec1 ?vec2) (dnum ?angle |deg|))
 )
 :hint (
  (bottom-out (string "Define a variable for the angle between ~A and ~A by using the Add Variable command on the Variable menu and selecting Angle." 
   (?v1-var algebra) (?v2-var algebra)))
 ))

; This represents introducing the angle-between by using
; the angle labelling tool on the diagram.
; We assert an action proposition 
;  (angle ?vec1 ?vec2) in this case 
; for the help system to match to the drawing entry action.
(defoperator draw-angle-between-known (?vec1 ?vec2)
 :preconditions (
 (not (angle ?vec1 ?vec2))
 ; vectors must be drawn first, with known angles
 ; note vector's axis owner bodies need not be the same
 (vector ?b1 ?vec1 (dnum ?v1-dir |deg|))
 (vector ?b2 ?vec2 (dnum ?v2-dir |deg|))
 ; fetch vector mag vars for forming variable name only
 (bind ?v1-mag-exp (vector-mag ?vec1))
 (bind ?v2-mag-exp (vector-mag ?vec2))
 (in-wm (variable ?v1-var ?v1-mag-exp))
 (in-wm (variable ?v2-var ?v2-mag-exp))
 (bind ?theta-var (format-sym "theta_~A_~A" ?v1-var ?v2-var))
 ; compute angle between vectors to make it known as side-effect.
 (bind ?angle (min (mod (- ?v1-dir ?v2-dir) 360)
                   (mod (- ?v2-dir ?v1-dir) 360)))
 (debug "angle between ~A and ~A = ~A~%" ?v1-var ?v2-var ?angle)
 )
 :effects (
   (angle ?vec1 ?vec2)	; action proposition
   (variable ?theta-var (angle-between ?vec1 ?vec2))
   (given (angle-between ?vec1 ?vec2) (dnum ?angle |deg|))
 )
 :hint ( 
; same hint as for angle variable -- angle drawing tool too difficult to use,  
; should just take it out. 
(bottom-out (string "Define a variable for the angle between ~A and ~A by using the Add Variable command on the Variable menu and selecting Angle." 
   (?v1-var algebra) (?v2-var algebra)))
 ))
;
; Following defines a variable for the work done by a force agent
; over a time interval.
(defoperator define-work (?b ?agent ?t)
 :preconditions (
 (object ?b)
 (time ?t)
 (test (time-intervalp ?t))
 (bind ?work-var (format-sym "work_~A_~A_~A" (body-name ?b) (body-name ?agent) 
 					     (time-abbrev ?t)))
 )
 :effects (
   (define-var (at (work ?b ?agent) ?t))
   (variable ?work-var (at (work ?b ?agent) ?t))
 )
 :hint (
   (bottom-out (string "Define a variable for ~A by using the Add Variable command on the Variable menu and selecting work" ((at (work ?b ?agent) ?t) def-np)))
 ))

;; following defines a variable for net-work done on an object due to
;; all forces over a time interval
(defoperator define-net-work (?b ?t)
 :preconditions (
 (object ?b)
 (time ?t)
 (test (time-intervalp ?t))
 (bind ?work-var (format-sym "net_work_~A_~A" (body-name ?b) (time-abbrev ?t)))
 )
 :effects (
   (define-var (at (net-work ?b) ?t))
   (variable ?work-var (at (net-work ?b) ?t))
 )
 :hint (
   (bottom-out (string "Define a variable for ~A by using the Add Variable command on the Variable menu, selecting work, then choosing work done by all forces." ((at (net-work ?b) ?t) def-np)))
 ))


;;
;; Net-work psm -- compute net work as the sum of the work done by
;; each force on the object. 
;;
;; The most natural method would be to write the equation 
;;           Work_net = workF1 + workF2 ... 
;; at the bubble-graph-level and rely on chaining to find the work done by each
;; of the work agents.  However, when we first tried this "chaining" version,
;; it gave rise to combinatorial explosion at the path traversal phase for 
;; *other* problems in which one was not expected to use work. Still, breaking
;; up net work into constituents at the bubble graph level in the manner of the
;; chaining version is necessary for some problems that require use of
;; work-energy to find work done by a single agent. 
;; 
;; We include alternate code for an "all-in-one" version that incorporates
;; subsidiary equations for the individual works done by each force. These 
;; terms are eliminated in the final equation, so the whole solution for 
;; net work occurs within a single psm. This means we can't simply chain from 
;; net work to find work done by an individual force at the top-level, though 
;; we could find the force magnitude.
;;
;; Either way the net work psm requires drawing a free body diagram showing 
;; all the forces on an object as for Newton's Law problems (but w/o accel).
;; Forces orthogonal to the displacement contribute nothing to 
;; the net work done so could in principle be left out of the computation 
;; entirely. For now we leave the forces in the diagram to teach the general 
;; method. The work terms wind up set to zero for these forces; only
;; the zero values occur in the final equation for net work in the all-in-one 
;; version.
;;
;; One could also compute net work by first computing the net force vector
;; and then computing net force dot displacement.  This was not done in the
;; CLIPS solutions and we avoid that for now since we are discouraging 
;; introduction of net force terms where not needed.

;#|; begin chaining net-work method

(defoperator net-work-contains (?sought)
  :preconditions 
  ((any-member ?sought  ((at (net-work ?b) ?t) 
	                 (at (work ?b ?agent) ?t)))
  ; make sure we can determine all agents doing work
  (not (unknown-work-agents))
  (test (time-intervalp ?t)))
  :effects 
  ((eqn-contains (net-work ?b ?t) ?sought)))

(defoperator apply-net-work (?b ?t)
  :preconditions (
   ; !!! can't draw forces from agents specified only as power sources
   ; draw free-body diagram showing all forces on object
   (net-work-diagram ?b ?t) 
   ; introduce net-work variable
   (variable ?net-work-var (at (net-work ?b) ?t))
   ; introduce variables for work done by each work source. 
   ; need to collect list of force *agents* to use in work quantities
   ; agent can be one we know exerts a force on body, but it can also be
   ; a power-source we are told is transferring energy to the body, where
   ; we might not have detailed information about the mechanism so can not
   ; find or draw a force.
   ; !!! this is bad if there are both friction and normal forces from a
   ; surface.  Cheap workaround is to suppress normal force in the problem if
   ; friction is present, but that is ugly. For now we list agents
   ; get the ind work operator to write expr for the non-orthogonal force 
   ; when it is asked to write work done by agent.
   (in-wm (forces ?b ?t ?forces))
   (setof (in-wm (does-work-on ?work-agent ?b ?t))
          ?work-agent ?other-agents)
   (bind ?agents (remove-duplicates (append (mapcar #'third ?forces) 
                                            ?other-agents)))
   (map ?agent ?agents
      (variable ?work-var (at (work ?b ?agent) ?t))
      ?work-var ?work-vars) 
  )
  :effects (
   (eqn (= ?net-work-var (+ . ?work-vars)) (net-work ?b ?t))
  )
  :hint (
    (teach (string "The net work done on an object is the sum of the work done on that object by each individual force or energy source acting on it."))
    (bottom-out (string "Write the equation ~A" ((= ?net-work-var (+ . ?work-vars)) algebra)))
  ))

;|#; end chaining version of net-work method

(defoperator draw-net-work-diagram (?b ?t)
  :specifications "choose body and draw all forces on it"
  :preconditions 
   ((body ?b ?t)
    ; make sure axis is allowed, even if unused
    (axis-for ?b ?t x 0) 
    (forces ?b ?t ?forces)
    )
   :effects ( (net-work-diagram ?b ?t) ))

;(defoperator draw-optional-axes (?b ?t)
;  :effects       ((opt-axis-drawn ?b ?t))
;  :preconditions ((axis-for ?b ?t x ?rot)))

#|;begin all-in-one net-work

(defoperator net-work-contains (?sought)
  :preconditions 
  ((in-wm (use-work))
   (any-member ?sought ( 
             (at (net-work ?b) ?t) 
	     (at (work ?b ?agent) ?t)
	     	      ))
  (test (time-intervalp ?t)))
  :effects  ; note this version issues in derived-eqn
  ((derived-eqn-contains (net-work ?b ?t) ?sought)))

(defoperator apply-net-work (?b ?t)
  :preconditions (
   ; draw free-body diagram showing all forces on object
   ; and extract list of force *agents* to use in work quantities
   (body ?b ?t)
   (forces ?b ?t ?forces)
   (bind ?agents (mapcar #'third ?forces))
   ; write subsidiary equations for work done by each force agent
   ; achieving each of these will introduce the relevant variable
   (map ?agent ?agents
      (eqn (= ?work-var ?work-exp) (work ?b ?agent ?t))
      ?work-var ?work-vars) 
   (debug "net work components: ~A~%" ?work-vars)
   ; write subsidiary equation for net work as sum of individual works
   (variable ?net-work-var (at (net-work ?b) ?t))
   (eqn (= ?net-work-var (+ . ?work-vars)) (net-work-compos ?b ?t))
   ; collect all work exprs from individual work equations written
   ; NB: don't collect ?exprs with setof since that will collapse duplicates.
   (setof (in-wm (eqn (= ?var ?expr) (work ?b ?agent1 ?t)))
          (= ?var ?expr) ?work-eqns)
   (bind ?work-exprs (mapcar #'third ?work-eqns))
   (debug "net work values: ~A~%" ?work-exprs)
  )
  :effects (
   (derived-eqn (= ?net-work-var (+ . ?work-exprs)) (net-work ?b ?t))
  )
)

; following writes net-work = work_agent1 + work_agent2 + ... work_agentn
; Degenerate case of an operator -- eqn-algebra is bound coming in since we 
; form it easily in caller above. But we need it in effects of something.
(defoperator write-net-work-compos (?b ?t)
  :effects 
    ((eqn (= ?net-work-var ?stuff) (net-work-compos ?b ?t)))
  ; :hint
  )

|#; end all-in-one net-work psm code

;;
;; work-energy psm -- net-work = change in kinetic energy
;;
;; In almost all Andes problems where net work can be computed the forces are
;; constant so an equivalent solution using Newton's Law + constant acceleration
;; kinematics can also be found.  This principle will also apply in cases where 
;; conservation of mechanical energy can be used, although it is intended for 
;; use when a non-conservative force is doing work.
;;
(defoperator work-energy-contains (?sought)
 :preconditions 
  ((in-wm (use-work))
   (any-member ?sought ( 
             (at (net-work ?b) (during ?t1 ?t2)) 
	     (at (mag (velocity ?b)) ?t1)
	     (at (mag (velocity ?b)) ?t2)
	     (mass ?b)
	     	      ))
  (time (during ?t1 ?t2)))
 :effects 
  ((derived-eqn-contains (work-energy ?b (during ?t1 ?t2)) ?sought)))

(defoperator write-work-energy (?b ?t1 ?t2)
 :preconditions (
    ; draw body and standard axes for principle
    (body ?b (during ?t1 ?t2))
    (axis-for ?b (during ?t1 ?t2) x 0)

    ; write fundamental principle Wnet = ke2 - ke1
    (eqn (= ?Wnet-var (- ?ke2-var ?ke1-var)) (work-delta-ke ?b ?t1 ?t2))
    ; write out ke1 = 0.5 * m * v1^2
    (eqn (= ?ke1-var ?ke1-val) (kinetic-energy ?b ?t1))
    ; write out ke2 = 0.5 * m * v2^2
    (eqn (= ?ke2-var ?ke2-val) (kinetic-energy ?b ?t2))
 )
 :effects ; post derived summary equation using written out ke terms
  ((derived-eqn (= ?Wnet-var (- ?ke2-val ?ke1-val)) 
                (work-energy ?b (during ?t1 ?t2))))
)

; Write work = delta ke without writing out values for the ke terms.
(defoperator write-work-delta-ke (?b ?t1 ?t2)
  :preconditions 
   ((variable ?Wnet-var (at (net-work ?b) (during ?t1 ?t2)))
    (variable ?ke1-var (at (kinetic-energy ?b) ?t1))
    (variable ?ke2-var (at (kinetic-energy ?b) ?t2)))
  :effects 
  ((eqn (= ?Wnet-var (- ?ke2-var ?ke1-var)) (work-delta-ke ?b ?t1 ?t2)))
  :hint (
   (point (string "What do you know about the relation between net work done on an object and its kinetic energy?" ))
   (teach (string "The work-energy principle states that the net work done on an object by all forces over an interval is equal to the change in its kinetic energy over that interval"))
  (bottom-out (string "Write the equation ~A" ((= ?Wnet-var (- ?ke2-var ?ke1-var)) algebra)))  ))


;; Change in mechanical energy: Wnc = ME2 - ME1
;;
;; This is a generalization of conservation of mechanical energy that is
;; applicable when non-conservative forces act on the object. This form
;; therefore subsumes conservation of energy as a special case when there
;; are no non-conservative forces. For now, we allow either form to be used in
;; those cases.

(defoperator change-ME-contains (?sought)
  :preconditions (
     (in-wm (use-work))
     (any-member ?sought ( ; need all ME quantities
			   (at (mag (velocity ?b)) ?t)
	                   (mass ?b) 
	                   (at (height ?b) ?t)
	                   (at (spring-const ?s) ?t)
	                   (at (compression ?s) ?t)
	                   (gravitational-acceleration ?planet)
                           (at (work-nc ?b) (during ?t1 ?t2)) ))
     (time ?t1)
     (time ?t2)
     (test (and (time-pointp ?t1) (time-pointp ?t2) (< ?t1 ?t2)))
  )
  :effects (
    (derived-eqn-contains (change-ME ?b ?t1 ?t2) ?sought)
    ; post this to make sure we get hint for energy prob axes
    (use-energy-axes)
  ))

(defoperator apply-change-ME (?b ?t1 ?t2)
 :preconditions (
  ; Draw the body and standard axes for principle
  (body ?b (during ?t1 ?t2))
  (axis-for ?b (during ?t1 ?t2) x 0)  

  ; write equation Wnc = ME2 - ME1
  (eqn (= ?Wnc (- ?te2 ?te1))  (change-ME-top ?b ?t1 ?t2))
  ; write equation ME2 = K2 + Ug2 [+ Us2]
  ; plus sub-eqns for terms on the rhs, getting combined result
  (derived-eqn (= ?te2 ?te2-exp) (total-energy ?b ?t2))
  ; write equation ME1 = K1 + Ug1 [+ Us1]
  ; plus sub-eqns for all terms on the rhs, getting combined result
  (derived-eqn (= ?te1 ?te1-exp) (total-energy ?b ?t1))
  ; write total mech. energy equivalence with all energy terms plugged in
  (bind ?eqn-algebra `(= ,?Wnc (- ,?te2-exp ,?te1-exp)))
  (debug "final change-ME eq: ~A~%" ?eqn-algebra)
 )
 :effects (
  (derived-eqn ?eqn-algebra (change-ME ?b ?t1 ?t2))
 )
)

; following writes the top-level change in ME equation,
;       Wnc = ME2 - ME1
(defoperator write-change-ME-top (?b ?t1 ?t2)
  :preconditions (
     (variable ?Wnc (at (work-nc ?b) (during ?t1 ?t2)))
     (variable ?ME1 (at (total-energy ?b) ?t1))
     (variable ?ME2 (at (total-energy ?b) ?t2))
  )
  :effects (
    (eqn (= ?Wnc (- ?ME2 ?ME1)) (change-ME-top ?b ?t1 ?t2))
  )
  :hint (
   (point (string "Think about what you can conclude about the total mechanical energy in the system throughout this problem."))
  (teach (string "The most general form of conservation of energy states that the work done by non-conservative forces over an interval is equal to the change in total mechanical energy over that interval."))
   (bottom-out (string "Write the equation ~A" 
                       ((= ?Wnc (- ?ME2 ?ME1)) algebra)))
  ))

;;
;; Wnc = Wf1 + Wf2 + ... where f1, f2, ... are non-conservative
;;
(defoperator Wnc-contains (?sought)
 :preconditions(
  (in-wm (use-work))
  (any-member ?sought ( (at (work ?body ?agent) ?t)
                        (at (work-nc ?body) ?t) ))
  ; Need to make sure agent exerts non-conservative force on body
  ; We do this when writing the equation below.
 )
 :effects (
  (eqn-contains (Wnc ?body ?t) ?sought)
 ))

(defoperator write-Wnc (?body ?t)
  :preconditions (
    ; draw body and standard axes for principle
    (body ?body ?t)
    (axis-for ?body ?t x 0)
    (variable ?Wnc (at (work-nc ?body) ?t))
   ; introduce variables for work done by each non-conservative work source. 
   ; need to collect list of force *agents* to use in work quantities
   ; agent can be one we know exerts a force on body, but it can also be
   ; a power-source we are told is transferring energy to the body, where
   ; we might not have detailed information about the mechanism so can not
   ; find or draw a force.
   (setof (nc-work-agent ?work-agent ?b ?t)
          ?work-agent ?agents)
   ; this would actually work if no nc work agents, since algebra module
   ; accepts (= Wnc (+)) interpreting n-ary sum of zero terms as zero.
   ; But is there a problem giving help based on this form?
   ; (test (not (null ?agents)))	
   (map ?agent ?agents
      (variable ?work-var (at (work ?b ?agent) ?t))
      ?work-var ?work-vars) 
  ) 
  :effects (
    (eqn (= ?Wnc (+ . ?work-vars)) (Wnc ?body ?t))
  ) 
  :hint (
   (point (string "You need to identify all the non-conservative forces that do work in this problem."))
   (teach (string "In Andes problems, the conservative or path-independent forces are gravity and spring forces; all other forces acting on a system are non-conservative and should be included in Wnc since they change the total mechanical energy of the system."))
   (bottom-out
    (string "Write the equation ~A" ( (= ?Wnc (+ . ?work-vars)) algebra)))
  ))

; following returns an agent of a non-conservative force on b during t
; via the nc-work-agent proposition. Note that an agent like the floor 
; may exert both normal and friction forces on object; we need to ignore
; the normal force and use the friction force. 
(defoperator get-nc-force-agent (?b ?t)
  :preconditions (
      (force ?b ?agent ?type ?t ?dir1 ?action)
      (test (not (member ?type '(weight gravitational normal spring))))
  )
  :effects (
     (nc-work-agent ?agent ?b ?t)
  ))

; if an entity is declared as a power source transmitting energy to ?b,
; without details of the force, then it is also an agent of Wnc
(defoperator get-nc-force-agent2 (?b ?t)
  :preconditions (
     (in-wm (does-work-on ?agent ?b ?t))
  )
  :effects (
    (nc-work-agent ?agent ?b ?t)
  ))

(defoperator define-Wnc (?b ?t)
  :preconditions (
    (bind ?work-var (format-sym "Wnc_~A_~A" (body-name ?b) (time-abbrev ?t)))
  )
 :effects (
   (define-var (at (work-nc ?b) ?t))
   (variable ?work-var (at (work-nc ?b) ?t))
 )
 :hint (
   (bottom-out (string "Define a variable for ~A by using the Add Variable command on the Variable menu, selecting work, then defining work done by all non-conservative forces." ((at (work-nc ?b) ?t) def-np)))
))

;;
;; average power = work/time
;;
;; Power is the rate of work done by some agent on some body
;; We can consider instantaneous power at a time point or average power over
;; a time interval.
;; We might also need net-power to correspond to net-work, though in all our
;; power problems there is a single power source, so we don't have much
;; need to sum up several.
;; Note in some cases we may be given that the agent is a source of energy 
;; transfer without being told the details of the mechanism, so we could not
;; draw the force and compute the work done by the force, but might do it
;; from the given power output.
(defoperator power-contains (?sought)
  :preconditions (
    (any-member ?sought ( (at (work ?b ?agent) ?t)
			  ; if sought is duration, need to bind ?body and 
			  ; ?agent -- a nuisance, since agents aren't always 
			  ; declared objects. For now, just don't allow it 
                          ; (duration ?t)
			  (at (power ?b ?agent) ?t)))
  )
  :effects (
    (eqn-contains (power ?b ?agent ?t) ?sought)
  ))

(defoperator write-power (?agent ?b ?t)
  :preconditions (
     (body ?b ?t)
     (axis-for ?b ?t x 0)
     (variable ?P-var  (at (power ?b ?agent) ?t))
     (variable ?W-var  (at (work ?b ?agent) ?t))
     (variable ?t-var  (duration ?t))
  )
  :effects (
    (eqn (= ?P-var (/ ?W-var ?t-var)) (power ?b ?agent ?t))
  )
  :hint (
   (teach (string "Power is the rate at which work is done. The average power supplied by a force over an interval is therefore the work done by that force over the interval divided by the time."))
   (bottom-out (string "Write the equation ~A" 
                       ((= ?P-var (/ ?W-var ?t-var)) algebra)))
  ))

(defoperator define-power-var (?b ?agent ?t)
 :preconditions (
 (bind ?power-var (format-sym "power_~A_~A_~A" (body-name ?b) (body-name ?agent) 
 					     (time-abbrev ?t)))
 )
 :effects (
   (define-var (at (power ?b ?agent) ?t))
   (variable ?power-var (at (power ?b ?agent) ?t))
 )
 :hint (
   (bottom-out (string "Define a variable for ~A by using the Add Variable command on the Variable menu and selecting power" ((at (power ?b ?agent) ?t) def-np) ))
 ))

;
; same as above for net-power = Wnet/t
;
(defoperator net-power-contains (?sought)
  :preconditions (
    (any-member ?sought ( (at (net-power ?b) ?t)
                          (at (net-work ?b) ?t)
			  ; for now don't use to find duration:
			  ; (duration ?t)
			  ))
  )
  :effects (
    (eqn-contains (net-power ?b ?t) ?sought)
  ))

(defoperator write-net-power (?b ?t)
  :preconditions (
     (body ?b ?t)
     (axis-for ?b ?t x 0)
     (variable ?P-var  (at (net-power ?b) ?t))
     (variable ?W-var  (at (net-work ?b) ?t))
     (variable ?t-var  (duration ?t))
  )
  :effects (
    (eqn (= ?P-var (/ ?W-var ?t-var)) (net-power ?b ?t))
  )
  :hint (
   (teach (string "Power is the rate at which work is done. The average net power supplied over an interval is therefore the net work done by all forces over the interval divided by the time."))
   (bottom-out (string "Write the equation ~A" 
                       ((= ?P-var (/ ?W-var ?t-var)) algebra)))
  ))

(defoperator define-net-power-var (?b ?t)
 :preconditions (
 (bind ?power-var (format-sym "Pnet_~A_~A" (body-name ?b) (time-abbrev ?t)))
 )
 :effects (
   (define-var (at (net-power ?b) ?t))
   (variable ?power-var (at (net-power ?b) ?t))
 )
 :hint (
   (bottom-out (string "Define a variable for ~A by using the Add Variable command on the Variable menu, selecting power, and defining power supplied by all forces" ((at (net-power ?b) ?t) def-np) ))
 ))

;
; instantaneous power = F dot v = F*v*cos(theta)
;
; This operator exactly parallels work, with velocity instead of displacement.
;
(defoperator inst-power-contains (?sought)
 :preconditions (
    (in-wm (use-work))
    (any-member ?sought (
		  (at (power ?b ?agent) ?t)
                  (at (mag (force ?b ?agent ?type)) ?t)
		  (at (mag (velocity ?b)) ?t)
		  ; NB: vector terms must be in sorted order:
		  (angle-between (at (force ?b ?agent ?type) ?t))
		                 (at (velocity ?b) ?t)
    			))
    (test (time-pointp ?t))
    ; get list of force agents we can use
    (setof (force ?b ?agent1 ?type1 ?t ?dir1 ?action) 
	   ?agent1 ?force-agents)
    ; select a force agent in case sought is velocity, else verify agent
    (any-member ?agent ?force-agents)
 )
 :effects (
    (eqn-contains (inst-power ?b ?agent ?t) ?sought)
 ))

(defoperator write-inst-power (?b ?agent ?t)
 
 :preconditions (
    ; !!! could be more than one force from agent, e.g. normal and friction
    ; from floor.  This should be fixed by adding type slot to work argument.
    ; Until then, just ignore normal force if there's more than one, since
    ; it does not contribute to the work done by this agent. Leave it if it's
    ; the only one in frictionless problems so we can write Wa = 0.
    (setof (force ?b ?agent ?type1 ?t ?dir1 ?action) 
	   ?type1 ?agent-force-types)
    (bind ?type (first (if (not (cdr ?agent-force-types)) ?agent-force-types
                           (remove 'Normal ?agent-force-types))))
    ; must draw body, force and velocity vectors
    (body ?b ?t)
    ; make sure standard axis is allowed, even if unused
    (axis-for ?b ?t x 0) 
    (vector ?b (at (force ?b ?agent ?type) ?t) ?dir-f)
    (vector ?b (at (velocity ?b) ?t) ?dir-d)
    (in-wm (variable ?F-var (at (mag (force ?b ?agent ?type)) ?t)))
    (in-wm (variable ?v-var (at (mag (velocity ?b)) ?t)))
    (variable ?theta-var (angle-between (at (force ?b ?agent ?type) ?t)
                                        (at (velocity ?b) ?t)))
    (variable ?P-var (at (power ?b ?agent) ?t))
 )
 :effects (
    (eqn (= ?P-var (* ?F-var ?v-var (cos ?theta-var)))
         (inst-power ?b ?agent ?t))
 )
 :hint (
  (teach (string "Power is the rate at which work is done. The instantaneous power supplied from a force F to a body moving at velocity v can be shown to be equal to F * v * cos ($q), where $q is the angle between the force and velocity vectors."))
  (bottom-out (string "Write the equation ~A"  
                ((= ?P-var (* ?F-var ?v-var (cos ?theta-var))) algebra)))
 ))

;;=============================================================================
;; Conservation of Linear Momentum
;;=============================================================================
    
(defoperator linmom-vector-contains (?sought)
  :preconditions (
  ; for now only apply if there is a collision 
  (collision ?colliding-bodies (during ?t1 ?t2) ?type)
   ; in case problem author didn't canonicalize body list:
  (bind ?bodies (sort ?colliding-bodies #'expr<))
  (any-member ?sought (
               (at (mag (velocity ?b)) ?t1) (at (dir (velocity ?b)) ?t1)
               (at (mag (velocity ?b)) ?t2) (at (dir (velocity ?b)) ?t2)
	       (mass ?b) 
	       ; in case bodies split from or join into compound:
	       (at (mag (velocity (compound ?bodies)) ?t1))
	       (at (mag (velocity (compound ?bodies)) ?t2))
	       (mass (compound ?bodies))
	       	      ))
  (test (or (contains-sym ?sought 'compound) 
            (member ?b ?colliding-bodies :test #'equal)))
  )
  :effects (
  (vector-psm-contains (cons-linmom ?bodies (during ?t1 ?t2)) ?sought)
  ; since only one compo-eqn under this vector psm, we can just
  ; select it now, rather than requiring further operators to do so
  (compo-eqn-contains (cons-linmom ?bodies (during ?t1 ?t2)) lm-compo ?sought)
  ))

(defoperator draw-linmom-diagram (?bodies ?t1 ?t2)
  :preconditions (
   (not (vector-diagram (cons-linmom ?bodies (during ?t1 ?t2))))
   ; how much to draw? a lot of vectors at issue:
   ; total system momentum before, total system momentum after
   ; constituent momenta (normally 2 initial, 2 final)
   ; and constituent velocities. 
   ; Ideally would allow but not require both momenta and velocities. 
   ; For now we include both so that both get defined.

   ; For when we provide tool to allow drawing of many-body systems:
          ; draw system
	  ;(body (system ?b1 ?b2) (during ?t1 ?t2))
   ; draw initial constituent velocity and momentum
   (initial-momentum-drawn ?bodies ?t1)
   ; draw final constitutent velocity and momentum
   (final-momentum-drawn ?bodies ?t2)
   ; draw axis to use for many-body system. 
   ; ! Because no vectors have been drawn on the system object, will always get
   ; standard horizontal-vertical axes since nothing to align with
   (axis-for (system . ?bodies) (during ?t1 ?t2) ?xyz ?rot)
   ; must also record axes to use for vectors on system's constituent bodies so they can be 
   ; picked up from working wm by compo-eqn choosing operators. Use-system-axis should apply 
   ; to inherit from the main system axis. Could also try to do this when drawing axis for 
   ; many-body system, if we had a special operator for that case. Note this doesn't register
   ; an axis for compound bodies that are constituents of the system in case of split/join.
   (foreach ?b ?bodies
      (axis-for ?b (during ?t1 ?t2) ?xyz ?rot))
  )
  :effects (
   (vector-diagram (cons-linmom ?bodies (during ?t1 ?t2)))
  ))

(defoperator draw-initial-momentum (?bodies ?t1)
  :preconditions (
     ; use this if bodies don't split from initial compound
     ; !!! code assumes there's only one collision in problem
     (in-wm (collision ?colliding-bodies (during ?t1 ?t2) ?type))
     (test (not (equal ?type 'split)))
     ; (foreach ?b ?bodies (body ?b ?t1)) ; drawing body unnecessary
     (foreach ?b ?bodies
   	(vector ?b (at (velocity ?b) ?t1) ?dir1))
     (foreach ?b ?bodies
   	(vector ?b (at (momentum ?b) ?t1) ?dir1))
  )
  :effects ( (initial-momentum-drawn ?bodies ?t1) ))

(defoperator draw-initial-momentum-split (?bodies ?t1)
  :preconditions (
     ; use this if collision involves split
     (in-wm (collision ?colliding-bodies (during ?t1 ?t2) split))
     (bind ?c `(compound ,@?bodies)) ; for shorthand
     (body ?c ?t1)
     (vector ?c (at (velocity ?c) ?t1) ?dir1)
     (vector ?c (at (momentum ?c) ?t1) ?dir1)
  )
  :effects ( (initial-momentum-drawn ?bodies ?t1) ))

(defoperator draw-final-momentum (?bodies ?t2)
  :preconditions (
     ; use this if bodies don't join into compound after collision
     (in-wm (collision ?colliding-bodies (during ?t1 ?t2) ?type))
     (test (not (equal ?type 'inelastic)))
    ; (foreach ?b ?bodies (body ?b ?t2)) ; drawing body unnecessary
     (foreach ?b ?bodies
   	(vector ?b (at (velocity ?b) ?t2) ?dir1))
     (foreach ?b ?bodies
   	(vector ?b (at (momentum ?b) ?t2) ?dir1))
  )
  :effects ( (final-momentum-drawn ?bodies ?t2) ))

(defoperator draw-final-momentum-join (?bodies ?t2)
  :preconditions (
     ; use this if collision involves join = completely inelastic collision
     (in-wm (collision ?colliding-bodies (during ?t1 ?t2) inelastic))
     (bind ?c `(compound ,@?bodies)) ; for shorthand
     (body ?c ?t2)
     (vector ?c (at (velocity ?c) ?t2) ?dir1)
     (vector ?c (at (momentum ?c) ?t2) ?dir1)
  )
  :effects ( (final-momentum-drawn ?bodies ?t2) ))


; operators for drawing momentum vectors on simple bodies
; these exactly parallel the velocity drawing operators

(defoperator draw-momentum-at-rest (?b ?t)
  :specifications 
   "If there is an object,
     and it is at rest at a certain time,
   then its momentum at that time is zero."
  :preconditions
   ((time ?t)
    (motion ?b ?t-motion at-rest)
    (test (tinsidep ?t ?t-motion))
    (bind ?mag-var (format-sym "p_~A_~A" ?b (time-abbrev ?t))))
  :effects
   ((vector ?b (at (momentum ?b) ?t) zero)
    (variable ?mag-var (at (mag (momentum ?b)) ?t))
    (given (at (mag (momentum ?b)) ?t) (dnum 0 |kg.m/s|)))
  :hint
   ((point (string "Notice that ~a is at rest ~a." ?b (?t pp)))
    (teach (string "When an object is at rest, its velocity is zero. Since the momentum vector is defined as mass times the velocity vector, the momentum is also zero at that time."))
    ; too simple for a kcd
    (bottom-out (string "Because ~a is at rest ~a, use the momentum tool to draw a zero-length momentum vector for it." ?b (?t pp)))))

; we could get momentum direction from velocity direction, but these operators
; get it from straight-line motion spec, so that it is not required that 
; velocity be drawn first.
(defoperator draw-momentum-straight (?b ?t)
  :specifications 
   "If an object is moving in a straight line at a certain time,
   then its momentum at that time is non-zero and in the same direction
     as its motion."
  :preconditions
   ((time ?t)
    (motion ?b ?t-motion (straight ?dontcare ?dir))
    (test (not (equal ?dir 'unknown)))  ; until conditional effects 
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (momentum ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "p_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var)))
  :effects
   ((vector ?b (at (momentum ?b) ?t) ?dir)
    (variable ?mag-var (at (mag (momentum ?b)) ?t))
    (variable ?dir-var (at (dir (momentum ?b)) ?t))
    (given (at (dir (momentum ?b)) ?t) ?dir))
  :hint
   ((point (string "Notice that ~a is moving in a straight line ~a." ?b (?t pp)))
    (teach (string "Whenever an object is moving in a straight line, it has a velocity in the same direction as its motion. Since the momentum vector is defined as mass times the velocity vector, the momentum will have the same direction as the velocity.")
	   (kcd "draw_momentum"))
    (bottom-out (string "Because ~a is moving in a straight line ~a, draw a non-zero momentum vector in direction ~a." ?b (?t pp) ?dir))))

(defoperator draw-momentum-straight-unknown (?b ?t)
  :specifications 
   "If an object is moving in a straight line at a certain time,
   then its momentum at that time is non-zero and in the same direction
     as its motion."
  :preconditions
   ((time ?t)
    (motion ?b ?t-motion (straight ?dontcare unknown))
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (momentum ?b) ?t) ?dir))
    (bind ?mag-var (format-sym "p_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
    ; following is for implicit eqn -- assumes we know how velocity vars are named
    (bind ?dir-vel (format-sym "Ov_~A_~A" (body-name ?b) (time-abbrev ?t)))
    )
  :effects
   ((vector ?b (at (momentum ?b) ?t) unknown)
    (variable ?mag-var (at (mag (momentum ?b)) ?t))
    (variable ?dir-var (at (dir (momentum ?b)) ?t))
    ; following is "optional equation" put out so solver will be able to 
    ; determine a value for 0p in case student happens to use it. It isn't
    ; needed for m*v form solution we teach, so student doesn't have to enter it
    (implicit-eqn (= ?dir-var ?dir-vel) (dir-momentum ?b ?t))
    )
  :hint
   ((point (string "Notice that ~a is moving in a straight line ~a, although the exact direction is unknown." ?b (?t pp)))
    (teach (string "Whenever an object is moving in a straight line, it has a non-zero velocity in the same direction as its motion. Since the momentum vector is defined as mass times the velocity vector, the momentum will have the same direction as the velocity.")
	   (kcd "draw_nonzero_momentum"))
    (bottom-out (string "Because ~a is moving in a straight line ~a, draw a non-zero momentum vector for it in an approximately correct direction, then erase the number in the direction box to indicate that the exact direction is unknown." ?b (?t pp)))))

; Might want rule that momentum direction = velocity direction for case where
; direction is unknown to write equation dirP = dirV. But dirP does not occur in
; any equation at the bubble graph level since we write p_x = m * v_x so
; only need projection of v, not of p.
; (defoperator momentum_dir_from_vdir)

; following still restricted to two-body collisions, and
; doesn't use compound bodies before split or after join
(defoperator write-cons-linmom-compo (?b1 ?b2 ?t1 ?t2 ?xyz ?rot)
  :preconditions (
  ; use these steps if no split or join
  (in-wm (collision ?colliding-bodies (during ?t1 ?t2) ?type))
  (test (not (member ?type '(split inelastic))))
  ; write subsidiary equations for all needed momenta components along ?xyz

  ; Using mass variable goal inflates file with at least 16 different possibilities -- 
  ; draw body at any of 3 times + defined variable = 4 ways to get each mass variable.
  ; Instead just require drawing bodies first, which will suffice to get mass variables.
  ; Note this will require the time choice on drawn bodies to be the interval, nothing else.
  ; (variable ?m1 (mass ?b1))
  ; (variable ?m2 (mass ?b2))
  (body ?b1 (during ?t1 ?t2))
  (body ?b2 (during ?t1 ?t2))
  ; retrieve mass variables
  (in-wm (variable ?m1 (mass ?b1)))
  (in-wm (variable ?m2 (mass ?b2)))
  ; p1i
  (variable ?v1i_compo (at (compo ?xyz ?rot (velocity ?b1)) ?t1))
  (variable ?p1i_compo (at (compo ?xyz ?rot (momentum ?b1)) ?t1))
  (eqn (= ?p1i_compo (* ?m1 ?v1i_compo)) (momentum-compo ?b1 ?t1 ?xyz ?rot))
  ; p2i
  (variable ?v2i_compo (at (compo ?xyz ?rot (velocity ?b2)) ?t1))
  (variable ?p2i_compo (at (compo ?xyz ?rot (momentum ?b2)) ?t1))
  (eqn (= ?p2i_compo (* ?m2 ?v2i_compo)) (momentum-compo ?b2 ?t1 ?xyz ?rot))
  ; p1f
  (variable ?v1f_compo (at (compo ?xyz ?rot (velocity ?b1)) ?t2))
  (variable ?p1f_compo (at (compo ?xyz ?rot (momentum ?b1)) ?t2))
  (eqn (= ?p1f_compo (* ?m1 ?v1f_compo)) (momentum-compo ?b1 ?t2 ?xyz ?rot))
  ; p2f
  (variable ?v2f_compo (at (compo ?xyz ?rot (velocity ?b2)) ?t2))
  (variable ?p2f_compo (at (compo ?xyz ?rot (momentum ?b2)) ?t2))
  (eqn (= ?p2f_compo (* ?m2 ?v2f_compo)) (momentum-compo ?b2 ?t2 ?xyz ?rot))
  ; and combine into final equation using velocities so cons-linmom can find them
  )
  :effects (
  (eqn (= (+ (* ?m1 ?v1i_compo) (* ?m2 ?v2i_compo))
          (+ (* ?m1 ?v1f_compo) (* ?m2 ?v2f_compo)))
       (compo-eqn lm-compo ?xyz ?rot (cons-linmom (?b1 ?b2) (during ?t1 ?t2))))
  ; need to collect compos of all terms and list in eqn-compos
  (eqn-compos 
       (compo-eqn lm-compo ?xyz ?rot (cons-linmom (?b1 ?b2) (during ?t1 ?t2)))
       (?v1i_compo ?v2i_compo ?v1f_compo ?v2f_compo) )
  )
  :hint (
  (point (string "Can you write an equation relating the ~a components of total momentum before and after the collision?" ((axis ?xyz ?rot) symbols-label)))
  (teach (string "The law of conservation of momentum states that if no external force acts on a system, then the total momentum remains constant. Because the total momentum is the vector sum of the momenta of each body in the system, this law entails that the sum of the momentum components in any direction is the same before and
 after a collision."))
  (bottom-out (string "Write conservation of momentum along the ~A axis as ~A"  
			((axis ?xyz ?rot) symbols-label)
			((= (+ (* ?m1 ?v1i_compo) (* ?m2 ?v2i_compo))
                            (+ (* ?m1 ?v1f_compo) (* ?m2 ?v2f_compo))) algebra)))
  ))

; Following writes p_x = m * vt_x for a single body and time
; body may be a compound body in case of splits or joins.
; this intermediate step is unnecessary since the term p_x is not used in the 
; final eqn, only m*v_x, but it does serve to illustrate where the term comes from.
(defoperator write-momentum-compo (?b ?t ?xyz ?rot)
  :preconditions (
    ; for now, all these preconds satisfied from above
    (in-wm (variable ?p_compo (at (compo ?xyz ?rot (momentum ?b)) ?t)))
    (in-wm (variable ?v_compo (at (compo ?xyz ?rot (velocity ?b)) ?t)))
    (in-wm (variable ?m (mass ?b)))
    ; for magnitude equation put out as implicit equation to make it optional
    (in-wm (variable ?p-var (at (mag (momentum ?b)) ?t)))
    (in-wm (variable ?v-var (at (mag (velocity ?b)) ?t)))
  )
  :effects (
    (eqn (= ?p_compo (* ?m_compo ?v_compo)) (momentum-compo ?b ?t ?xyz ?rot))
    (implicit-eqn (= ?p-var (* ?m ?v-var)) (mag-momentum ?b ?t))
  )
  :hint (
    (point (string "In order to form an expression for the ~a component of total momentum ~a, you will need an expression for the ~a component of the momentum of ~A ~A"
     ((axis ?xyz ?rot) symbols-label) (?t pp)
     ((axis ?xyz ?rot) symbols-label)  ?b (?t pp)))
    (teach (string "The linear momentum of a body is a vector defined as its mass times the velocity vector. Therefore, the component of a body's momentum along an axis can be expressed as its mass times the component of the body's velocity along that axis."))
    (bottom-out (string "Write the equation ~A"  
                        ((= ?p_compo (* ?m_compo ?v_compo)) algebra)))
  ))

(defoperator write-cons-linmom-compo-split (?b1 ?b2 ?t1 ?t2 ?xyz ?rot)
  :preconditions (
  ; use these steps if collision involves split 
  (in-wm (collision ?colliding-bodies (during ?t1 ?t2) split))
  ; write subsidiary equations for all needed momenta components along ?xyz
  ; p_initial = pc
  (bind ?c (combine-bodies ?b1 ?b2))
  (body ?c ?t1) 
  (in-wm (variable ?mc (mass ?c)))
  ; we need to choose an axis to use for the compound since nothing
  (axis-for ?c (during ?t1 ?t2) ?xyz-c ?rot-t)
  (variable ?vc_compo (at (compo ?xyz ?rot (velocity ?c)) ?t1))
  (variable ?pc_compo (at (compo ?xyz ?rot (momentum ?c)) ?t1))
  (eqn (= ?pc_compo (* ?mc ?vc_compo)) (momentum-compo ?c ?t1 ?xyz ?rot))
  ; p1f
  ;(variable ?m1 (mass ?b1))
  (body ?b1 ?t2)
  (in-wm (variable ?m1 (mass ?b1)))
  (variable ?v1f_compo (at (compo ?xyz ?rot (velocity ?b1)) ?t2))
  (variable ?p1f_compo (at (compo ?xyz ?rot (momentum ?b1)) ?t2))
  (eqn (= ?p1f_compo (* ?m1 ?v1f_compo)) (momentum-compo ?b1 ?t2 ?xyz ?rot))
  ; p2f
  ;(variable ?m2 (mass ?b2))
  (body ?b2 ?t2)
  (in-wm (variable ?m2 (mass ?b2)))
  (variable ?v2f_compo (at (compo ?xyz ?rot (velocity ?b2)) ?t2))
  (variable ?p2f_compo (at (compo ?xyz ?rot (momentum ?b2)) ?t2))
  (eqn (= ?p2f_compo (* ?m2 ?v2f_compo)) (momentum-compo ?b2 ?t2 ?xyz ?rot))
  ; and combine into final equation using velocities so cons-linmom can find them
  )
  :effects (
  (eqn (= (* ?mc ?vc_compo) 
             (+ (* ?m1 ?v1f_compo) (* ?m2 ?v2f_compo)))
       (compo-eqn lm-compo ?xyz ?rot (cons-linmom (?b1 ?b2) (during ?t1 ?t2))))
  ; need to collect compos of all terms and list in eqn-compos
  (eqn-compos 
       (compo-eqn lm-compo ?xyz ?rot (cons-linmom (?b1 ?b2) (during ?t1 ?t2)))
       (?vc_compo ?v1f_compo ?v2f_compo) )
  )
  :hint (
  (point (string "Can you write an equation relating the ~a components of total momentum before and after the collision?" ((axis ?xyz ?rot) symbols-label)))
  (teach (string "The law of conservation of momentum states that if no external force acts on a system, then the total momentum remains constant. Because the total momentum is the vector sum of the momenta of each body in the system, this law entails that the sum of the momentum components in any direction is the same before and
 after a collision."))
    (bottom-out (string "Write conservation of momentum along the ~A axis as ~A"  
		        ((axis ?xyz ?rot) symbols-label)
                        ((= (* ?mc ?vc_compo) 
                            (+ (* ?m1 ?v1f_compo) (* ?m2 ?v2f_compo))) algebra)))
  ))

(defoperator write-cons-linmom-compo-join (?b1 ?b2 ?t1 ?t2 ?xyz ?rot)
  :preconditions (
  ; use these steps if join in inelastic collision
  (in-wm (collision ?colliding-bodies (during ?t1 ?t2) inelastic))
  ; write subsidiary equations for all needed momenta components along ?xyz
  ; p1i
  ;(variable ?m1 (mass ?b1))
  (body ?b1 ?t1)
  (in-wm (variable ?m1 (mass ?b1)))
  (variable ?v1i_compo (at (compo ?xyz ?rot (velocity ?b1)) ?t1))
  (variable ?p1i_compo (at (compo ?xyz ?rot (momentum ?b1)) ?t1))
  (eqn (= ?p1i_compo (* ?m1 ?v1i_compo)) (momentum-compo ?b1 ?t1 ?xyz ?rot))
  ; p2i
  ;(variable ?m2 (mass ?b2))
  (body ?b2 ?t1)
  (in-wm (variable ?m2 (mass ?b2)))
  (variable ?v2i_compo (at (compo ?xyz ?rot (velocity ?b2)) ?t1))
  (variable ?p2i_compo (at (compo ?xyz ?rot (momentum ?b2)) ?t1))
  (eqn (= ?p2i_compo (* ?m2 ?v2i_compo)) (momentum-compo ?b2 ?t1 ?xyz ?rot)) 
   ; p_final = pc
  (bind ?c (combine-bodies ?b1 ?b2))
  (body ?c ?t2)
  (in-wm (variable ?mc (mass ?c)))
  (variable ?vc_compo (at (compo ?xyz ?rot (velocity ?c)) ?t2))
  (variable ?pc_compo (at (compo ?xyz ?rot (momentum ?c)) ?t2))
  (eqn (= ?pc_compo (* ?mc ?vc_compo)) (momentum-compo ?c ?t2 ?xyz ?rot))
  ; and combine into final equation using velocities so cons-linmom can find them
  )
  :effects (
  (eqn (= (+ (* ?m1 ?v1i_compo) (* ?m2 ?v2i_compo))
          (* ?mc ?vc_compo))
       (compo-eqn lm-compo ?xyz ?rot (cons-linmom (?b1 ?b2) (during ?t1 ?t2))))
  (eqn-compos 
       (compo-eqn lm-compo ?xyz ?rot (cons-linmom (?b1 ?b2) (during ?t1 ?t2)))
       (?v1i_compo ?v2i_compo ?vc_compo) )
  )
  :hint (
   (point (string "Can you write an equation relating the ~a components of total momentum before and after the collision?" ((axis ?xyz ?rot) symbols-label)))
  (teach (string "The law of conservation of momentum states that if no external force acts on a system, then the total momentum remains constant. Because the total momentum is the vector sum of the momenta of each body in the system, this law entails that the sum of the momentum components in any direction is the same before and after a collision."))
    (bottom-out (string "Write conservation of momentum along the ~A axis as ~A"  
		        ((axis ?xyz ?rot) symbols-label)  
                        ((= (+ (* ?m1 ?v1i_compo) (* ?m2 ?v2i_compo))
                               (* ?mc ?vc_compo)) algebra)))
  ))

; 
; if we are given that a collision is perfectly elastic, we may have to use 
; the fact that kinetic energy is conserved in addition to momentum.
; The following operator applies conservation of kinetic energy to perfectly
; elastic collisions. This is slightly different than the more general 
; conservation of energy equation so we group it under linear momentum.
; It is a separate scalar equation psm (not part of the cons linmom psm)
; so it will only be applied if needed to determine some unknown and goes
; at the bubble-graph level.
;
(defoperator cons-ke-elastic-contains (?quantity)
  :preconditions (
    (collision ?colliding-bodies (during ?t1 ?t2) elastic)
    (any-member ?quantity (
			(at (mag (velocity ?b)) ?t1)
			(at (mag (velocity ?b)) ?t2)
			(mass ?b)
                	  ))
    (test (member ?b ?colliding-bodies :test #'equalp))
    ; in case problem author didn't canonicalize list of bodies
    (bind ?bodies (sort ?colliding-bodies #'expr<))
  )
  :effects (
    (eqn-contains (cons-ke-elastic ?bodies (during ?t1 ?t2)) ?quantity)
  ))

(defoperator write-cons-ke-elastic (?bodies ?t1 ?t2)
  :preconditions (
   ; !! Not clear if have to write equation for each of these
   ; write sub equation for each initial ke, saving values
   (map ?b ?bodies
     (eqn (= ?var ?ke1-val) (kinetic-energy ?b ?t1))
     ?ke1-val ?ke1-terms)
   ; write sub equation for each final ke, saving values
   (map ?b ?bodies
     (eqn (= ?var ?ke2-val) (kinetic-energy ?b ?t2))
     ?ke2-val ?ke2-terms)
  )
  :effects (
     ; final equation sets sum of ke's equal
     (eqn (= (+ . ?ke1-terms) (+ . ?ke2-terms)) 
     	  (cons-ke-elastic ?bodies (during ?t1 ?t2)))
  )
  :hint (
   (point (string "Notice that the collision is elastic."))
   (teach (string "An elastic collision is one in which total kinetic energy is conserved. You can use this fact to equate the total kinetic energy in the system before and after the collision."))
   (bottom-out (string "Write the equation ~A"  
                        ((= (+ . ?ke1-terms) (+ . ?ke2-terms)) algebra)))
  ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Rotational Kinematics
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Objects rotating in the x-y plane of the screen are described by 
;; 	(motion ?obj ?time (rotating ?axis-pt ?rotate-dir ?accel-spec)
;; ?axis-pt: name of pt about which rotation occurs 
;;           most often 'cm for center of mass
;; ?rotate-dir: 'cw or 'ccw or 'unknown
;; ?accel-spec: constant, speed-up, slow-down, unknown
;;
;; Rotational vectors point along the z-axis perpendicular to the plane
;; of the screen. Directions along the z axis are represented by 
;; the special atoms 'into and 'out-of in direction slots and are computed
;; using the right-hand-rule. We also use 'unknown-zdir for rotational 
;; vectors of unknown orientation to indicate they are known to be along the 
;; z-axis.  This applies to net torque, for example, before the sum of the
;; individual torques is computed, so you don't yet know which way the object 
;; will be torqued.
;;
;; In equations the direction variable OV denotes direction with respect
;; to the z-axis so is always equal to either 0 or 180. We nevertheless
;; write out projection equations as V_z = V * cos (OV). 
;;
;; Using the apparatus of angles and z-dir projections is overkill
;; for these problems since all the vectors will have only two possible 
;; directions and the projections will always just give a sign. The 
;; quantities could be treated as signed scalar magnitudes instead.  
;; We use this method because: we want a step in any case for moving from 
;; given rotation directions to choose the signs to use when plugging in 
;; terms into a standard equation. I.e. we don't want given values
;; to include the signs, else mistake in sign just looks like transcription 
;; error, when it could indicate uncertainty about right hand rule.  Also,
;; this notation is currently used on the ANDES interface; it gives us a 
;; number the student can enter as an answer for a sought z-axis direction 
;; and an equation we can use algebraically to specify it; and, it may help 
;; to teach general vector concepts.
;;
;; There is a special driver for angular psms because they operate slightly 
;; differently from the vector psms. Mainly we know the axis is going
;; to be the z-axis, so don't have to go to the trouble of drawing axes and
;; choosing directions based on drawn vectors to apply.  Independently,
;; we don't go through the step of grouping different component equations
;; under a single psm with a common diagram here; we just associate the
;; diagram with the equation and only draw the vectors we need.
;;
;; Note: In current Andes you can't use z-component variables until you draw a
;; coordinate axis, even though the z axis is not settable and the xy rotation
;; doesn't matter. We expect to change Andes so that this becomes unnecessary; 
;; for now we include the axis drawing step to achieve a z axis at 0. This 
;; should always be achievable by draw-unrotated-axes. It might fail in
;; the future a problem if any linear vectors are drawn on the body.

(defoperator apply-angular-psm (?sought ?eqn-id)
   :preconditions (
     (not (component-form)) ; suppress projections unless component-form
     (angular-eqn-contains ?eqn-id ?sought)
     (debug "To find ~a trying z-vector eqn ~A~%" ?sought ?eqn-id)
     (vector-diagram ?eqn-id)
     (debug "Diagram drawn for ~A, writing z-compo eqn~%" ?eqn-id)
     (eqn ?z-compo-eqn (compo-eqn z 0 ?eqn-id))
     (debug "Wrote z-compo eqn ~a ~%" (list ?z-compo-eqn ?eqn-id))
     (derived-eqn ?compo-free-eqn (compo-free z 0 ?eqn-id))
     (debug "Compo-free eqn: ~a. ~%" ?compo-free-eqn)
   )
   :effects (
    (psm-applied ?sought (compo-free z 0 ?eqn-id) ?compo-free-eqn)
   ))

; Following variant writes component-form equations in order to solve
; for z components directly, rather than magnitude/direction of z vectors.
; This is especially necessary on problems where the direction of some
; angular vector like net torque or angular acceleration is unknown,
; since our algebra solver cannot currently solve for unknown phi angles 
; from projection equations like alpha_z = alpha * cos(phi_alpha) together 
; with the magnitude of alpha, which can be determined by alpha = abs(alpha_z).
; The reason is that it can't invert cos(phi) = 1 (or -1) to solve for phi

(defoperator apply-angular-psm-compo-form (?sought ?eqn-id) 
   :preconditions
     ((component-form) ; needed to filter method when sought is duration.
      (any-member ?sought ((at (compo z 0 ?vector) ?t)
			   (duration ?t)))
      ; vector psms defined to seek vector magnitudes, so need to 
      ; pretend we are seeking magnitude to hook into existing vector
      ; psm selecting code.  If sought is duration, just leave it
      (bind ?vec-sought (if (eql (first ?sought) 'duration) ?sought
                         `(at (mag ,?vector) ,?t))) 
      (angular-eqn-contains ?eqn-id ?vec-sought)
      (debug "To find ~a trying z-vector eqn ~A~%" ?sought ?eqn-id)
      (vector-diagram ?eqn-id)
      (debug "Diagram drawn for ~A, writing z-compo eqn~%" ?eqn-id)
      (eqn ?z-compo-eqn (compo-eqn z 0 ?eqn-id))
      (debug "Wrote z-compo eqn ~a ~%" (list ?z-compo-eqn ?eqn-id))
     )
   :effects
   ((psm-applied ?sought (compo-eqn z 0 ?eqn-id) ?z-compo-eqn)))


; draw angular velocity of an object rotating in a known direction 
; Direction is given as cw or ccw in a motion description statement.
; May be used for instantaneous ang-vel at an instant or
; average ang-vel over an interval
; corresponds to draw-velocity-straight
(defoperator draw-ang-velocity-rotating (?b ?t)
   :preconditions (
    (time ?t)
    (motion ?b ?t-motion (rotating ?axis ?rotate-dir ?accel-spec))
    (test (not (equal ?rotate-dir 'unknown)))  
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (ang-velocity ?b) ?t) ?dir-drawn))
    (bind ?dir (rotation-zdir ?rotate-dir))
    (bind ?mag-var (format-sym "omega_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
  )
  :effects (
    (variable ?mag-var (at (mag (ang-velocity ?b)) ?t))
    (variable ?dir-var (at (dir (ang-velocity ?b)) ?t))
    ;(variable ?zc-var  (at (compo z 0 (mag (ang-velocity ?b))) ?t))
    (given (at (dir (ang-velocity ?b)) ?t) ?dir)
    (vector ?b (at (ang-velocity ?b) ?t) ?dir) 
  )
  :hint 
 ((point (string "Notice that ~a is rotating ~a about an axis ~a." ?b (?rotate-dir adj) (?t pp)))
   (teach (string "The angular velocity vector represents the rate of change of a rotating object's angular position. The angular velocity vector lies along the z-axis in Andes problems. By the right hand rule it points out of the x-y plane of the diagram for counter-clockwise rotation and into the x-y plane for clockwise rotation."))
   (bottom-out (string "Because ~a is rotating ~a ~A, use the velocity tool to draw a non-zero angular velocity vector with direction ~a ." ?b (?rotate-dir adj)(?t pp) (?dir adj)))
  ))

; Draw zero angular velocity for an object that is not rotating.
; This is currently specified using same 'at-rest motion specifier 
; as for translational motion problems.
; If we ever wanted to allow for combinations of translational and 
; rotational motions we would change to use a distinct atom to say that
; the object is non-rotating as distinct from translationally at-rest.
(defoperator draw-ang-velocity-at-rest (?b ?t)
   :preconditions (
    (motion ?b ?t-motion at-rest)
    (time ?t)
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (ang-velocity ?b) ?t) ?dir-drawn))
    (bind ?mag-var (format-sym "omega_~A_~A" (body-name ?b) (time-abbrev ?t)))
  )
  :effects (
    (vector ?b (at (ang-velocity ?b) ?t) zero) 
    (variable ?mag-var (at (mag (ang-velocity ?b)) ?t))
    (given (at (mag (ang-velocity ?b)) ?t) (dnum 0 |rad/s|))
  )
  :hint (
    (point (string "Notice that ~a is at rest ~a." ?b (?t pp)))
    (teach (string "The angular velocity vector represents the rate of change of a rotating object's angular position. If an object is at rest its angular position is not changing, so its angular velocity is zero.")) 
    (bottom-out (string "Because ~a is not rotating ~a, use the velocity tool to draw a zero-length angular velocity vector for it." ?b (?t pp)))
  )
)

; draw angular displacement of an object rotating in a known direction
; over an interval. 
(defoperator draw-ang-displacement-rotating (?b ?t)
  :preconditions (
    (time ?t)
    (motion ?b ?t-motion (rotating ?axis ?rotate-dir ?accel-spec))
    (test (not (equal ?rotate-dir 'unknown)))  
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (ang-displacement ?b) ?t) ?dir-drawn))
    (bind ?dir (rotation-zdir ?rotate-dir))
    (bind ?mag-var (format-sym "theta_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
  )
  :effects (
    (vector ?b (at (ang-displacement ?b) ?t) ?dir) 
    (variable ?mag-var (at (mag (ang-displacement ?b)) ?t))
    (variable ?dir-var (at (dir (ang-displacement ?b)) ?t))
    (given (at (dir (ang-displacement ?b)) ?t) ?dir)
  )
  :hint
  ((point (string "Notice that ~a is rotating ~a ~a." ?b (?rotate-dir adj) (?t pp)))
   (teach (string "The angular displacement of an object over an interval represents its net change in angular position as it rotates during that interval.  This vector is defined to lie along the z-axis in Andes problems. By the right hand rule, the angular displacment vector points out of the x-y plane of the diagram for net counter-clockwise rotation and into the x-y plane for net clockwise rotation."))
   (bottom-out (string "Because ~a is rotating ~A ~a, use the displacement tool to draw a non-zero displacement vector for it in direction ~a" ?b (?rotate-dir adj) (?t pp) (?dir adj)))
   ))

; draw angular acceleration of an object rotating in a known direction
; and speeding up
(defoperator draw-ang-accelerating(?b ?t)
  :preconditions 
   ((time ?t)
    (motion ?b ?t-motion (rotating ?axis ?rotate-dir speed-up))
    (test (not (equal ?rotate-dir 'unknown)))  
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (ang-accel ?b) ?t) ?dir-drawn))
    (bind ?dir (rotation-zdir ?rotate-dir))
    (bind ?mag-var (format-sym "alpha_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var)))
  :effects 
   ((vector ?b (at (ang-accel ?b) ?t) ?dir) 
    (variable ?mag-var (at (mag (ang-accel ?b)) ?t))
    (variable ?dir-var (at (dir (ang-accel ?b)) ?t))
    (given (at (dir (ang-accel ?b)) ?t) ?dir))
  :hint
   ((point (string "Notice that the rate at which ~a is rotating is increasing ~a" ?b (?t pp)))
    (teach (string "The angular acceleration vector represents the rate of change of a rotating object's angular velocity. If an object's rate of rotation is speeding up then its angular velocity vector is increasing in magnitude over time, so the angular acceleration will point in the same direction as the angular velocity. By the right-hand rule that will be out of the x-y plane for ccw rotation and into the plane for cw rotation."))
    (bottom-out (string "Because ~a is rotating ~a ~a so its angular velocity points ~A, and it's angular velocity is increasing, you should use the acceleration tool to draw an angular acceleration for it pointing ~a." 
    ?b (?rotate-dir adj) (?t pp) (?dir adj) (?dir adj)))
    ))

; draw angular acceleration of an object rotating in a known direction
; and slowing down
(defoperator draw-ang-decelerating(?b ?t)
  :preconditions (
    (time ?t)
    (motion ?b ?t-motion (rotating ?axis ?rotate-dir slow-down))
    (test (not (equal ?rotate-dir 'unknown)))  
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (ang-accel ?b) ?t) ?dir-drawn))
    (bind ?vel-dir (rotation-zdir ?rotate-dir))
    (bind ?dir (opposite ?vel-dir))
    (bind ?mag-var (format-sym "alpha_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
  )
  :effects 
   ((vector ?b (at (ang-accel ?b) ?t) ?dir) 
    (variable ?mag-var (at (mag (ang-accel ?b)) ?t))
    (variable ?dir-var (at (dir (ang-accel ?b)) ?t))
    (given (at (dir (ang-accel ?b)) ?t) ?dir))
  :hint
   ((point (string "Notice that the rate at which ~a is rotating is decreasing ~a" ?b (?t pp)))
    (teach (string "The angular acceleration vector represents the rate of change of a rotating object's angular velocity. If an object's rate of rotation is slowing down then its angular velocity vector is decreasing in magnitude over time, so the angular acceleration will point in the opposite direction from the angular velocity, as determined by the right-hand rule."))
    (bottom-out (string "Because the angular acceleration of ~a ~a opposes the angular velocity for ~A rotation, which points ~A, you should use the acceleration tool to draw an angular acceleration for it pointing ~a." 
    ?b  (?t pp) (?rotate-dir adj) (?vel-dir adj) (?dir adj)))))

; !!! draw-zero-ang-accel for object at rest or rotating at constant vel.

; draw angular acceleration of an objection rotating in an unknown direction
; but known to be accelerating. This arises in torque problems which seek
; angular acceleration at an instant from given forces. 
; Since we need not be given the initial angular velocity we don't know if it 
; is speeding up or slowing down, but we do know it may be changing (i.e. it
; is not known constant) Strictly, zero acceleration is a possible answer, but 
; that is a bad choice for Andes problems since we expect any zero vectors to 
; be determinable from the givens. By drawing it unknown we should allow that 
; it could turn out to be zero. 
(defoperator draw-ang-accel-unknown-dir (?b ?t)
  :preconditions (
    (time ?t)
    (motion ?b ?t-motion (rotating ?axis unknown ?accel-spec))
    (test (not (equal ?accel-spec 'constant)))
    (test (tinsidep ?t ?t-motion))
    (not (vector ?b (at (ang-accel ?b) ?t) ?dir-drawn))
    (bind ?mag-var (format-sym "alpha_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
  )
  :effects 
   ((vector ?b (at (ang-accel ?b) ?t) z-unknown) 
    (variable ?mag-var (at (mag (ang-accel ?b)) ?t))
    (variable ?dir-var (at (dir (ang-accel ?b)) ?t)))
  :hint 
  ((point (string "You need to introduce a term for the angular acceleration of ~A." ?b))
    (teach (string "When a body is subject to a non-zero net torque it will have an angular acceleration in the direction of the net torque. In this problem you can assume that the forces will result in a net torque so the body will have a non-zero angular acceleration. Whether the angular acceleration points into or out of the plane requires calculation to determine. Since it must lie along the z axis, you should draw it but specify an unknown Z direction ." ?b))
    (bottom-out (string "Use the acceleration tool to draw a non-zero angular acceleration for ~a ~A and select Unknown Z direction in the dialog box." ?b (?t pp)))
  ))
 

; angular sdd:
; angular displacement = avg angular velocity * duration
; Because this uses average angular velocity it does not require
; that the velocity be constant. It could also be called the definition
; of average angular velocity, as scalar sdd is definition of average speed.
(defoperator ang-sdd-contains (?quantity)
  :preconditions (
   (any-member ?quantity (
                (at (mag (ang-velocity ?b)) ?t)
		(at (mag (ang-displacement ?b)) ?t)
		(duration ?t)
		))
   (object ?b)
   (time ?t)
   (test (time-intervalp ?t)))
  :effects (
  (angular-eqn-contains (ang-sdd ?b ?t) ?quantity)
  ))

(defoperator draw-ang-sdd-vectors (?b ?t1 ?t2)
  :preconditions (
   (not (vector-diagram (ang-sdd ?b (during ?t1 ?t2))))
   (body ?b (during ?t1 ?t2))
   (vector ?b (at (ang-velocity ?b) (during ?t1 ?t2)) ?dir-v)
   (vector ?b (at (ang-displacement ?b) (during ?t1 ?t2)) ?dir-d)
   (variable ?var (duration (during ?t1 ?t2)))
   (axis-for ?b (during ?t1 ?t2) z 0)
  )
  :effects (
    (vector-diagram (ang-sdd ?b (during ?t1 ?t2)))
  )
)

; this writes the compo equation; we use generic projection operators
; to produce the compo-free equation.
(defoperator write-ang-sdd (?b ?t)
  :preconditions
   ((variable ?theta_z  (at (compo z 0 (ang-displacement ?b)) ?t))
    (variable ?omega_z  (at (compo z 0 (ang-velocity ?b)) ?t))
    (variable ?t-var (duration ?t)))
  :effects 
   ((eqn (= ?theta_z (* ?omega_z ?t-var)) (compo-eqn z 0 (ang-sdd ?b ?t)))
    (eqn-compos (compo-eqn z 0 (ang-sdd ?b ?t)) (?theta_z ?omega_z)))
  :hint (
  (point (string "Can you write an equation in terms of z components relating average angular velocity to angular displacement and duration?"))
   (teach (string "The average angular velocity of a rotating object over an interval is defined to be the angular displacement divided by the duration of the interval. This gives the rotational counterpart of distance = average speed * time. Writing vector relations like this in terms of the vector components is recommended to avoid sign errors."))
   (bottom-out (string "Write the equation ~a=~a * ~a." (?theta_z algebra) (?omega_z algebra) (?t-var algebra)))
  ))

; angular version of lk-no-s: omega_f = omega_i + alpha_avg * t
; Because this uses average angular acceleration, it doesn't require
; acceleration to be constant
(defoperator rk-no-s-contains (?sought)
 :preconditions (
  (any-member ?sought
	       ( (at (mag (ang-velocity ?b)) ?t1)
		 (at (dir (ang-velocity ?b)) ?t1)
		 (at (mag (ang-velocity ?b)) ?t2)
		 (at (dir (ang-velocity ?b)) ?t2)
		 (at (mag (ang-accel ?b)) (during ?t1 ?t2))
		 (at (dir (ang-accel ?b)) (during ?t1 ?t2))
		 (duration (during ?t1 ?t2))
		 ))
   (object ?b)
   (time (during ?t1 ?t2))
  )
 :effects ( (angular-eqn-contains (rk-no-s ?b (during ?t1 ?t2)) ?sought) ))

(defoperator draw-rk-no-s-vectors (?b ?t1 ?t2)
  :preconditions  (
   (not (vector-diagram (rk-no-s ?b (during ?t1 ?t2))))
   (body ?b (during ?t1 ?t2))
   (vector ?b (at (ang-velocity ?b) ?t2) ?dir-v2)
   (vector ?b (at (ang-accel ?b) (during ?t1 ?t2)) ?dir-d)
   (vector ?b (at (ang-velocity ?b) ?t1) ?dir-v1)
   (variable ?var (duration (during ?t1 ?t2)))
   (axis-for ?b (during ?t1 ?t2) z 0)
  )
  :effects ( (vector-diagram (rk-no-s ?b (during ?t1 ?t2))) )
)

(defoperator write-rk-no-s (?b ?t1 ?t2)
 :preconditions
  ((variable ?omega2_z (at (compo z 0 (ang-velocity ?b)) ?t2))
   (variable ?omega1_z (at (compo z 0 (ang-velocity ?b)) ?t1))
   (variable ?alpha_z  (at (compo z 0 (ang-accel ?b)) (during ?t1 ?t2)))
   (variable ?t-var (duration (during ?t1 ?t2))))
  :effects 
  ((eqn (= ?omega2_z (+ ?omega1_z (* ?alpha_z ?t-var))) 
               (compo-eqn z 0 (rk-no-s ?b (during ?t1 ?t2))))
   (eqn-compos (compo-eqn z 0 (rk-no-s ?b (during ?t1 ?t2))) 
   	(?omega2_z ?omega1_z ?alpha_z))
   (assume using-rk-eqn ?b ?t1 ?t2))
    :hint
   ((point (string "Can you think of an equation that relates the z component of average angular acceleration to that of the initial angular velocity, final angular velocity, and duration?"))
    (teach (string "Acceleration is the rate of change of velocity. The average acceleration vector over some time is defined as the difference between initial and final velocity vectors divided by the duration. This definition can be be applied in component form to relate ~A, ~A, ~A and ~A" (?omega2_z algebra) (?omega1_z algebra) (?alpha_z algebra) (?t-var algebra)))
    (bottom-out (string "Write the equation ~a = ~a + ~a*~a" 
                        (?omega2_z algebra) (?omega1_z algebra) 
			(?alpha_z algebra) (?t-var algebra)))))

; angular version of lk-no-vf: 
;        theta12 = omega1 * t + 0.5 * alpha12 * t12^2
(defoperator rk-no-vf-contains (?sought)
 :preconditions (
  (any-member ?sought
	       ( (at (mag (ang-displacement ?b)) (during ?t1 ?t2))
		 (at (dir (ang-displacement ?b)) (during ?t1 ?t2))
		 (at (mag (ang-velocity ?b)) ?t1)
		 (at (dir (ang-velocity ?b)) ?t1)
		 (at (mag (ang-accel ?b)) (during ?t1 ?t2))
		 (at (dir (ang-accel ?b)) (during ?t1 ?t2))
		 (duration (during ?t1 ?t2))
		 ))
   ; only applies if accel is constant within interval we are using
   (time (during ?t1 ?t2))  ; ensure both endpoints bound
   (constant (ang-accel ?b) ?t-constant)
   (test (tinsidep `(during ,?t1 ,?t2) ?t-constant))
  )
 :effects ( (angular-eqn-contains (rk-no-vf ?b (during ?t1 ?t2)) ?sought) )
)

(defoperator draw-rk-no-vf-vectors (?b ?t1 ?t2)
  :preconditions  (
   (not (vector-diagram (rk-no-vf ?b (during ?t1 ?t2))))
   (body ?b (during ?t1 ?t2))
   (vector ?b (at (ang-displacement ?b) (during ?t1 ?t2)) ?dir-d)
   (vector ?b (at (ang-accel ?b) (during ?t1 ?t2)) ?dir-a)
   (vector ?b (at (ang-velocity ?b) ?t1) ?dir-v1)
   (variable ?var (duration (during ?t1 ?t2)))
   (axis-for ?b (during ?t1 ?t2) z 0)
  )
  :effects ( (vector-diagram (rk-no-vf ?b (during ?t1 ?t2))) )
)

(defoperator write-rk-no-vf (?b ?t1 ?t2)
 :preconditions(
   (variable ?theta_z  (at (compo z 0 (ang-displacement ?b)) (during ?t1 ?t2)))
   (variable ?omega1_z (at (compo z 0 (ang-velocity ?b)) ?t1))
   (variable ?alpha_z  (at (compo z 0 (ang-accel ?b)) (during ?t1 ?t2)))
   (variable ?t-var    (duration (during ?t1 ?t2)))
  )
  :effects (
   (eqn (= ?theta_z (+ (* ?omega1_z ?t-var)
                       (* 0.5 ?alpha_z (^ ?t-var 2))) )
               (compo-eqn z 0 (rk-no-vf ?b (during ?t1 ?t2))))
   (eqn-compos (compo-eqn z 0 (rk-no-vf ?b (during ?t1 ?t2))) 
   	(?theta_z ?omega1_z ?alpha_z))
   (assume using-rk-eqn ?b ?t1 ?t2)
   )
  :hint (
    (point (string "Do you know an equation relating the z component of angular displacement to that of initial angular velocity, time, and angular acceleration when angular acceleration is constant?"))
    (bottom-out (string "Write the equation ~A" 
                ((= ?theta_z (+ (* ?omega1_z ?t-var)
                               (* 0.5 ?alpha_z (^ ?t-var 2)))) algebra) ))
  ))

; angular version of lk-no-t 
;        omega2^2 = omega1^2 + 2 * alpha12 * theta12
(defoperator rk-no-t-contains (?sought)
 :preconditions (
  (any-member ?sought
	       ( (at (mag (ang-velocity ?b)) ?t1)
		 (at (dir (ang-velocity ?b)) ?t1)
	         (at (mag (ang-velocity ?b)) ?t2)
		 (at (dir (ang-velocity ?b)) ?t2)
	         (at (mag (ang-displacement ?b)) (during ?t1 ?t2))
		 (at (dir (ang-displacement ?b)) (during ?t1 ?t2))
		 (at (mag (ang-accel ?b)) (during ?t1 ?t2))
		 (at (dir (ang-accel ?b)) (during ?t1 ?t2))
		 ))
   ; only applies if accel is constant within interval we are using
   (time (during ?t1 ?t2))  ; ensure both endpoints bound
   (constant (ang-accel ?b) ?t-constant)
   (test (tinsidep `(during ,?t1 ,?t2) ?t-constant))
  )
 :effects ( (angular-eqn-contains (rk-no-t ?b (during ?t1 ?t2)) ?sought) )
)

(defoperator draw-rk-no-t-vectors (?b ?t1 ?t2)
  :preconditions  (
   (not (vector-diagram (rk-no-t ?b (during ?t1 ?t2))))
   (body ?b (during ?t1 ?t2))
   (vector ?b (at (ang-velocity ?b) ?t2) ?dir-v2)
   (vector ?b (at (ang-velocity ?b) ?t1) ?dir-v1)
   (vector ?b (at (ang-accel ?b) (during ?t1 ?t2)) ?dir-a)
   (vector ?b (at (ang-displacement ?b) (during ?t1 ?t2)) ?dir-d)
   (axis-for ?b (during ?t1 ?t2) z 0)
  )
  :effects ( (vector-diagram (rk-no-t ?b (during ?t1 ?t2))) )
)

(defoperator write-rk-no-t (?b ?t1 ?t2)
 :preconditions(
   (variable ?omega2_z (at (compo z 0 (ang-velocity ?b)) ?t2))
   (variable ?omega1_z (at (compo z 0 (ang-velocity ?b)) ?t1))
   (variable ?alpha_z  (at (compo z 0 (ang-accel ?b)) (during ?t1 ?t2)))
   (variable ?theta_z  (at (compo z 0 (ang-displacement ?b)) (during ?t1 ?t2)))
  )
  :effects (
   (eqn (= (^ ?omega2_z 2) (+ (^ ?omega1_z 2)
                              (* 2 ?alpha_z ?theta_z)))
               (compo-eqn z 0 (rk-no-t ?b (during ?t1 ?t2))))
   (eqn-compos (compo-eqn z 0 (rk-no-t ?b (during ?t1 ?t2))) 
   	(?omega2_z ?omega1_z ?alpha_z ?theta_z))
   (assume using-rk-eqn ?b ?t1 ?t2)
   )
  :hint (
    (point (string "Do you know an equation relating the z components of initial angular velocity, final angular velocity, angular acceleration, and angular displacement when acceleration is constant?"))
    (bottom-out 
      (string "Write the equation ~A" 
               ((= (^ ?omega2_z 2) (+ (^ ?omega1_z 2)
                                   (* 2 ?alpha_z ?theta_z))) algebra)))
  ))


; Counterpart to lk-no-a would be 
;          theta12 = 0.5 * (omega_i + omega_f) * t12
; This formula wasn't used in the CLIPS solution so it's not included here.
; It would be straightforward to add it if desired.


; LINEAR-VEL: Linear velocity of point on rotating object 
;    v_pt = omega * r 	where r is the radial distance from axis to point.
;
; We need an operator to draw the linear velocity of the rotating point with an
; appropriate direction, even though direction doesn't matter for the
; answer. For now we derive a motion statement for it from
; a description of the point's relative position from the center at the
; sample time shown in the problem diagram together
; with the rotation direction; draw-velocity-curved will then draw it.
; We could also add another special-purpose velocity drawing operator.
; Note CLIPS solutions didn't pick any particular location of the point at
; the time in question so left the velocity direction completely unspecified. 
;
; Exactly which quantity type to use for this "r" in our solutions is 
; a little unclear.  A "radius" is simply the distance between two points
; one of which happens to locate an axis of rotation. So we could just use
; distance-between, though would have to add this, since we haven't used it 
; yet.  But students are most likely to use the radius tool to label this, 
; However, our revolution-radius quantity does not have a slot for the axis 
; point. 
;
; So we settled on a relative-position vector, with an instruction on the
; problem page to use this quantity. This is mainly because we are 
; already using that for the direction of the point, and also because we hope 
; to move to using position vectors more consistently for spatial relations 
; in the future. We have an operator put out an equation for the equality of 
; revolution-radius to relative position of point from axis, though hopefully 
; the tutor will be able to avoid hinting to perform this step.
;
; Another possibility is to try to split the method graph inside 
; the psm to use both methods of specifying this quantity, but that involves
; coding two completely different versions of the operator.

; Following derives linear motion description from given relative position
; of point on rim and rotation direction, for use by curved velocity drawing op
(defoperator describe-linear-motion (?pt ?t)
   :preconditions (
   (part-of ?pt ?whole-body)
   (time ?t)
   (motion ?whole-body ?t-rotating (rotating ?axis-pt ?rotate-dir ?dontcare))
   (test (not (equal ?rotate-dir 'unknown)))
   (test (tinsidep ?t ?t-rotating))
   (given (at (dir (relative-position ?pt ?axis-pt)) ?t) (dnum ?r-dir |deg|))
   (bind ?v-dir (if (equal ?rotate-dir 'ccw) (mod (+ ?r-dir 90) 360)
                  (mod (- ?r-dir 90) 360)))
   (bind ?a-dir (mod (+ ?r-dir 180) 360))  
   (debug "linear motion of ~A: vel dir ~A, accel dir ~A~%" ?pt ?v-dir ?a-dir)
   )
   :effects (
     (motion ?pt ?t (curved circular ((dnum ?v-dir |deg|) 
                                      (dnum ?a-dir |deg|))))
   )
)

(defoperator linear-vel-contains (?sought)
   :preconditions (
   (any-member ?sought (
		  (at (mag (velocity ?pt)) ?t)
                  (at (mag (ang-velocity ?whole-body)) ?t)
		  (at (mag (relative-position ?pt ?axis)) ?t)
		))
   (part-of ?pt ?whole-body)
   (time ?t)
   (motion ?whole-body ?t-rotating (rotating ?axis . ?dontcare))
   (test (tinsidep ?t ?t-rotating))
   )
   :effects (
     (eqn-contains (linear-vel ?pt ?t ?axis) ?sought)
   ))

(defoperator write-linear-vel (?pt ?t)
   :preconditions (
      (part-of ?pt ?whole-body)
      ; Problems that use only this rule should draw a body for
      ; consistency.  We choose the whole rotating object as our 
      ; body, as suggested by Bob 
      (body ?whole-body ?t)
      (variable ?v-var (at (mag (velocity ?pt)) ?t))
      (variable ?omega-var (at (mag (ang-velocity ?whole-body)) ?t))
      (variable ?r-var (at (mag (relative-position ?pt ?axis)) ?t))
   )
   :effects (
    (eqn  (= ?v-var (* ?omega-var ?r-var)) (linear-vel ?pt ?t ?axis))
   )
   :hint (
    (point (string "Do you know the relation between the linear velocity of a point on a rotating object and the angular velocity of the rotation?"))
    (teach (string "The linear velocity of a point on a rotating object is equal to the angular velocity of the rotation times the radius of the point's circular motion = magnitude of relative position of the point from the axis of rotation."))
    (bottom-out (string "Write the equation ~A"
                         ((= ?v-var (* ?omega-var ?r-var)) algebra)))
   )
)


;; following asserts the equality r = magR, so that we can describe the 
;; motion in terms of relative position vectors in the problem statement, 
;; while the formula uses the revolution-radius quantity.
(defoperator radius-equals-relpos (?pt ?t)
   :specifications "the radius of revolution of a point on a rotating object is equal
   to the magnitude of its relative position from the axis of rotation" 
   :preconditions (
   (part-of ?pt ?whole-body)
   (motion ?whole-body ?t-rotating (rotating ?axis-pt . ?dontcare))
   (time ?t)
   (test (tinsidep ?t ?t-rotating))
   (given (at (mag (relative-position ?pt ?axis-pt)) ?t) ?value)
   )
   :effects (
    (equals (at (revolution-radius ?pt) ?t) 
            (at (mag (relative-position ?pt ?axis-pt)) ?t))
   ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Angular momentum and its conservation
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Moment of inertia:
; This is the rotational analog of mass. Unlike our mass, this quantity 
; needs a time because in some problems it can change due to changes in 
; the configuration of the mass. The classic case is a pirouetting skater 
; tucking in the arms, reducing moment of inertia in order to spin faster.
;
; This means that if we are interested in I of an object at two times, we must
; introduce different variables for each even if there is no change.
; However, in our current problems, whenever I can be calculated by formula 
; from shape, it is constant throughout the problem. In problems where I 
; varies, I is just given at the various times, since the shape, such as that 
; of a man holding out his arms, is usually complex. It would be more 
; convenient if we could specify I over the whole range of the problem
; where it is constant, but we lack a good way to do this.
;
; The moment of inertia of a body also depends on the axis of rotation being
; considered, e.g. it is different for a stick rotating about its center 
; than about its end. The "shape" statement which specifies the rigid body
; shape also includes a third argument giving the axis of rotation relevant 
; to the problem, so the relevant axis can be derived. We don't have 
; problems where rotation about more than one axis is considered.

(defoperator define-moment-of-inertia (?b ?t)
  :preconditions (
    (object ?b)
    (time ?t)
    (bind ?I-var (format-sym "I_~A_~A" (body-name ?b) (time-abbrev ?t)))
  )
  :effects (
    (define-var (at (moment-of-inertia ?b) ?t))
    (variable ?I-var (at (moment-of-inertia ?b) ?t))
  )
  :hint (
   (bottom-out (string "Use the Add Variable command to define a variable for the moment of inertia of ~A ~A" ?b (?t pp)))
  ))

; Shape variables: We define special scalar variables for the appropriate
; dimensions characterizing certain rigid bodies.

; length: defines a variable for the length of a rigid body that has a 
; dimension normally described as a length, i.e. rod or rectangular plate
(defoperator define-shape-length (?b)
  :preconditions (
     (object ?b)
     (shape ?b ?shape ?dontcare)
     (any-member ?shape (rod rectangle))
     (bind ?l-var (format-sym "length_~A" (body-name ?b)))
  )
  :effects (
    (define-var (length ?b))
    (variable ?l-var (length ?b))
  )
  :hint (
    (bottom-out (string "Use the Add Variable command to define a variable for the length of ~A"  ?b))
  ))


;;; mass per length
(def-qexp mass-per-length (mass-per-length ?rope)
  :units |kg/m|
  :restrictions nonnegative 
  :english ("the mass-per-length of ~A" (nlg ?rope))
  :fromworkbench `(mass-per-length ,body))

(defoperator define-mass-per-length (?rope)
  :preconditions(
		 (object ?rope)
		 (shape ?rope rod ?dontcare)
		 (bind ?lambda-var (format-sym "mu_~A" (body-name ?rope))))
  :effects (
	    (variable ?lambda-var (mass-per-length ?rope))
	    (define-var (mass-per-length ?rope)))
  :hint ((bottom-out 
	  (string "Define a variable for the mass per unit length of ~A by using the Add Variable command on the Variable menu and selecting mass-per-length."  ?rope))))

;;; mass per length = mass /length of a rod

(def-psmclass mass-per-length-eqn (mass-per-length-eqn ?body)
  :complexity major
  :doc "mass per length = mass/length"
  :english ("mass per length = mass/length")
  :expFormat ("applying mass per length = mass/length")
  :EqnFormat ("mu = m/l"))

(defoperator mass-per-length-eqn-contains (?quantity)
  :preconditions (
		  (object ?b)
		  (shape ?b rod ?dontcare) ;; make sure it has right shape
		  (any-member ?quantity
			      ((mass-per-length ?b)
			       (length ?b)
			       (mass ?b))))
  :effects
  ((eqn-contains (mass-per-length-equation ?b) ?quantity)))

(defoperator mass-per-length-equation (?b)
  :preconditions (
		  (variable ?m (mass ?b))
		  (variable ?l (length ?b))
		  (variable ?mu (mass-per-length ?b)))
  :effects
  ((eqn (= ?mu (/ ?m ?l)) (mass-per-length-equation ?b)))
  :hint
  ((point (string "Find the mass per unit length."))
   (teach (string "The mass per unit length is the total mass of ~a divided by the length of ~a" ?b ?b))
   (bottom-out (string "Because ~a is mass per length, write ~a=~a/~a"
		       ?mu ?mu ?m ?l))
   ))

; defines a variable for the "width" of a rigid body that has a dimension
; normally described as a width, i.e. second dimension of rectangle.
; Body dimensions are typically given; which one counts as "length" and 
; which one as "width" would have to be specified in the verbal problem 
; statement of the given dimensions. 
(defoperator define-width (?b)
  :preconditions (
     (object ?b)
     (shape ?b rectangle ?dontcare)
     (bind ?l-var (format-sym "width_~A" (body-name ?b)))
  )
  :effects (
    (define-var (width ?b))
    (variable ?l-var (width ?b))
  )
  :hint (
    (bottom-out (string "Use the Add Variable command to define a variable for the width of ~A" ?b))
  ))

; following defines a variable for radius of a rigid body
; whose dimension would normally be characterized as a radius
; !!! no facility exists for doing this on andes interface !!!
(defoperator define-shape-radius (?b ?t)
  :preconditions 
     ((object ?b)
     (shape ?b ?shape ?dontcare)
     (any-member ?shape (hoop disk sphere spherical-shell))
     (time ?t)
     (bind ?r-var (format-sym "r_~A_~A" (body-name ?b) (time-abbrev ?t))))
  :effects ( 
    (define-var (at (radius ?b) ?t)) 
    (variable ?r-var (at (radius ?b) ?t)) 
  )
  :hint (
    (bottom-out (string "Use the Add Variable command to define a variable for the radius of ~A" ?b))
  ))

;-------------------------------------------------------------------------
; Formulas for moment of inertia for objects of various shapes about
; axes such as cm (for center of mass) or end. 
;-------------------------------------------------------------------------

; I for long thin rod rotating about cm = 1/12 m l^2, where l is length
(defoperator I-rod-cm-contains (?sought)
  :preconditions 
  ((shape ?b rod cm)
  (any-member ?sought ( (at (moment-of-inertia ?b) ?t)
		        (mass ?b)
		        (length ?b) ))
  (time ?t))
  :effects ( (eqn-contains (I-rod-cm ?b ?t) ?sought)))

(defoperator write-I-rod-cm (?b ?t)
  :preconditions (
    (variable ?I-var (at (moment-of-inertia ?b) ?t))
    (variable ?m-var (mass ?b))
    (variable ?l-var (length ?b) ))
  :effects 
    ((eqn (= ?I-var (* (/ 1 12) ?m-var (^ ?l-var 2))) (I-rod-cm ?b ?t)))
   :hint
    ((point (string "You need the formula for the moment of inertia of a long thin rod rotating about its center of mass."))
     (bottom-out (string "Write the equation ~A"
            ((= ?I-var (* (/ 1 12) ?m-var (^ ?l-var 2))) algebra)))))

; I for long thin rod about end = 1/3 M * L^2 where L is length
; This is our only formula for rotation not about the center of mass.
; It could be derived from the formula for I about cm plus the "parallel 
; axis theorem", but we don't include that yet.
(defoperator I-rod-end-contains (?sought)
  :preconditions 
  ((shape ?b rod end)
  (any-member ?sought ( (at (moment-of-inertia ?b) ?t)
		        (mass ?b)
		        (length ?b) ))
  (time ?t))
  :effects ( (eqn-contains (I-rod-end ?b ?t) ?sought)))

(defoperator write-I-rod-end (?b ?t)
  :preconditions (
    (variable ?I-var (at (moment-of-inertia ?b) ?t))
    (variable ?m-var (mass ?b))
    (variable ?l-var (length ?b) ))
  :effects 
    ((eqn (= ?I-var (* (/ 1 3) ?m-var (^ ?l-var 2))) (I-rod-end ?b ?t)))
  :hint
    ((point (string "You need the formula for the moment of inertia of a long thin rod rotating about its end."))
     (bottom-out (string "Write the equation ~A"
            ((= ?I-var (* (/ 1 3) ?m-var (^ ?l-var 2))) algebra)))))


; I for hoop of given radius about center: I = MR^2 where R is radius
; !!! quick hack !!! The workbench offers a "radius" variable, but uses it
; to mean "radius of uniform circular motion" -- our "revolution-radius" --
; and has nothing to be radius of a rigid body shape. In order to allow
; this to be defined with the current workbench, we define I for a hoop in 
; terms of a revolution radius. This is not totally awful since our hoop is 
; likely rotating about it's center of mass, but it should be fixed in
; the workbench. 
(defoperator I-hoop-cm-contains (?sought)
  :preconditions 
  ((shape ?b hoop cm)
  (any-member ?sought ((at (moment-of-inertia ?b) ?t)
		   (mass ?b)
		   ; more correct:
		   ;(at (radius ?b) ?t)
		   (at (revolution-radius ?b) ?t)
		      ))
  (time ?t))
  :effects 
    ((eqn-contains (I-hoop-cm ?b ?t) ?sought)))

(defoperator write-I-hoop-cm (?b ?t)
  :preconditions 
    ((variable ?I-var (at (moment-of-inertia ?b) ?t))
    (variable ?m-var (mass ?b))
    ; more correct:
    ;(variable ?r-var (at (radius ?b) ?t))
    (variable ?r-var (at (revolution-radius ?b) ?t))
    )
  :effects 
  ( (eqn (= ?I-var (* ?m-var (^ ?r-var 2))) (I-hoop-cm ?b ?t)) )
   :hint
    ((point (string "You need the formula for the moment of inertia of a hoop rotating about its center of mass."))
     (bottom-out (string "Write the equation ~A"
            ((= ?I-var (* ?m-var (^ ?r-var 2))) algebra)))))

; I for disk or cylinder of given radius about center: I = 1/2 M R^2
(defoperator I-disk-cm-contains (?sought)
  :preconditions 
  ((shape ?b disk cm)
  (any-member ?sought ((at (moment-of-inertia ?b) ?t)
		       (mass ?b)
		       (at (radius ?b) ?t)))
  (time ?t))
  :effects 
    ( (eqn-contains (I-disk-cm ?b ?t) ?sought) ))

(defoperator write-I-disk-cm (?b ?t)
  :preconditions (
    (variable ?I-var (at (moment-of-inertia ?b) ?t))
    (variable ?m-var (mass ?b))
    (variable ?r-var (at (radius ?b) ?t))
  )
  :effects 
    ( (eqn (= ?I-var (* 0.5 ?m-var (^ ?r-var 2))) (I-disk-cm ?b ?t)) ))

; rectangular plate I = 1/12 M * (l^2 + w^2) where l = length, w = width
(defoperator I-rect-cm-contains (?sought)
  :preconditions 
  ((shape ?b rectangle cm)
  (any-member ?sought ( (at (moment-of-inertia ?b) ?t)
		        (mass ?b)
		        (length ?b) 
		        (width ?b) ))
  (time ?t))
  :effects ( (eqn-contains (I-rect-cm ?b ?t) ?sought)))

(defoperator write-I-rect-cm (?b ?t)
  :preconditions 
   ((variable ?I-var (at (moment-of-inertia ?b) ?t))
    (variable ?m-var (mass ?b))
    (variable ?l-var (length ?b)) 
    (variable ?w-var (width ?b)))
  :effects 
    ((eqn (= ?I-var (* (/ 1 12) ?m-var (+ (^ ?l-var 2) 
                                          (^ ?w-var 2)))) 
          (I-rect-cm ?b ?t)))
   :hint
    ((point (string "You need the formula for the moment of inertia of a rectangle rotating about its center of mass."))
     (bottom-out (string "Write the equation ~A"
            ((= ?I-var (* (/ 1 12) ?m-var (+ (^ ?l-var 2) 
                                             (^ ?w-var 2))))  algebra)))))

;; moment of inertia of a compound body is sum of moments of inertia of 
;; its constituents
(defoperator I-compound-contains (?sought)
   :preconditions (
     (any-member ?sought ( (at (moment-of-inertia (compound . ?bodies)) ?t) ))
     ; can also find I for component bodies from I of compound, see below
   )
   :effects (
     (eqn-contains (I-compound ?bodies ?t) ?sought)
   ))

(defoperator I-compound-contains2 (?sought)
   :preconditions (
     (object (compound . ?bodies))
     (any-member ?sought ( (at (moment-of-inertia ?b) ?t) ))
     (test (member ?b ?bodies :test #'equal))
   )
   :effects (
     (eqn-contains (I-compound ?bodies ?t) ?sought)
   ))

(defoperator write-I-compound (?bodies ?t)
   :preconditions (
      ; make sure compound body is drawn. This is the only place the compound occurs
      ; as a "principle body" in a cons ang-mom problem, for next-step-help to prompt
      ; to draw it at the beginning. (This isn't needed for counterpart mass-compound,
      ; since compound is drawn as one way of defining mass variable.)
      (body (compound . ?bodies) ?t)
      (variable ?I-var (at (moment-of-inertia (compound . ?bodies)) ?t))
      (map ?body ?bodies
         (variable ?Ipart-var (at (moment-of-inertia ?body) ?t))
	 ?Ipart-var ?Ipart-vars)
   )
   :effects (
      (eqn (= ?I-var (+ . ?Ipart-vars)) (I-compound ?bodies ?t))
   )
   :hint (
     (point (string "Think about how the moment of inertia of a compound body relates to the moments of inertia of its parts"))
     (teach (string "The moment of inertia of a compound body is the sum of the moments of inertia of its parts"))
     (bottom-out (string "Write the equation ~A"
               ((= ?I-var (+ . ?Ipart-vars)) algebra)))
   ))


;; magnitude of angular momentum: 
;; following draws the angular momentum direction based on the drawn
;; angular velocity vector.
;; !!! could put out equation linking dirL = dirOmega, even if unknown
(defoperator draw-ang-momentum-rotating (?b ?t)
   :preconditions (
    (object ?b)
    (time ?t)
    (not (vector ?b (at (ang-momentum ?b) ?t)))
    ; draw the angular velocity
    (vector ?b (at (ang-velocity ?b) ?t-rotating) ?dir-vel)
    (test (not (equal ?dir-vel 'unknown)))
    (test (tinsidep ?t ?t-rotating))
    (bind ?mag-var (format-sym "L_~A_~A" (body-name ?b) (time-abbrev ?t)))
    (bind ?dir-var (format-sym "O~A" ?mag-var))
  )
  :effects (
    (vector ?b (at (ang-momentum ?b) ?t) ?dir-vel)
    (variable ?mag-var (at (mag (ang-momentum ?b)) ?t))
    (variable ?dir-var (at (dir (ang-momentum ?b)) ?t)) 
    (given (at (dir (ang-momentum ?b)) ?t) ?dir-vel)
   )
  :hint (
   (point (string "Notice that ~a is rotating ~a so has a non-zero angular velocity vector directed ~A." ?b  (?t pp) (?dir-vel adj)))
   (teach (string "In the case of a symmetrical rigid body rotating about a fixed axis, the angular momentum vector will be equal to the moment of inertia -- a scalar-- times the angular velocity vector. The angular momentum will therefore point along the z axis in the same direction as the angular velocity vector."))
   (bottom-out (string "Because ~a has an angular velocity pointing ~a ~A, use the momentum tool to draw a non-zero angular momentum vector with direction ~a ." ?b (?dir-vel adj)(?t pp) (?dir-vel adj)))
  ))

; following writes the equation for angular momentum 
; compo equation: L_z = I * omega_z
(defoperator ang-momentum-contains (?sought)
   :preconditions (
      (any-member ?sought (
              (at (mag (ang-momentum ?b)) ?t)
              (at (dir (ang-momentum ?b)) ?t)
	      (at (mag (ang-velocity ?b)) ?t)
	      (at (dir (ang-velocity ?b)) ?t)
	      (at (moment-of-inertia ?b) ?t)
                          )) 
   )
   :effects ((angular-eqn-contains (ang-momentum ?b ?t) ?sought))
)

(defoperator draw-ang-momentum-vectors (?b ?t)
  :preconditions 
     ( (not (vector-diagram (ang-momentum ?b ?t))) 
       (vector ?b (at (ang-momentum ?b) ?t) ?dir) 
       (axis-for ?b ?t z 0) )
  :effects 
     ( (vector-diagram (ang-momentum ?b ?t)) ))

(defoperator write-ang-momentum (?b ?t)
  :preconditions (
     (variable ?L_z     (at (compo z 0 (ang-momentum ?b)) ?t))
     (variable ?omega_z (at (compo z 0 (ang-velocity ?b)) ?t))
     (variable ?I   (at (moment-of-inertia ?b) ?t))
  )
  :effects (
     (eqn (= ?L_z (* ?I ?omega_z)) 
                 (compo-eqn z 0 (ang-momentum ?b ?t)))
     (eqn-compos (compo-eqn z 0 (ang-momentum ?b ?t)) (?L_z ?omega_z))
  )
  :hint (
    (point (string "Can you write an equation for the z component of the angular momentum of ~A ~A" ?b (?t pp)))
    (teach (string "For a body rotating about a fixed axis, the angular momentum vector will be equal to its moment of inertia (a scalar) times the its angular velocity vector. The angular momentum vector will therefore point in the same direction as the angular velocity vector. You can use this vector relation to write an equation for the z component of angular momentum in terms of the z component of angular velocity and the moment of inertia of the object."))
    (bottom-out (string "Write the equation ~A"
                         ((= ?L_z (* ?I ?omega_z)) algebra)))
   ))

;; conservation of angular momentum
;; Ang mom of a system of bodies is conserved when the net torque is zero.
;; We could check by verifying no forces on any part of object.
;;
;; For now we just rely on a "rotation-change" statement in the problem 
;; description. This functions like the "collision" statement in linear 
;; momentum problems. It indicates that there has been some change affecting
;; the ang-mom-conserving change in rotational variables. 
;; This should be changed to use more general principles in the future.
;; Note we need some way of knowing that if two bodies have coupled that
;; angular momentum is not conserved for an individual body.
;; 
(defoperator cons-angmom-contains (?sought)
  :preconditions (
  ; for now only apply if we are given some momentum conserving change:
  (rotation-change ?body-list (during ?t1 ?t2) ?split-join)
  (any-member ?sought (
               (at (mag (ang-velocity ?b)) ?t1) (at (dir (ang-velocity ?b)) ?t1)
               (at (mag (ang-velocity ?b)) ?t2) (at (dir (ang-velocity ?b)) ?t2)
	       (at (moment-of-inertia ?b) ?t1) (at (moment-of-inertia ?b) ?t2)
	       ; in case of split or join
	       (at (mag (ang-velocity (compound ?bodies)) ?t1))
	       (at (mag (ang-velocity (compound ?bodies)) ?t2))
	       	      ))
  (test (or (contains-sym ?sought 'compound)
            (member ?b ?body-list :test #'equal)))
  ; in case problem author didn't canonicalize body list:
  (bind ?bodies (sort ?body-list #'expr<))
  )
  :effects (
    (angular-eqn-contains (cons-angmom ?bodies (during ?t1 ?t2)) ?sought)
  ))

(defoperator draw-cons-angmom-vectors (?bodies ?t1 ?t2)
  :preconditions (
   ; don't use this in case of a join or split
   (not (rotation-change ?body-list (during ?t1 ?t2) join))
   (not (rotation-change ?body-list (during ?t1 ?t2) split))
   ; what to draw here? Issues same as conservation of linmom.
   ; draw system
	  ; until we sort out drawing of many-body systems
	  ;(body (system ?b1 ?b2) (during ?t1 ?t2))
   ; since no join/split, draw bodies over whole interval:
   (foreach ?b ?bodies 
        (body ?b (during ?t1 ?t2)))
   ; draw each body's initial angular momentum (will draw vel in process)
   (foreach ?b ?bodies
   	(vector ?b (at (ang-momentum ?b) ?t1) ?dir1))
   ; draw each body's final angular momentum 
   (foreach ?b ?bodies
   	(vector ?b (at (ang-momentum ?b) ?t2) ?dir2))
   ; need to draw an axis so components can be defined
   (axis-for (system . ?bodies) (during ?t1 ?t2) z 0)
   ; must also assert axes to use for constituent bodies so it can be 
   ; found by compo-var defining operator.  Could also do this when 
   ; drawing axis for compound system.
   (foreach ?b ?bodies
      (add-to-wm (axis-for ?b (during ?t1 ?t2) z 0)))
  )
  :effects (
   (vector-diagram (cons-angmom ?bodies (during ?t1 ?t2)))
  ))
 
; draw the diagram for a join, showing compound body after coupling.
(defoperator draw-cons-angmom-vectors-join (?bodies ?t1 ?t2)
  :preconditions (
   ; only use this in case of a join
   (in-wm (rotation-change ?body-list (during ?t1 ?t2) join))
   ; what to draw here? Issues same as conservation of linmom.
   ; draw system
	  ; until we sort out drawing of many-body systems
	  ;(body (system ?b1 ?b2) (during ?t1 ?t2))
   ; draw each body at initial time
   (foreach ?b ?bodies 
        (body ?b ?t1))
   ; draw each body's initial angular momentum (will draw vel in process)
   (foreach ?b ?bodies
   	(vector ?b (at (ang-momentum ?b) ?t1) ?dir1))
   ; draw compound body for final angular momentum 
   (bind ?c `(compound ,@?bodies)) ; for shorthand
   (body ?c ?t2)
   ; draw final angular momentum of compound
   (vector ?c (at (ang-momentum ?c) ?t2) ?dir-c)
   ; need to draw an axis so components can be defined
   (axis-for (system . ?bodies) (during ?t1 ?t2) z 0)
   ; must also assert axes to use for constituent bodies so it can be 
   ; found by compo-var defining operator.  Could also do this when 
   ; drawing axis for compound system.
   (foreach ?b ?bodies
      (add-to-wm (axis-for ?b ?t1 z 0)))
   (add-to-wm (axis-for ?c ?t2 z 0))
  )
  :effects (
   (vector-diagram (cons-angmom ?bodies (during ?t1 ?t2)))
  ))

; following should be filled in but no problem currently needs it:
#|
(defoperator draw-cons-angmom-split (?bodies ?t1 ?t2)
  :preconditions (
    (not (vector-diagram (cons-angmom ?bodies (during ?t1 ?t2))))
   ; only use this in case of a split
   (in-wm (rotation-change ?body-list (during ?t1 ?t2) split))
   )
  :effects (
   )
)
|#

(defoperator write-cons-angmom (?bodies ?t1 ?t2)
  :preconditions (
   ; don't use this in case of a join
   (not (rotation-change ?body-list (during ?t1 ?t2) join))
  ; apply single-body ang-momentum method for each to draw vectors and 
  ; generate compo equation for each body at initial and final times
  (map ?b ?bodies
     (eqn (= ?L1_z ?Iw_z) (compo-eqn z 0 (ang-momentum ?b ?t1)))
       ?Iw_z ?Iw_z1-terms)
  (map ?b ?bodies
     (eqn (= ?L1_z ?Iw_z) (compo-eqn z 0 (ang-momentum ?b ?t2)))
       ?Iw_z ?Iw_z2-terms)
  ; need to collect compos of all terms to list in final eqn-compos
  (map ?b ?bodies
       (eqn-compos (compo-eqn z 0 (ang-momentum ?b ?t1)) ?compos)
       ?compos ?t1-compo-sets) ; result is list of lists
  (map ?b ?bodies
       (eqn-compos (compo-eqn z 0 (ang-momentum ?b ?t2)) ?compos)
       ?compos ?t2-compo-sets)	; result is list of lists
  (bind ?all-compos (flatten (append ?t2-compo-sets ?t1-compo-sets)))
  )
  :effects (
  (eqn (= (+ . ?Iw_z1-terms) (+ . ?Iw_z2-terms))
       (compo-eqn z 0 (cons-angmom ?bodies (during ?t1 ?t2))))
  (eqn-compos 
       (compo-eqn z 0 (cons-angmom ?bodies (during ?t1 ?t2)))
       ?all-compos)
	   )
  :hint (
  (point (string "Can you write an equation relating the z components making up the total angular momentum before and after the change?"))
  (teach (string "The law of conservation of angular momentum states that if no external torque acts on a system, then the total angular momentum in the system remains constant. Because the total angular momentum is the vector sum of the angular momenta of each body in the system, this law entails that the sum of the z components of the angular momenta of each body is the same before and after any internal change such as change of shape, as long as there is no external torque."))
  (bottom-out (string "Write the equation ~A" 
                      ((= (+ . ?Iw_z1-terms) (+ . ?Iw_z2-terms)) algebra)))
  ))


; same as above for case of bodies joining together into compound
(defoperator write-cons-angmom-join (?bodies ?t1 ?t2)
  :preconditions (
   ; use this only in case of a join
   (in-wm (rotation-change ?body-list (during ?t1 ?t2) join))
  ; apply single-body ang-momentum method for each to draw vectors and 
  ; generate compo equation for each body at initial and final times
  ; initial time:
  (map ?b ?bodies
     (eqn (= ?L1_z ?Iw_z) (compo-eqn z 0 (ang-momentum ?b ?t1)))
       ?Iw_z ?Iw_z1-terms)
  ; need to save compos from all equations to list in final eqn-compos
  (map ?b ?bodies
       (eqn-compos (compo-eqn z 0 (ang-momentum ?b ?t1)) ?compos)
       ?compos ?t1-compo-sets) ; result is list of lists
  ; final time is the compound
  (bind ?c `(compound ,@?bodies)) ; for shorthand
  (eqn (= ?Lc_z ?Icw_z) (compo-eqn z 0 (ang-momentum ?c ?t2)))
  (bind ?bodies2 (list ?c))  ; to use same collecting code for t2
  (map ?b ?bodies2
       (eqn-compos (compo-eqn z 0 (ang-momentum ?b ?t2)) ?compos)
       ?compos ?t2-compo-sets)	; result is list of lists
  (bind ?all-compos (flatten (append ?t2-compo-sets ?t1-compo-sets)))
  )
  :effects (
  (eqn (= (+ . ?Iw_z1-terms) ?Icw_z)
       (compo-eqn z 0 (cons-angmom ?bodies (during ?t1 ?t2))))
  (eqn-compos 
       (compo-eqn z 0 (cons-angmom ?bodies (during ?t1 ?t2)))
       ?all-compos)
	   )
   :hint (
 (point (string "Can you write an equation relating the ~a components making up
 the total angular momentum before and after the change?" ((axis ?xyz ?rot) symbols-label)))
  (teach (string "The law of conservation of angular momentum states that if no external torque acts on a system, then the total angular momentum in the system constant. Because the total angular momentum is the vector sum of the angular momenta of each body in the system, this law entails that the sum of the angular momentum components in the z direction is the same before and after a collision."))
  (bottom-out (string "Write the equation ~A" 
                      ((= (+ . ?Iw_z1-terms) ?Icw_z) algebra)))	  
	  ))


;;===================== Torque and Net Torque =========================


;; Net torque psm -- for computing net torque on an object as sum of
;; torques produced by individual forces on parts of object.
;;
;; We also have a variant for computing the z component of net torque
;; since this is asked for in some of our problems.

(defoperator net-torque-zc-contains (?sought)
  :preconditions (
    (any-member ?sought (
                     ;(at (mag (net-torque ?b ?axis)) ?t)
		     ;(at (dir (net-torque ?b ?axis)) ?t)
		     (at (compo z 0 (net-torque ?b ?axis)) ?t)
		     ; for now, don't use to solve for individual torques:
		     ;(at  (mag (torque ?b ?axis ?force)) ?t)
		     ;(at  (dir (torque ?b ?axis ?force)) ?t)
                        ))
   ; make sure there aren't unknown forces, as in basic rotational kinematics
   ; problems with unexplained accelerations
   (not (unknown-forces))
   )
   :effects (
     (angular-eqn-contains (net-torque ?b ?axis ?t zc) ?sought)
   ))

(defoperator net-torque-contains (?sought)
  :preconditions (
    (any-member ?sought (
                     (at (mag (net-torque ?b ?axis)) ?t)
		     (at (dir (net-torque ?b ?axis)) ?t)
		     (at  (mag (torque ?b ?axis ?force)) ?t)
		     (at  (dir (torque ?b ?axis ?force)) ?t)
                        ))
   ; make sure there aren't unknown forces, as in basic rotational kinematics
   ; problems with unexplained accelerations
   (not (unknown-forces))
   )
   :effects (
     (angular-eqn-contains (net-torque ?b ?axis ?t) ?sought)
   ))

; draw an individual torque due to a force with at known direction
; acting on a point with a known relative position
(defoperator draw-torque (?b ?axis ?pt ?agent ?type ?t)
   :preconditions (
     (in-wm (part-of ?pt ?b))
     ;(force ?pt ?agent ?type ?t (dnum ?dir-f |deg|) action) 
     ; draw the force on the point of applicatin
     (vector ?pt (at (force ?pt ?agent ?type) ?t) (dnum ?dir-f |deg|))
     ; fetch the relative position vector and calculate torque direction
     (in-wm (given (at (dir (relative-position ?pt ?axis)) ?t) 
                   (dnum ?dir-r |deg|)))
     (bind ?torque-dir (torque-zdir ?dir-f ?dir-r))
     ; var name identifies force by point of application and agent alone
     (bind ?mag-var (format-sym "TOR_~A_~A_~A_~A" (body-name ?b) ?pt ?agent 
                                                 (time-abbrev ?t)))
     (bind ?dir-var (format-sym "O~A" ?mag-var))
     (debug "Drawing torque on ~A from force at ~A ~A plane~%" ?b ?pt ?torque-dir)
   )
   :effects (
     (vector ?b (at (torque ?b ?axis (force ?pt ?agent ?type)) ?t) ?torque-dir)
     (variable ?mag-var (at (mag (torque ?b ?axis (force ?pt ?agent ?type))) ?t))
     (variable ?dir-var (at (dir (torque ?b ?axis (force ?pt ?agent ?type))) ?t)) 

     (given (at (dir (torque ?b ?axis (force ?pt ?agent ?type))) ?t) ?torque-dir)
   )
   :hint (
    (point (string "Notice that there is a[n] ~A force acting at ~a ~A which might have a tendency to cause ~a to rotate about ~A."
                   (?type adj) ?pt (?t pp) ?b ?axis))
    (teach (string "A torque vector represents the tendency of a force acting on a rigid body to rotate the body about some axis. In Andes problems the torque vector will lie in the z axis, pointing in the positive direction (out of the plane of the diagram) for torques that tend to cause ccw rotations, and in the negative direction (into the plane) for torques that tend to cause cw rotations."))
    (bottom-out (string "Use the torque vector drawing tool (labelled $t) to draw the torque about ~a due to the force acting at ~A ~A and set the direction to point ~A" ?axis ?pt (?t pp) (?torque-dir adj)))
   ))

; For drawing net torque. Direction usually must be calculated, but first
; two operators apply for special cases:

; draw net torque if we have been given its direction
(defoperator draw-net-torque-known-dir (?b ?axis ?t)
 :preconditions (
     (in-wm (given (at (dir (net-torque ?b ?axis)) ?t) ?dir))
     ; var name identifies force by point of application and agent alone
     (bind ?mag-var (format-sym "NTOR_~A_~A_~A" (body-name ?b) ?axis 
                                                 (time-abbrev ?t)))
     (bind ?dir-var (format-sym "O~A" ?mag-var))
     (not (vector ?b (at (net-torque ?b ?axis) ?t) ?dontcare))
     (bind ?phi-value (zdir-phi ?dir))
   )
   :effects (
     (vector ?b (at (net-torque ?b ?axis) ?t) ?dir)
     (variable ?mag-var (at (mag (net-torque ?b ?axis)) ?t))
     (variable ?dir-var (at (dir (net-torque ?b ?axis)) ?t)) 
     (given (at (dir (net-torque ?b ?axis)) ?t) ?dir)
     ; Because dir is problem given, find-by-psm won't ensure implicit eqn
     ; gets written. Given value may not be used elsewhere so ensure it here.
     (implicit-eqn (= ?dir-var ?phi-value) (at (dir (net-torque ?b)) ?t))
   )
   :hint (
    (point (string "You were given the direction of the net torque on ~a about ~a ~a in this situation." ?b ?axis (?t pp)))
   (bottom-out (string "Use the torque vector drawing tool (labelled $t) to draw the net torque on ~a about ~a ~A and set the direction to point ~A" ?b ?axis (?time pp) (?dir adj))) 
   ))

; draw net torque if direction of angular acceleration known
; may be directly given or derivable from motion spec
; In some cases this is a cheat for where the direction is obvious because
; there is only one force, so we have given that the object's rotation is
; speeding up.
(defoperator draw-net-torque-from-ang-accel (?b ?axis ?t)
  :preconditions (
     (not (vector ?b (at (net-torque ?b ?axis) ?t) ?dontcare))
     (given (at (dir (ang-accel ?b)) ?t) ?dir)
     (test (not (equal ?dir 'unknown)))
     ; var name identifies force by point of application and agent alone
     (bind ?mag-var (format-sym "NTOR_~A_~A_~A" (body-name ?b) ?axis 
                                                 (time-abbrev ?t)))
     (bind ?dir-var (format-sym "O~A" ?mag-var))
   )
   :effects (
     (vector ?b (at (net-torque ?b ?axis) ?t) ?dir)
     (variable ?mag-var (at (mag (net-torque ?b ?axis)) ?t))
     (variable ?dir-var (at (dir (net-torque ?b ?axis)) ?t)) 
     (given (at (dir (net-torque ?b ?axis)) ?t) ?dir)
   )
  :hint (
    (point (string "You should be able to determine the direction of the angular acceleration of ~a ~a from the problem description. You can use that to determine the direction of the net torque." ?b (?t pp)))
     (teach (string "Newton's Second Law for rotation says that the net torque on an object is proportional to its angular acceleration. This is a vector relation, therefore the net torque will point in the same direction as the angular acceleration vector."))
   (bottom-out (string "Since the angular acceleration is known to be directed ~A, use the torque vector drawing tool (labelled $t) to draw the net torque on ~a about ~a ~A and set the direction to point ~A" (?dir adj) ?b ?axis (?time pp) (?dir adj))) 
   ))

; draw zero net torque if object given in rotational equilibrium
; we specify this with a given value of 0 for net torque.
(defoperator draw-net-torque-non-rotating (?b ?axis ?t)
  :preconditions (
     (not (vector ?b (at (net-torque ?b ?axis) ?t) ?dontcare))
     ; NB: must be plain number, not dnum
     (in-wm (given (at (mag (net-torque ?b ?axis)) ?t) 0))
     ; var name identifies force by point of application and agent alone
     (bind ?mag-var (format-sym "NTOR_~A_~A_~A" (body-name ?b) ?axis 
                                                 (time-abbrev ?t)))
   )
   :effects (
     (vector ?b (at (net-torque ?b ?axis) ?t) zero)
     (variable ?mag-var (at (mag (net-torque ?b ?axis)) ?t))
     ; put out implicit equation for given
     (implicit-eqn (= ?mag-var 0) (given (at (mag (net-torque ?b ?axis)) ?t)))
   )
   :hint (
     (point (string "Notice that you were told that ~A is in rotational equilibrium ~A. That should tell you something about the net torque." ?b (?t pp)))
     (teach (string "A rigid object is said to be in rotational equilibrium if the net torque from all external forces acting on it is zero, so it has no tendency to rotate."))
    (bottom-out (string "Since the object is in rotational equilibrium, use the torque vector drawing tool (labelled $t) to draw a zero length vector representing the net torque on ~a about ~a ~A." ?b ?axis (?t pp) (?dir adj))) 
   ))

; following draws the net torque vector on a body at an unknown direction
; We presume it is unknown until torques from all forces are computed and summed
; Later we will add operators to draw it at a determinate direction if that can
; be determined easily from the givens, e.g. if all given forces torque in 
; same direction.
(defoperator draw-net-torque-unknown-dir (?b ?axis ?t)
  :preconditions (
     ; apply when none of above known dir ops apply:
     ; not just given dir:
     (not (given (at (dir (net-torque ?b ?axis)) ?t) ?given-dir))
     ; not given ang-accel dir
     (not (given (at (dir (ang-accel ?b)) ?t) ?dir))
     ;     and dir(ang-accel) not derivable from motion
     (not (motion ?b ?t-motion (rotating ?axis ?rotate-dir ?accel-spec))
          (and (not (eq ?rotate-dir 'unknown))
	       (or (eq ?accel-spec 'speed-up)
	           (eq ?accel-spec 'slow-down))))
     ; not known in rotational equilibrium:
     (not (given (at (mag (net-torque ?b ?axis)) ?t) 0))
     ; can't determine as torque due to magnetic field (see forces.cl)
     (not  (given (at (dir (dipole-moment ?b)) ?t) ?dir-mu))
     ; var name identifies force by point of application and agent alone
     (bind ?mag-var (format-sym "NTOR_~A_~A_~A" (body-name ?b) ?axis 
                                                 (time-abbrev ?t)))
     (bind ?dir-var (format-sym "O~A" ?mag-var))
     (not (vector ?b (at (net-torque ?b ?axis) ?t) ?dontcare))
   )
   :effects (
     (vector ?b (at (net-torque ?b ?axis) ?t) z-unknown)
     (variable ?mag-var (at (mag (net-torque ?b ?axis)) ?t))
     (variable ?dir-var (at (dir (net-torque ?b ?axis)) ?t)) 
   )
   :hint (
     (point (string "You need to introduce a term for the net torque on ~a ~a" ?b (?t pp)))
     (teach (string "The net torque on a rigid body will represent the tendency of the body to rotate cw or ccw by a vector along the z axis in accordance with the right hand rule. Although you know the net torque vector lies along the z axis, it requires calculation to determine whether it points into or out of the plane. Therefore you should specify its direction as Unknown Z direction in the dialog box after drawing it."))
     (bottom-out (string "Use the torque vector drawing tool (labelled $t) to draw a non-zero net torque vector on ~A about ~a ~A, seelecting \"Unknown Z direction\" from the direction menu in the dialog box." ?b ?axis (?t pp)))
   ))


(defoperator draw-all-torques (?b ?axis ?t)
   :specifications 
    "If there are any torques on ?body at ?time,
     then make them the set of torques on ?body at ?time"
   :preconditions
   ((body ?b ?t)
    ; draw all individual torques we can find
    (setof (vector ?b (at (torque ?b ?axis ?force) ?t) ?dir) 
	   (torque ?b ?axis ?force) 
	   ?torques))
   :effects
    ((torques ?b ?axis ?t ?torques)))

(defoperator draw-net-torque-diagram (?b ?axis ?t)
  :preconditions (
   ; draw all torques due to each force
   (torques ?b ?axis ?t ?torques)
   ; draw net torque on object 
   (vector ?b (at (net-torque ?b ?axis) ?t) ?dir)
   (axis-for ?b ?t z 0)
   ; define for zc form only:
   ; (variable ?tnet_z (at (compo z 0 (net-torque ?b ?axis)) ?t)) 
  )
  :effects (
    (vector-diagram (net-torque ?b ?axis ?t))
    (vector-diagram (net-torque ?b ?axis ?t zc))
  ))

;; following draws torque diagram for qualititative problems that ask for 
;; all torques only.  This shows a body and all torques on it. 
;; We make axes optional here. Counterpart to draw-standard-fbd
(defoperator draw-torque-fbd (?b ?axis ?t)
   :preconditions 
           ((body ?b ?t)
	    (torques ?b ?axis ?t ?forces)
	    (optional (axis-for ?b ?t z 0)))
   :effects ((torque-fbd ?b ?axis ?t)))

; generate equation for net torque:
; Tnet_z = Tau1_z + Tau2_z + Tau3_z
;
; The generic projection operator plugs in
;    magTau * cos (0Tau_z) for Tau_z, where cos (0Tau_z) = +/- 1
; We might like to use torque mag formula
;    magR * magF * sin (ThetaRF)  for magTau1
; and plug these terms in final equation for net torque. But that would 
; preclude using the generic operators for writing a component equation then
; for moving from component eqns to compo-free eqns by plugging in projections.
; We would have to plug in projections first then plug in magnitude expressions.
; For now we just enter equations for mag of individual torques as separate in 
; bubble graph. 

;
; net-torque zc is a special case form for zcomponent if zc-form flag is set.
; It doesn't plug in projection for zc. This is for use when sought is zc of
; net torque.

(defoperator write-net-torque-zc (?b ?axis ?t)
  :preconditions (
   (in-wm (zc-form))
   ; fetch list of individual torques, extracting list of forces
   (in-wm (torques ?b ?axis ?t ?torques))
   (bind ?forces (mapcar #'fourth ?torques))
   ; define component variables for each of the contributing torques
   (map ?force ?forces
      (variable ?ti_z (at (compo z 0 (torque ?b ?axis ?force)) ?t))
      ?ti_z ?torque-compos) 
   (debug "net torque components: ~A~%" ?torque-compos)
   ; define zc net torque variable 
   (variable ?tnet_z (at (compo z 0 (net-torque ?b ?axis)) ?t))
   ; for algebraic completeness: write projection equation for net torque 
   ; to determine values of mag or dir.
   ; (eqn ?tnet_projection (projection ?tnet_z))
   ; fetch mag variable for implicit equation (defined when drawn)
   (in-wm (variable ?mag-var (at (mag (net-torque ?b ?axis)) ?t)))
  )
  :effects (
   (eqn (= ?tnet_z (+ . ?torque-compos)) 
        (compo-eqn z 0 (net-torque ?b ?axis ?t zc)))
   ; need to list eqn-compos so projections get plugged in for component 
   ; torques.  Don't do this for net torque however, just leave it as z-comp.
   (eqn-compos (compo-eqn z 0 (net-torque ?b ?axis ?t zc))  ?torque-compos)
   ; for algebraic completeness: put out equation for mag torque 
   ; in terms of component, so gets determined from tau_z if dir is unknown
   (implicit-eqn (= ?mag-var (abs (?tnet_z))) 
                 (at (mag (net-torque ?b ?axis)) ?t))
  )
  :hint (
    (point (string "Can you write an equation for the z component of the net torque in terms of the z components of the torques due to each force?"))
    (teach (string "The net torque on a rigid body is the vector sum of the individual torques due to each force acting on that body. Therefore the z component of the net torque is the sum of the z components of the torque dues to each force."))
    (bottom-out (string "Write the equation ~A" 
          ((= ?tnet_z (+ . ?torque-compos)) algebra)))
  ))

; net-torque zc writes equation for zcomponent if zc-form flag is set.
;
; Following is more standard compo-eqn, which also asks for projection for 
; net torque. For use when dir is known. This can now be used with generic
; component-form flag as well, so zc-form special case is sort of unnecessary.
(defoperator write-net-torque (?b ?axis ?t)
  :preconditions (
   (not (zc-form))
   ; fetch list of individual torques, extracting list of forces
   (in-wm (torques ?b ?axis ?t ?torques))
   (bind ?forces (mapcar #'fourth ?torques))
   ; define component variables for each of the contributing torques
   (map ?force ?forces
      (variable ?ti_z (at (compo z 0 (torque ?b ?axis ?force)) ?t))
      ?ti_z ?torque-compos) 
   (debug "net torque components: ~A~%" ?torque-compos)
   ; define zc net torque variable 
   (variable ?tnet_z (at (compo z 0 (net-torque ?b ?axis)) ?t))
   (bind ?all-compos (cons ?tnet_z ?torque-compos))
  )
  :effects (
   (eqn (= ?tnet_z (+ . ?torque-compos)) 
               (compo-eqn z 0 (net-torque ?b ?axis ?t)))
   (eqn-compos (compo-eqn z 0 (net-torque ?b ?axis ?t)) ?all-compos)
  )
  :hint (
   (point (string "Can you write an equation for the z component of the net torque in terms of the z components of the torques due to each force?"))
    (teach (string "The net torque on a rigid body is the vector sum of the individual torques due to each force acting on that body. Therefore the z component of the net torque is the sum of the z components of the torque dues to each force."))
    (bottom-out (string "Write the equation ~A" 
          ((= ?tnet_z (+ . ?torque-compos)) algebra)))
  ))

;
; mag-torque: scalar equation for magnitude of an individual torque
;

(defoperator mag-torque-contains (?sought)
   :preconditions (
   (any-member ?sought (
                  (at (mag (torque ?b ?axis (force ?pt ?agent ?type))) ?t)
		  (at (mag (force ?pt ?agent ?type)) ?t)
		  (at (mag (relative-position ?pt ?axis)) ?t)
                  (angle-between (at (force ?pt ?agent ?type) ?t)
		                 (at (relative-position ?pt ?axis) ?t))
		  ; doesn't exactly contain directions of relative position
		  ; and force, only difference between these
                       ))
   ; So far this will apply in any problem where any force is sought. 
   ; Require pt of application to be part of larger rigid body, so that
   ; won't apply if dealing only with particles. 
   (part-of ?pt ?b)
   ; !!! if sought is not torque, e.g. a force on body part, have to choose 
   ; an axis on body about which to consider torque.  In theory the torque about
   ; an axis is defined for any point on the object, but if it's fixed at a
   ; pivot or known to be rotating we should pick that axis.
   ; So might want rotation-axis statement ala CLIPs to tell this. 
   (rotation-axis ?b ?axis)
   )
   :effects ((eqn-contains (mag-torque ?b ?axis (force ?pt ?agent ?type) ?t) ?sought)))

(defoperator write-mag-torque (?b ?axis ?pt ?agent ?type ?t)
   :preconditions (
      (variable ?tau-var (at (mag (torque ?b ?axis (force ?pt ?agent ?type))) ?t))
      (variable ?f-var   (at (mag (force ?pt ?agent ?type)) ?t))
      (variable ?r-var   (at (mag (relative-position ?pt ?axis)) ?t))
      (variable ?theta-var (angle-between (at (force ?pt ?agent ?type) ?t) 
                                          (at (relative-position ?pt ?axis) ?t)))
   )
   :effects (
      (eqn (= ?tau-var (* ?r-var ?f-var (sin ?theta-var))) 
             (mag-torque ?b ?axis (force ?pt ?agent ?type) ?t))
   )
   :hint (
   (point (string "You need an expression for the magnitude of the torque due to the ~A force acting at ~A" (?type adj) ?pt))
   (teach (string "The magnitude of the torque $t resulting from a force of magnitude F acting at a point of perpendicular distance r from the axis is given by $t = r * F * sin ($q), where $q is the smaller of two angles between the vectors r and F."))
   (bottom-out (string "Write the equation ~A" 
               ((= ?tau-var (* ?r-var ?f-var (sin ?theta-var))) algebra)))
   ))
   

;
; torque-zc: equation for individual torque z-component
;  tau_z = F*r*sin(thetaF - thetaR)
;

(defoperator torque-zc-contains (?sought)
  :preconditions (
    (any-member ?sought ( 
             (at (compo z 0 (torque ?b ?axis (force ?pt ?agent ?type))) ?t)
             (at (mag (force ?pt ?agent ?type)) ?t)
             (at (dir (force ?pt ?agent ?type)) ?t)
	     (at (mag (relative-position ?pt ?axis)) ?t)
	     (at (dir (relative-position ?pt ?axis)) ?t)
	                ))
   ; So far this will apply in any problem where any force is sought. 
   ; Require pt of application to be part of larger rigid body, so that
   ; won't apply if dealing only with particles. 
   (part-of ?pt ?b)
   ; if sought is not torque, e.g. a force on body part, have to choose 
   ; an axis on body about which to consider torque.  In theory the torque about
   ; an axis is defined for any point on the object, but if it's fixed at a
   ; pivot or known to be rotating we should pick that axis.
   (rotation-axis ?b ?axis)
   )
 :effects (
    (eqn-contains (torque-zc ?b ?axis (force ?pt ?agent ?type) ?t) ?sought)
  ))

(defoperator write-torque-zc (?b ?axis ?pt ?agent ?type ?t)
  :preconditions (
      (variable ?tau-zc (at (compo z 0 (torque ?b ?axis (force ?pt ?agent ?type))) ?t))
      (variable ?f-var      (at (mag (force ?pt ?agent ?type)) ?t))
      (variable ?theta-f    (at (dir (force ?pt ?agent ?type)) ?t))
      (variable ?r-var      (at (mag (relative-position ?pt ?axis)) ?t))
      (variable ?theta-r    (at (dir (relative-position ?pt ?axis)) ?t))
   )
   :effects (
      (eqn (= ?tau-zc (* ?r-var ?f-var (sin (- ?theta-f ?theta-r)))) 
             (torque-zc ?b ?axis (force ?pt ?agent ?type) ?t))
   )
   :hint (
   (point (string "You need an expression for the z component of the torque due to the ~A force acting at ~A" (?type adj) ?pt))
   (teach (string "The z component of the torque $t resulting from a force of magnitude F acting at a point of perpendicular distance r from the axis can be calculated as $t_z = r * F * sin ($qF - $qr) where $qF and $qr are the orientations of the vectors F and r ."))
   (bottom-out (string "Write the equation ~A" 
          ((= ?tau-zc (* ?r-var ?f-var (sin (- ?theta-f ?theta-r)))) algebra)))
  ))

; num-torques mainly for test problems:
(defoperator num-torques-contains (?b ?t)
  :preconditions ()
  :effects ( (eqn-contains (num-torques ?b ?axis ?t) (at (num-torques ?b ?axis) ?t)) ))

(defoperator write-num-torques (?b ?axis ?t)
  :preconditions 
   ((torques ?b ?axis ?t ?torques)
    (bind ?count (length ?torques))
    (variable ?n-var (at (num-torques ?b ?axis) ?t)) )
  :effects 
  ( (eqn (= ?n-var ?count) (num-torques ?b ?axis ?t)) ))
 
(defoperator define-num-torques (?b ?axis ?t)
   :preconditions 
   ((bind ?n-var (format-sym "ntorques_~A_~A" (body-name ?b) (time-abbrev ?t))))
   :effects 
   ( (variable ?n-var (at (num-torques ?b ?axis) ?t)) ))

; following lets us avoid declaring parts of rigid bodies as objects.
; we define forces as acting on parts.
; parts must be objects to be used in force drawing rules.
(defoperator use-part-as-object (?part ?whole)
   :preconditions 
    ((in-wm (part-of ?part ?whole))
     (in-wm (object ?whole))
     (not (object ?part)))
   :effects ( (object ?part) ))

;;
;; NSL for rotation tau_net = I * alpha
;;
;; !!! Need special handling of case where alpha = 0 here, 
;; parallel to NFL version of NL -- can't use this to find I in this
;; case because rhs vanishes.

(defoperator NL-rotation-contains (?sought)
   :preconditions (
   (any-member ?sought (
              (at (mag (ang-accel ?b)) ?t)
              (at (dir (ang-accel ?b)) ?t)
	      (at (compo z 0 (net-torque ?b ?axis)) ?t) 
	      ;(at (mag (net-torque ?b ?axis)) ?t) 
	      ;(at (dir (net-torque ?b ?axis)) ?t) 
	      (at (moment-of-inertia ?b) ?t)
	               ))
   ; need to determine rotation axis if not seeking torque
   (rotation-axis ?b ?axis)
   )
   :effects (
     (angular-eqn-contains (NL-rot ?b ?axis ?t) ?sought)
   ))

(defoperator draw-NL-rot-diagram (?b ?axis ?t)
    :preconditions (
      (not (vector-diagram (NL-rot ?b ?axis ?t)))
      ;(body ?b ?t)
      (torques ?b ?axis ?t ?torques)
      (vector ?b (at (net-torque ?b ?axis) ?t) ?dir)
      (vector ?b (at (ang-accel ?b) ?t) ?dir-accel)
      (axis-for ?b ?t z 0)
    )
    :effects (
      (vector-diagram (NL-rot ?b ?axis ?t))
    ))

(defoperator write-NL-rotation (?b ?axis ?t)
   
   :preconditions (
     (variable ?tau_z   (at (compo z 0 (net-torque ?b ?axis)) ?t))
     (variable ?I       (at (moment-of-inertia ?b) ?t))
     (variable ?alpha_z (at (compo z 0 (ang-accel ?b)) ?t))
     ; fetch mag variable for implicit equation (defined when drawn)
     (in-wm (variable ?mag-var (at (mag (ang-accel ?b)) ?t)))
   )
   :effects (
     (eqn (= ?tau_z (* ?I ?alpha_z)) 
                 (compo-eqn z 0 (NL-rot ?b ?axis ?t)))
     (eqn-compos (compo-eqn z 0 (NL-rot ?b ?axis ?t)) (?tau_z ?alpha_z))
; Don't do this because it can pre-empt projection if it is in fact used
; on a component-form problem for magnitude (Extor5a)
     ; for algebraic completeness: put out equation for mag ang-accel
     ; in terms of component, so gets determined from alpha_z if dir is unknown
     ; (implicit-eqn (= ?mag-var (abs (?alpha_z))) (at (mag (ang-accel ?b)) ?t))
   )
   :hint (
    (point (string "Can you relate the z components of net torque and angular acceleration?"))
    (teach (string "Just as Newton's Second Law says that Fnet = m*a, Newton's Law for rotation states that the net torque on an object equals the object's moment of inertia times its angular acceleration. This vector relation can be applied along the z axis to relate the z-components of net torque and angular acceleration."))
    (bottom-out (string "Write Newton's Law for rotation in terms of component variables along the z axis, namely ~A." 
                        ((= ?tau_z (* ?I ?alpha_z)) algebra)))
   ))

