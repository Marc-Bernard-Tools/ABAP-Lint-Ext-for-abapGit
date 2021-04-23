CLASS zcl_abaplint_abapgit_ext_ui DEFINITION
  PUBLIC
  INHERITING FROM zcl_abapgit_gui_component
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    INTERFACES zif_abapgit_gui_event_handler .
    INTERFACES zif_abapgit_gui_renderable .

    CLASS-METHODS create
      IMPORTING
        !iv_key        TYPE zif_abapgit_persistence=>ty_repo-key
        !iv_check_run  TYPE string
      RETURNING
        VALUE(ri_page) TYPE REF TO zif_abapgit_gui_renderable
      RAISING
        zcx_abapgit_exception .
    METHODS constructor
      IMPORTING
        !iv_key       TYPE zif_abapgit_persistence=>ty_repo-key OPTIONAL
        !iv_check_run TYPE string OPTIONAL
      RAISING
        zcx_abapgit_exception .
  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF c_mode,
        no_source   TYPE i VALUE 0,
        with_source TYPE i VALUE 1,
      END OF c_mode.

    CONSTANTS:
      BEGIN OF c_action,
        go_back TYPE string VALUE 'go_back',
        sort_1  TYPE string VALUE 'sort_1',
        sort_2  TYPE string VALUE 'sort_2',
        sort_3  TYPE string VALUE 'sort_3',
        jump    TYPE string VALUE 'jump',
      END OF c_action .
    DATA mv_mode TYPE i .
    DATA mo_repo TYPE REF TO zcl_abapgit_repo_online .
    DATA mv_check_run TYPE string .
    DATA mt_annotations TYPE zcl_abaplint_abapgit_ext_annot=>ty_annotations .

    METHODS _render_source
      IMPORTING
        !is_issue      TYPE zcl_abaplint_abapgit_ext_issue=>ty_issue
      RETURNING
        VALUE(ri_html) TYPE REF TO zif_abapgit_html .
    METHODS _render_annotations
      RETURNING
        VALUE(ri_html) TYPE REF TO zif_abapgit_html
      RAISING
        zcx_abapgit_exception .
    METHODS _render_annotation
      IMPORTING
        !is_annotation TYPE zcl_abaplint_abapgit_ext_annot=>ty_annotation
      RETURNING
        VALUE(ri_html) TYPE REF TO zif_abapgit_html
      RAISING
        zcx_abapgit_exception .
    CLASS-METHODS _build_menu
      RETURNING
        VALUE(ro_menu) TYPE REF TO zcl_abapgit_html_toolbar .
ENDCLASS.



CLASS zcl_abaplint_abapgit_ext_ui IMPLEMENTATION.


  METHOD constructor.

    DATA lo_annotations TYPE REF TO zcl_abaplint_abapgit_ext_annot.

    super->constructor( ).

    IF iv_key IS INITIAL.
      zcx_abapgit_exception=>raise( 'No repository key supplied' ).
    ELSE.
      mo_repo ?= zcl_abapgit_repo_srv=>get_instance( )->get( iv_key ).
    ENDIF.

    IF iv_check_run IS INITIAL.
      zcx_abapgit_exception=>raise( 'No check run supplied' ).
    ELSE.
      mv_check_run = iv_check_run.
    ENDIF.

    CREATE OBJECT lo_annotations
      EXPORTING
        iv_url       = mo_repo->get_url( )
        iv_check_run = mv_check_run.

    mt_annotations = lo_annotations->get( ).

    mv_mode = c_mode-with_source.

  ENDMETHOD.


  METHOD create.

    DATA lo_component TYPE REF TO zcl_abaplint_abapgit_ext_ui.

    CREATE OBJECT lo_component
      EXPORTING
        iv_key       = iv_key
        iv_check_run = iv_check_run.

    ri_page = zcl_abapgit_gui_page_hoc=>create(
      iv_page_title      = 'abaplint Annotations'
      io_page_menu       = _build_menu( )
      ii_child_component = lo_component ).

  ENDMETHOD.


  METHOD zif_abapgit_gui_event_handler~on_event.

    DATA:
      lv_program TYPE progname,
      lv_line    TYPE i.

    CASE ii_event->mv_action.
      WHEN c_action-go_back.

        rs_handled-state = zcl_abapgit_gui=>c_event_state-go_back.

      WHEN c_action-jump.

        lv_program = ii_event->query( )->get( 'PROGRAM' ).
        lv_line    = ii_event->query( )->get( 'LINE' ).

        CALL FUNCTION 'RS_TOOL_ACCESS'
          EXPORTING
            operation           = 'SHOW'
            object_name         = lv_program
            object_type         = 'PROG'
            include             = lv_program
            position            = lv_line
            in_new_window       = abap_false
          EXCEPTIONS
            not_executed        = 1
            invalid_object_type = 2
            OTHERS              = 3.
        IF sy-subrc <> 0.
          zcx_abapgit_exception=>raise_t100( ).
        ENDIF.

        rs_handled-state = zcl_abapgit_gui=>c_event_state-no_more_act.

      WHEN c_action-sort_1.
        "SORT mt_result BY objtype objname test code sobjtype sobjname line col.
        rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
      WHEN c_action-sort_2.
        "SORT mt_result BY objtype objname sobjtype sobjname line col test code.
        rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
      WHEN c_action-sort_3.
        "SORT mt_result BY test code objtype objname sobjtype sobjname line col.
        rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.

    ENDCASE.

  ENDMETHOD.


  METHOD zif_abapgit_gui_renderable~render.

    gui_services( )->register_event_handler( me ).

    CREATE OBJECT ri_html TYPE zcl_abapgit_html.

    ri_html->add( `<div class="repo">` ).
    ri_html->add( zcl_abapgit_gui_chunk_lib=>render_repo_top(
                    io_repo               = mo_repo
                    iv_show_commit        = abap_false
                    iv_interactive_branch = abap_false ) ).
    ri_html->add( `</div>` ).

    ri_html->add( _render_annotations( ) ).

  ENDMETHOD.


  METHOD _build_menu.

    DATA:
      lo_sort_menu TYPE REF TO zcl_abapgit_html_toolbar.

    CREATE OBJECT lo_sort_menu.

    lo_sort_menu->add(
      iv_txt = 'By Object, Check, Sub-object'
      iv_act = c_action-sort_1
    )->add(
      iv_txt = 'By Object, Sub-object, Line'
      iv_act = c_action-sort_2
    )->add(
      iv_txt = 'By Check, Object, Sub-object'
      iv_act = c_action-sort_3 ).

    CREATE OBJECT ro_menu.

    ro_menu->add(
      iv_txt = 'Sort'
      io_sub = lo_sort_menu
    )->add(
      iv_txt = 'Back'
      iv_act = zif_abapgit_definitions=>c_action-go_back ).

  ENDMETHOD.


  METHOD _render_annotation.

    DATA:
      lo_issue    TYPE REF TO zcl_abaplint_abapgit_ext_issue,
      ls_issue    TYPE zcl_abaplint_abapgit_ext_issue=>ty_issue,
      ls_mtdkey   TYPE seocpdkey,
      lv_class    TYPE string,
      lv_icon     TYPE string,
      lv_obj_text TYPE string,
      lv_obj_link TYPE string,
      lv_msg_text TYPE string,
      lv_msg_link TYPE string.

    CREATE OBJECT ri_html TYPE zcl_abapgit_html.

    CREATE OBJECT lo_issue
      EXPORTING
        iv_path = is_annotation-path
        iv_line = is_annotation-start_line.

    ls_issue = lo_issue->get( ).

    CASE is_annotation-annotation_level.
      WHEN 'failure'.
        lv_class = 'ci-error'.
        lv_icon  = ri_html->icon(
          iv_name = 'exclamation-circle/red'
          iv_hint = 'Failure' ).
      WHEN 'warning'.
        lv_class = 'ci-warning'.
        lv_icon  = ri_html->icon(
          iv_name = 'exclamation-triangle/yellow'
          iv_hint = 'Warning' ).
      WHEN OTHERS.
        lv_class = 'ci-info'.
    ENDCASE.

    CASE ls_issue-obj_type.
      WHEN 'CLAS'.
        CASE to_lower( ls_issue-obj_subtype ).
          WHEN zif_abapgit_oo_object_fnc=>c_parts-locals_def.
            lv_obj_text = |CLAS { ls_issue-obj_name } : Local Definitions|.
          WHEN zif_abapgit_oo_object_fnc=>c_parts-locals_imp.
            lv_obj_text = |CLAS { ls_issue-obj_name } : Local Implementations|.
          WHEN zif_abapgit_oo_object_fnc=>c_parts-macros.
            lv_obj_text = |CLAS { ls_issue-obj_name } : Macros|.
          WHEN zif_abapgit_oo_object_fnc=>c_parts-testclasses.
            lv_obj_text = |CLAS { ls_issue-obj_name } : Test Classes|.
          WHEN OTHERS.
            cl_oo_classname_service=>get_method_by_include(
              EXPORTING
                incname             = ls_issue-program
              RECEIVING
                mtdkey              = ls_mtdkey
              EXCEPTIONS
                class_not_existing  = 1
                method_not_existing = 2
                OTHERS              = 3 ).
            IF sy-subrc = 0.
              lv_obj_text = |CLAS { ls_issue-obj_name }->{ ls_mtdkey-cpdname }|.
            ELSE.
              lv_obj_text = |CLAS { ls_issue-obj_name }|.
            ENDIF.
        ENDCASE.
      WHEN 'FUGR'.
        lv_obj_text = |FUGR { ls_issue-obj_name } { ls_issue-obj_subtype }|.
      WHEN OTHERS.
        lv_obj_text = |{ ls_issue-obj_type } { ls_issue-obj_name }|.
    ENDCASE.

    lv_msg_text = escape(
      val    = is_annotation-title
      format = cl_abap_format=>e_html_text ).

    lv_msg_link = ri_html->a(
      iv_txt   = ri_html->icon( 'file-alt' )
      iv_act   = |{ zif_abapgit_definitions=>c_action-url }?url={ is_annotation-message }|
      iv_class = 'url' ).

    lv_obj_text = |{ lv_obj_text } [ @{ ls_issue-line } ]|.
    lv_obj_link = |{ c_action-jump }?program={ ls_issue-program }&line={ ls_issue-line }|.

    ri_html->add( |<li class="{ lv_class }">| ).
    ri_html->add_a(
      iv_txt = lv_obj_text
      iv_act = lv_obj_link
      iv_typ = zif_abapgit_html=>c_action_type-sapevent ).
    ri_html->add( |<span>{ lv_msg_link } { lv_msg_text }</span>| ).

    IF mv_mode = c_mode-with_source.
      ri_html->add( _render_source( ls_issue ) ).
    ENDIF.

    ri_html->add( |</li>| ).

  ENDMETHOD.


  METHOD _render_annotations.

    CONSTANTS lc_limit TYPE i VALUE 200.

    FIELD-SYMBOLS <ls_annotation> LIKE LINE OF mt_annotations.

    CREATE OBJECT ri_html TYPE zcl_abapgit_html.

    ri_html->add( '<div class="ci-result">' ).

    LOOP AT mt_annotations ASSIGNING <ls_annotation> TO lc_limit.

      ri_html->add( _render_annotation( <ls_annotation> ) ).

    ENDLOOP.

    ri_html->add( '</div>' ).

    IF lines( mt_annotations ) = 0.
      ri_html->add( '<div class="dummydiv success">' ).
      ri_html->add( ri_html->icon( 'check' ) ).
      ri_html->add( 'No abaplint findings' ).
      ri_html->add( '</div>' ).
    ELSEIF lines( mt_annotations ) > lc_limit.
      ri_html->add( '<div class="dummydiv warning">' ).
      ri_html->add( ri_html->icon( 'exclamation-triangle' ) ).
      ri_html->add( |Only first { lc_limit } findings shown in list| ).
      ri_html->add( '</div>' ).
    ENDIF.

  ENDMETHOD.


  METHOD _render_source.

    CONSTANTS c_lines TYPE i VALUE 5.

    DATA:
      lv_source LIKE LINE OF is_issue-source,
      lv_line   TYPE i.

    CREATE OBJECT ri_html TYPE zcl_abapgit_html.

    ri_html->add( '<div class="diff_content">' ).
    ri_html->add( '<table class="diff_tab syntax-hl" i>' ).
    ri_html->add( '<thead class="nav_line">' ).
    ri_html->add( '<tr>' ).
    ri_html->add( '<th class="num"></th>' ).
    ri_html->add( '<th></th>' ).
    ri_html->add( '</tr>' ).
    ri_html->add( '</thead>' ).

    LOOP AT is_issue-source INTO lv_source FROM ( is_issue-line - c_lines ) TO ( is_issue-line + c_lines ).
      lv_line = sy-tabix.
      lv_source = escape(
        val = lv_source
        format = cl_abap_format=>e_html_text ).
      ri_html->add( '<tr>' ).
      IF lv_line = is_issue-line.
        ri_html->add( |<td class="num diff_del">{ lv_line }</td><td class="code diff_del">{ lv_source }</td>| ).
      ELSE.
        ri_html->add( |<td class="num diff_others">{ lv_line }</td><td class="code diff_others">{ lv_source }</td>| ).
      ENDIF.
      ri_html->add( '</tr>' ).
    ENDLOOP.

    ri_html->add( '</table>' ).
    ri_html->add( '</div>' ).

  ENDMETHOD.
ENDCLASS.
