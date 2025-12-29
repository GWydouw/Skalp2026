var app = new Vue({
    el: '#app',
    data: {
        skalp_materials: true,
        materials: [],
        libraries: [],
        selected_library: '',
        selected_material: '',
        isHovering: false,
    },
    methods: {
        selectmaterial: function (materialname) {
            if (window.picker_mode_active) {
                window.confirm_replacement(materialname);
                return;
            }
            this.selected_material = materialname;
            sketchup.select(materialname, context_menu_active);
        },
        contextmenu: function (event, material) {
            app.selectmaterial(material); // selecteert ook het materiaal visueel
            event.preventDefault();
            current_context_material = material;
            const menu = document.getElementById("context-menu");

            // First show visibility hidden to calculate dimensions
            menu.style.opacity = "0";
            menu.style.display = "block";

            const menuWidth = menu.offsetWidth;
            const menuHeight = menu.offsetHeight;
            const windowWidth = window.innerWidth;
            const windowHeight = window.innerHeight;

            let top = event.pageY;
            let left = event.pageX;

            // Check vertical overflow
            if (top + menuHeight > windowHeight) {
                top = top - menuHeight; // Open upwards
            }

            // Check horizontal overflow
            if (left + menuWidth > windowWidth) {
                left = windowWidth - menuWidth - 10; // Align left, with padding
            }

            menu.style.top = top + "px";
            menu.style.left = left + "px";
            menu.style.opacity = "1";

            // Disable/Enable items based on library
            const isSketchUp = (app.selected_library === "SketchUp materials in model");
            const isSkalpInModel = (app.selected_library === "Skalp materials in model");

            menu.querySelectorAll("li").forEach(li => {
                if (li.classList.contains("separator")) return;

                // Reset first
                li.classList.remove("disabled");

                if (isSketchUp) {
                    li.classList.add("disabled");
                } else {
                    // Check data attributes
                    if (li.hasAttribute("data-only-model")) {
                        if (!isSkalpInModel) li.classList.add("disabled");
                    }
                    if (li.hasAttribute("data-only-library")) {
                        if (isSkalpInModel) li.classList.add("disabled");
                    }
                }
            });

            // Remove any old context-active classes
            document.querySelectorAll('.context-active').forEach(el => el.classList.remove('context-active'));
            event.currentTarget.classList.add('context-active');
        }
    }
});

function hover_material(materialname) {
    // No-op or implement Vue hover state if needed
}

function select(materialname) {
    app.selected_material = materialname;
}

function hide_library_actions() {
    var div = document.getElementById("library_actions_icon");
    if (div) div.style.display = "none";
}

function unselect() {
    app.selected_material = '';
}

function in_model_materials() {
    app.selected_library = 'Skalp materials in model';
    sketchup.library('Skalp materials in model');
}

function ready_materialSelector() {
    sketchup.dialog_ready();
}

// Position tracking (keep existing logic for saving window pos)
var x_ori, y_ori;
setInterval(function () {
    var x = window.screenX;
    var y = window.screenY;

    if (x != x_ori || y != y_ori) {
        x_ori = x;
        y_ori = y;
        position();
    }
}, 1000);

function position() {
    var x = window.screenX;
    var y = window.screenY;
    var h = window.outerHeight;
    var w = window.outerWidth;

    sketchup.position(x, y, w, h);
}

function load_materials(type, materials) {
    var data = [];
    app.skalp_materials = type;

    // Expecting [name, source, name, source...]
    if (materials && Array.isArray(materials)) {
        for (var i = 0; i < materials.length; i = i + 2) {
            data.push({
                name: materials[i],
                source: materials[i + 1]
            });
        }
    }

    app.materials = data;
    // Don't auto-select first one if we want "none" behavior or clean state
    if (data.length > 0 && !app.selected_material) {
        // app.selected_material = data[0].name; 
    }

    // Update scroll indicators after Vue render
    setTimeout(function () {
        if (typeof updateScrollIndicators === 'function') {
            updateScrollIndicators();
        }
    }, 100);
}

function su_focus() {
    sketchup.su_focus();
}

function load_libraries(libraries) {
    app.libraries = libraries;
    // Default select if needed, or let Ruby drive it
    if (libraries.length > 0 && !app.selected_library) {
        app.selected_library = libraries[0];
    }
}

function onblur() {
    // sketchup.dialog_blur();
}

function library(name) {
    app.selected_library = name;
    sketchup.library(name);
}

function material_menu(element, action) {
    element.selectedIndex = 0
    sketchup.material_menu(action);
}

function library_menu(element, action) {
    element.selectedIndex = 0
    sketchup.library_menu(action);
}

function selected_material(materialname) {
    app.selected_material = materialname;
}