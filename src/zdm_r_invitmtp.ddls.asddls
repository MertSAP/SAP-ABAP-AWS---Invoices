@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Invoice Item Interface View'
define view entity ZDM_R_INVITMTP as select from zdm_ainvitm
association        to parent ZDM_R_INVHDRTP as _Invoice        on  $projection.InvoiceID = _Invoice.InvoiceID
{
    key invoice_id as InvoiceID,
    key item_num as ItemNum,
    quantity as Quantity,
    description as Description,
    @Semantics.amount.currencyCode: 'Currency'
    unit_price as UnitPrice,
    @Semantics.amount.currencyCode: 'Currency'
    line_price as LinePrice,
    currency as Currency,
    local_last_changed_at as LocalLastChangedAt,
    _Invoice
}
