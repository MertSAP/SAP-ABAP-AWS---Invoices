CLASS zdm_cl_aws_invoice_storage DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_invoice_id TYPE zdm_int_invnum
                        RAISING
                                  /aws1/cx_rt_technical_generic
                                  /aws1/cx_rt_no_auth_generic
                                  /aws1/cx_rt_service_generic.
    METHODS get_object
      IMPORTING
                iv_filename   TYPE zdm_file_name
      RETURNING VALUE(result) TYPE xstring
      RAISING
                /aws1/cx_rt_technical_generic
                /aws1/cx_rt_service_generic.

    METHODS delete_object
      IMPORTING
        iv_filename TYPE zdm_file_name
      RAISING
        /aws1/cx_rt_technical_generic
        /aws1/cx_rt_service_generic.

    METHODS put_object
      IMPORTING
        iv_filename     TYPE zdm_file_name
        iv_old_filename TYPE zdm_file_name
        iv_body         TYPE xstring
      RAISING
        /aws1/cx_rt_technical_generic
        /aws1/cx_rt_service_generic.

    METHODS get_filename
      IMPORTING
                iv_filename   TYPE zdm_file_name
      RETURNING VALUE(result) TYPE zdm_file_name.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS: cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZINVOICE'.
    CONSTANTS: cv_lres TYPE  /aws1/rt_resource_logical VALUE'ZINVOICE_BUCKET'.
    DATA: bucket     TYPE /aws1/s3_bucketname.
    DATA: o_s3       TYPE REF TO /aws1/if_s3.
    DATA: invoice_id TYPE zdm_int_invnum.
ENDCLASS.



CLASS zdm_cl_aws_invoice_storage IMPLEMENTATION.
  METHOD constructor.
    DATA(go_session) = /aws1/cl_rt_session_aws=>create( cv_pfl   ).
    bucket   = go_session->resolve_lresource( cv_lres ).
    o_s3       = /aws1/cl_s3_factory=>create( go_session ).
    invoice_id = iv_invoice_id.
  ENDMETHOD.

  METHOD get_object.
    DATA(oo_result) = o_s3->getobject(           " oo_result is returned for testing purposes. "
                  iv_bucket = bucket
                  iv_key = CONV /aws1/s3_objectkey( iv_filename ) ).
    result = oo_result->get_body( ).
  ENDMETHOD.


  METHOD delete_object.
    o_s3->deleteobject(  iv_bucket = bucket
                  iv_key = CONV /aws1/s3_objectkey( iv_filename ) ).
  ENDMETHOD.

  METHOD put_object.
    DATA(new_filename) = get_filename( iv_filename = iv_filename ).

    IF iv_old_filename IS NOT INITIAL.
      delete_object( iv_filename = iv_old_filename ).
    ENDIF.

    o_s3->putobject(   iv_bucket = bucket
                  iv_key = CONV /aws1/s3_objectkey( new_filename )
                  iv_body = iv_body ).

  ENDMETHOD.

  METHOD get_filename.
    DATA: lv_ext TYPE string.
    FIND PCRE '\.([^\.]+)$' IN iv_filename SUBMATCHES lv_ext.
    result = |{ invoice_id }.{ lv_ext }|.
  ENDMETHOD.

ENDCLASS.
