@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '##GENERATED Invoice Header'
define root view entity ZDM_R_INVHDRTP
  as select from zdm_ainvhdr as Invoice
   composition [0..*] of ZDM_R_INVITMTP  as _InvoiceItems
{
  key invoice_id as InvoiceID,
  ext_invoice_id as ExtInvoiceID,
  status as Status,
  po_num as PoNum,
    case status
        when 'O' then 'Awaiting Approval'
        when 'A' then 'Approved'
        when 'R' then 'Rejected'
        else ''
    end as StatusText,
  invoice_receipt_date as InvoiceReceiptDate,
  due_date as DueDate,
  @Semantics.amount.currencyCode: 'Currency'
  subtotal as Subtotal,
  currency as Currency,
  @Semantics.amount.currencyCode: 'Currency'
  total as Total,
  @Semantics.amount.currencyCode: 'Currency'
  amount_due as AmountDue,
  @Semantics.amount.currencyCode: 'Currency'
  tax as Tax,
  vendor_address as VendorAddress,
  vendor_tax_number as VendorTaxNumber,
  vendor_name as VendorName,
  mimetype as Mimetype,
  filename as Filename,
  tmp_mimetype as TmpMimetype,
  tmp_filename as TmpFilename,
  tmp_attachment as TmpAttachment,
  @Semantics.user.createdBy: true
  local_created_by as LocalCreatedBy,
  @Semantics.systemDateTime.createdAt: true
  local_created_at as LocalCreatedAt,
  @Semantics.user.localInstanceLastChangedBy: true
  local_last_changed_by as LocalLastChangedBy,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  local_last_changed_at as LocalLastChangedAt,
  @Semantics.systemDateTime.lastChangedAt: true
  last_changed_at as LastChangedAt,
  _InvoiceItems
  
}
