CLASS lsc_zdm_r_invhdrtp DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS adjust_numbers REDEFINITION.
    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zdm_r_invhdrtp IMPLEMENTATION.



  METHOD adjust_numbers.
    IF mapped-invoiceitem IS NOT INITIAL.

      DATA: max_item_id TYPE i VALUE 0.

      LOOP AT mapped-invoiceitem  ASSIGNING FIELD-SYMBOL(<item>).
        <item>-InvoiceID = <item>-%tmp-InvoiceID.
        IF max_item_id EQ 0.
          SELECT MAX( item_num ) FROM zdm_ainvitm WHERE invoice_id = @<item>-InvoiceID INTO @max_item_id .
        ENDIF.

        max_item_id += 1.
        <item>-ItemNum = max_item_id.

      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD save_modified.
    IF delete-invoice IS NOT INITIAL.
      SELECT InvoiceID, Filename FROM zdm_r_invhdrtp
      FOR ALL ENTRIES IN @delete-invoice
      WHERE InvoiceID = @delete-invoice-InvoiceID
      INTO TABLE @DATA(lt_filenames).

      LOOP AT lt_filenames INTO DATA(ls_filenames)
       WHERE Filename IS NOT INITIAL.
        TRY.
            DATA(storage_helper) = NEW zdm_cl_aws_invoice_storage( ls_filenames-InvoiceID ).
            storage_helper->delete_object( iv_filename = ls_filenames-filename ).
          CATCH /aws1/cx_rt_technical_generic /aws1/cx_rt_service_generic /aws1/cx_rt_no_auth_generic.
            "handle exception
        ENDTRY.
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
    METHODS uploadtos3 FOR DETERMINE ON SAVE
      IMPORTING keys FOR invoice~uploadtos3.
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE invoice.
    CONSTANTS:
      "travel status
      BEGIN OF invoice_status,
        notsubmitted TYPE c LENGTH 1 VALUE '', "Not Submitted
        open         TYPE c LENGTH 1 VALUE 'O', "Open
        approved     TYPE c LENGTH 1 VALUE 'A', "Approved
        rejected     TYPE c LENGTH 1 VALUE 'R', "Rejected
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
                                                         THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

                        %action-Edit           = COND #( WHEN invoice-Status <> invoice_status-notsubmitted
                                                         THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )


                        %action-approveInvoice = COND #( WHEN invoice-Status EQ 'O'
                                                         THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

                        %action-rejectInvoice  = COND #( WHEN invoice-Status EQ 'O'
                                                         THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
                    ) ).


  ENDMETHOD.

  METHOD setStatusOnDraftCreate.
    READ ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
         ENTITY Invoice
           FIELDS ( Status )
           WITH CORRESPONDING #( keys )
         RESULT DATA(invoices).

    DELETE invoices WHERE Status IS NOT INITIAL.
    IF invoices IS INITIAL.
      RETURN.
    ENDIF.
    "update involved instances
    MODIFY ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
      ENTITY Invoice
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR invoice IN invoices INDEX INTO i (
                      %tky   = invoice-%tky
                      Status = invoice_status-open ) ).

  ENDMETHOD.

  METHOD approveInvoice.
    MODIFY ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
          ENTITY Invoice
             UPDATE FIELDS ( Status )
                WITH VALUE #( FOR key IN keys ( %tky   = key-%tky
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
                WITH VALUE #( FOR key IN keys ( %tky   = key-%tky
                                                Status = invoice_status-rejected ) ). " 'A' Approved

    " read changed data for result
    READ ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
      ENTITY Invoice
         ALL FIELDS WITH
         CORRESPONDING #( keys )
       RESULT DATA(invoices).

    result = VALUE #( FOR invoice IN invoices ( %tky = invoice-%tky  %param = invoice ) ).
  ENDMETHOD.

  METHOD earlynumbering_create.
    DATA: invoice_id_max TYPE zdm_int_invnum.

    " Ensure Travel ID is not set yet (idempotent)- must be checked when BO is draft-enabled
    LOOP AT entities INTO DATA(invoice) WHERE InvoiceID IS NOT INITIAL.
      APPEND CORRESPONDING #( invoice ) TO mapped-invoice.
    ENDLOOP.

    DATA(entities_wo_InvoiceID) = entities.
    DELETE entities_wo_InvoiceID WHERE InvoiceID IS NOT INITIAL.

    " Get Numbers
    TRY.
        cl_numberrange_runtime=>number_get(
          EXPORTING
            nr_range_nr       = '01'
            object            = 'ZDM_INVNUM'
            quantity          = CONV #( lines( entities_wo_InvoiceID ) )
          IMPORTING
            number            = DATA(number_range_key)
            returncode        = DATA(number_range_return_code)
            returned_quantity = DATA(number_range_returned_quantity)
        ).
      CATCH cx_number_ranges INTO DATA(lx_number_ranges).
        LOOP AT entities_wo_InvoiceID INTO invoice.
          APPEND VALUE #( %cid = invoice-%cid
                          %key = invoice-%key
                          %msg = lx_number_ranges
                        ) TO reported-invoice.
          APPEND VALUE #( %cid = invoice-%cid
                          %key = invoice-%key
                        ) TO failed-invoice.
        ENDLOOP.
        EXIT.
    ENDTRY.


    " At this point ALL entities get a number!entities_wo_InvoiceID
    ASSERT number_range_returned_quantity = lines( entities_wo_InvoiceID ).

    invoice_id_max = number_range_key - number_range_returned_quantity.

    " Set Travel ID
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity>).
      invoice_id_max += 1.

      APPEND VALUE #( %cid      = <ls_entity>-%cid
                      %is_draft = <ls_entity>-%is_draft
                      InvoiceID = invoice_id_max
                    ) TO mapped-invoice.
    ENDLOOP.


  ENDMETHOD.

  METHOD uploadToS3.
    READ ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
        ENTITY Invoice ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT FINAL(lt_invoices_entity).

    LOOP AT lt_invoices_entity INTO DATA(invoice_entity)
        WHERE TmpAttachment IS NOT INITIAL.

      DATA(lv_success) = abap_true.


      TRY.
          DATA(storage_helper) = NEW zdm_cl_aws_invoice_storage( invoice_entity-InvoiceID ).
          storage_helper->put_object( iv_filename = invoice_entity-tmpfilename
                                      iv_old_filename = invoice_entity-filename
                                      iv_body = invoice_entity-tmpattachment ).

        CATCH /aws1/cx_rt_technical_generic /aws1/cx_rt_service_generic  /aws1/cx_rt_no_auth_generic.
          "handle exception
          lv_success = abap_false.
      ENDTRY.

      IF lv_success EQ abap_true.
        invoice_entity-Filename = storage_helper->get_filename( invoice_entity-TmpFilename ).
        invoice_entity-Mimetype = invoice_entity-TmpMimetype.
        CLEAR invoice_entity-TmpAttachment.
        CLEAR invoice_entity-TmpMimetype.
        CLEAR invoice_entity-TmpFilename.

        MODIFY ENTITIES OF zdm_r_invhdrtp IN LOCAL MODE
         ENTITY Invoice
         UPDATE FIELDS ( TmpAttachment TmpFilename TmpMimetype Filename Mimetype )
         WITH VALUE #( ( %key = invoice_entity-%key
                         %is_draft = invoice_entity-%is_draft
                         TmpAttachment = invoice_entity-TmpAttachment
                         TmpFilename = invoice_entity-TmpFilename
                         TmpMimetype = invoice_entity-TmpMimetype
                         Filename = invoice_entity-Filename
                         Mimetype = invoice_entity-Mimetype
                         ) ) FAILED DATA(failed_update)
                         REPORTED DATA(reported_update).
      ELSE.
        INSERT VALUE #( %tky                   = invoice_entity-%tky
                         %element-TmpAttachment = if_abap_behv=>mk-on
                         %msg                   = me->new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                                             text     = 'Unable to Store Invoice' ) ) INTO TABLE reported-invoice.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
