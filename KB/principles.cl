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
		 (leaf torque-zc :tutorial "Individual torque magnitude")
		 (leaf net-torque-zc :tutorial "Net torque")
		 )
	 )
 (group "Work Energy and Power" 
	 (leaf work :tutorial "Work done by a force")
	 (leaf net-work :tutorial "Net work")
	 (leaf work-energy :tutorial "Work-Energy")
	 (leaf cons-energy :tutorial "Conservation of Energy")
	 (leaf change-me :tutorial "Conservation of Energy")
	 (leaf kinetic-energy :tutorial "Conservation of Energy")
	 (leaf rotational-energy :tutorial "Conservation of Energy")
	 (leaf grav-energy :tutorial "Conservation of Energy")
	 (leaf spring-energy :tutorial "Conservation of Energy")
	 (leaf electric-energy :tutorial "Electric Potential")
	 (leaf power :tutorial "Power")
	 (leaf net-power :tutorial "Power")
	 (leaf inst-power :tutorial "Power")
	 (leaf intensity-to-power :tutorial "Intensity")
	 (leaf uniform-intensity-to-power :tutorial "Intensity")
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
	 (leaf point-charge-potential :tutorial "Electric Potential")
	 (leaf net-potential :tutorial "Electric Potential")
	 (leaf electric-energy :tutorial "Electric Potential")
	 (leaf electric-dipole-moment-mag :tutorial "Dipoles")
	 (leaf electric-dipole-moment :bindings ((?axis . x)) :tutorial "Dipoles")
	 (leaf electric-dipole-moment :bindings ((?axis . y)) :tutorial "Dipoles")
	 (leaf electric-dipole-torque-mag :tutorial "Dipoles")
	 (leaf electric-dipole-torque :bindings ((?axis . z)) :tutorial "Dipoles")
	 (leaf electric-dipole-energy :tutorial "Dipoles")
	 (leaf charge-force-Bfield-mag :tutorial "Magnetic Field")
	 (leaf charge-force-Bfield-x :tutorial "Magnetic Field")
	 (leaf charge-force-Bfield-y :tutorial "Magnetic Field")
	 (leaf charge-force-Bfield-z :tutorial "Magnetic Field")
	 (leaf current-force-Bfield-mag)
	 (leaf straight-wire-Bfield)
	 (leaf center-coil-Bfield)
	 (leaf inside-solenoid-Bfield)
	 (leaf net-field-magnetic :bindings ((?axis . x)))
	 (leaf net-field-magnetic :bindings ((?axis . y)))
	 (leaf magnetic-flux-constant-field)
	 (leaf magnetic-flux-constant-field-change)
	 (leaf faradays-law)
	 (leaf magnetic-dipole-moment-mag :tutorial "Dipoles")
	 (leaf magnetic-dipole-moment :bindings ((?axis . x)) :tutorial "Dipoles")
	 (leaf magnetic-dipole-moment :bindings ((?axis . y)) :tutorial "Dipoles")
	 (leaf magnetic-dipole-torque-mag :tutorial "Dipoles")
	 (leaf magnetic-dipole-torque :bindings ((?axis . x)) :tutorial "Dipoles")
	 (leaf magnetic-dipole-torque :bindings ((?axis . y)) :tutorial "Dipoles")
	 (leaf magnetic-dipole-torque :bindings ((?axis . z)) :tutorial "Dipoles")
	 (leaf magnetic-dipole-energy :tutorial "Dipoles")
	 (leaf electromagnetic-wave-field-amplitude)
	 )
 (group "DC Circuits" 
	 (leaf loop-rule :tutorial "Loop Rule")
	 (leaf junction-rule :tutorial "Junction Rule")
	 (leaf electric-power :tutorial "Electric Power")
	 (group "Resistance" 
		 (leaf equiv-resistance-series :tutorial "Series Resistors")
		 (leaf equiv-resistance-parallel :tutorial "Parallel Resistors")
		 (leaf current-equiv)
		 (leaf ohms-law :tutorial "Ohm's Law")
		 )
	 (group "Capacitance" 
		 (leaf cap-defn :tutorial "Capacitance")
		 (leaf equiv-capacitance-parallel :tutorial "Parallel Capacitors")
		 (leaf equiv-capacitance-series :tutorial "Series Capacitors")
		 (leaf charge-same-caps-in-branch :tutorial "Series Capacitors")
		 (leaf cap-energy :tutorial "Capacitor Energy")
		 (leaf RC-time-constant :tutorial "RC Circuits")
		 (leaf charging-capacitor-at-time :tutorial "RC Circuits")
		 (leaf discharging-capacitor-at-time :tutorial "RC Circuits")
		 (leaf current-in-RC-at-time :tutorial "RC Circuits")
		 (leaf charge-on-capacitor-percent-max :tutorial "RC Circuits")
		 )
	 (group "Inductance" 
		 (leaf inductor-emf :tutorial "Inductance")
		 (leaf mutual-inductor-emf :tutorial "Inductance")
		 (leaf avg-rate-current-change :tutorial "Inductance")
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
		 (leaf const-vx :tutorial "Constant velocity component")
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
			 )
			 (group "Compound Bodies" 
				(leaf mass-compound :tutorial "Mass of a compound body")
				(leaf kine-compound :bindings ((?vec-type . velocity)) :tutorial "Kinematics of compound same as part")
				(leaf kine-compound :bindings ((?vec-type . acceleration)) :tutorial "Kinematics of compound same as part")
				(leaf force-compound :tutorial "Force on a compound body")
				)
			)
		 (group "Rotational" 
			(leaf net-torque-zc :tutorial "Net torque")
			(leaf torque-zc :tutorial "Individual torque magnitude")
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
	 (leaf net-work :tutorial "Net work")
	 (leaf work-nc :tutorial "Conservation of Energy")
	 (leaf kinetic-energy :tutorial "Conservation of Energy")
	 (leaf rotational-energy :tutorial "Conservation of Energy")
	 (leaf grav-energy :tutorial "Conservation of Energy")
	 (leaf spring-energy :tutorial "Conservation of Energy")
	 (leaf electric-energy :tutorial "Electric Potential")
	 (leaf height-dy :tutorial "Height and Displacement")
	 (leaf power :tutorial "Power")
	 (leaf net-power :tutorial "Power")
	 )
 (group "Fluids" 
	 (leaf pressure-at-open-to-atmosphere :tutorial "Atmospheric Pressure")
	 (leaf std-constant-Pr0 :bindings 0 :tutorial "Atmospheric Pressure")
	 )
 )
(group "Calculate a vector component" 
 (group "Displacement" 
	 (leaf proj :bindings ((?axis . x) (?vector . (displacement ?body))) :tutorial "Projection Equations")
	 (leaf proj :bindings ((?axis . y) (?vector . (displacement ?body))) :tutorial "Projection Equations")
	 )
 (group "Velocity" 
	 (leaf proj :bindings ((?axis . x) (?vector . (velocity ?body))) :tutorial "Projection Equations")
	 (leaf proj :bindings ((?axis . y) (?vector . (velocity ?body))) :tutorial "Projection Equations")
	 )
 (group "Acceleration" 
	 (leaf proj :bindings ((?axis . x) (?vector . (acceleration ?body))) :tutorial "Projection Equations")
	 (leaf proj :bindings ((?axis . y) (?vector . (acceleration ?body))) :tutorial "Projection Equations")
	 )
 (group "Force" 
	 (leaf proj :bindings ((?axis . x) (?vector . (force . ?args))) :tutorial "Projection Equations")
	 (leaf proj :bindings ((?axis . y) (?vector . (force . ?args))) :tutorial "Projection Equations")
	 )
 (group "Relative Position"
	 (leaf proj :bindings ((?axis . x) (?vector . (relative-position ?body ?origin))) :tutorial "Projection Equations")
	 (leaf proj :bindings ((?axis . y) (?vector . (relative-position ?body ?origin))) :tutorial "Projection Equations")
)
 (group "Momentum"
	 (leaf proj :bindings ((?axis . x) (?vector . (momentum ?body))) :tutorial "Projection Equations")
	 (leaf proj :bindings ((?axis . y) (?vector . (momentum ?body))) :tutorial "Projection Equations")
	 )
 )
(group "Use information specific to this problem"
 (leaf equals :bindings ((?quant1 . (distance ?body :time ?time))))
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
		   :direction :output :if-exists :supersede)))
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
