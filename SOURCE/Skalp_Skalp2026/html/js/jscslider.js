var jscsd = { 'w':15, 'h':15 };
var jscsc = 0;
var jscsm = false;
var jscsid = 0;

$(function() {
	$(document).mouseup(function() { jscsm = false; });
	
	$('.slider').each(function() {
		w = $(this).width();
		
		c = $(this).attr('class').split(/\s+/);
		cs = new Array();
		for(i in c) if(c[i].substr(0, 10)=="jscslider_") cs.push(c[i]);
		cs = cs.join(" ");
		
		htm = '<div class="jscslider '+cs+'" style="width:'+w+'px;" id="id_jscslider_'+jscsc+'">'+
			'<div class="jscslider_scale"></div>'+
			'<div class="jscslider_tracker"></div>'+
			'</div>';
		
		min = parseInt($(this).attr('min'));
		max = parseInt($(this).attr('max'));
		if(isNaN(min)) min = 0;
		if(isNaN(max)) max = 100;
		val = (isNaN(parseInt($(this).val()))?min:parseInt($(this).val()));
		step = (w-jscsd.w)/(max-min);
		
		$(this).after(htm).attr('readonly', true).css('display', "none");
		$('#id_jscslider_'+jscsc).data({'min':min, 'max':max, 'w':w, 'step':step}).children('.jscslider_tracker').css("left", ((val-min)*step));
		
		jscsc++;
	});
	
	if($('.jscslider_tracker').length)
	{
		jscsd.w = $('.jscslider_tracker').eq(0).width();
		jscsd.h = $('.jscslider_tracker').eq(0).height();
		h = $('.jscslider').eq(0).height();
		$('.jscslider_tracker').css('top', ((h-jscsd.h)/2));
	}
	
	$('.jscslider').click(function(event) {
		pos = $(this).offset();
		x = (event.pageX-pos.left)-(jscsd.w/2);
		jscs_hit($(this), x);
	}).mousemove(function(event) {
		if(!jscsm) return;
		
		event.preventDefault();
		
		pos = $(this).offset();
		x = (event.pageX-pos.left)-(jscsd.w/2);
		jscs_hit($(this), x);
	}).mousedown(function(event) {
		if(event.which==1) {
			jscsm = true;
			jscsid = $(this).attr('id');
			event.preventDefault();
			
			$(this).prev().focus();
		}
	});

});

function jscs_hit(j, x) {
	min = j.data('min');
	max = j.data('max');
	w = j.data('w');
	step = j.data('step');
	
	val = min+Math.round(x/step);
	val = (val>max?max:(val<min?min:val));
	
	j.children('.jscslider_tracker').css("left", ((val-min)*step));
	j.prev().val(val).change();
}