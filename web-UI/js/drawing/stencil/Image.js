dojo.provide("drawing.stencil.Image");


drawing.stencil.Image = drawing.util.oo.declare(
	drawing.stencil._Base,
	function(options){
		if(options.data){
			this.src = options.data.src;
		}
	},
	{
		anchorType: "group",
		
		_createHilite: function(){
			this.remove(this.hit);
			this.hit = this.parent.createRect(this.data)
				.setStroke(this.style.currentHit)
				.setFill(this.style.currentHit.fill);
			this.util.attr(this.hit, "drawingType", "stencil");
		},
		_create: function(shp, d, sty){
			this.remove(this[shp]);
			var s = this.parent.getParent();//_getParentSurface();
			this[shp] = s.createImage(d)
			this.parent.add(this[shp]);
			this.util.attr(this[shp], "drawingType", "stencil");
		},
		
		render: function(){
			if(this.data.width == "auto"){
				this.getImageSize(true);
				return;
			}
			this.onBeforeRender(this);
			this._createHilite();
			this._create("shape", this.data, this.style.current);
		},
		getImageSize: function(render){
			var img = dojo.create("img", {src:this.data.src}, dojo.body());
			dojo.connect(img, "load", this, function(){
				var dim = dojo.marginBox(img);
				this.setData({
					x:this.data.x,
					y:this.data.y,
					src:this.data.src,
					width:dim.w,
					height:dim.h
				});
				dojo.destroy(img);
				render && this.render();
			});
		},
		dataToPoints: function(o){
			o = o || this.data;
			this.points = [
				{x:o.x, y:o.y}, 						// TL
				{x:o.x + o.width, y:o.y},				// TR
				{x:o.x + o.width, y:o.y + o.height},	// BR
				{x:o.x, y:o.y + o.height}				// BL
			];
			return this.points;
		},
		
		pointsToData: function(p){
			p = p || this.points;
			var s = p[0];
			var e = p[2];
			this.data = {
				x: s.x,
				y: s.y,
				width: e.x-s.x,
				height: e.y-s.y,
				src: this.src || this.data.src
			};
			return this.data;
			
		}
	}
);
drawing.stencil.Image.name = "Image";
drawing.stencil.Image.drawable = false;