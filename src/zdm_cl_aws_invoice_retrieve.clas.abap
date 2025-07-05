CLASS zdm_cl_aws_invoice_retrieve DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zdm_cl_aws_invoice_retrieve IMPLEMENTATION.
  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA: lt_orginal_data type standard Table of zdm_c_invhdrtp.
    lt_orginal_data = CORRESPONDING #( it_original_data ).

    LOOP at lt_orginal_data ASSIGNING FIELD-SYMBOL(<original_data>).
        IF <original_data>-Filename is not INITIAL.

            TRY.
                DATA(storage_helper) = new zdm_cl_aws_invoice_storage( <original_data>-InvoiceID ).
                <original_data>-attachment = storage_helper->get_object( iv_filename = <original_data>-filename ).
              CATCH /aws1/cx_rt_technical_generic /aws1/cx_rt_service_generic /AWS1/CX_RT_NO_AUTH_GENERIC.
                "handle exception
            ENDTRY.

        endif.
        ct_calculated_data = CORRESPONDING #( lt_orginal_data ).
    ENDLOOP.

  ENDMETHOD.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.

  ENDMETHOD.

ENDCLASS.
