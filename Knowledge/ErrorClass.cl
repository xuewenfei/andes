;;; Defines the struct and the macro for defining error classes, which
;;; appear in errors.cl and are interpreted by whatswrong.cl

(defvar **entry-tests**)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  One may want to still return a hint even in a case with a correct match.
;;     "This is correct, but you are being a little sloppy with your drawing."
;;  Also, one often has matching system entries for an incorrect student
;;  entry.  Currently, this is assumed to be determined by the last
;;  successful (correct ...) or (fix-eqn-by-replacing ...) match.
;;  Thus, correct returns only a Boolean value.
;;

(defstruct entry-test
  Name        ;atom
  Conditions  ;ordered list of conditons (see whatswrong.cl)
  apply       ;Conditions of application
					;no-match:  use after no match found
					;match:  use after match found
					;nil:  always apply
  correct         ;boolean for match.  Match contained in last match
					; with (correct ...)
  hint            ;Lisp evaluable form giving resulting hint sequence
					;to replace function call
  order           ;List of dotted pairs giving order specification
  )

(defun clear-entry-tests ()
  (setf **entry-tests** nil))

(defmacro def-Error-Class (name arguments conditions &key (Probability 0.1) (Utility 1.0))
  `(push (make-entry-test :name (quote ,name)
			   :conditions (quote ,conditions)
			   :apply 'no-match
			   :correct nil  ;never matches for errors
			   :hint (quote ,(cons name arguments))
			   :order (quote ((probability ,@probability) 
				    (utility ,@utility)))
			   )
	 **entry-tests**))

;;;
;;;   More general utility to perform tests
;;;


(defmacro def-entry-test (name &key conditions apply correct hint
			       (order '((global 1))))
  (when (find name **entry-tests** :key #'entry-test-name)
    (error "entry test ~A already exists." name))
  (let ((e (make-entry-test :name name
			    :conditions conditions  
			    :apply apply
			    :correct correct
			    :hint `(make-hint-seq ,hint) 
			    :order order
			    )))
    (push e **entry-tests**)
    t))
