var app = new Vue({
    el: '#app',
    data: {
        skalp_materials: true,
        materials: [{name: 'material 1', image_top: 10, text_top:12, source:''},
            {name: 'material 2', image_top: 34, text_top:36, source:''},
            {name: 'material 3', image_top: 58, text_top:60, source:''}],
        libraries: ['test1', 'test2'],
        selected_library: 'test1',
        selected_material: 'material 1',
        isHovering: false,
    },
    methods: {
        selectmaterial: function (materialname) {
            remove_selected_material();
            add_selected_material(materialname);
            sketchup.select(materialname, context_menu_active);
        }
    }
});

function hover_material(materialname){
    remove_hovering();
    add_hovering(materialname);
}

function select(materialname){
    remove_selected_material();
    add_selected_material(materialname);
    app.selected_material = materialname;
}

function hide_library_actions(){
    var div = document.getElementById("library_actions");
    div.style.display = "none";
}

function unselect(){
    remove_selected_material();
}

function remove_selected_material(){
    var materials = document.getElementsByClassName("material-text-selected");
    var i;
    for (i = 0; i < materials.length; i++) {
        materials[i].classList.remove("material-text-selected");
    }
}

function remove_hovering(){
    var materials = document.getElementsByClassName("material-hover");
    var i;
    for (i = 0; i < materials.length; i++) {
        materials[i].classList.remove("material-hover");
    }
}

function add_hovering(material){
    var element = document.querySelector("span[title='" + material.toString() + "']");
    element.classList.add("material-hover");
}

function add_selected_material(material){
    var element = document.querySelector("span[title='" + material.toString() + "']");
    element.classList.add("material-text-selected");
}

function in_model_materials(){
    app.selected_library = 'Skalp materials in model';
    sketchup.library('Skalp materials in model');
}

function ready_materialSelector(){
    sketchup.dialog_ready();
}

var x_ori, y_ori;

setInterval(function(){
    var x = window.screenX;
    var y = window.screenY;

    if (x!=x_ori || y!=y_ori){
        x_ori = x;
        y_ori = y;
        position();
    }

    }, 1000);

function position(){
    var x = window.screenX;
    var y = window.screenY;
    var h = window.outerHeight;
    var w = window.outerWidth;

    sketchup.position(x, y, w, h);
}

function load_materials(type, materials) {
    var data = [];
    app.skalp_materials = type;

    var material_data = [];
    for (var i = 0; i< materials.length; i=i+4){
        var material_data = {name: materials[i], preview_top: materials[i+1], text_top: materials[i+2], source: materials[i+3]};
        data.push(material_data) ;
    }

    app.materials = data;
    app.selected_material = data[0];
}

function su_focus(){
    sketchup.su_focus();
}

function load_libraries(libraries) {
    var data = [];

    for (var i = 0; i< libraries.length; i++){
        data.push(libraries[i]);
    }

    app.libraries = data;
    app.selected_library = data[1];
}

function onblur(){
    // sketchup.dialog_blur();
}

function library(name) {
    sketchup.library(name);
}

function material_menu(element, action){
    element.selectedIndex = 0
    sketchup.material_menu(action);
}

function library_menu(element, action){
    element.selectedIndex = 0
    sketchup.library_menu(action);
}

function selected_material(materialname){

}