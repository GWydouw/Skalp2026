// Javascript function for skalp dialog
// http://www.javascriptobfuscator.com/default.aspx


/* Creates a uppercase hex number with at least length digits from a given number */
function fixedHex(number, length) {
    var str = number.toString(16).toUpperCase();
    while (str.length < length)
        str = "0" + str;
    return str;
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

// BROWSER WINDOW

function onfocus() {
    if (document.activeElement != document.body) document.activeElement.blur();
    document.getElementById("sections_list").focus();
    window.location = 'skp:dialog_focus@';
}

function onfocus_hatch() {
    window.location = 'skp:dialog_focus@';
}

function onblur() {
    var style = "";
    if (in_edit == true) {
        style = save_style(true);
        in_edit = false;
        $(".column_delete").css("width", "1px");
        $(".delete_image").css("width", "0px");
        $(".column_drag").css("width", "1px");
        $(".drag_image").css("width", "0px");
        $(".drag_image").css("opacity", "0");
        $(".column_delete").css("opacity", "0");
    };

    if (document.activeElement != document.body) document.activeElement.blur();
    var x = window.screenX.toString();
    var y = window.screenY.toString();
    var params = x.concat(";", y, ";", style);

    window.location = 'skp:dialog_blur@' + params;
}

function reset_undo_flag() {
    window.location = 'skp:reset_dialog_undo_flag@';
}

function materialSelector(id) {
    var x = window.screenX.toString();
    var y = window.screenY.toString();
    var params = x.concat(";", y, ";", id.toString());
    window.location = 'skp:materialSelector@' + params;
}

function deselect() {
    window.location = 'skp:deselect@';
}

function dialog_resize() {

    var w = window.innerWidth.toString();
    var h = window.innerHeight.toString();
    var wi = window.innerWidth;
    var hi = window.innerHeight;

    var min_w = $("#min_width").val();
    var min_h = $("#min_height").val();
    var max_h = $("#max_height").val();

    var h_def = hi;
    var w_def = wi;
    var resize = false;

    if (wi < min_w) {
        w_def = min_w;
        resize = true;
    }

    if (hi < min_h) {
        h_def = min_h;
        resize = true;
    }

    if (hi > max_h) {
        h_def = max_h;
        resize = true;
    }

    if (resize == true) { window.resizeTo(w_def, h_def); }


    var params = w.concat(";", h);

    var h_styles = (window.innerHeight - 75) + "px";
    // $('#skalp_styles').css({"height":h_styles});

    window.location = 'skp:dialog_resize@' + params;
}

function ready() {
    if (document.activeElement != document.body) document.activeElement.blur();

    var h = document.documentElement.clientHeight.toString();
    var w = document.documentElement.clientWidth.toString();
    var params = w.concat(";", h);

    window.location = 'skp:dialog_ready@' + params;
}

function ready_hatch() {
    //prevent dragging of images
    $("img").mousedown(function (e) {
        e.preventDefault()
    });

    dialog_resize(); // Ensure layout is calculated on load

    var h = document.documentElement.clientHeight.toString();
    var w = document.documentElement.clientWidth.toString();
    var params = w.concat(";", h);

    window.location = 'skp:dialog_ready@' + params;
}

// SELECTBOX

function set_value(id, item) {
    var listbox = document.getElementById(id);
    listbox.value = item;
}


function set_value_clear(id) {
    var listbox = document.getElementById(id);
    listbox.value = "";
}

function set_value_add(id, item) {
    var listbox = document.getElementById(id);
    var v = listbox.value;

    listbox.value = v.concat(item);
}

function get_length(id) {
    var listbox = document.getElementById(id);
    document.getElementById('RUBY_BRIDGE').value = listbox.options.length
}

function position() {
    var x = window.screenX.toString();
    var y = window.screenY.toString();
    document.getElementById('RUBY_BRIDGE').value = x.concat(',', y)
}

function add_listbox(id, item) {
    var listbox = document.getElementById(id);
    var option = document.createElement("option");
    option.value = item;
    option.text = item;
    listbox.add(option);
}

function clear_listbox(id) {
    var listbox = document.getElementById(id);
    var i;
    for (i = listbox.options.length - 1; i >= 0; i--) {
        listbox.remove(i);
    }
}

function clear_listbox_by_class(class_name) {
    var listboxes = $(class_name);

    $(class_name).each(function () {
        var listbox = $(this)[0];
        var i;
        for (i = listbox.options.length - 1; i >= 0; i--) {
            listbox.remove(i);
        }
    })
}

function add_listbox_by_class(class_name, item) {
    $(class_name).each(function (i, select) {
        var listb = $(this)

        var items = item.split(';');

        $.each(items, function (i, opt) {
            listb.append($('<option>', {
                value: opt,
                text: opt
            }));
        });
    });
}

function sort_listbox(box) {
    var temp_opts = new Array();
    var temp = new Object();
    for (var i = 0; i < box.options.length; i++) {
        temp_opts[i] = box.options[i];
    }
    for
        (var x = 0; x < temp_opts.length - 1; x++) {
        for
            (var y = (x + 1); y < temp_opts.length; y++) {
            if
                (temp_opts[x].text > temp_opts[y].text) {
                tempT = temp_opts[x].text;
                tempV = temp_opts[x].value;
                temp_opts[x].text = temp_opts[y].text;
                temp_opts[x].value = temp_opts[y].value;
                temp_opts[y].text = tempT;
                temp_opts[y].value = tempV;
            }
        }
    }
    for
        (var i = 0; i < box.options.length; i++) {
        box.options[i].text = temp_opts[i].text;
        box.options[i].value = temp_opts[i].value;
    }
}

function model_lists() {
    clear_listbox_by_class('.convert_to_layer_list_model');
    add_listbox_by_class('.convert_to_layer_list_model', $('#layers').val());

    // clear_listbox_by_class('.convert_to_material_list_model');
    // add_listbox_by_class('.convert_to_material_list_model', $('#patterns').val());

    clear_listbox_by_class('.selector_name_layer_list');
    add_listbox_by_class('.selector_name_layer_list', $('#layers').val());

    clear_listbox_by_class('.selector_name_layer2_list');
    add_listbox_by_class('.selector_name_layer2_list', $('#layers2').val());

    clear_listbox_by_class('.selector_name_material_list');
    add_listbox_by_class('.selector_name_material_list', $('#patterns').val());

    clear_listbox_by_class('.selector_name_scene_list');
    add_listbox_by_class('.selector_name_scene_list', $('#scenes').val());

    clear_listbox_by_class('.convert_to_layer_list');
    add_listbox_by_class('.convert_to_layer_list', $('#layers2').val());

    // clear_listbox_by_class('.convert_to_material_list');
    // add_listbox_by_class('.convert_to_material_list', $('#patterns').val());
}

// DIALOGBOX

function hatch_up() {
    document.getElementById('hatch_icon').src = 'icons/hatch_icon_12x12.png';
}


function hatch_down() {
    document.getElementById('hatch_icon').src = 'icons/hatch_icon_12x12_pushed.png';
}

function hatch_up_pattern() {
    document.getElementById('hatch_icon_pattern').src = 'icons/hatch_icon_12x12.png';
}


function hatch_down_pattern() {
    document.getElementById('hatch_icon_pattern').src = 'icons/hatch_icon_12x12_pushed.png';
}

function sections_add_up() {
    document.getElementById('sections_add').src = 'icons/add.png';
}


function sections_delete_up() {
    document.getElementById('sections_delete').src = 'icons/delete.png';
}


function sections_show_more_down() {
    document.getElementById('sections_show_more').src = 'icons/show_more_pushed.png';
}

function hatch_show_more_down() {
    document.getElementById('hatch_show_more').src = 'icons/show_more_pushed.png';
}

// TO SKETCHUP
function update_scene() {
    window.location = 'skp:update_Skalp_scene@';
}

function set_linestyle(linestyle) {
    window.location = 'skp:set_linestyle@' + utf8(linestyle);
}

function style_edit_menu(index) {
    if (index == 0) {
        open_edit_mode();
    };
    if (index == 1) { window.location = 'skp:reset_style@'; };
}

function open_edit_mode() {
    if ($(".column_delete").css("width") == "1px") {
        in_edit = true;
        $(".column_delete").css("width", "16px");
        $(".delete_image").css("width", "16px");
        $(".column_drag").css("width", "20px");
        $(".drag_image").css("width", "16px");
        $(".drag_image").css("opacity", "1");
        $(".column_delete").css("opacity", "1");
        $("#menu_edit").text('Close Edit Rules');
    }
    else {
        save_style(false)
        in_edit = false;
        $(".column_delete").css("width", "1px");
        $(".delete_image").css("width", "0px");
        $(".column_drag").css("width", "1px");
        $(".drag_image").css("width", "0px");
        $(".drag_image").css("opacity", "0");
        $(".column_delete").css("opacity", "0");
        $("#menu_edit").text('Edit Rules');
    }
}

function menu(index) {
    if (index == 0) { window.location = 'skp:set_live_updating@'; };
    if (index == 1) { window.location = 'skp:set_section_offset@'; };
    if (index == 2) { window.location = 'skp:set_render_brightness@'; };
    if (index == 3) { window.location = 'skp:set_linestyle_system@'; };
    if (index == 4) { window.location = 'skp:export_LayOut@'; };
    if (index == 5) { window.location = 'skp:skalp2dxf@'; };
    if (index == 6) { window.location = 'skp:scenes2images@'; };
    if (index == 7) { window.location = 'skp:export_patterns@'; };
    if (index == 8) { window.location = 'skp:save_active_style_to_library@'; };
    if (index == 9) { window.location = 'skp:load_style_from_library@'; };
    if (index == 10) { window.location = 'skp:export_materials@'; };
    if (index == 11) { window.location = 'skp:import_materials@'; };
    if (index == 12) { window.location = 'skp:export_layer_mapping@'; };
    if (index == 13) { window.location = 'skp:import_layer_mapping@'; };
}

function hatchmenu(index) {
    if (index == 0) {
        window.location = 'skp:import_pat_file@';
    };
}

function sections_add() {
    document.getElementById('sections_add').src = 'icons/add_pushed.png';
    window.location = 'skp:sections_add@';
}

function edit_hatchmaterial() {
    var hatchname = document.getElementById('material_list').value
    window.location = 'skp:edit_hatchmaterial@' + utf8(hatchname);
}

function sections_switch() {
    window.location = 'skp:sections_switch@'
}

function active_sectionplane_toggle() {
    window.location = 'skp:active_sectionplane_toggle@'
}

function attach_material() {
    var name = document.getElementById('hatch_name').value;
    window.location = 'skp:attach_material_from_pattern_designer@' + utf8(name);
}


function sections_delete() {
    document.getElementById('sections_delete').src = 'icons/delete_pushed.png';
    window.location = 'skp:sections_delete@';
}

function sections_show_more() {
    var x = window.screenX.toString() || window.screenLeft.toString();
    var y = window.screenY.toString() || window.screenTop.toString();
    var params = x.concat(";", y);

    window.location = 'skp:sections_show_more@' + params;

}

function hatch_show_more() {
    var x = window.screenX.toString() || window.screenLeft.toString();
    var y = window.screenY.toString() || window.screenTop.toString();
    var params = x.concat(";", y);

    window.location = 'skp:hatch_show_more@' + params;
}

function change_active_sectionplane(value) {
    window.location = 'skp:change_active_sectionplane@' + utf8(value);
}


function rename_sectionplane(value) {
    window.location = 'skp:rename_sectionplane@' + utf8(value);
}


function define_tag(value) {
    window.location = 'skp:define_tag@' + utf8(value);
}

function define_sectionmaterial(material) {
    window.location = 'skp:define_sectionmaterial@' + utf8(material);
}

function solid_color(value) {
    if (value == true) {
        $("#units").attr('disabled', true);
        $("#lineweight_model").attr('disabled', true);
        $("#lineweight_paper").attr('disabled', true);
        $("#align_pattern").attr('disabled', true);

        // Hide entire rows
        $("#pattern_line_color_row").hide();
        $("#pattern_line_width_row").hide();

        $("#tile_x").attr('disabled', true);
        $("#tile_y").attr('disabled', true);


        $("#tile_x").css('color', 'lightgrey');
        $("#tile_y").css('color', 'lightgrey');

        $("#translate_01").css('color', 'lightgrey'); // Section Line Width label? No, translate_01 is Line Width (Pattern)
        // $("#translate_05").css('color', 'lightgrey'); // Section Line Width - KEEP ACTIVE
        // $("#translate_06").css('color', 'lightgrey'); // Fill Color - KEEP ACTIVE
        $("#translate_08").css('color', 'lightgrey'); // Line Width
        $("#translate_17").css('color', 'lightgrey'); // Line Color
        $("#translate_18").css('color', 'lightgrey'); // Align with objects
        // $("#translate_section_line_color").css('color', 'lightgrey'); // Section Line Color - KEEP ACTIVE
    } else {
        $("#units").attr('disabled', false);
        $("#lineweight_model").attr('disabled', false);
        $("#lineweight_paper").attr('disabled', false);
        $("#align_pattern").attr('disabled', false);

        // Show rows
        $("#pattern_line_color_row").show();
        $("#pattern_line_width_row").show();

        $("#tile_x").attr('disabled', false);
        $("#tile_y").attr('disabled', false);

        $("#tile_x").css('color', 'red');
        $("#tile_y").css('color', 'green');

        $("#translate_01").css('color', 'black');
        $("#translate_05").css('color', 'black');
        $("#translate_06").css('color', 'black');
        $("#translate_08").css('color', 'black');
        $("#translate_17").css('color', 'black');
        $("#translate_18").css('color', 'black');
        $("#translate_section_line_color").css('color', 'black');
    }
}

function select_pattern(value) {
    if (value === "Import AutoCAD pattern...") {
        sketchup.import_pat_file();
        return;
    }
    if (value === "----------------------") {
        return;
    }

    // Check for SOLID_COLOR
    if (value.indexOf("SOLID_COLOR") !== -1) {
        solid_color(true);
    } else {
        solid_color(false);
    }

    create_preview(1);
}

function select_material(value) {
    $('#hatch_name').val(value);
    // Trigger SOLID_COLOR check if material uses it? 
    // Usually pattern is selected separate from material name, 
    // but loading a material might set pattern list.
    create_preview(1);
}

delete_hatch_ready = true;

function create_hatch() {
    if (delete_hatch_ready == true) {
        var acad_pat = document.getElementById('acad_pattern_list').value;
        var name = document.getElementById('hatch_name').value;
        var size_x = document.getElementById('tile_x').value;
        var slider = document.getElementById('slider').value;
        var space = document.getElementById('units').value;
        var pen_paper = document.getElementById('lineweight_paper').value;
        var pen_model = document.getElementById('lineweight_model').value;
        // Use Spectrum pickers
        var fill_color = $("#fill_color_input").spectrum("get").toRgbString();
        var line_color = $("#line_color_input").spectrum("get").toRgbString();
        var section_line_color = $("#section_line_color_input").spectrum("get").toRgbString();
        var aligned = $("#align_pattern").prop('checked');
        var section_cut_width = document.getElementById('sectioncut_linewidth').value;
        var unify = $("#unify_material").prop('checked');
        var drawing_priority = document.getElementById('zindex').value;

        var pattern_type = document.getElementById('pattern_type').value;
        var insulation_style = document.getElementById('insulation_style').value;

        var params = [
            utf8(acad_pat),
            size_x,
            space,
            pen_paper,
            pen_model,
            line_color,
            fill_color,
            slider,
            "0",
            aligned,
            section_cut_width,
            utf8(name),
            section_line_color,
            unify,
            drawing_priority,
            pattern_type,
            insulation_style
        ].join(';');

        window.location = 'skp:create_hatch@' + params;
    }
}

// Helper function to return color string as-is (handling rgba)
function getColorString(val) {
    if (!val) return 'rgb(255,255,255)';
    return val;
}


function create_new_hatch() {
    var x = window.screenX.toString() || window.screenLeft.toString();
    var y = window.screenY.toString() || window.screenTop.toString();
    var params = x.concat(";", y);

    window.location = 'skp:create_new_hatch@' + params;
}

function delete_hatch() {
    delete_hatch_ready = false;
    var name = document.getElementById('hatch_name').value;
    window.location = 'skp:delete_hatch@' + utf8(name);
}

function set_fill_color(rgb) {
    $("#fill_color_input").spectrum("set", rgb);
    $("#fill_color_block").css('background-color', rgb);
}

function set_line_color(rgb) {
    $("#line_color_input").spectrum("set", rgb);
    $("#line_color_block").css('background-color', rgb);
}

// Helper function to convert rgb string to hex
function rgbToHex(rgb) {
    if (rgb.startsWith('#')) return rgb;
    var result = rgb.match(/\d+/g);
    if (!result || result.length < 3) return '#000000';
    return '#' + result.slice(0, 3).map(function (x) {
        var hex = parseInt(x).toString(16);
        return hex.length === 1 ? '0' + hex : hex;
    }).join('');
}

function create_preview(status) {

    var acad_pat = document.getElementById('acad_pattern_list').value;
    var size_x = document.getElementById('tile_x').value;
    var slider = document.getElementById('slider').value;
    var space = document.getElementById('units').value;
    var pen_paper = document.getElementById('lineweight_paper').value;
    var pen_model = document.getElementById('lineweight_model').value;

    // Use Spectrum
    var fill_color = $("#fill_color_input").spectrum("get").toRgbString();
    var line_color = $("#line_color_input").spectrum("get").toRgbString();
    var section_line_color = $("#section_line_color_input").spectrum("get").toRgbString();

    var aligned = $("#align_pattern").prop('checked');
    var section_cut_width = document.getElementById('sectioncut_linewidth').value;
    var materialname = document.getElementById('hatch_name').value;
    var unify = $("#unify_material").prop('checked');
    var drawing_priority = document.getElementById('zindex').value;

    var pattern_type = document.getElementById('pattern_type').value;
    var insulation_style = document.getElementById('insulation_style').value;

    var params = [
        utf8(acad_pat),
        size_x,
        space,
        pen_paper,
        pen_model,
        line_color,
        fill_color,
        slider,
        status,
        aligned,
        section_cut_width,
        utf8(materialname),
        section_line_color,
        unify,
        drawing_priority,
        pattern_type,
        insulation_style
    ].join(';');

    if (acad_pat != '') {
        window.location = 'skp:create_preview@' + params;
    }
}

function units(value) {
    $('#update_preview').show();
    if (value == 'paperspace') {
        $("#lineweight_paper").show();
        $("#lineweight_model").hide();

        window.location = 'skp:print_units@';
    }
    else {
        $("#lineweight_model").show();
        $("#lineweight_paper").hide();

        window.location = 'skp:model_units@';
    }
}

function set_fog_distance(value) {
    window.location = 'skp:set_fog_distance@' + value;
}

function change_drawing_scale(value) {
    window.location = 'skp:change_drawing_scale@' + value;
}

// FROM SKETCHUP

function sections_switch_toggle(status) {

    if (status == true) {
        document.getElementById('sections_switch').src = 'icons/onoff_green_small.png'
    }
    else {
        document.getElementById('sections_switch').src = 'icons/onoff_grey_small.png'
    }
}

// PATTERNDESIGNER

function change_tile_y(tile_x) {
    var gauge_ratio = $('#gauge_ratio').val();
    $('#update_preview').show();
    tile_x = tile_x.replace("'", "feet");
    params = tile_x.concat(";", gauge_ratio);
    window.location = 'skp:change_tile_y@' + params;
}

function change_tile_x(tile_y) {
    var gauge_ratio = $('#gauge_ratio').val();
    $('#update_preview').show();
    tile_y = tile_y.replace("'", "feet");
    params = tile_y.concat(";", gauge_ratio);
    window.location = 'skp:change_tile_x@' + params;
}

$(function () {
    $("#hatch_add").mousedown(function () {
        $this.attr('src', 'icons/add_pushed.png');
    });


    $("#hatch_add").mouseup(function () {
        $this.attr('src', 'icons/add.png');
    });

    $("#hatch_delete").mousedown(function () {
        $this.attr('src', 'icons/delete_pushed.png');
    });

    $("#hatch_delete").mouseup(function () {
        $this.attr('src', 'icons/delete.png');
    });

    $(document).keydown(function (e) {

        if (e.keyCode == 27) {
            document.getElementById('RUBY_BRIDGE').value = 'ESC'
            //alert('ESC pressed');
        }   // esc
    });

    $("#sections_switch").mousedown(function () {
        var items = $("#sections_list option").length;
        if (items == 1) {
            $("#sections_add").attr('src', 'icons/add_pushed.png');
        }
    });

    $("#sections_switch").mouseup(function () {
        $("#sections_add").attr('src', 'icons/add.png');
    });

    $("#drawing_scale_input").bind('blur keyup', function (e) {
        if (e.type == 'blur' || e.keyCode == '13') {
            change_drawing_scale(this.value)
        }
    });

    $("#sections_rename").bind('blur keyup', function (e) {
        if (e.type == 'blur' || e.keyCode == '13') {
            rename_sectionplane(this.value)
        }
    });

    $("#tag").bind('blur keyup', function (e) {
        if (e.type == 'blur' || e.keyCode == '13') {
            define_tag(this.value)
        }
    });

    $("#fog_distance_input").bind('blur keyup', function (e) {
        console.log('fog_distance_input event:', e.type, 'keyCode:', e.keyCode, 'value:', this.value);
        if (e.type == 'blur' || e.keyCode == '13') {
            console.log('Calling set_fog_distance with:', this.value);
            set_fog_distance(this.value)
        }
    });

    $("#hatch_name").bind('blur keyup', function (e) {
        if (e.type == 'blur' || e.keyCode == '13') {
            $('#update_preview').show();
        }
    });

    $("#tile_x").bind('blur keyup', function (e) {
        if (e.type == 'blur' || e.keyCode == '13') {
            change_tile_y(this.value)
        }
    });

    $("#tile_y").bind('blur keyup', function (e) {
        if (e.type == 'blur' || e.keyCode == '13') {
            change_tile_x(this.value)
        }
    });

    $("#lineweight_model").bind('blur keyup', function (e) {
        if (e.type == 'blur' || e.keyCode == '13') {
            $('#update_preview').show();
            create_preview(0);
        }
    });

});



// STYLES
var in_edit = false;

$(function () {

    var fixHelperModified = function (e, tr) {
        var $originals = tr.children();
        var $helper = tr.clone();
        $helper.children().each(function (index) {
            $(this).width($originals.eq(index).width())
        });

        return $helper;
    };

    $('#sortable').sortable({
        axis: "y",
        helper: fixHelperModified
    }).disableSelection()

    //prevent dragging of images
    $("img").mousedown(function (e) {
        e.preventDefault()
    });

    $("#add_item").click(function () {
        add_row(1);
    });
});

function highlight(element, status) {
    if (status == true) {
        element.css("width", "95%")
        element.css("border-width", "1px");
        element.css("border-radius", "2px");
        element.css("background-color", "rgb(250,250,250)");
        element.css("box-shadow", "none");
    }
    else {
        element.css("width", "95%")
        element.css("background-color", "rgb(255,255,255)");
        element.css("border-width", "0");
        element.css("border-radius", "0");
        element.css("box-shadow", "none");
    }
}

function highlight_empty(element) {
    element.css("width", "95%")
    element.css("background-color", "rgb(250,250,250)");
    element.css("border-width", "1px");
    element.css("border-radius", "2px");
    element.css("box-shadow", "0 0 3px 2px rgb(205,51,50)");

}

function highlight_empty_materialselector(element) {
    element.css("width", "95%")
    element.css("background-color", "rgb(250,250,250)");
    element.css("border-width", "1px");
    element.css("border-radius", "2px");
    element.css("box-shadow", "0 0 3px 2px rgb(205,51,50)");
    element.off("click");
    element.on("click", function (event) {
        materialSelector(element.attr('id'));
        highlight(element, false);
    })
}

function unique_id() {
    return Math.random().toString(36).substr(2, 9);
};

function add_row(num) {

    for (i = 1; i < num + 1; i++) {

        var id = unique_id();

        if (in_edit == true) {
            var in_edit_icons_size = 16;
        } else {
            var in_edit_icons_size = 0;
        };

        $("#sortable").append(
            '<tr class="ui-state-default">' +
            '<td class="column_drag"><img id="drag" src="icons/drag.png" alt="" height=16 width=' + in_edit_icons_size + '  class="drag_image"> </td>' +
            '<td class="column_selector_type">' +
            '<div class="div_selector_type">' +

            '<img class="selector_type_image" src="icons/default_icon_12x12.png" height=12 width=12>' +
            '<select title="Select input type for this mapping rule" class="selector_type">' +
            '<option value=":Nothing">- Nothing selected -</option>' +
            '<option value=":ByObject">Pattern by Object</option>' +
            '<option value=":ByLayer">Pattern by Tag</option>' +
            (typeof multitag_visible !== 'undefined' && multitag_visible ? '<option value=":ByMultiTag">Pattern by MultiTag</option>' : '') +
            '<option value=":ByTexture">Pattern by Texture</option>' +
            '<option value=":Layer">Tag</option>' +
            '<option value=":Tag">Label</option>' +
            '<option value=":Pattern">Pattern</option>' +
            '<option value=":Texture">Texture</option>' +
            '<option value=":Scene">Scene</option>' +
            '</select>' +

            '</div>' +
            '</td>' +
            '<td class="column_selector_name"> ' +
            '<div class="div_selector_name">' +

            '<input type="text" id="' + id + '1" class="style_textbox selector_name_value not_active" > ' +
            '<select class="style_listbox selector_name_layer2_list not_active" > </select>' +
            '<select class="style_listbox selector_name_material_list not_active" > </select>' +
            '<select class="style_listbox selector_name_scene_list not_active" > </select>' +

            '</div>' +
            '</td>' +
            '<td class="column_arrow" style="opacity:0;" style="font-size: 10px">=></td>' +
            '<td class="column_convert_to_type">' +
            '<div class="div_convert_to_selector">' +

            '<img class="convert_to_type_image" src="icons/hatch_icon_12x12.png" height=12 width=12 style="opacity:0;">' +

            '</div>' +
            '</td>' +
            '<td class="column_convert_to"> ' +
            '<div class="div_convert_to">' +

            '<input type="text" id="' + id + '2" class="style_textbox convert_to_value not_active" readonly="readonly"> ' +
            '<select class="style_listbox convert_to_layer_list not_active" > </select>' +
            '<input class="style_listbox convert_to_material_list not_active" > </input>' +

            '</div>' +
            '</td>' +
            '<td class="column_delete"><img src="icons/delete_red_16x16.png" alt="" height=16 width=' + in_edit_icons_size + ' class="delete_image"> </td>' +
            '</tr>');

        if (in_edit == true) {
            $(".column_delete").css("width", "16px");
            $(".delete_image").css("width", "16px");
            $(".column_drag").css("width", "20px");
            $(".drag_image").css("width", "16px");
            $(".drag_image").css("opacity", "1");
            $(".column_delete").css("opacity", "1");
        } else {
            $(".column_delete").css("width", "1px");
            $(".delete_image").css("width", "0px");
            $(".column_drag").css("width", "1px");
            $(".drag_image").css("width", "0px");
            $(".drag_image").css("opacity", "0");
            $(".column_delete").css("opacity", "0");
        }

        model_lists();
    }

    // CONVERT FROM

    $(".selector_name_layer_list").off("click");
    $(".selector_name_layer_list").on("click", function (event) {
        clear_listbox_by_class('.selector_name_layer_list');
        add_listbox_by_class('.selector_name_layer_list', $('#layers').val());
    })

    $(".selector_name_layer_list").off("change");
    $(".selector_name_layer_list").on("change", function (event) {
        $(this).siblings('.selector_name_value').val($(this).val());
        highlight($(this).closest('tr').find('.selector_name_value'), true);
    })

    $(".selector_name_value").off("change");

    $(".selector_name_value").on("change", function (event) {
        if ($(this).closest('tr').find('.selector_name_value').val() != '') {
            highlight($(this).closest('tr').find('.selector_name_value'), true);
        } else {
            highlight_empty($(this).closest('tr').find('.selector_name_value'));
        }
    })


    $(".selector_name_layer2_list").off("click");
    $(".selector_name_layer2_list").on("click", function (event) {
        clear_listbox_by_class('.selector_name_layer2_list');
        add_listbox_by_class('.selector_name_layer2_list', $('#layers2').val());
    })

    $(".selector_name_layer2_list").off("change");
    $(".selector_name_layer2_list").on("change", function (event) {
        $(this).siblings('.selector_name_value').val($(this).val());
        highlight($(this).closest('tr').find('.selector_name_value'), true);
    })

    $(".selector_name_material_list").off("click");
    $(".selector_name_material_list").on("click", function (event) {
        clear_listbox_by_class('.selector_name_material_list');
        add_listbox_by_class('.selector_name_material_list', $('#patterns').val());
    })

    $(".selector_name_material_list").off("change");
    $(".selector_name_material_list").on("change", function (event) {
        $(this).siblings('.selector_name_value').val($(this).val());
        highlight($(this).closest('tr').find('.selector_name_value'), true);
    })

    $(".selector_name_material_list").width(0);

    $(".selector_name_scene_list").off("click");
    $(".selector_name_scene_list").on("click", function (event) {
        clear_listbox_by_class('.selector_name_scene_list');
        add_listbox_by_class('.selector_name_scene_list', $('#scenes').val());
    })

    $(".selector_name_scene_list").off("change");
    $(".selector_name_scene_list").on("change", function (event) {
        $(this).siblings('.selector_name_value').val($(this).val());
        highlight($(this).closest('tr').find('.selector_name_value'), true);
    })

    $(".selector_name_scene_list").width(0);


    update_sudata();

    // OTHER

    $(".column_delete").off("click");
    $(".column_delete").on("click", function (event) {
        $(this).parent('tr').remove();
    });

    $(".selector_type").off("change");
    $(".selector_type").on("change", function (event) {

        var t = $(this)[0].value;
        var icon = $(this).siblings(".selector_type_image");

        var image = $(this).closest('tr').find('.convert_to_type_image');
        var input_field = $(this).closest('tr').find('.selector_name_value');
        var select_layer = $(this).closest('tr').find('.selector_name_layer2_list');
        var select_pattern = $(this).closest('tr').find('.selector_name_material_list');
        var select_scene = $(this).closest('tr').find('.selector_name_scene_list');

        var menu = $(this).closest('tr').find('.convert_to_type_selector');
        var icon2 = $(this).siblings(".convert_to_type_image");
        var input_field2 = $(this).closest('tr').find('.convert_to_value');
        var select_layer2 = $(this).closest('tr').find('.convert_to_layer_list');
        var select_pattern2 = $(this).closest('tr').find('.convert_to_material_list');
        var list = $(this).closest('tr').find('.style_listbox')

        var arrow = $(this).closest('tr').find('.column_arrow');

        switch (t) {
            case ':Layer':
                icon[0].src = "icons/layer_icon_12x12.png";

                input_field.val('');
                select_pattern.width(0);
                select_layer.width('100%');
                select_scene.width(0);

                input_field.attr('readonly', false);
                input_field.off("click");
                input_field.css("color", "rgb(0,0,0)");
                input_field.css("text-decoration", "none");
                menu.width('12px');
                arrow.css("opacity", "1");
                arrow.css("font-size", "10px");
                image.css("opacity", "1");
                select_pattern2.width('100%');

                select_layer.empty;
                select_pattern.empty;
                select_scene.empty;

                select_layer2.empty;
                select_pattern2.empty;

                input_field.removeClass("yes-select").addClass("no-select");

                input_field.removeClass("active").addClass("active");
                select_layer.removeClass("active").addClass("active");
                select_pattern.removeClass("active").addClass("not_active");
                select_scene.removeClass("active").addClass("not_active");

                highlight_empty(input_field);

                input_field2.val('');
                input_field2.removeClass("not_active").addClass("active");
                select_layer2.removeClass("active").addClass("not_active");
                //select_pattern2.removeClass("not_active").addClass("active");
                //select_pattern2.width('100%');
                select_layer2.width(0);
                input_field2.attr('readonly', false);
                highlight_empty_materialselector(input_field2);

                input_field2.removeClass("yes-select").addClass("no-select")

                break;
            case ':Tag':
                icon[0].src = "icons/tag_icon_12x12.png";

                input_field.val('');
                select_pattern.width(0);
                select_layer.width(0);
                select_scene.width(0);

                input_field.attr('readonly', false);
                input_field.off("click");
                input_field.css("color", "rgb(0,0,0)");
                input_field.css("text-decoration", "none");
                menu.width('12px');
                arrow.css("opacity", "1");
                arrow.css("font-size", "10px");
                image.css("opacity", "1");
                select_pattern2.width('100%');

                select_layer.empty;
                select_pattern.empty;
                select_scene.empty;

                select_layer2.empty;
                select_pattern2.empty;

                input_field.removeClass("no-select").addClass("yes-select");

                input_field.removeClass("active").addClass("active");
                select_layer.removeClass("active").addClass("not_active");
                select_pattern.removeClass("active").addClass("not_active");
                select_scene.removeClass("active").addClass("not_active");

                menu.removeClass("not_active").addClass("active");
                select_layer2.removeClass("active").addClass("not_active");
                select_pattern2.removeClass("active").addClass("not_active");

                highlight_empty(input_field);

                input_field2.val('');
                input_field2.removeClass("not_active").addClass("active");
                select_layer2.removeClass("active").addClass("not_active");
                //select_pattern2.removeClass("not_active").addClass("active");
                //select_pattern2.width('100%');
                select_layer2.width(0);
                input_field2.attr('readonly', false);
                highlight_empty_materialselector(input_field2);

                input_field2.removeClass("yes-select").addClass("no-select")

                break;
            case ':Pattern':
                icon[0].src = "icons/hatch_icon_12x12.png";

                input_field.val('');
                //select_pattern.width('100%');
                select_layer.width(0);
                select_scene.width(0);
                input_field.attr('readonly', false);
                input_field.off("click");
                input_field.css("color", "rgb(0,0,0)");
                input_field.css("text-decoration", "none");
                menu.width('12px');
                arrow.css("opacity", "1");
                arrow.css("font-size", "10px");
                image.css("opacity", "1");
                select_pattern2.width('100%');

                input_field.val('');
                select_layer.empty;
                select_pattern.empty;
                select_scene.empty;

                select_layer2.empty;
                select_pattern2.empty;

                input_field.removeClass("yes-select").addClass("no-select");

                input_field.removeClass("not_active").addClass("active");
                select_layer.removeClass("active").addClass("not_active");
                select_pattern.removeClass("active").addClass("active");
                select_scene.removeClass("active").addClass("not_active");

                menu.removeClass("not_active").addClass("active");
                select_layer2.removeClass("active").addClass("not_active");
                select_pattern2.removeClass("active").addClass("not_active");

                highlight_empty_materialselector(input_field);

                input_field2.val('');
                input_field2.removeClass("not_active").addClass("active");
                select_layer2.removeClass("active").addClass("not_active");
                //select_pattern2.removeClass("not_active").addClass("active");
                //select_pattern2.width('100%');
                select_layer2.width(0);
                input_field2.attr('readonly', false);
                highlight_empty_materialselector(input_field2);

                input_field2.removeClass("yes-select").addClass("no-select")

                break;
            case ':Texture':
                icon[0].src = "icons/texture_icon_12x12.png";

                input_field.val('');
                select_pattern.width('100%');
                select_layer.width(0);
                select_scene.width(0);
                input_field.attr('readonly', false);
                input_field.off("click");
                input_field.css("color", "rgb(0,0,0)");
                input_field.css("text-decoration", "none");
                menu.width('12px');
                arrow.css("opacity", "1");
                arrow.css("font-size", "10px");
                image.css("opacity", "1");
                select_pattern2.width('100%');

                input_field.val('');
                select_layer.empty;
                select_pattern.empty;
                select_scene.empty;

                select_layer2.empty;
                select_pattern2.empty;

                input_field.removeClass("yes-select").addClass("no-select")

                input_field.removeClass("not_active").addClass("active");
                select_layer.removeClass("active").addClass("not_active");
                select_pattern.removeClass("active").addClass("active");
                select_scene.removeClass("active").addClass("not_active");

                menu.removeClass("not_active").addClass("active");
                select_layer2.removeClass("active").addClass("not_active");
                select_pattern2.removeClass("active").addClass("not_active");

                highlight_empty(input_field);

                input_field2.val('');
                input_field2.removeClass("not_active").addClass("active");
                select_layer2.removeClass("active").addClass("not_active");
                //select_pattern2.removeClass("not_active").addClass("active");
                //select_pattern2.width('100%');
                select_layer2.width(0);
                input_field2.attr('readonly', false);
                highlight_empty_materialselector(input_field2);

                input_field2.removeClass("yes-select").addClass("no-select")

                break;
            case ':Object':
            case ':ByObject':
                icon[0].src = "icons/object_icon_12x12.png";

                select_pattern.width(0);
                select_layer.width(0);
                select_scene.width(0);
                select_pattern2.width(0);
                select_layer2.width(0);
                input_field.val('by Object');
                input_field.off("click");
                input_field.css("color", "rgb(0,0,0)");
                input_field.css("text-decoration", "none");
                $(this).closest('tr').find('.convert_to_value').val(" ")
                input_field.attr('readonly', true);
                menu.width('0');
                arrow.css("opacity", "0");
                image.css("opacity", "0");
                select_pattern2.width('0');
                select_layer.width('0');

                select_layer.empty;
                select_pattern.empty;
                select_scene.empty;

                select_layer2.empty;
                select_pattern2.empty;

                input_field.removeClass("yes-select").addClass("no-select")

                input_field.removeClass("active").addClass("active");
                select_layer.removeClass("active").addClass("not_active");
                select_pattern.removeClass("active").addClass("not_active");
                select_scene.removeClass("active").addClass("not_active");

                menu.removeClass("active").addClass("not_active");
                select_layer2.removeClass("active").addClass("not_active");
                select_pattern2.removeClass("active").addClass("not_active");

                highlight(input_field, false);
                highlight(input_field2, false);

                break;
            case ':ByTexture':
                icon[0].src = "icons/texture_icon_12x12.png";

                select_pattern.width(0);
                select_layer.width(0);
                select_scene.width(0);
                select_pattern2.width(0);
                select_layer2.width(0);
                input_field.val('by Texture');
                input_field.css("color", "rgb(0,0,0)");
                input_field.css("text-decoration", "none");
                input_field.off("click");
                $(this).closest('tr').find('.convert_to_value').val(" ")
                input_field.attr('readonly', true);
                menu.width('0');
                arrow.css("opacity", "0");
                image.css("opacity", "0");
                select_pattern2.width('0');
                select_layer.width('0');

                select_layer.empty;
                select_pattern.empty;
                select_scene.empty;

                select_layer2.empty;
                select_pattern2.empty;

                input_field.removeClass("yes-select").addClass("no-select")

                input_field.removeClass("active").addClass("active");
                select_layer.removeClass("active").addClass("not_active");
                select_pattern.removeClass("active").addClass("not_active");
                select_scene.removeClass("active").addClass("not_active");

                menu.removeClass("active").addClass("not_active");
                select_layer2.removeClass("active").addClass("not_active");
                select_pattern2.removeClass("active").addClass("not_active");

                highlight(input_field, false);
                highlight(input_field2, false);

                break;

            case ':ByMultiTag':
                icon[0].src = "icons/layer_icon_12x12.png";

                input_field.val('');
                select_pattern.width(0);
                select_layer.width(0);
                select_scene.width(0);
                select_pattern2.width(0);
                select_layer2.width(0);
                input_field.val('by MultiTag');
                $(this).closest('tr').find('.convert_to_value').val(" ")
                input_field.attr('readonly', true);
                menu.width('0');
                arrow.css("opacity", "0");
                image.css("opacity", "0");
                select_pattern2.width('0');
                select_layer.width('0');

                select_layer.empty;
                select_pattern.empty;
                select_scene.empty;

                select_layer2.empty;
                select_pattern2.empty;

                input_field.removeClass("yes-select").addClass("no-select")

                input_field.removeClass("active").addClass("active");
                select_layer.removeClass("active").addClass("not_active");
                select_pattern.removeClass("active").addClass("not_active");
                select_scene.removeClass("active").addClass("not_active");

                menu.removeClass("active").addClass("not_active");
                select_layer2.removeClass("active").addClass("not_active");
                select_pattern2.removeClass("active").addClass("not_active");

                highlight(input_field, false);
                highlight(input_field2, false);

                break;
            case ':ByLayer':
                icon[0].src = "icons/layer_icon_12x12.png";

                input_field.val('');
                select_pattern.width(0);
                select_layer.width(0);
                select_scene.width(0);
                select_pattern2.width(0);
                select_layer2.width(0);
                input_field.val('by Tag');
                input_field.css("color", "rgb(64,134,170)");
                input_field.css("text-decoration", "underline");
                input_field.on("click", function (event) { window.location = 'skp:define_layer_materials@'; });
                $(this).closest('tr').find('.convert_to_value').val(" ")
                input_field.attr('readonly', true);
                menu.width('0');
                arrow.css("opacity", "0");
                image.css("opacity", "0");
                select_pattern2.width('0');
                select_layer.width('0');

                select_layer.empty;
                select_pattern.empty;
                select_scene.empty;

                select_layer2.empty;
                select_pattern2.empty;

                input_field.removeClass("yes-select").addClass("no-select")

                input_field.removeClass("active").addClass("active");
                select_layer.removeClass("active").addClass("not_active");
                select_pattern.removeClass("active").addClass("not_active");
                select_scene.removeClass("active").addClass("not_active");

                menu.removeClass("active").addClass("not_active");
                select_layer2.removeClass("active").addClass("not_active");
                select_pattern2.removeClass("active").addClass("not_active");

                highlight(input_field, false);
                highlight(input_field2, false);

                break;
            case ':Nothing':
                icon[0].src = "icons/default_icon_12x12.png";

                input_field.val('');
                select_pattern.width(0);
                select_layer.width(0);
                select_scene.width(0);
                select_pattern2.width(0);
                select_layer2.width(0);
                input_field.val('');
                input_field.off("click");
                input_field.css("color", "rgb(0,0,0)");
                input_field.css("text-decoration", "none");
                $(this).closest('tr').find('.convert_to_value').val(" ")
                input_field.attr('readonly', true);
                menu.width('0');
                arrow.css("opacity", "0");
                image.css("opacity", "0");
                select_pattern2.width('0');
                select_layer.width('0');

                input_field.val('');
                select_layer.empty;
                select_pattern.empty;
                select_scene.empty;

                select_layer2.empty;
                select_pattern2.empty;

                input_field.removeClass("yes-select").addClass("no-select")

                input_field.removeClass("active").addClass("not_active");
                select_layer.removeClass("active").addClass("not_active");
                select_pattern.removeClass("active").addClass("not_active");
                select_scene.removeClass("active").addClass("not_active");

                menu.removeClass("active").addClass("not_active");
                select_layer2.removeClass("active").addClass("not_active");
                select_pattern2.removeClass("active").addClass("not_active");

                highlight(input_field, false);
                highlight(input_field2, false);

                break;

            case ':Scene':
                icon[0].src = "icons/scene_icon_12x12.png";

                input_field.val('');
                select_pattern.width(0);
                select_layer.width(0);
                select_scene.width('100%');
                input_field.attr('readonly', false);
                input_field.off("click");
                input_field.css("color", "rgb(0,0,0)");
                input_field.css("text-decoration", "none");
                menu.width('0');
                arrow.css("opacity", "0");
                image.css("opacity", "0");
                select_pattern2.width('0');
                select_layer.width('0');

                input_field.val('');
                select_layer.empty;
                select_pattern.empty;
                select_scene.empty;

                select_layer2.empty;
                select_pattern2.empty;

                input_field.removeClass("yes-select").addClass("no-select")

                input_field.removeClass("not_active").addClass("active");
                select_layer.removeClass("active").addClass("not_active");
                select_pattern.removeClass("active").addClass("not_active");
                select_scene.removeClass("active").addClass("active");

                menu.removeClass("active").addClass("not_active");
                select_layer2.removeClass("active").addClass("not_active");
                select_pattern2.removeClass("active").addClass("not_active");

                highlight_empty(input_field);
                highlight(input_field2, false);

                break;
        }

    });

    // CONVERT TO

    $(".convert_to_value").off("click");
    $(".convert_to_value").on("click", function (event) {
        materialSelector(this.id);
    })

    $(".convert_to_value").hover(function () {
        $(this).css("font-weight", "bold")
    }, function () {
        $(this).css("font-weight", "normal")
    });

    $(".selector_name_value").hover(function () {
        $(this).css("font-weight", "bold")
    }, function () {
        $(this).css("font-weight", "normal")
    });

    $("#material_list").hover(function () {
        $(this).css("font-weight", "bold")
    }, function () {
        $(this).css("font-weight", "normal")
    });

    $(".convert_to_layer_list").off("click");
    $(".convert_to_layer_list").on("click", function (event) {
        clear_listbox_by_class('.convert_to_layer_list');
        add_listbox_by_class('.convert_to_layer_list', $('#layers2').val())
    })

    $(".convert_to_layer_list").off("change");
    $(".convert_to_layer_list").on("change", function (event) {
        $(this).siblings('.convert_to_value').val($(this).val());
        highlight($(this).siblings('.convert_to_value'), true);
    })

    update_sudata();
};

function save_style(blur) {
    tableArr = new Array();

    var check = $("#save_check").prop('checked');
    var layer = $("#model_layer").val();
    var material = $("#model_material").val();

    if (check == true) {
        tableArr.push(1)
    }
    else {
        tableArr.push(0)
    }

    tableArr.push('|:Model|,|' + utf8(material) + '|');

    $('#sortable td').each(function () {
        value = $(this).find('.selector_name_value, .convert_to_value').val();
        type = $(this).find('.selector_type').val();
        tableArr.push('|' + utf8(type) + '|');
        tableArr.push('|' + utf8(value) + '|');
    });

    if (blur == true) {
        return tableArr;
    } else {

        window.location = 'skp:apply_style@' + tableArr;
    }
}

function update_sudata() {
    window.location = 'skp::update_dialog_lists@';
}

/* CUSTOM PATTERN DROPDOWN LOGIC */

function toggle_dropdown() {
    $('.custom-select-wrapper').toggleClass('open');
}

$(document).click(function (event) {
    if (!$(event.target).closest('.custom-select-wrapper').length) {
        $('.custom-select-wrapper').removeClass('open');
    }
});

function get_thumb_url(name) {
    if (!name || name === "----------------------" || name === "Import AutoCAD pattern..." || name === "SOLID_COLOR, solid color without hatching") {
        return "";
    }
    var safeName = name.replace(/[^a-zA-Z0-9]/g, "_");
    return "icons/thumbs/" + safeName + ".png";
}

function refresh_custom_dropdown() {
    var select = document.getElementById('acad_pattern_list');
    var optionsContainer = document.getElementById('custom_pattern_options');
    var selectedText = document.getElementById('selected_pattern_text');
    var selectedThumb = document.getElementById('selected_pattern_thumb');

    if (!select || !optionsContainer) return;

    optionsContainer.innerHTML = '';

    for (var i = 0; i < select.options.length; i++) {
        var opt = select.options[i];
        var val = opt.value;
        var text = opt.text;

        if (val === "----------------------" || val === "----------------------") {
            var sep = document.createElement('div');
            sep.className = 'custom-option separator';
            optionsContainer.appendChild(sep);
        } else {
            var div = document.createElement('div');
            div.className = 'custom-option';
            if (val === select.value) {
                div.classList.add('selected');
                selectedText.innerText = text;
                var thumbUrl = get_thumb_url(val);
                if (thumbUrl) {
                    selectedThumb.src = thumbUrl;
                    selectedThumb.style.display = 'block';
                } else {
                    selectedThumb.style.display = 'none';
                }
            }

            var thumbUrl = get_thumb_url(val);
            if (thumbUrl) {
                var img = document.createElement('img');
                img.src = thumbUrl;
                img.onerror = function () { this.style.display = 'none'; };
                div.appendChild(img);
            }

            var span = document.createElement('span');
            span.innerText = text;
            div.appendChild(span);

            div.onclick = (function (v, t) {
                return function () {
                    select_custom_option(v, t);
                };
            })(val, text);

            optionsContainer.appendChild(div);
        }
    }
}

function select_custom_option(value, text) {
    var select = document.getElementById('acad_pattern_list');
    select.value = value;

    // Trigger the original change event logic
    select_pattern(value);

    // Update UI
    refresh_custom_dropdown();
    $('.custom-select-wrapper').removeClass('open');
}

function thumbnails_ready() {
    refresh_custom_dropdown();
}


