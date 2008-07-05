;;;;
;;;;       list of PSMclasses grouped into catagories
;;;;   

;; Use (principles-file) to generate file KB/principles.tsv

(defparameter *principle-tree* '(
(group "Write a Principle"
(group "Kinematics" 
(group "Translational"			
       (leaf sdd :tutorial "Average speed")
       (leaf avg-velocity :bindings ((?axis . x)) :tutorial "Average velocity")
       (leaf avg-velocity :bindings ((?axis . y)) :tutorial "Average velocity")
       ;; alternative form of equation
       (leaf lk-no-s :EqnFormat ("a(avg)_~a = (vf_~a - vi_~a)/t" 
				 (axis-name ?axis) (axis-name ?axis) 
				 (axis-name ?axis))
	     :bindings ((?axis . x)) :tutorial "Average acceleration")
       ;; alternative form of equation
       (leaf lk-no-s :EqnFormat ("a(avg)_~a = (vf_~a - vi_~a)/t" 
				 (axis-name ?axis) (axis-name ?axis) 
				 (axis-name ?axis))
	     :bindings ((?axis . y)) :tutorial "Average acceleration")
       (leaf lk-no-vf :bindings ((?axis . x)) :tutorial "Constant acceleration")
       (leaf lk-no-vf :bindings ((?axis . y)) :tutorial "Constant acceleration")
       (leaf lk-no-s :bindings ((?axis . x)) :tutorial "Constant acceleration")
       (leaf lk-no-s :bindings ((?axis . y)) :tutorial "Constant acceleration")
       (leaf lk-no-t :bindings ((?axis . x)) :tutorial "Constant acceleration")
       (leaf lk-no-t :bindings ((?axis . y)) :tutorial "Constant acceleration")
       (leaf sdd-constvel :bindings ((?axis . x)) :tutorial "Constant velocity component")
       (leaf sdd-constvel :bindings ((?axis . y)) :tutorial "Constant velocity component")
       (leaf const-v :bindings ((?axis . x)) :tutorial "Constant velocity component")
       (leaf const-v :bindings ((?axis . y)) :tutorial "Constant velocity component")
       (leaf centripetal-accel :tutorial "Centripetal acceleration")
       (leaf centripetal-accel-compo :bindings ((?axis . x)) :tutorial "Centripetal acceleration")
       (leaf centripetal-accel-compo :bindings ((?axis . y)) :tutorial "Centripetal acceleration")
       (leaf relative-vel :bindings ((?axis . x)) :tutorial "Relative Velocity")
       (leaf relative-vel :bindings ((?axis . y)) :tutorial "Relative Velocity")
       )
(group "Rotational" 
       (leaf ang-sdd :tutorial "Angular velocity")
       ;; alternative form of equation
       (leaf rk-no-s :EqnFormat "$a(avg) = ($wf - $wi)/t" 
	     :tutorial "Angular acceleration")
       (leaf rk-no-vf :tutorial "Constant angular acceleration")
       (leaf rk-no-s :tutorial "Constant angular acceleration")
       (leaf rk-no-t :tutorial "Constant angular acceleration")
       (leaf linear-vel :tutorial "Linear velocity")
       (leaf rolling-vel :tutorial "Linear velocity")
       )
)
(group "Newton's Laws" 
       (group "Translational" 
	      (leaf NSL :bindings ((?axis . x)) :tutorial "Newton's Second Law")
	      (leaf NSL :bindings ((?axis . y)) :tutorial "Newton's Second Law")
	      (leaf net-force :bindings ((?axis . x)) :tutorial "Newton's Second Law")
	      (leaf net-force :bindings ((?axis . y)) :tutorial "Newton's Second Law")
	      (leaf NTL :tutorial "Newton's Third Law")
	      (leaf NTL-vector :bindings ((?axis . x)) :tutorial "Newton's Third Law")
		 (leaf NTL-vector :bindings ((?axis . y)) :tutorial "Newton's Third Law")
		 (leaf ug :tutorial "Universal Gravitation")
		 )
	 (group "Rotational" 
		 (leaf NFL-rot :tutorial "Newton's Law for rotation")
		 (leaf NSL-rot :tutorial "Newton's Law for rotation")
		 (leaf mag-torque :tutorial "Individual torque magnitude")
		 (leaf torque :bindings ((?xyz . x)) :tutorial "Individual torque magnitude")
		 (leaf torque :bindings ((?xyz . y)) :tutorial "Individual torque magnitude")
		 (leaf torque :bindings ((?xyz . z)) :tutorial "Individual torque magnitude")
		 (leaf net-torque-zc :tutorial "Net torque")
		 )
	 )
 (group "Work Energy and Power" 
	 (leaf work :tutorial "Work done by a force")
	 (leaf net-work :tutorial "Net work")
	 (leaf work-nc :tutorial "Conservation of Energy")
	 (leaf work-energy :tutorial "Work-Energy")
	 (leaf mechanical-energy :tutorial "Conservation of Energy")
	 (leaf change-me :tutorial "Conservation of Energy")
	 (leaf cons-energy :tutorial "Conservation of Energy")
	 (leaf potential-energy-definition)
	 (leaf kinetic-energy :tutorial "Conservation of Energy")
	 (leaf rotational-energy :tutorial "Conservation of Energy")
	 (leaf grav-energy :tutorial "Conservation of Energy")
	 (leaf gravitational-energy-point)
	 (leaf spring-energy :tutorial "Conservation of Energy")
	 (leaf electric-energy :tutorial "Electric Potential")
	 (leaf power :tutorial "Power")
	 (leaf net-power :tutorial "Power")
	 (leaf inst-power :tutorial "Power")
	 (leaf spherical-intensity-to-power :tutorial "Intensity")
	 (leaf uniform-intensity-to-power :tutorial "Intensity")
	 (leaf net-intensity :tutorial "Intensity")
	 (leaf intensity-to-decibels :tutorial "Intensity")
	 (leaf intensity-to-decibels :EqnFormat "I = Iref*10^($b/10)" :tutorial "Intensity")
	 (leaf intensity-to-poynting-vector-magnitude :tutorial "Intensity")
	 )
 (group "Momentum and Impulse" 
	 (group "Translational" 
		 (leaf momentum-compo :bindings ((?axis . x)) :tutorial "Conservation of Momentum")
		 (leaf momentum-compo :bindings ((?axis . y)) :tutorial "Conservation of Momentum")
		 (leaf cons-linmom :bindings ((?axis . x)) :tutorial "Conservation of Momentum")
		 (leaf cons-linmom :bindings ((?axis . y)) :tutorial "Conservation of Momentum")
		 (leaf cons-ke-elastic :tutorial "Elastic collisions")
		 (leaf impulse-force :bindings ((?axis . x)) :tutorial "Impulse")
		 (leaf impulse-force :bindings ((?axis . y)) :tutorial "Impulse")
		 (leaf impulse-momentum :bindings ((?axis . x)) :tutorial "Impulse")
		 (leaf impulse-momentum :bindings ((?axis . y)) :tutorial "Impulse")
		 (leaf NTL-impulse :tutorial "Impulse")
		 (leaf NTL-impulse-vector :bindings ((?axis . x)) :tutorial "Impulse")
		 (leaf NTL-impulse-vector :bindings ((?axis . y)) :tutorial "Impulse")
		 (leaf center-of-mass-compo :bindings ((?axis . x)) :tutorial "Center of Mass")
		 (leaf center-of-mass-compo :bindings ((?axis . y)) :tutorial "Center of Mass")
		 )
	 (group "Rotational" 
		 (leaf ang-momentum :tutorial "Angular momentum definition")
		 (leaf cons-angmom :tutorial "Conservation of Angular momentum")
		 )
	 )
 (group "Fluids"
	 (leaf pressure-height-fluid :tutorial "Pressure Height")
	 (leaf bernoulli :tutorial "Bernoulli's Principle")
	 (leaf equation-of-continuity :tutorial "Bernoulli's Principle")
	 (leaf pressure-force :tutorial "Pressure")
	 (leaf density :tutorial "Mass Density")
	 (leaf archimedes :tutorial "Buoyant Force")
	 )
 (group "Electricity and Magnetism"
         (leaf charged-particles) 
	 (leaf coulomb)
	 (leaf coulomb-compo :bindings ((?axis . x)))
	 (leaf coulomb-compo :bindings ((?axis . y)))
	 (leaf charge-force-Efield-mag :tutorial "Electric Field")
	 (leaf charge-force-Efield :bindings ((?axis . x)) :tutorial "Electric Field")
	 (leaf charge-force-Efield :bindings ((?axis . y)) :tutorial "Electric Field")
	 (leaf point-charge-Efield-mag :tutorial "Point Charge Field")
	 (leaf point-charge-Efield :bindings ((?axis . x)) :tutorial "Point Charge Field")
	 (leaf point-charge-Efield :bindings ((?axis . y)) :tutorial "Point Charge Field")
	 (leaf net-field-electric :bindings ((?axis . x)) :tutorial "Electric Field")
	 (leaf net-field-electric :bindings ((?axis . y)) :tutorial "Electric Field")
	 (leaf electric-flux-constant-field)
	 (leaf electric-flux-constant-field-change)
	 (leaf sum-fluxes)
	 (leaf point-charge-potential :tutorial "Electric Potential")
	 (leaf net-potential :tutorial "Electric Potential")
	 (leaf electric-energy :tutorial "Electric Potential")
	 (leaf gauss-law)
	 (leaf electric-dipole-moment-mag :tutorial "Dipoles")
	 (leaf electric-dipole-moment :bindings ((?axis . x)) :tutorial "Dipoles")
	 (leaf electric-dipole-moment :bindings ((?axis . y)) :tutorial "Dipoles")
	 (leaf electric-dipole-torque-mag :tutorial "Dipoles")
	 (leaf electric-dipole-torque :bindings ((?axis . z)) :tutorial "Dipoles")
	 (leaf electric-dipole-energy :tutorial "Dipoles")
	 (leaf charge-force-Bfield-mag :tutorial "Magnetic Field")
	 (leaf charge-force-Bfield :bindings ((?axis . x)) 
	       :tutorial "Magnetic Field")
	 (leaf charge-force-Bfield :bindings ((?axis . y)) 
	       :tutorial "Magnetic Field")
	 (leaf charge-force-Bfield :bindings ((?axis . z)) 
	       :tutorial "Magnetic Field")
	 (leaf current-force-Bfield-mag)
	 (leaf biot-savert-point-particle-mag)
	 (leaf biot-savert-point-particle :bindings ((?axis . x)))
	 (leaf biot-savert-point-particle :bindings ((?axis . y)))
	 (leaf biot-savert-point-particle :bindings ((?axis . z)))
	 (leaf straight-wire-Bfield)
	 (leaf center-coil-Bfield)
	 (leaf inside-solenoid-Bfield)
	 (leaf net-field-magnetic :bindings ((?axis . x)))
	 (leaf net-field-magnetic :bindings ((?axis . y)))
	 (leaf net-field-magnetic :bindings ((?axis . z)))
	 (leaf magnetic-flux-constant-field)
	 (leaf magnetic-flux-constant-field-change)
	 (leaf faradays-law)
	 (leaf amperes-law :tutorial "Ampere's Law")
	 (leaf magnetic-dipole-moment-mag :tutorial "Dipoles")
	 (leaf magnetic-dipole-moment :bindings ((?axis . x)) :tutorial "Dipoles")
	 (leaf magnetic-dipole-moment :bindings ((?axis . y)) :tutorial "Dipoles")
	 (leaf magnetic-dipole-moment :bindings ((?axis . z)) :tutorial "Dipoles")
	 (leaf magnetic-dipole-torque-mag :tutorial "Dipoles")
	 (leaf magnetic-dipole-torque :bindings ((?axis . x)) :tutorial "Dipoles")
	 (leaf magnetic-dipole-torque :bindings ((?axis . y)) :tutorial "Dipoles")
	 (leaf magnetic-dipole-torque :bindings ((?axis . z)) :tutorial "Dipoles")
	 (leaf magnetic-dipole-energy :tutorial "Dipoles")
	 (leaf electromagnetic-wave-field-amplitude)
	 )
 (group "Circuits" 
	 (leaf loop-rule :tutorial "Loop Rule")
	 (leaf junction-rule :tutorial "Junction Rule")
	 (leaf electric-power :tutorial "Electric Power")
	 (group "Resistance" 
		 (leaf equiv-resistance-series :tutorial "Series Resistors")
		 (leaf equiv-resistance-parallel :tutorial "Parallel Resistors")
		 (leaf ohms-law :tutorial "Ohm's Law")
		 )
	 (group "Capacitance" 
		 (leaf capacitance-definition :tutorial "Capacitance")
		 (leaf equiv-capacitance-parallel :tutorial "Parallel Capacitors")
		 (leaf equiv-capacitance-series :tutorial "Series Capacitors")
		 (leaf charge-same-caps-in-branch :tutorial "Series Capacitors")
		 (leaf junction-rule-cap)
		 (leaf cap-energy :tutorial "Capacitor Energy")
		 (leaf RC-time-constant :tutorial "RC Circuits")
		 (leaf charging-capacitor-at-time :tutorial "RC Circuits")
		 (leaf discharging-capacitor-at-time :tutorial "RC Circuits")
		 (leaf current-in-RC-at-time :tutorial "RC Circuits")
		 (leaf charge-capacitor-percent-max :tutorial "RC Circuits")
		 )
	 (group "Inductance" 
		 (leaf inductor-emf :tutorial "Inductance")
		 (leaf mutual-inductor-emf :tutorial "Inductance")
		 (leaf inductor-energy :tutorial "Inductance")
		 (leaf solenoid-self-inductance :tutorial "Inductance")
		 (leaf LR-time-constant :tutorial "LR Circuits")
		 (leaf LR-current-growth :tutorial "LR Circuits")
		 (leaf LR-growth-Imax :tutorial "LR Circuits")
		 (leaf LR-current-decay :tutorial "LR Circuits")
		 (leaf LR-decay-Imax :tutorial "LR Circuits")
		 (leaf LC-angular-frequency :tutorial "LC Circuits")
		 (leaf RLC-time-constant :tutorial "RLC Circuits")
		 (leaf RLC-angular-frequency :tutorial "RLC Circuits")
		 (leaf transformer-voltage)
		 (leaf transformer-power)
		 )
	 )
 (group "Optics" 
	 (leaf lens-eqn :tutorial "Lens Equation")
	 (leaf magnification-eqn :tutorial "Magnification")
	 (leaf focal-length-mirror :tutorial "Spherical Mirror")
	 (leaf lens-combo :tutorial "Combined Lenses")
	 (leaf combo-magnification :tutorial "Magnification")
	 (leaf compound-focal-length :tutorial "Touching Lenses")
	 (leaf wave-speed-refraction)
	 (leaf refraction-vacuum)
	 (leaf snells-law)
	 (leaf total-internal-reflection)
	 (leaf brewsters-law)
	 (leaf polarizer-intensity :bindings ((?fraction . 1)))
	 (leaf polarizer-intensity :bindings ((?fraction . 0)))
	 (leaf slit-interference)
	 (leaf frauenhofer-diffraction)
	 (leaf resolution-circular-aperture)
	 (leaf radiation-pressure)
	 )
 (group "Waves and Oscillations" 
	 (leaf wavenumber-lambda-wave)
	 (leaf frequency-of-wave)
	 (leaf period-of-wave)
	 (leaf speed-of-wave)
	 (leaf speed-equals-wave-speed)
	 (leaf wave-speed-string)
	 (leaf max-transverse-speed-wave)
	 (leaf max-transverse-abs-acceleration-wave)
	 (leaf spring-mass-oscillation)
	 (leaf pendulum-oscillation)
	 (leaf doppler-frequency)
	 (leaf harmonic-of)
	 (leaf beat-frequency)
	 (leaf energy-decay)
	 (leaf wave-speed-light)
	 )
 )
(group "Apply a Definition or Auxiliary Law"
 (group "Kinematics"
	 (group"Translational"
		 (leaf net-disp :bindings ((?axis . x)) :tutorial "Net Displacement")
		 (leaf net-disp :bindings ((?axis . y)) :tutorial "Net Displacement")
		 (leaf avg-velocity :bindings ((?axis . x)) :tutorial "Average velocity")
		 (leaf avg-velocity :bindings ((?axis . y)) :tutorial "Average velocity")
       (leaf lk-no-s :EqnFormat ("a(avg)_~a = (vf_~a - vi_~a)/t" 
				 (axis-name ?axis) (axis-name ?axis) 
				 (axis-name ?axis))
	     :bindings ((?axis . x)) :tutorial "Average acceleration")
       ;; alternative form of equation
       (leaf lk-no-s :EqnFormat ("a(avg)_~a = (vf_~a - vi_~a)/t" 
				 (axis-name ?axis) (axis-name ?axis) 
				 (axis-name ?axis))
	     :bindings ((?axis . y)) :tutorial "Average acceleration")
		 (leaf free-fall-accel :tutorial "Free fall acceleration")
		 (leaf std-constant-g :tutorial "Value of g near Earth")
		 (leaf period-circle :tutorial "Period Circular")
		)
	 (group "Rotational" 
		 (leaf ang-sdd :tutorial "Angular velocity")
		 (leaf rk-no-s :tutorial "Angular acceleration")
		 )
	 )
 (group	 "Newton's Laws" 
		 (group	 "Translational" 
			 (group"Force Laws" 
			 (leaf wt-law :tutorial "Weight Law")
			 (leaf kinetic-friction :tutorial "Kinetic Friction")
			 (leaf static-friction :tutorial "Static Friction max")
			 (leaf spring-law :tutorial "Hooke's Law")
			 (leaf tensions-equal :tutorial "Equal tensions at both ends")
			 (leaf thrust-force :tutorial "thrust force")
			 (leaf thrust-force-vector :bindings ((?axis . x)) :tutorial "thrust force")
			 (leaf thrust-force-vector :bindings ((?axis . y)) :tutorial "thrust force")
			 (leaf drag-force-turbulent :tutorial "drag force")
			 )
			 (group "Compound Bodies" 
				(leaf mass-compound :tutorial "Mass of a compound body")
				(leaf volume-compound)
				(leaf kine-compound :bindings ((?vec-type . velocity)) :tutorial "Kinematics of compound same as part")
				(leaf kine-compound :bindings ((?vec-type . acceleration)) :tutorial "Kinematics of compound same as part")
				(leaf force-compound :tutorial "Force on a compound body")
				)
			)
		 (group "Rotational" 
			(leaf net-torque-zc :tutorial "Net torque")
			(leaf torque :bindings ((?xyz . z)) :tutorial "Individual torque magnitude")
			(leaf mag-torque :tutorial "Individual torque magnitude")
			(group "Moment of Inertia" 
			 (leaf I-disk-cm :tutorial "disk about center of mass")
			 (leaf I-rod-cm :tutorial "Long thin rod about center of mass")
			 (leaf I-rod-end :tutorial "Long thin rod about end")
			 (leaf I-hoop-cm :tutorial "Hoop about center of mass")
			 (leaf I-rect-cm :tutorial "Rectangle about center of mass")
			 (leaf I-compound :tutorial "Compound body")
			 )
			)
		)
 (group "Work and Energy" 
	 (leaf work-nc :tutorial "Conservation of Energy")
	 (leaf mechanical-energy :tutorial "Conservation of Energy")
	 (leaf height-dy :tutorial "Height and Displacement")
	 )
 (group "Fluids" 
	 (leaf pressure-at-open-to-atmosphere :tutorial "Atmospheric Pressure")
	 (leaf std-constant-Pr0 :bindings 0 :tutorial "Atmospheric Pressure")
	 )
 )
(group "Calculate a vector component" 
 (group "Displacement" 
	 (leaf projection  :bindings ((?axis . x) (?vector . (displacement . ?rest))) :tutorial "Projection Equations")
	 (leaf projection :bindings ((?axis . y) (?vector . (displacement . ?rest))) :tutorial "Projection Equations")
	 )
 (group "Velocity" 
	 (leaf projection :bindings ((?axis . x) (?vector . (velocity . ?rest))) :tutorial "Projection Equations")
	 (leaf projection :bindings ((?axis . y) (?vector . (velocity . ?rest))) :tutorial "Projection Equations")
	 )
 (group "Acceleration" 
	 (leaf projection :bindings ((?axis . x) (?vector . (acceleration . ?rest))) :tutorial "Projection Equations")
	 (leaf projection :bindings ((?axis . y) (?vector . (acceleration . ?rest))) :tutorial "Projection Equations")
	 )
 (group "Force" 
	 (leaf projection :bindings ((?axis . x) (?vector . (force . ?rest))) :tutorial "Projection Equations")
	 (leaf projection :bindings ((?axis . y) (?vector . (force . ?rest))) :tutorial "Projection Equations")
	 )
 (group "Relative Position"
	 (leaf projection :bindings ((?axis . x) (?vector . (relative-position . ?rest))) :tutorial "Projection Equations")
	 (leaf projection :bindings ((?axis . y) (?vector . (relative-position . ?rest))) :tutorial "Projection Equations")
)
 (group "Momentum"
	 (leaf projection :bindings ((?axis . x) (?vector . (momentum . ?rest))) :tutorial "Projection Equations")
	 (leaf projection :bindings ((?axis . y) (?vector . (momentum . ?rest))) :tutorial "Projection Equations")
	 )
 )
(group "Use information specific to this problem"
 (leaf equals)
 (leaf angle-direction)
 (leaf displacement-distance)
 (leaf current-thru-what)
 (leaf num-forces)
 (leaf given-fraction)
 (leaf opposite-relative-position)
 (leaf sum-times :tutorial "Sum of times")
 (leaf sum-distances)
 (leaf sum-distance)
 (leaf pyth-thm :tutorial "Pythagorean Theorem")
 (leaf unit-vector-mag) 
 (leaf connected-accels :tutorial "Equal accelerations")
 (leaf connected-velocities :tutorial "Equal velocities")
 (leaf complimentary-angles)
 (leaf supplementary-angles)
 (leaf right-triangle-tangent)
 (leaf tensions-equal :tutorial "Equal tensions at both ends")
 (leaf vector-magnitude :tutorial "Pythagorean Theorem")
 (leaf rdiff :bindings ((?axis . x)))
 (leaf rdiff :bindings ((?axis . y)))
 (leaf area-of-rectangle)
 (leaf area-of-rectangle-change)
 (leaf area-of-circle)
 (leaf circumference-of-circle-r)
 (leaf circumference-of-circle-d)
 (leaf volume-of-cylinder)
 (leaf mass-per-length-eqn)
 (leaf turns-per-length-definition)
 (leaf average-rate-of-change)
 )
))

#|
(defun principles-leaf-string (name &keys short-name bindings tutorial)
 (format nil "LEAF~C~A ~A~C~A~C~@[~A~]" \#tab 
(psmclass-eqnformat (lookup-psmclass name)) short-name
(if bindings (list name bindings) name) tutorial

(defun chomp (x)
 (if (eq (first x) 'group)
 (mapcar #'chomp (cddr x))
 (format t "~(~A~%  ~S~) \"~A\"~%" (second x) (third x) (fourth x))))
 
(mapcar #'chomp *principle-tree*)
|#

;;;          Generate file KB/principles.tsv

(defun principles-file ()
  "construct file KB/principles.tsv"
  (let ((str (open (merge-pathnames  "KB/principles.tsv" *Andes-Path*)
		   :direction :output :if-exists :supersede
		   ;; The workbench uses an older windows-specific 
		   ;; character encoding
	         :external-format #+sbcl :windows-1252 #+allegro :1252)))
    (dolist (p *principle-tree*) (principle-branch-print str p))
    (close str)))

(defun principle-branch-print (str p)
  "prints a group in KB/principles.tsv"
  (cond ((eq (car p) 'group)
	 ;; principles.tsv file format is 4 tab-separated columns
	 (format str "GROUP~C~A~C~C~%" #\tab (cadr p) #\tab #\tab)
	 (dolist (pp (cddr p)) (principle-branch-print str pp))
	 (format str "END_GROUP~C~A~C~C~%"  #\tab (cadr p) #\tab #\tab))
	((eq (car p) 'leaf)
	 (apply #'principle-leaf-print (cons str (cdr p))))))

;; keywords :short-name and :EqnFormat override definitions in Ontology
(defun principle-leaf-print (str class &key tutorial (bindings no-bindings)
					EqnFormat short-name) 
  "prints a principle in KB/principles.tsv"
  (let ((pc (lookup-psmclass-name class)))
    (format str "LEAF~C~A    ~A~C~(~A~)~C~@[~A~]~%" #\tab 
	    (eval-print-spec (or EqnFormat (psmclass-EqnFormat pc)) bindings)
	    (eval-print-spec (or short-name (psmclass-short-name pc)) bindings)
	    #\tab
	    (if (eq bindings no-bindings) (psmclass-name pc)
	      ;; if bindings have been supplied, construct list
	      ;; turn off pretty-print to prevent line breaks
	      (write-to-string (list (psmclass-name pc) bindings) :pretty nil))
	    #\tab
	    tutorial)))

;;;          Generate file Documentation/principles.html
;;;
;;;  See Bug #1475
;;;   expression to fix the special characters
;;;   perl -pi.orig -e 's/&/&amp;/g; s/\$w/&omega;/g; s/\$p/&pi;/g; s/\$S/&Sigma/g; s/\$q/&theta;/g; s/\$l/&lambda;/g; s/\$a/&alpha;/g; s/\$r/&rho;/g; s/\$F/&Phi;/g; s/\$e/&epsilon;/g; s/\$m/&mu;/g; s/\$t/&tau;/g; s/\$b/&beta;/g;' principles.html

;;; Get a list of homework sets into lisp.
;;; cd Problems; perl -w -n -e 'if(m/"(.*?\.aps)">(.*?)</){open F,"< $1" or next;my @y=<F>;close F;shift @y;shift @y;chomp(@y);print "($2 (@y))\n";}' index.html

(defun principles-html-file ()
  "construct file Documentation/principles.html"
  (let ((Stream  (open 
		 (merge-pathnames  "Documentation/principles.html" *Andes-Path*)
		   :direction :output :if-exists :supersede)))
  (andes-init)
  ;;  Assume stream has UTF-8 encoding (default for sbcl)
  ;;  Should test this is actually true or change the charset to match
  ;;  the actual character code being used by the stream
  ;;  something like:
  (when (streamp Stream) 
    #+sbcl (unless (eq (stream-external-format Stream) ':utf-8)
	     (error "Wrong character code ~A, should be UTF-8" 
		    (stream-external-format Stream))))
  (format Stream 
	  (strcat
	   "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">~%"
	   "<html> <head>~%"
	   ;;	   "   <meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\">~%"
	   "   <meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">~%"
	   "<link rel=\"stylesheet\" type=\"text/css\" href=\"main.css\">~%"
	   "<title>Principles</title>~%"
	   "</head>~%"
	   "<body>~%"
	   "<h1>Principles and Problems</h1>~%"
	   "<ul>~%"))

    (dolist (p *principle-tree*) (principle-branch-print-html stream p))

   (format Stream (strcat
		   "</ul>~%"
		   "</body>~%"
		   "</html>~%"))
    (when (streamp stream) (close stream))))

(defun principle-branch-print-html (str p)
  "prints a group in Documentation/principles.html"
  (cond ((eq (car p) 'group)
	 (format str "<li>~A~%<ul>~%" (cadr p))
	 (dolist (pp (cddr p)) (principle-branch-print-html str pp))
	 (format str "</ul>~%"))
	((eq (car p) 'leaf)
	 (apply #'principle-leaf-print-html (cons str (cdr p))))))

;; keywords :short-name and :EqnFormat override definitions in Ontology
(defun principle-leaf-print-html (str class &key tutorial (bindings no-bindings)
					EqnFormat short-name) 
  "prints a principle in KB/principles.tsv"
  (format t "print leaf ~A~%" class)
  (let* ((pc (lookup-psmclass-name class))
	 (probs (remove-if-not
		 #'(lambda (Prob)
		     (unless (problem-graph Prob)
		       (read-problem-info (string (problem-name prob)))
		       (when *cp* (setf (problem-graph Prob) 
					(problem-graph *cp*))))
		;     (format t "problem ~A with ~A~%" 
		;	     (problem-name prob) 
		;	     (length (second (problem-graph *cp*))))
		       (some #'(lambda (enode)
				; (format t "   bind ~A and ~A~%" 
				;	 (psmclass-form pc) (enode-id enode))
				 (unify (psmclass-form pc)
					(enode-id enode) bindings)) 
			     (second (problem-graph Prob))))
		 (choose-working-probs '(andes2)))))
    (format str "<li>~A ~A  ~(~A ~)~%" 
	    (eval-print-spec (or EqnFormat (psmclass-EqnFormat pc)) bindings)
	    (eval-print-spec (or short-name (psmclass-short-name pc)) bindings)
	    (mapcar #'problem-name probs))))
