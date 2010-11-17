dojo.provide("andes.WordTip");

dojo.declare("andes.WordTip", null, {
    // Summary:
    //      Singleton whose job is to watch the textbox
    //      and connect to the server when there are changes
    //      to show them to the student.
    //stub: null,
    conEdit: null,
    stencil: null,
    constructor: function(){
        this.conEdit = dojo.byId("conEdit");    
        dojo.connect(this.conEdit, "keydown", this, "textMonitor");
        console.log("I've got conedit now", this.conEdit);
    },
    
    add: function(obj){
        this[obj.id] = obj;
    },
    
    textMonitor: function(evt){
        if(evt.keyCode == dojo.keys.SPACE || evt.keyCode == dojo.keys.TAB || evt.keyCode == 188){
	    console.log("andes.WordTip.textMonitor this=",this);
            var tx = dojo.trim(this.conEdit.innerHTML);//this.statement.cleanText(conEdit.innerHTML);
            tx = this.removeBreaks(tx);
            var symbol = andes.variablename.parse(tx);
	    console.log("---Text for word-suggest----> ", tx,symbol);
	    this.sendToServer(tx,symbol);
        };
        if(evt.keyCode == dojo.keys.ENTER || evt.keyCode == dojo.keys.ESCAPE){
            dijit.hideTooltip(this.conEdit);
        }
        var cn = dojo.connect(document,"mouseup",this, function(evt){
            dojo.disconnect(cn);
            dijit.hideTooltip(this.conEdit);
        })
    },
    
    removeBreaks: function(txt){
        dojo.forEach(['<br>', '<br/>', '<br />', '\\n', '\\r'], function(br){
            txt = txt.replace(new RegExp(br, 'gi'), " ");
        });
        return txt;
    },
    
    sendToServer: function(text,symbol){
        // Code duplication with convert.js, should have common data structure.
        // Bug #1833
        var andesTypes = {
               "dojox.drawing.stencil.Line":"line",
               "dojox.drawing.stencil.Rect":"rectangle",
               "dojox.drawing.stencil.Ellipse":"ellipse",
               "dojox.drawing.tools.custom.Vector":"vector",
               "dojox.drawing.tools.custom.Axes":"axes",
               "dojox.drawing.tools.custom.Equation":"equation",
               "dojox.drawing.stencil.Image":"graphics",
               "dojox.drawing.tools.TextBlock":"statement"
       };
         
        // BvdS:  This strategy doesn't work in the case of modifying
	// a statement after drawing a vector.  Bug #1832
        var current = "statement";
        if(this.drawing){
            var type = this.drawing.currentStencil ? this.drawing.currentStencil.type : dojo.attr(this.conEdit.parentNode, "id");
	    if(type && andesTypes[type]){
                current = andesTypes[type];
	    } else {
                console.warn("andes.WordTip.sendToServer invalid type=",type);
	    }
        };
        console.log("Suggest for -----------------------", this);
        andes.api.suggestWord({type: current, text: text, symbol:symbol});
    },
    
    processResults: function(results){
        // Return may also include log messages and other directives.
        // Here, we ignore any other directives.
        dojo.forEach(results, function(line){
            if(line.action=="next-words"){
                dijit.hideTooltip(this.conEdit);
                if(line.words.length > 0 || line["last-word"]){
                    var size = Math.min(7, line.words.length);
		    var wrd = line["last-word"]?"&lt;done&gt;":"";
                    for(var i=0; i<size; i++){
			if(wrd.length>0) {wrd += ", ";}
                        wrd += line.words[i];
                    };
		    if(i<line.words.length){
			wrd += ", &#8230;";
		    }
                    console.log("Successfully retrieved tips: ", line.words.join(), " \nminimized to: ", wrd);
                    dijit.showTooltip(wrd, this.conEdit, "above");   
                };
            };
        },this);
    }
});