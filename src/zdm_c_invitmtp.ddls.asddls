@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Invoice Items Projection View'
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.semanticKey: [ 'ItemNum' ]
define view entity ZDM_C_INVITMTP as projection on ZDM_R_INVITMTP
{
    key InvoiceID,
    key ItemNum,
    Quantity,
    Description,
     @Semantics.amount.currencyCode: 'Currency' 
    UnitPrice,
    @Semantics.amount.currencyCode: 'Currency'
    LinePrice,
    Currency,
    LocalLastChangedAt,
    /* Associations */
   _Invoice: redirected to parent ZDM_C_INVHDRTP
}
