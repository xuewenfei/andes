;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Eqn.cl
;; Collin Lynch
;; 2/7/2001
;;
;; This file defines the Bubblegraph data structures for the 
;; Andes2 help system.  The structures themselves are generated by the
;; code located in sgg/GraphGenerator.cl  This code has been located
;; here to facilitate its use by other parts of the help system.
;;
;; A bubblegraph itself is a list of the form 
;; (<Qnodes> <Enodes> <Vars> <Eqns>) where: 
;; 

;;==============================================================
;; Equation structs are used to catalog the equation elements
;; in a system.
  
(defstruct (eqn (:print-function print-eqn))
  index
  Type	   ;One of Eqn, Given-Eqn, Derived-Eqn  
  Algebra
  Exp
  Nodes
  Solved)  ;if t then this equation has been solved.

(defun print-eqn (Eqn &optional (Stream t) (Level 0))
  "Print out an eqn as a list."
  (pprint-Indent :block Level)
  (format Stream "~A" 
	  (list 'eqn (Eqn-Index Eqn) (Eqn-Type Eqn) (Eqn-Algebra Eqn) 
		(Eqn-Exp Eqn) (Eqn-Nodes Eqn) (Eqn-Solved Eqn))))

(defun print-mreadable-eqn (Eqn &optional (Stream t) (Level 0))
  "Print out an eqn as a list."
  (pprint-Indent :block Level)
  (format Stream "(Eqn ~W" (Eqn-Index Eqn))
  (format Stream " ~W" (Eqn-Type Eqn))
  (format Stream " ~W" (Eqn-Algebra Eqn))
  (format Stream " ~W" (Eqn-Exp Eqn)) 
  (format Stream " ~W" (collect-nodes->gindicies (Eqn-Nodes Eqn)))
  (format Stream " ~W)~%" (Eqn-Solved Eqn)))


(defun print-mreadable-eqns (E S)
  "Print the specified Eindex E in mreadable form."
  (format S "(")
  (dolist (Eq E)
    (print-mreadable-eqn Eq S))
  (format S ")~%"))


(defun read-mreadable-eqns (S G)
  "Read in an Mreadable Eindex associated with Bubblegraph G."
  (loop for E in (read S "Malformed Eqns file")
      collect (EqnList->Eqn E G)))

(defun Eqnlist->Eqn (L Graph)
  "Given a list of an eqn generate an eqn struct from it."
  (make-eqn :Index (nth 1 L)
	    :Type (nth 2 L)
	    :Algebra (nth 3 L)
	    :Exp (nth 4 L)
	    :nodes (collect-gindicies->nodes (nth 5 L) Graph)
	    :Solved (nth 6 L)))

(defun eqns-equalp (X Y)
  "Determine if the two eqns are equalp."
  (when (unify (eqn-Exp X) (Eqn-Exp Y))
    (when (not (equal (eqn-Algebra X) (eqn-Algebra Y))) ;sanity check
      (error "eqns-equalp:  same Eqn-Exp but different algebra:~%     ~A~%     ~A~%" 
	      X Y))
    (when (not (eql (eqn-type X) (eqn-type Y))) ;sanity check
      (format t "!!! eqns-equalp:  same Eqn-Exp but different type:~%     ~A~%     ~A~%" 
	      X Y))
    (eql (eqn-type X) (eqn-type Y))))

;;; make-qsolver-eqn
;;; As Eqns come out of the qsolver they consist of lists that
;;; need to be modified.  This code takes those eqn list of
;;; the form (<Type> <Algebra> <ID>) and generates eqn strcuts
;;; from them.
(defun make-qsolver-eqn (QE)
  "Convert QE to an eqn."
  (make-eqn :type (car QE)
	    :Algebra (nth 1 QE)
	    :Exp (Nth 2 QE)))

(defun collect-qsolver-eqns (QEqns)
  "Collect the eqns for the specified Qsolver eqns."
  (loop for Q in Qeqns
      collect (make-qsolver-eqn Q)))

;;-----------------------------------------------------------------
;; use functions.

(defun gen-eqn (Type Algebra Expression Nodes)
  "Generate a new eqn."
  (when (null nodes) (error "gen-eqn expects non-null nodes~%"))
  (make-eqn :Type Type
	    :Algebra Algebra
	    :exp Expression
	    :Nodes Nodes))


(defun merge-duplicate-eqns (Eqns)
  "Iterate through the list merging duplicate eqns."
  (let ((R (list (car Eqns))) tmp)
    (dolist (E (cdr Eqns))
      (cond ((setq tmp (find-exp->eqn (Eqn-exp E) R))
	     (merge-eqns E tmp))
	    (t (push E R))))
    R))


;;; Equation merging can take place in two ways.
;;; Firstly if the equations are equalp (including type)
;;; then the nodes lists are unioned and set into the
;;; second eqn.  If the equations differ only in type
;;; then the system will test if they can be merged.
;;;
;;; If the eqns cannot be merged then an error is returned.
(defun merge-eqns (E1 E2)
  "Merge Eqn 1 into Eqn 2."
  (cond ((eqns-equalp E1 E2)                           
	 (setf (Eqn-Nodes E2)
	   (union (Eqn-Nodes E2) (Eqn-Nodes E1))))
	;; equations have different types
	((merge-eqn-types (Eqn-Type E1) (Eqn-Type E2))
	 (format t "!!! merge-eqns merging different types:~%   ~A~%    ~A~%" 
		 E1 E2)
	 (setf (Eqn-Type E2)
	   (merge-eqn-types (Eqn-Type E1) (Eqn-Type E2)))
	 (setf (Eqn-Nodes E2)
	   (union (Eqn-Nodes E2) (Eqn-Nodes E1))))

	(t (error "Two ~A eqns don't match:~%~A~%~A~%" 
		  (Eqn-exp E1) E1 E2))))


;;  This tells us which equation types can actually be merged
(defun merge-eqn-types (T1 T2)
  "If the two equation types can be merged, return merged type."
  (let ((m1 '(Implicit-Eqn Given-Eqn))
	(m2 '(Implicit-Eqn Eqn)))
    (cond 
     ;; merge Implicit-Eqn and Given-Eqn into Implicit-Eqn
     ((and (member T1 m1) (member T2 m1)) 'Implicit-Eqn)
     ;; merge Implicit-Eqn and Eqn into Implicit-Eqn
     ((and (member T1 m2) (member T2 m2)) 'Implicit-Eqn)
     (t nil))))


(defun eqns->Algebra (Eqns)
  "Collect the algebra elements out of a list of eqns."
  (loop for E in Eqns
      collect (Eqn-Algebra E)))


(defun mark-unsolved-eqns (Uvars Eqns)
  "Given the list of equations mark those that contain unsolved vars."
  (loop for E in Eqns
      when (loop for V in Uvars
	       when (contains-sym (Eqn-Algebra E) (Qvar-var V))
	       return t)
      do (setf (Eqn-Solved E) nil)
      else do (setf (Eqn-Solved E) t))
  Eqns)
			     


(defun collect-solved-eqns (Eqns)
  "Get the solved equations from the list."
  (loop for E in Eqns
      when (Eqn-Solved E)
      collect E))

(defun collect-unsolved-eqns (Eqns)
  "Get the solved equations from the list."
  (loop for E in Eqns
      unless (Eqn-Solved E)
      collect E))

(defun eqns->IndyEqns (Eqns)
  (push-index
   (loop for E in Eqns
       when (Eqn-Solved E)
       collect (list (Eqn-Algebra E)))))

(defun eqns->Help-Sys-Eqns (Eqns)
  (push-index
   (loop for E in Eqns
       when (and (not (eq (eqn-type E) 'Derived-eqn))
		 (Eqn-Solved E))
       collect (list (Eqn-Algebra E)))))

(defun list-base-eqns (Eqns)
  "Collect the list of all base eqns."
  (loop for E in Eqns
      when (not (eq (Eqn-Type E) 'Derived-Eqn))   ;; IE Eqn, Given Eqn and Implicit-Eqn.
      collect E))


;;; Return t iff the specified equation's algebra contains
;;; the specified element be it list or atom.
(defun eqn-algebra-contains? (Elt Eqn &key (test #'equal))
  "Return t iff the equation algebra contains the specified element."
  (recursive-member Elt (eqn-algebra Eqn) :test Test))
  

;;-----------------------------------------------------------------
;; Equation Index.

(defun Index-eqn-list (Eqns)
  "Set the equation indicies in the list."
  (dotimes (N (length Eqns))
    (setf (Eqn-Index (nth N Eqns)) N))
  Eqns)

(defun find-algebra->eqn (Alg Eqns)
  "Find the eqn that matches Algebra."
  (find Alg Eqns :key #'eqn-Algebra :test #'equal))

(defun find-exp->eqn (Exp Eqns)
  "Obtain the Eqn that is connected to the Exp supplied."
  (find Exp Eqns :key #'Eqn-Exp :test #'unify))



(defun collect-indicies->eqns (Indicies Eqns)
  "Given a list of indicies and a list of vars collect the specified vars."
  (loop for I in Indicies
      collect (collect-index->eqn I Eqns)))


(defun collect-index->eqn (I Eqns)
  "Given a list of indicies and a list of vars collect the specified vars."
  (let ((eqn (nth I eqns)))
    (when (null eqn) (error "Index i=~A larger than ~A eqns~%" 
			    i (length eqns)))
    (when (not (= I (Eqn-Index eqn)))
      (error "Incompatible variable index ~A ~A" I Eqns))
    eqn))

(defun collect-algebra->eqns (Equations Eqns)
  (loop for E in Equations
      when (find-algebra->eqn (second E) Eqns)
      collect it
      else do (error "Unrecognized Equation ~A supplied." E)))
  


;;; Given an element and a list of equations collect all those
;;; eqns in the list that contain the specified element.
(defun collect-eqn-algebra-contains? (Elt Eqns &key (test #'equal))
  "Return t iff the equation algebra contains the specified element."
  (remove-if-not
   #'(lambda (E) (recursive-member Elt (eqn-algebra E) :test Test))
   Eqns))



;;; In order to facilitate contact between the algebra
;;; system and the help system it is useful to sort the 
;;; eqn index by type.
(defun sort-eqn-list (Eqns)
  "Sort the list of eqns for use."
  (sort Eqns #'eqn-sort-comp))

;;; Hack that should be located else where in ontology say.
(defun eqn-sort-comp (e1 e2)
  "Compare e1 and e2 t if e1 < e2."
  (or (and (eql (eqn-type e1) (eqn-type e2))
	   (or (and (eqn-solved e1) (eqn-solved e2))
	       (and (eqn-solved e1) (not (eqn-solved e2)))))
      
      (eq (eqn-type e2) 'implicit-eqn)
      
      (and (eq (eqn-type e2) 'derived-eqn)
	   (not (eq (eqn-type e1) 'implicit-eqn)))
      
      (and (eq (eqn-type e2) 'eqn)
	   (eq (eqn-type e1) 'given-eqn))))

  
;;----------------------------------------------------
;; compare eqn indicies

(defun eqn-indicies-equalp (I1 I2)
  "Are the two indicies equalp?"
  (null (set-exclusive-or I1 I2 :test #'eqns-ni-equalp)))

(defun eqns-ni-equalp (e1 e2)
  "Are the two qvars equal but for their index."
  (and (unify (eqn-type e1) (eqn-type e2))
       (unify (eqn-algebra e1) (eqn-algebra e2))
       (unify (eqn-exp e1) (eqn-exp e2))
       (unify (eqn-solved e1) (eqn-solved e2))
       (equal-sets (mapcar #'bgnode-exp (eqn-Nodes e1))
		    (mapcar #'bgnode-exp (eqn-Nodes e2)))))
