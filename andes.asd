;;;; -*- Lisp -*-
;;;; above sets emacs major mode to Lisp
;;;;
;;;;  Use this to compile:
;;;;  (asdf:operate 'asdf:load-op 'andes)
;;;;

;;;; This was stolen from maxima.asd
#+(or sbcl openmcl)
(or (find-package "USER")
    (rename-package "COMMON-LISP-USER" "COMMON-LISP-USER" '("USER")))
(in-package :user)
(in-package :asdf) 

(defsystem :andes
  :name "Andes"
  :description "Andes physics tutor system"
  :components (
	       (:module "Base"
;			:description "Common Utilities"
			:components ((:file "Htime")
				     (:file "Unification")
				     (:file "Utility")))
	       (:module "Solver_Release"
			:components ((:file "solver")))
	       (:module "Knowledge"
			:depends-on ("Base" "Solver_Release")
			:components ((:file "eqn")         
				     (:file "Nogood")    
				     (:file "Operators")  
				     (:file "qvar")
				     (:file "BubbleGraph")  
				     (:file "ErrorClass")  
				     (:file "Ontology")  
				     (:file "Problem")    
				     (:file "Solution")))	       
	       (:module "KB"
;			:description "Knowledge Base"
			:depends-on ("Knowledge" "Base")
			:components ((:file "Physics-Funcs")
				     (:file "Newtons2")        
				     (:file "Problems")   
;;;;
;;;; The remaining files are just needed for the help system???
;;;;
#|				     (:file "errors")
				     (:file "NewtonsNogoods")  
				     (:file "psm-list")
				     (:file "force-problems")  
				     (:file "Ontology")        
				     (:file "PyreneesProblems")
				     (:file "circuit-ontology")  
				     (:file "forces")          
				     (:file "optics")          
				     (:file "vectors")
				     (:file "circuit-problems")  
				     (:file "makeprob")        
				     (:file "vectors-problems")
				     (:file "circuits")
|#
))
	       (:module "SGG"
;			:description "Solution Graph Generator"
			:depends-on ("Base" "Knowledge")
			:components ((:file "Qsolver")
				     (:file "Exec")       
				     (:file "Macros")         
				     (:file "SolutionPoint")
				     (:file "GraphGenerator") 
				     (:file "ProblemSolver")
				     (:file "SolutionSets")))
#|	       	       (:module "Help"
			:components ((:file "utilities")
				     (:file "lrdc-errors")
				     (:file "History")
				     (:file "StudentFile")
				     (:file "tell") ; tracing tool
				     
				     ;; Solution graph
				     (:file "SolutionGraph")
				     
				     ;; Entry Intepreter: generic + non-eq
				     (:file "symbols")
				     (:file "State")
				     (:file "clips-vars")
				     (:file "Entry-API")
				     
				     ;; Equation parser/interpreter
				     (:file "grammar")
				     (:file "physics-algebra-rules")
				     (:file "parse")
				     (:file "pre2in")
				     (:file "in2pre")
				     (:file "parse-andes")
				     (:file "interpret-equation")
				     
				     ;;  Help
				     (:file "HelpMessages")
				     (:file "whatswrong")
				     (:file "NextStepHelp")
				     (:file "IEA")
				     (:file "nlg") ; Natural language.
				     
				     ;; Automatic statistics code.
				     (:file "Statistics")
				     
				     ;; Top-level manager
				     (:file "Interface") ; The interface api.
				     (:file "Commands")
				     (:file "API")
				     (:file "Andes2-Main")))
|#
	       ))
;;;;
;;;;  make source file extension "cl"  See asdf manual
;;;;

(defmethod source-file-type ((c cl-source-file) (s (eql (find-system :andes))))
   "cl")
