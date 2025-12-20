// SKALP C
#include <stdint.h>
#include <iostream>
#include <stdio.h>
#include <stdlib.h> 
#include <string>
#include <math.h>
#include "RubyUtils/RubyUtils.h"
#include "base64/base64.h"
#include "GeneralHash/GeneralHashFunctions.h"
#include "clipper.hpp"

#ifndef DBL2NUM
# define DBL2NUM rb_float_new 
#endif

using namespace std;
using namespace ClipperLib;

//prototype declaration
static void puts(VALUE var);
static VALUE ccw(VALUE self, VALUE rpt1, VALUE rpt2, VALUE rpt3);
static VALUE loadcode_mac();
static VALUE get_mac(VALUE self, VALUE save);
static VALUE id();
static VALUE set_id();
static VALUE get_id();
static void load_data_file(std::string file_name);
static void ccA(int num);
static void select_action(VALUE self, VALUE action_hash);
static void skalp_requires();
static void skalp_require_isolate();
static void skalp_require_dialog();
static void skalp_require_hatch_lib();
static void skalp_require_hatchtile();
static void skalp_require_hatch_class();
static void skalp_require_hatchdefinition_class();
static void skalp_require_hatchline_class();
static void skalp_require_hatchpatterns_main();
static void skalp_require_license();
static void skalp_require_run();
static int num2action(int num);
static VALUE replace_section(VALUE self); //ccA function in C
static VALUE cleared_selection();
static VALUE changed_selection(VALUE selection);
static VALUE set_Sketchup();
static VALUE check_mac();
static VALUE macs();
static VALUE mac2id(VALUE self, VALUE mac);
static long position();
//Clipper START
static ID id_even_odd;
static ID id_non_zero;

static int scale_factor = 10000;

static inline Clipper*
XCLIPPER(VALUE x)
{
    Clipper* clipper;
    Data_Get_Struct(x, Clipper, clipper);
    return clipper;
}

static inline ClipperOffset*
XCLIPPER_OFFSET(VALUE x)
{
    ClipperOffset* clipper_offset;
    Data_Get_Struct(x, ClipperOffset, clipper_offset);
    return clipper_offset;
}

static inline PolyFillType
sym_to_filltype(VALUE sym)
{
    ID inp = rb_to_id(sym);
    
    if (inp == id_even_odd) {
        return pftEvenOdd;
    } else if (inp == id_non_zero) {
        return pftNonZero;
    }
    
    rb_raise(rb_eArgError, "%s", "Expected :even_odd or :non_zero");
}

extern "C" {
    
    static void
    ary_to_polygon(VALUE ary, Path* poly)
    {
        const char* earg =
        "Polygons have format: [[p0_x, p0_y], [p1_x, p1_y], ...]";
        
        Check_Type(ary, T_ARRAY);
        
        for(long i = 0; i != RARRAY_LEN(ary); i++) {
            VALUE sub = rb_ary_entry(ary, i);
            Check_Type(sub, T_ARRAY);
            
            if(RARRAY_LEN(sub) != 2) {
                rb_raise(rb_eArgError, "%s", earg);
            }
            
            VALUE px = rb_ary_entry(sub, 0);
            VALUE py = rb_ary_entry(sub, 1);
            
            int p2x = (int)(NUM2DBL(px) * scale_factor);
            int p2y = (int)(NUM2DBL(py) * scale_factor);
            
            poly->push_back(IntPoint(p2x, p2y));
        }
    }
    
    static void
    ary_to_polypolygon(VALUE ary, Paths* polypoly)
    {
        Check_Type(ary, T_ARRAY);
        for(long i = 0; i != RARRAY_LEN(ary); i++) {
            Path p;
            VALUE sub = rb_ary_entry(ary, i);
            Check_Type(sub, T_ARRAY);
            ary_to_polygon(sub, &p);
            polypoly->push_back(p);
        }
    }
    
    static void
    rbclipper_free(void* ptr)
    {
        delete (Clipper*) ptr;
    }
    
    static VALUE
    rbclipper_new(VALUE klass)
    {
        Clipper* ptr = new Clipper;
        VALUE r = Data_Wrap_Struct(klass, 0, rbclipper_free, ptr);
        rb_obj_call_init(r, 0, 0);
        return r;
    }
    
    
    static VALUE
    rbclipper_add_polygon_internal(VALUE self, VALUE polygon,
                                   PolyType polytype)
    {
        Path tmp;
        ary_to_polygon(polygon, &tmp);
        XCLIPPER(self)->AddPath(tmp, polytype, true);
        return Qnil;
    }
    
    static VALUE
    rbclipper_add_subject_polygon(VALUE self, VALUE polygon)
    {
        return rbclipper_add_polygon_internal(self, polygon, ptSubject);
    }
    
    
    static VALUE
    rbclipper_add_clip_polygon(VALUE self, VALUE polygon)
    {
        return rbclipper_add_polygon_internal(self, polygon, ptClip);
    }
    
    
    static VALUE
    rbclipper_add_poly_polygon_internal(VALUE self, VALUE polypoly,
                                        PolyType polytype)
    {
        Paths tmp;
        ary_to_polypolygon(polypoly, &tmp);
        XCLIPPER(self)->AddPaths(tmp, polytype, true);
        return Qnil;
    }
    
    static VALUE
    rbclipper_add_subject_poly_polygon(VALUE self, VALUE polygon)
    {
        return rbclipper_add_poly_polygon_internal(self, polygon, ptSubject);
    }
    
    static VALUE
    rbclipper_add_clip_poly_polygon(VALUE self, VALUE polygon)
    {
        return rbclipper_add_poly_polygon_internal(self, polygon, ptClip);
    }
    
    
    static VALUE
    rbclipper_clear(VALUE self)
    {
        XCLIPPER(self)->Clear();
        return Qnil;
    }
    
    
    static VALUE
    rbclipper_execute_internal(VALUE self, ClipType cliptype,
                               VALUE subjfill, VALUE clipfill)
    {
        if (NIL_P(subjfill))
            subjfill = ID2SYM(id_even_odd);
        
        if (NIL_P(clipfill))
            clipfill = ID2SYM(id_even_odd);
        
        Paths solution;
        XCLIPPER(self)->Execute((ClipType) cliptype,
                                solution,
                                sym_to_filltype(subjfill),
                                sym_to_filltype(clipfill));
        
        double distance = 1.415 * (double(scale_factor) / 1000);
        CleanPolygons(solution, distance);
        VALUE r = rb_ary_new();
        for(Paths::iterator i = solution.begin();
            i != solution.end();
            ++i) {
            VALUE sub = rb_ary_new();
            for(Path::iterator p = i->begin(); p != i->end(); ++p) {
                VALUE point_array = rb_ary_new();
                rb_ary_push(point_array, DBL2NUM((double) p->X / double(scale_factor)));
                rb_ary_push(point_array, DBL2NUM((double) p->Y / double(scale_factor)));
                rb_ary_push(sub, point_array);
            }
            rb_ary_push(r, sub);
        }
        
        return r;
    }
    
    static VALUE
    rbclipper_intersection(int argc, VALUE* argv, VALUE self)
    {
        VALUE subjfill, clipfill;
        rb_scan_args(argc, argv, "02", &subjfill, &clipfill);
        return rbclipper_execute_internal(self, ctIntersection, subjfill, clipfill);
    }
    
    static VALUE
    rbclipper_union(int argc, VALUE* argv, VALUE self)
    {
        VALUE subjfill, clipfill;
        
        rb_scan_args(argc, argv, "02", &subjfill, &clipfill);
        
        return rbclipper_execute_internal(self, ctUnion, subjfill, clipfill);
    }
    
    
    static VALUE
    rbclipper_difference(int argc, VALUE* argv, VALUE self)
    {
        VALUE subjfill, clipfill;
        rb_scan_args(argc, argv, "02", &subjfill, &clipfill);
        return rbclipper_execute_internal(self, ctDifference, subjfill, clipfill);
    }
    
    
    static VALUE
    rbclipper_xor(int argc, VALUE* argv, VALUE self)
    {
        VALUE subjfill, clipfill;
        rb_scan_args(argc, argv, "02", &subjfill, &clipfill);
        return rbclipper_execute_internal(self, ctXor, subjfill, clipfill);
    }
    
    
    //ClipperOffset
    
    static void
    rbclipper_offset_free(void* ptr)
    {
        delete (ClipperOffset*) ptr;
    }
    
    static VALUE
    rbclipper_offset_new(VALUE klass)
    {
        ClipperOffset* ptr = new ClipperOffset;
        VALUE r = Data_Wrap_Struct(klass, 0, rbclipper_offset_free, ptr);
        rb_obj_call_init(r, 0, 0);
        return r;
    }
    
    static VALUE
    rbclipper_offset_add_polygon_internal(VALUE self, VALUE polygon)
    {
        Path tmp;
        ary_to_polygon(polygon, &tmp);
        XCLIPPER_OFFSET(self)->MiterLimit = 3 * double(scale_factor);
        XCLIPPER_OFFSET(self)->AddPath(tmp, jtMiter, etClosedPolygon);
        return Qnil;
    }
    
    
    static VALUE
    rbclipper_offset_add_poly_polygon_internal(VALUE self, VALUE polypoly)
    {
        Paths tmp;
        ary_to_polypolygon(polypoly, &tmp);
        XCLIPPER_OFFSET(self)->MiterLimit = 3 * double(scale_factor);
        XCLIPPER_OFFSET(self)->AddPaths(tmp, jtMiter, etClosedPolygon);
        return Qnil;
    }
    
    static VALUE
    rbclipper_offset_add_polygon(VALUE self, VALUE polygon)
    {
        return rbclipper_offset_add_polygon_internal(self, polygon);
    }
    
    static VALUE
    rbclipper_offset_add_poly_polygon(VALUE self, VALUE polygon)
    {
        return rbclipper_offset_add_poly_polygon_internal(self, polygon);
    }
    
    static VALUE
    rbclipper_offset_clear(VALUE self)
    {
        XCLIPPER_OFFSET(self)->Clear();
        return Qnil;
    }
    
    static VALUE
    rbclipper_offset_execute_internal(VALUE self, VALUE delta)
    {
        Paths solution;
        XCLIPPER_OFFSET(self)->Execute(solution,
                                       (double)(NUM2DBL(delta) * double(scale_factor)));
        VALUE r = rb_ary_new();
        for(Paths::iterator i = solution.begin();
            i != solution.end();
            ++i) {
            VALUE sub = rb_ary_new();
            for(Path::iterator p = i->begin(); p != i->end(); ++p) {
                VALUE point_array = rb_ary_new();
                rb_ary_push(point_array, DBL2NUM((double) p->X / double(scale_factor)));
                rb_ary_push(point_array, DBL2NUM((double) p->Y / double(scale_factor)));
                rb_ary_push(sub, point_array);
            }
            rb_ary_push(r, sub);
        }
        
        return r;
    }
    
    static VALUE
    rbclipper_offset_execute(VALUE self, VALUE delta)
    {
        return rbclipper_offset_execute_internal(self, delta);
    }
    
}
typedef VALUE (*ruby_method)(...);

//Clipper END
static void puts(VALUE var){
    rb_gv_set("p", var);
    rb_eval_string("puts $p.to_s");
}

static VALUE ccw(VALUE self, VALUE rpt1, VALUE rpt2, VALUE rpt3){
    
    double pt1x = NUM2DBL(rb_ary_entry(rpt1,0));
    double pt1y = NUM2DBL(rb_ary_entry(rpt1,1));
    double pt2x = NUM2DBL(rb_ary_entry(rpt2,0));
    double pt2y = NUM2DBL(rb_ary_entry(rpt2,1));
    double pt3x = NUM2DBL(rb_ary_entry(rpt3,0));
    double pt3y = NUM2DBL(rb_ary_entry(rpt3,1));
    
    double area2 = (pt2x-pt1x)*(pt3y-pt1y)-(pt2y-pt1y)*(pt3x-pt1x);
    
    if (area2 < 0.0)
    {
        return Qtrue;
    }
    else if (area2 > 0.0)
    {
        return Qfalse;
    }
    else
    {
        return INT2NUM(1); /* originally returned -1 */
    }
}


static VALUE loadcode_mac(){
    std::string r_str =
#include "macaddr.data"
    ;
    std::string d_str = base64_decode(r_str);
    rb_eval_string(d_str.c_str());
    
    return Qtrue;
}

static VALUE get_mac(VALUE self, VALUE save)
{
    
    VALUE mSkalp = rb_define_module("Skalp");
    VALUE mMac = rb_define_module_under(mSkalp, "Mac");
    VALUE mac_list = rb_funcall(mMac, rb_intern("address"),0);
    VALUE mac = rb_ary_entry(mac_list, 0);
    
    std::string key = StringValueCStr(mac);
    
    if (save == Qtrue) {
        set_id();
        set_Sketchup();
    }
    
    return rb_str_new2(key.c_str());
}

static VALUE macs()
{
    
    VALUE mSkalp = rb_define_module("Skalp");
    VALUE mMac = rb_define_module_under(mSkalp, "Mac");
    VALUE mac_list = rb_funcall(mMac, rb_intern("address"),0);
    
    return mac_list;
}

static VALUE check_mac()
{
    VALUE id = get_id();
    
    VALUE mSkalp = rb_define_module("Skalp");
    VALUE mMac = rb_define_module_under(mSkalp, "Mac");
    VALUE mac_list = rb_funcall(mMac, rb_intern("address"),0);
    VALUE check = Qfalse;
    
    long i;
    long len = RARRAY_LEN(mac_list) ;
    
    for(i = 0; i < len; i++)
    {
        VALUE mac = rb_ary_entry(mac_list, i);
        std::string key = StringValueCStr(mac);
        
        int hkey = (int) APHash(key);
        
        VALUE check_string = rb_funcall(INT2NUM(abs(hkey)),rb_intern("to_s"),0);
        VALUE id_string = rb_funcall(id,rb_intern("to_s"),0);
        
        int check1 = NUM2INT(rb_funcall(check_string,rb_intern("to_i"),0));
        int check2 = NUM2INT(rb_funcall(id_string,rb_intern("to_i"),0));
        
        if ((check1 - check2) == 0) {
            check = Qtrue;
        };
    }
    
    return check;
}

static long position()
{
    VALUE id = get_id();
    
    VALUE mSkalp = rb_define_module("Skalp");
    VALUE mMac = rb_define_module_under(mSkalp, "Mac");
    VALUE mac_list = rb_funcall(mMac, rb_intern("address"),0);
    VALUE position = 0;
    
    long i;
    long len = RARRAY_LEN(mac_list) ;
    
    for(i = 0; i < len; i++)
    {
        VALUE mac = rb_ary_entry(mac_list, i);
        std::string key = StringValueCStr(mac);
        
        int hkey = (int) APHash(key);
        
        VALUE check_string = rb_funcall(INT2NUM(abs(hkey)),rb_intern("to_s"),0);
        VALUE id_string = rb_funcall(id,rb_intern("to_s"),0);
        
        int check1 = NUM2INT(rb_funcall(check_string,rb_intern("to_i"),0));
        int check2 = NUM2INT(rb_funcall(id_string,rb_intern("to_i"),0));
        
        if ((check1 - check2) == 0) {
            position = i;
        };
    }
    
    return (long)position;
}

static VALUE id()
{
    VALUE mSkalp = rb_define_module("Skalp");
    VALUE mMac = rb_define_module_under(mSkalp, "Mac");
    VALUE mac_list = rb_funcall(mMac, rb_intern("address"),0);
    VALUE mac = rb_ary_entry(mac_list, position());
    
    std::string key = StringValueCStr(mac);
    
    int hkey = (int) APHash(key);
    return INT2NUM(abs(hkey));
}

static VALUE mac2id(VALUE self, VALUE mac)
{
    std::string key = StringValueCStr(mac);
    
    int hkey = (int) APHash(key);
    return INT2NUM(abs(hkey));
}

static VALUE set_id(){
    VALUE mac_hash = id();
    VALUE mSketchup = rb_define_module("Sketchup");
    rb_funcall(mSketchup, rb_intern("write_default"), 3, rb_str_new2("Skalp"), rb_str_new2("id"), mac_hash);
    
    return Qtrue;
}

static VALUE set_Sketchup(){
    VALUE mSketchup = rb_define_module("Sketchup");
    rb_funcall(mSketchup, rb_intern("write_default"), 3, rb_str_new2("SketchUp"), get_mac(Qfalse, Qfalse), INT2NUM(1));
    
    return Qtrue;
}

static VALUE get_id(){
    VALUE mSketchup = rb_define_module("Sketchup");
    return rb_funcall(mSketchup, rb_intern("read_default"), 2, rb_str_new2("Skalp"), rb_str_new2("id"));
}

static void load_data_file(std::string file_name){
    std::string d_str = base64_decode(file_name);
    rb_eval_string(d_str.c_str());
    
}

static int num2action(int num) //beveiligingscontrole
{
    int radius = 360;
    int size = 2;
    int length = 180;
    int width, height;
    
    VALUE mSkalp = rb_define_module("Skalp");
    VALUE mMac = rb_define_module_under(mSkalp, "Mac");
    VALUE mac_list = rb_funcall(mMac, rb_intern("address"),0);
    VALUE mac = rb_ary_entry(mac_list, position());
    
    std::string key = StringValueCStr(mac);
    int hkey = (int) APHash(key);
    width = abs(hkey);
    height = NUM2INT(get_id());
    int result = num - 1 + width - height + ((radius/length)/size);
    
    return result;
}

static VALUE replace_section(VALUE self){
    //Skalp::SectionAlgorithm.count_sections_reset
    
    //if @model.active_sectionplane
    //  @model.active_sectionplane.calculate_section(false)
    //end
    
    VALUE mSkalp = rb_define_module("Skalp");
    VALUE mSectionAlgorithm = rb_define_class_under(mSkalp, "SectionAlgorithm", rb_cObject);
    rb_funcall(mSectionAlgorithm, rb_intern("count_sections_reset"),0);
    
    VALUE model = rb_iv_get(self, "@model");
    VALUE active_sectionplane = rb_funcall(model, rb_intern("active_sectionplane"),0);
    
    if ((active_sectionplane != Qnil) && (active_sectionplane != Qfalse))
    {
        rb_funcall(active_sectionplane, rb_intern("calculate_section"),1, Qfalse);
        
    }
    return Qtrue;
}

static VALUE cleared_selection(){
    VALUE mSkalp = rb_define_module("Skalp");
    VALUE dialog = rb_funcall(mSkalp, rb_intern("dialog"),0);
    rb_funcall(dialog, rb_intern("update"),0);
    return Qtrue;
}

static VALUE changed_selection(VALUE selection){
    VALUE mSkalp = rb_define_module("Skalp");
    VALUE dialog = rb_funcall(mSkalp, rb_intern("dialog"),0);
    rb_funcall(dialog, rb_intern("update"),0);
    return Qtrue;
}

static void ccA(int num){
    std::string data;
    int action = num2action(num);
    
    switch (action)
    {
        case 1:
            data =
#include "Skalp_ccA_active_page_changed.data"
            ;
            break;
        case 2:
            data =
#include "Skalp_ccA_active_path_changed.data"
            ;
            break;
        case 3:
            data =
#include "Skalp_ccA_active_tool_changed.data"
            ;
            break;
        case 4:
            data =
#include "Skalp_ccA_add_element.data"
            ;
            break;
        case 5:
            data =
#include "Skalp_ccA_add_layer.data"
            ;
            break;
        case 6:
            data =
#include "Skalp_ccA_add_page.data"
            ;
            break;
        case 7:
            data =
#include "Skalp_ccA_change_active_sectionplane.data"
            ;
            break;
        case 8:
            data =
#include "Skalp_ccA_change_sectionplane.data"
            ;
            break;
        case 9:
            data =
#include "Skalp_ccA_changed_layer.data"
            ;
            break;
        case 10:
            data =
#include "Skalp_ccA_changed_selection.data"
            ;
            break;
        case 11:
            data =
#include "Skalp_ccA_cleared_selection.data"
            ;
            break;
        case 12:
            data =
#include "Skalp_ccA_erase_sectionplane.data"
            ;
            break;
        case 13:
            data =
#include "Skalp_ccA_find_face_parents.data"
            ;
            break;
        case 14:
            data =
#include "Skalp_ccA_modified_element.data"
            ;
            break;
        case 15:
            data =
#include "Skalp_ccA_removed_element.data"
            ;
            break;
        case 16:
            data =
#include "Skalp_ccA_removed_layer.data"
            ;
            break;
        case 17:
            data =
#include "Skalp_ccA_removed_page.data"
            ;
            break;
        case 19:
            data =
#include "Skalp_ccA_save_settings_to_scene.data"
            ;
            break;
        default:
            data =
#include "Skalp_ccA_no-license.data"
            ;
            puts(rb_str_new2("NO LICENSE"));
            break;
            
    }
    
    load_data_file(data);
    
}

static void select_action(VALUE self, VALUE action_hash){
    
    VALUE action, entity, entity_id, tool_id, entities;
    VALUE model, tree, pages, page, layer, selection, sectionplane;
    
    action = rb_hash_aref(action_hash, ID2SYM(rb_intern("action")));
    
    
    if (action == ID2SYM(rb_intern("add_element")))
    {
        entity = rb_hash_aref(action_hash, ID2SYM(rb_intern("entity")));
        ccA(4); //add_element
        rb_funcall(self, rb_intern("ccA"), 1, entity);
        
        rb_iv_set(self, "@update_needed", Qtrue);
        rb_iv_set(self, "@process_entities", Qtrue);
    }
    else if (action == ID2SYM(rb_intern("modified_element")))
    {
        
        model = rb_iv_get(self, "@model");
        tree = rb_funcall(model, rb_intern("tree"),0);
        
        entity = rb_hash_aref(action_hash, ID2SYM(rb_intern("entity")));
        ccA(14); //modified_element
        rb_funcall(self, rb_intern("ccA"), 1, entity);
        
        rb_iv_set(self, "@update_needed", Qtrue);
        rb_iv_set(self, "@process_entities", Qtrue);
    }
    else if (action == ID2SYM(rb_intern("removed_element")))
    {
        entities = rb_hash_aref(action_hash, ID2SYM(rb_intern("entities")));
        entity_id = rb_hash_aref(action_hash, ID2SYM(rb_intern("entity_id")));
        ccA(15); //removed_element
        rb_funcall(self, rb_intern("ccA"), 2, entities, entity_id);
        
        rb_iv_set(self, "@update_needed", Qtrue);
        rb_iv_set(self, "@process_entities", Qtrue);
    }
    else if (action == ID2SYM(rb_intern("change_sectionplane")))
    {
        entity = rb_hash_aref(action_hash, ID2SYM(rb_intern("entity")));
        ccA(8); //change_sectionplane
        rb_funcall(self, rb_intern("ccA"), 1, entity);
    }
    else if (action == ID2SYM(rb_intern("erase_sectionplane")))
    {
        entity = rb_hash_aref(action_hash, ID2SYM(rb_intern("entity")));
        ccA(12);//erase_sectionplane
        rb_funcall(self, rb_intern("ccA"), 1, entity);
    }
    else if (action == ID2SYM(rb_intern("changed_sectionmaterial")))
    {
        entity = rb_hash_aref(action_hash, ID2SYM(rb_intern("entity")));
        model = rb_iv_get(self, "@model");
        tree = rb_funcall(model, rb_intern("tree"),0);
        rb_funcall(tree, rb_intern("skpEntity_update_sectionmaterial"), 1, entity);
        
        rb_iv_set(self, "@update_needed", Qtrue);
        rb_iv_set(self, "@process_entities", Qtrue);
        
    }
    else if (action == ID2SYM(rb_intern("update_style")))
    {
        rb_iv_set(self, "@update_needed", Qtrue);
    }
    else if (action == ID2SYM(rb_intern("changed_tag")))
    {
        entity = rb_hash_aref(action_hash, ID2SYM(rb_intern("entity")));
        model = rb_iv_get(self, "@model");
        tree = rb_funcall(model, rb_intern("tree"),0);
        rb_funcall(tree, rb_intern("skpEntity_update_tag"), 1, entity);
        
        rb_iv_set(self, "@update_needed", Qtrue);
        rb_iv_set(self, "@process_entities", Qtrue);
        
    }
    else if (action == ID2SYM(rb_intern("modified_pages")))
    {
        
        pages = rb_hash_aref(action_hash, ID2SYM(rb_intern("pages")));
        model = rb_iv_get(self, "@model");
        VALUE selected_page = rb_funcall(pages, rb_intern("selected_page"),0);
        if (selected_page != Qnil){
            
            if (pages && (rb_funcall(pages, rb_intern("valid?"), 0) == Qtrue) && selected_page && (rb_funcall(selected_page, rb_intern("valid?"), 0) == Qtrue))
            {
                VALUE new_active_page = selected_page;
                
                if ((new_active_page != rb_iv_get(self, "@active_page"))||(rb_funcall(model, rb_intern("sectionplane_in_active_page_match_model_sectionplane?"),0) == Qfalse))
                {
                    ccA(1);//active_page_changed
                    rb_funcall(self, rb_intern("ccA"), 1, new_active_page);
                    rb_iv_set(self, "@active_page", new_active_page);
                }
                else if (new_active_page == rb_iv_get(self, "@active_page")) //(rb_funcall(new_active_page, rb_intern("name"),0) != rb_iv_get(self, "@active_pagename"))
                {
                    rb_iv_set(self, "@set_layers", Qtrue);
                }
            }
        }
    }
    
    else if (action == ID2SYM(rb_intern("add_page")))
    {
        page = rb_hash_aref(action_hash, ID2SYM(rb_intern("page")));
        ccA(6); //add_page
        rb_funcall(self, rb_intern("ccA"), 1, page);
        
    }
    else if (action == ID2SYM(rb_intern("removed_page")))
    {
        page = rb_hash_aref(action_hash, ID2SYM(rb_intern("page")));
        ccA(17); //removed_page
        rb_funcall(self, rb_intern("ccA"), 1, page);
    }
    else if (action == ID2SYM(rb_intern("add_layer")))
    {
        layer = rb_hash_aref(action_hash, ID2SYM(rb_intern("layer")));
        ccA(5); //add_layer
        rb_funcall(self, rb_intern("ccA"), 1, layer);
    }
    else if (action == ID2SYM(rb_intern("removed_layer")))
    {
        layer = rb_hash_aref(action_hash, ID2SYM(rb_intern("layer")));
        ccA(16);//removed_layer
        rb_funcall(self, rb_intern("ccA"), 1, layer);
    }
    else if (action == ID2SYM(rb_intern("current_layer_changed")))
    {
        layer = rb_hash_aref(action_hash, ID2SYM(rb_intern("layer")));
        //ccA(22);//current_layer_changed
        //rb_funcall(self, rb_intern("ccA"), 1, layer);
    }
    else if (action == ID2SYM(rb_intern("changed_layer")))
    {
        layer = rb_hash_aref(action_hash, ID2SYM(rb_intern("layer")));
        ccA(9);//changed_layer
        rb_funcall(self, rb_intern("ccA"), 1, layer);
    }
    else if (action == ID2SYM(rb_intern("changed_selection")))
    {
        selection = rb_hash_aref(action_hash, ID2SYM(rb_intern("selection")));
        ccA(10);//changed_selection
        rb_funcall(self, rb_intern("ccA"), 1, selection);
    }
    else if (action == ID2SYM(rb_intern("cleared_selection")))
    {
        ccA(11);//cleared_selection
        rb_funcall(self, rb_intern("ccA"), 0);
    }
    else if (action == ID2SYM(rb_intern("update_skalp_scene")))
    {
        ccA(19);
        rb_funcall(self, rb_intern("ccA"), 0);
    }
    else if (action == ID2SYM(rb_intern("change_active_sectionplane")))
    {
        sectionplane = rb_hash_aref(action_hash, ID2SYM(rb_intern("sectionplane")));
        ccA(7);
        rb_funcall(self, rb_intern("ccA"), 1, sectionplane);
    }
    else if (action == ID2SYM(rb_intern("undo_transaction")))
    {
        //rb_funcall(self, rb_intern("undo_transaction"), 0);
    }
    else if (action == ID2SYM(rb_intern("commit_transaction")))
    {
        //rb_funcall(self, rb_intern("commit_transaction"), 0);
    }
    else if (action == ID2SYM(rb_intern("redo_transaction")))
    {
        //rb_funcall(self, rb_intern("redo_transaction"), 0);
    }
    else if (action == ID2SYM(rb_intern("active_path_changed")))
    {
        //model = rb_iv_get(self, "@model");
        model = rb_hash_aref(action_hash, ID2SYM(rb_intern("model")));
        ccA(2);//active_path_changed
        rb_funcall(self, rb_intern("ccA"), 1, model);
        rb_iv_set(self, "@update_needed", Qtrue);
    }
    else if (action == ID2SYM(rb_intern("active_tool_changed")))
    {
        tool_id = rb_hash_aref(action_hash, ID2SYM(rb_intern("tool_id")));
        ccA(3);//active_tool_changed
        rb_funcall(self, rb_intern("ccA"), 1, tool_id);
    }
    else
    {
        
    }
}


static void skalp_require_dialog(){
    std::string data_file =
#include "Skalp_dialog.data"
    ;
    
    load_data_file(data_file);
}

static void skalp_require_run(){
    std::string data_file =
#include "Skalp_start.data"
    ;
    
    load_data_file(data_file);
}

static void skalp_require_license(){
    loadcode_mac();
    
    std::string data_file =
#include "Skalp_license.data"
    ;
    
    load_data_file(data_file);
}

static void skalp_require_hatch_lib(){
    std::string data_file =
#include "Skalp_hatch_lib.data"
    ;
    
    load_data_file(data_file);
}

static void skalp_require_hatchtile(){
    std::string data_file =
#include "Skalp_hatchtile.data"
    ;
    
    load_data_file(data_file);
}

static void skalp_require_hatch_class(){
    std::string data_file =
#include "Skalp_hatch_class.data"
    ;
    
    load_data_file(data_file);
}

static void skalp_require_hatchdefinition_class(){
    std::string data_file =
#include "Skalp_hatchdefinition_class.data"
    ;
    
    load_data_file(data_file);
}

static void skalp_require_hatchline_class(){
    std::string data_file =
#include "Skalp_hatchline_class.data"
    ;
    
    load_data_file(data_file);
}

static void skalp_require_hatchpatterns_main(){
    std::string data_file =
#include "Skalp_hatchpatterns_main.data"
    ;
    
    load_data_file(data_file);
}

static void skalp_require_isolate(){
    std::string data_file18 =
#include "Skalp_isolate.data"
    ;
    load_data_file(data_file18);
}

static void skalp_requires(){
    std::string data_file1 =
#include "Skalp_converter.data"
    ;
    
    load_data_file(data_file1);
    
    std::string data_file2 =
#include "Skalp_tree.data"
    ;
    
    load_data_file(data_file2);
    
    
    std::string data_file3 =
#include "Skalp_layer.data"
    ;
    load_data_file(data_file3);
    
    
    std::string data_file4 =
#include "Skalp_page.data"
    ;
    load_data_file(data_file4);
    
    
    std::string data_file5 =
#include "Skalp_visibility.data"
    ;
    load_data_file(data_file5);
    
    
    std::string data_file6 =
#include "Skalp_section2D.data"
    ;
    load_data_file(data_file6);
    
    
    std::string data_file7 =
#include "Skalp_sectionplane.data"
    ;
    load_data_file(data_file7);
    
    
    std::string data_file8 =
#include "Skalp_section.data"
    ;
    load_data_file(data_file8);
    
    std::string data_file9 =
#include "Skalp_model.data"
    ;
    load_data_file(data_file9);
    
    std::string data_file10 =
#include "Skalp_algorithm.data"
    ;
    load_data_file(data_file10);
    
    std::string data_file11 =
#include "Skalp_control_center.data"
    ;
    load_data_file(data_file11);
    
    std::string data_file13 =
#include "Skalp_dxf.data"
    ;
    load_data_file(data_file13);
    
    std::string data_file14 =
#include "Skalp_pages_undoredo.data"
    ;
    load_data_file(data_file14);
    
    std::string data_file15 =
#include "Skalp_memory_attributes.data"
    ;
    load_data_file(data_file15);
    
    std::string data_file16 =
#include "Skalp_materials.data"
    ;
    load_data_file(data_file16);
    
    std::string data_file17 =
#include "Skalp_fog.data"
    ;
    load_data_file(data_file17);
    
    std::string data_file19 =
#include "Skalp_dashed_lines.data"
    ;
    load_data_file(data_file19);
    
    std::string data_file20 =
#include "Skalp_hiddenlines.data"
    ;
    load_data_file(data_file20);
    
    std::string data_file21 =
#include "Skalp_multipolygon.data"
    ;
    load_data_file(data_file21);
}

extern "C"
void Init_SkalpC()
{
    VALUE mSkalp = rb_define_module("Skalp");
    VALUE cControlCenter = rb_define_class_under(mSkalp, "ControlCenter", rb_cObject);
    // Clipper
    // http://angusj.com/delphi/clipper.php
    // documentation: http://www.angusj.com/delphi/clipper/documentation/Docs/Overview/_Body.htm
    
    id_even_odd = rb_intern("even_odd");
    id_non_zero = rb_intern("non_zero");
    
    VALUE k = rb_define_class_under(mSkalp, "Clipper", rb_cObject);
    
    rb_define_singleton_method(k, "new",
                               (ruby_method) rbclipper_new, 0);
    rb_define_method(k, "add_subject_polygon",
                     (ruby_method) rbclipper_add_subject_polygon, 1);
    rb_define_method(k, "add_clip_polygon",
                     (ruby_method) rbclipper_add_clip_polygon, 1);
    rb_define_method(k, "add_subject_poly_polygon",
                     (ruby_method) rbclipper_add_subject_poly_polygon, 1);
    rb_define_method(k, "add_clip_poly_polygon",
                     (ruby_method) rbclipper_add_clip_poly_polygon, 1);
    rb_define_method(k, "clear!",
                     (ruby_method) rbclipper_clear, 0);
    
    rb_define_method(k, "intersection",
                     (ruby_method) rbclipper_intersection, -1);
    rb_define_method(k, "union",
                     (ruby_method) rbclipper_union, -1);
    rb_define_method(k, "difference",
                     (ruby_method) rbclipper_difference, -1);
    rb_define_method(k, "xor",
                     (ruby_method) rbclipper_xor, -1);
    
    // ClipperOffset
    VALUE o = rb_define_class_under(mSkalp, "ClipperOffset", rb_cObject);
    
    rb_define_singleton_method(o, "new",
                               (ruby_method) rbclipper_offset_new, 0);
    rb_define_method(o, "add_polygon",
                     (ruby_method) rbclipper_offset_add_polygon, 1);
    rb_define_method(o, "add_poly_polygon",
                     (ruby_method) rbclipper_offset_add_poly_polygon, 1);
    rb_define_method(o, "clear!",
                     (ruby_method) rbclipper_offset_clear, 0);
    rb_define_method(o, "offset",
                     (ruby_method) rbclipper_offset_execute, 1);
    // geom
    rb_define_module_function(mSkalp, "ccw", VALUEFUNC(ccw),3);
    
    // selection
    rb_define_method(cControlCenter, "cleared_selection", VALUEFUNC(cleared_selection),0);
    rb_define_method(cControlCenter, "changed_selection", VALUEFUNC(changed_selection),1);
    
    // replace section
    rb_define_method(cControlCenter, "replace_section", VALUEFUNC(replace_section),0);
    
    // control center process_queue
    rb_define_method(cControlCenter, "select_action", VALUEFUNC(select_action),1);
    
    // mac testing
    rb_define_module_function(mSkalp, "loadcode_mac", VALUEFUNC(loadcode_mac),0);
    rb_define_module_function(mSkalp, "load_test", VALUEFUNC(loadcode_mac),0);
    rb_define_module_function(mSkalp, "get_mac", VALUEFUNC(get_mac),1);
    rb_define_module_function(mSkalp, "macs", VALUEFUNC(macs),0);
    rb_define_module_function(mSkalp, "id", VALUEFUNC(id),0);
    rb_define_module_function(mSkalp, "get_id", VALUEFUNC(get_id),0);
    rb_define_module_function(mSkalp, "set_id", VALUEFUNC(set_id),0);
    rb_define_module_function(mSkalp, "mac2id", VALUEFUNC(mac2id),1);
    
    // require
    rb_define_module_function(mSkalp, "skalp_requires", VALUEFUNC(skalp_requires),0);
    rb_define_module_function(mSkalp, "skalp_require_dialog", VALUEFUNC(skalp_require_dialog),0);
    rb_define_module_function(mSkalp, "skalp_require_isolate", VALUEFUNC(skalp_require_isolate),0);
    
    rb_define_module_function(mSkalp, "skalp_require_hatch_lib", VALUEFUNC(skalp_require_hatch_lib),0);
    rb_define_module_function(mSkalp, "skalp_require_hatchtile", VALUEFUNC(skalp_require_hatchtile),0);
    rb_define_module_function(mSkalp, "skalp_require_hatch_class", VALUEFUNC(skalp_require_hatch_class),0);
    rb_define_module_function(mSkalp, "skalp_require_hatchdefinition_class", VALUEFUNC(skalp_require_hatchdefinition_class),0);
    rb_define_module_function(mSkalp, "skalp_require_hatchline_class", VALUEFUNC(skalp_require_hatchline_class),0);
    rb_define_module_function(mSkalp, "skalp_require_hatchpatterns_main", VALUEFUNC(skalp_require_hatchpatterns_main),0);
    
    rb_define_module_function(mSkalp, "skalp_require_license", VALUEFUNC(skalp_require_license),0);
    rb_define_module_function(mSkalp, "skalp_require_run", VALUEFUNC(skalp_require_run),0);
    rb_define_module_function(mSkalp, "ready", VALUEFUNC(check_mac),0);
    rb_define_module_function(mSkalp, "check_mac", VALUEFUNC(check_mac),0);
    
}
