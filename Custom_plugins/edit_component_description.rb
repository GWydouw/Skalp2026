 module Tommy
  UI.add_context_menu_handler do | context_menu |
    if Sketchup.active_model.selection && Sketchup.active_model.selection.count == 1 && Sketchup.active_model.selection.first.class == Sketchup::ComponentInstance
      context_menu.add_item(Skalp.translate("Edit Component description")){
        component = Sketchup.active_model.selection.first
        description_text = component.definition.description
        name = component.definition.name

        dialog = UI::WebDialog.new('Edit Component description', false, 'ComponentDescription', 275, 180, 100, 100, false)
        html = <<HTML
               <!DOCTYPE html>
              <html>

                  <script>
                    function change_description() {
                        var description = document.getElementById('description').value;
                        window.location = 'skp:edit@' + description;
                    }
                    function cancel() {
                        window.location = 'skp:cancel@';
                    }

                    function ready() {
                        window.location = 'skp:ready@';
                    }
                  </script>
                <style>
                  *{
                   font-size:12px;
                   font-family:"Arial" ;
                  }

                  #description {
                    width: 255px;
                    height: 80px;
                    rows = "5";
                  }

                </style>

                <body onload="ready()">

                  Name: <div id="component_name"> </div> <br>
                  Description: <br>
                  <textarea id="description"> </textarea>
                  <br>
                  <input type="submit" value="Edit" onclick="change_description()">
                  <input type="submit" value="Cancel" onclick="cancel()">
                </body>
              </html>
HTML

        dialog.add_action_callback("edit") {|dialog, params|
          Sketchup.active_model.start_operation('Edit Component description', true, false, false)
          component.definition.description = params
          Sketchup.active_model.commit_operation
          dialog.close
        }

        dialog.add_action_callback("cancel") {|dialog, params|
          dialog.close
        }

        dialog.add_action_callback("ready") {|dialog, params|
          js_command = "document.getElementById('component_name').innerHTML = '#{name}';"
          dialog.execute_script(js_command)
          js_command = "document.getElementById('description').innerHTML = '#{description_text}';"
          dialog.execute_script(js_command)
        }

        dialog.set_html(html)
        dialog.show
      }
    end
  end
 end
