$(function(){
    $("#export").click(function(){
        sketchup.export();
    });

    $("#cancel").click(function(){
        sketchup.cancel();
    });
});

function ready(){
    sketchup.dialog_ready();
}

function change_section_layer(value){
    skethup.change_section_layer(utf8(value))
}

function change_section_suffix(value){
    sketchup.change_section_suffic(utf8(value));
}

function change_hatch_suffix(value){
    sketchup.change_hatch_suffix(utf8(value));
}

function change_fill_suffix(value){
    sketchup.change_fill_suffix(utf8(value));
}

function change_forward_layer(value){
    sketchup.change_forward_layer(utf8(value));
}

function change_forward_suffix(value){
    sketchup.change_forward_suffix(utf8(value));
}

function change_forward_color(value){
    sketchup.change_forward_color(utf8(value));
}

function change_rear_layer(value){
    sketchup.change_rear_layer(utf8(value));
}

function change_rear_suffix(value){
    sketchup.change_fill_suffix(utf8(value));
}

function change_rear_color(value){
    sketchup.change_rear_color(utf8(value));
}

function change_where(value){
    sketchup.change_where(utf8(value));
}

function change_fileformat(value){
    sketchup.change_fileformat(utf8(value));
}

function resize_dialog() {
    var w = window.outerWidth;
    var h = window.outerHeight;
    var isMac = navigator.platform.toUpperCase().indexOf('MAC')>=0;

    if (isMac){h = h-21;};
    $(".scene").width(w-72);
    $(".table").height(h-339);
    $("#scenes").height(h-356);

    var params = w.toString().concat(";", h.toString());
    sketchup.resize_dialog(utf8(params));
}

/* Creates a unicode literal based on the string. nts: UTF-8 is an encoding - Unicode is a character set*/
function utf8(str) {
    if (str === undefined) {
        return str
    } else {
        var i;
        var result = "";
        for (i = 0; i < str.length; ++i) {
            /* You should probably replace this by an isASCII test */
            if (str.charCodeAt(i) > 126 || str.charCodeAt(i) < 32)
                result += "\\\\" + "u" + fixedHex(str.charCodeAt(i), 4);
            else
                result += str[i];
        }
        return result;
    }
}

function set_value(id, item){
    var listbox = document.getElementById(id);
    listbox.value = item;
}

function disable_input(id, status){
    var input_field = document.getElementById(id);

    if (status){
        input_field.classList.remove('enabled')
        input_field.classList.add('disabled')
    }else{
        input_field.classList.remove('disabled')
        input_field.classList.add('enabled')
    }

    input_field.disabled = status;
}

function toggleCheckbox(element)
{
    var name = element.value;
    var status = element.checked;
    var params = name.concat(";", status);

    sketchup.scene_selected(params);
}