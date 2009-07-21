dojo.provide("drawing.manager.Canvas");

(function(){
	
	drawing.manager.Canvas = drawing.util.oo.declare(
		// summary:
		//	Creates a dojox.gfx.surface to be used for Drawing. Note that
		//	The 'surface' that Drawing uses is actually a dojox.gfx.group.
		//	This allows for more versatility.
		//
		//	Called internally from a dojox.Drawing.
		//
		//	Note: Surface creation is asynchrous. Connect to
		//  	onSurfaceReady in Drawing.
		//
		function(/*Object*/options){
			dojo.mixin(this, options);
			
			var dim = dojo.contentBox(this.srcRefNode);
			this.height = this.parentHeight = dim.h;
			this.width = this.parentWidth = dim.w;
			this.domNode = dojo.create("div", {id:"canvasNode"}, this.srcRefNode);
			dojo.style(this.domNode, {
				width:this.width,
				height:"auto"
			});
			
			dojo.setSelectable(this.domNode, false);
			
			this.id = this.id || this.util.uid("surface");
			
			this.gfxSurface = dojox.gfx.createSurface(this.domNode, this.width, this.height);
			this.gfxSurface.whenLoaded(this, function(){
				setTimeout(dojo.hitch(this, function(){
					this.surfaceReady = true;
					if(dojo.isIE){
						//this.gfxSurface.rawNode.parentNode.id = this.id;
					}else if(dojox.gfx.renderer == "silverlight"){
						this.id = this.domNode.firstChild.id
					}else{
						//this.gfxSurface.rawNode.id = this.id;
					}
					
					this.underlay = this.gfxSurface.createGroup();
					this.surface = this.gfxSurface.createGroup();
					this.overlay = this.gfxSurface.createGroup();
					this.surface.setTransform({dx:0, dy:0,xx:1,yy:1});
					
					this.gfxSurface.getDimensions = dojo.hitch(this.gfxSurface, "getDimensions");
					if(options.callback){
						options.callback(this.domNode);
					}
				}),500);
			});
			this._mouseHandle = this.mouse.register(this);
		},
		{
			/*=====
			dojox.__CanvasArgs = function(node, duration, easing){
				//	callback: Function
				//		Method to be called when surface is ready
				//	srcRefNode: HTMLNode
				//		Node when surface is created.
				//	width: [readonly] Number
				//		Width to create surface  Changes on resize.
				//	height: [readonly] Number
				//		Height to create surface  Changes on resize.
				//	id: ? String
				//		Optional id
				//	util: Drawing.util
				//		Pointer to util
				//	mouse: Drawing.mouse
				//		Pointer to mouse
				// 	useScrollbars: [readonly] Boolean
				//		Whether Canvas scrolls or not
				//		(the Pan plugin is needed and will set this)
				//	parentWidth:  [readonly] Number
				//		The width of the node that contains the node
				//		from which the surface was created. Basically
				//		the node that may resize, like a ContentPane.
				//	parentHeight:  [readonly] Number
				//		See parentWidth
				//	baseClass: String
				//		The class applied to the surface node.
				//	surfaceReady: [readonly] Boolean
				//		True when surface is created.
				//
				id:"",
				width:0,
				height:0,
				parentHeight:0, // may change on pane or browser resize
				parentWidth:0, // may change on pane or browser resize
				domNode:null,
				srcRefNode:null,
				util:null,
				mouse:null,
				surfaceReady:false,
			}
			=====*/
						
			useScrollbars: true,
			baseClass:"drawingCanvas",
			
			resize: function(width, height){
				// summary:
				//	Method used to change size of canvas. Potentially
				//	called from a container like ContentPane. May be
				//	called directly.
				//	
				this.parentWidth = width;
				this.parentHeight = height;
				this.setDimensions(width, height);
			},
			
			setDimensions: function(width, height, scrollx, scrolly){
				// summary:
				//	Internal. Changes canvas size and sets scroll position.
				//	Do not call this, use resize().
				//
				// changing the size of the surface and setting scroll
				// if items are off screen
				var sw = this.getScrollWidth() //+ 10;
				this.width = Math.max(width, this.parentWidth);
				this.height = Math.max(height, this.parentHeight);
				
				if(this.height>this.parentHeight){
					this.width -= sw;
				}
				if(this.width>this.parentWidth){
					this.height -= sw;
				}
				
				this.gfxSurface.setDimensions(this.width, this.height);

			
				this.domNode.parentNode.scrollTop = scrolly || 0;
				this.domNode.parentNode.scrollLeft = scrollx || 0;
				
				
				if(this.useScrollbars){
					//console.info("Set Canvas Scroll", (this.height > this.parentHeight), this.height, this.parentHeight)
					dojo.style(this.domNode.parentNode, {
						overflowY: this.height > this.parentHeight ? "scroll" : "hidden",
						overflowX: this.width > this.parentWidth ? "scroll" : "hidden"
					});
				}else{
					dojo.style(this.domNode.parentNode, {
						overflowY: "hidden",
						overflowX: "hidden"
					});
				}
			},
			
			
			setZoom: function(zoom){
				// summary:
				//	Internal. Zooms canvas in and out.
				this.surface.setTransform({xx:zoom, yy:zoom});
			},
			
			onScroll: function(){
				// summary:
				//	Event fires on scroll.NOT IMPLEMENTED
			},
			
			getScrollOffset: function(){
				// summary:
				//	Get the scroll position of the canvas
				return {
					top:this.domNode.parentNode.scrollTop,
					left:this.domNode.parentNode.scrollLeft		
				}; // Object
			},
			
			getScrollWidth: function() {
				// summary:
				//	Special method used to detect the width (and height)
				// of the browser scrollbars. Becomes memoized.
				//
				var p = dojo.create('div');
				p.innerHTML = '<div style="width:50px;height:50px;overflow:hidden;position:absolute;top:0px;left:-1000px;"><div style="height:100px;"></div>';
				var div = p.firstChild;
				dojo.body().appendChild(div);
				var noscroll = dojo.contentBox(div).h;
				dojo.style(div, "overflow", "scroll")
				var scrollWidth = noscroll - dojo.contentBox(div).h;
				dojo.destroy(div);
				this.getScrollWidth = function(){
					return scrollWidth;
				}
				return scrollWidth; // Object
			}
		}
	);
	
})();