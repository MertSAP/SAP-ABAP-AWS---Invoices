CLASS lsc_zdm_r_invhdrtp DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS adjust_numbers REDEFINITION.

ENDCLASS.

CLASS lsc_zdm_r_invhdrtp IMPLEMENTATION.

  METHOD adjust_numbers.
    DATA: invoice_id_max TYPE zdm_int_invnum.
    IF mapped-invoice IS NOT INITIAL.
      TRY.
          "get numbers
          cl_numberrange_runtime=>number_get(
            EXPORTING
              nr_range_nr       = '01'
              object            = 'ZDM_INVNUM'
              quantity          = CONV #( lines( mapped-invoice ) )
            IMPORTING
              number            = DATA(number_range_key)
              returncode        = DATA(number_range_return_code)
              returned_quantity = DATA(number_range_returned_quantity)
          ).
        CATCH cx_number_ranges INTO DATA(lx_number_ranges).
          RAISE SHORTDUMP TYPE cx_number_ranges
            EXPORTING
              previous = lx_number_ranges.
      ENDTRY.

      ASSERT number_range_returned_quantity = lines( mapped-invoice ).
      invoice_id_max = number_range_key - number_range_returned_quantity.
      LOOP AT mapped-invoice ASSIGNING FIELD-SYMBOL(<invoice>).
        invoice_id_max += 1.
        <invoice>-InvoiceID = invoice_id_max.
      ENDLOOP.
    ENDIF.

    IF mapped-invoiceitem IS NOT INITIAL.
      READ ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
        ENTITY InvoiceItem BY \_Invoice
          FROM VALUE #( FOR invoiceitem IN mapped-invoiceitem WHERE ( %tmp-InvoiceID IS INITIAL )
                                                            ( %pid = invoiceitem-%pid
                                                              %key = invoiceitem-%tmp ) )
        LINK DATA(lineitem_to_invoice_links).

      LOOP AT mapped-invoiceitem ASSIGNING FIELD-SYMBOL(<invoiceitem>).
        <invoiceitem>-InvoiceID =
          COND #( WHEN <invoiceitem>-%tmp-InvoiceID IS INITIAL
                  THEN mapped-invoice[ %pid = lineitem_to_invoice_links[ source-%pid = <invoiceitem>-%pid ]-target-%pid ]-InvoiceID
                  ELSE <invoiceitem>-%tmp-InvoiceID ).
      ENDLOOP.

      LOOP AT mapped-invoiceitem INTO DATA(mapped_invoiceitem) GROUP BY mapped_invoiceitem-InvoiceID.
        SELECT MAX( booking_id ) FROM zrap110_abookSOL WHERE travel_id = @mapped_invoiceitem-InvoiceID INTO @DATA(max_lineitem_id) .
        LOOP AT GROUP mapped_invoiceitem ASSIGNING <invoiceitem>.
          max_lineitem_id += 1.
          <invoiceitem>-ItemNum = max_lineitem_id.
        ENDLOOP.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_Invoice DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Invoice RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Invoice RESULT result.
    METHODS setstatusondraftcreate FOR DETERMINE ON SAVE
      IMPORTING keys FOR invoice~setstatusondraftcreate.
    METHODS approveinvoice FOR MODIFY
      IMPORTING keys FOR ACTION invoice~approveinvoice RESULT result.

    METHODS rejectinvoice FOR MODIFY
      IMPORTING keys FOR ACTION invoice~rejectinvoice RESULT result.
    CONSTANTS:
      "travel status
      BEGIN OF invoice_status,
        notsubmitted  TYPE c LENGTH 1 VALUE '', "Not Submitted
        open     TYPE c LENGTH 1 VALUE 'O', "Open
        approved TYPE c LENGTH 1 VALUE 'A', "Approved
        rejected TYPE c LENGTH 1 VALUE 'R', "Rejected
      END OF invoice_status.
ENDCLASS.

CLASS lhc_Invoice IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
         ENTITY Invoice
            FIELDS ( Status )
            WITH CORRESPONDING #( keys )
          RESULT DATA(invoices)
          FAILED failed.

    " evaluate the conditions, set the operation state, and set result parameter
    result = VALUE #( FOR invoice IN invoices
                       ( %tky                   = invoice-%tky

                   "     %features-%update      = COND #( WHEN invoice-Status <> ''
                                                       "   THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled   )

                        %features-%delete      = COND #( WHEN invoice-Status = invoice_status-open
                                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled   )

                         %action-Edit           =  COND #( WHEN invoice-Status <> invoice_status-notsubmitted
                                                          THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled   )


                         %action-approveInvoice   = COND #( WHEN invoice-Status EQ 'O'
                                                              THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled   )

                         %action-rejectInvoice   = COND #( WHEN invoice-Status EQ 'O'
                                                              THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled   )
                      ) ).


  ENDMETHOD.

  METHOD setStatusOnDraftCreate.
    READ ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
         ENTITY Invoice
           FIELDS ( Status )
           WITH CORRESPONDING #( keys )
         RESULT DATA(invoices).

    DELETE invoices WHERE Status IS NOT INITIAL.
    CHECK invoices IS NOT INITIAL.


    "update involved instances
    MODIFY ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
      ENTITY Invoice
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR invoice IN invoices INDEX INTO i (
                           %tky      = invoice-%tky
                           Status  =  invoice_status-open ) ).

  ENDMETHOD.

  METHOD approveInvoice.
    MODIFY ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
          ENTITY Invoice
             UPDATE FIELDS ( Status )
                WITH VALUE #( FOR key IN keys ( %tky         = key-%tky
                                                Status = invoice_status-approved ) ). " 'A' Approved

    " read changed data for result
    READ ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
      ENTITY Invoice
         ALL FIELDS WITH
         CORRESPONDING #( keys )
       RESULT DATA(invoices).

    result = VALUE #( FOR invoice IN invoices ( %tky = invoice-%tky  %param = invoice ) ).
  ENDMETHOD.

  METHOD rejectInvoice.
    MODIFY ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
          ENTITY Invoice
             UPDATE FIELDS ( Status )
                WITH VALUE #( FOR key IN keys ( %tky         = key-%tky
                                                Status = invoice_status-rejected ) ). " 'A' Approved

    " read changed data for result
    READ ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
      ENTITY Invoice
         ALL FIELDS WITH
         CORRESPONDING #( keys )
       RESULT DATA(invoices).

    result = VALUE #( FOR invoice IN invoices ( %tky = invoice-%tky  %param = invoice ) ).
  ENDMETHOD.

ENDCLASS.
