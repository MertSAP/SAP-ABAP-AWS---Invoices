@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Projection View for ZDM_R_INVHDRTP'
@ObjectModel.semanticKey: [ 'InvoiceID' ]
define root view entity ZDM_C_INVHDRTP
  provider contract transactional_query
  as projection on ZDM_R_INVHDRTP
{
  key InvoiceID,
  ExtInvoiceID,
  Status,
  StatusText,
  PoNum,
  InvoiceReceiptDate,
  DueDate,
  Subtotal,
  Currency,
  Total,
  AmountDue,
  Tax,
  VendorAddress,
  VendorTaxNumber,
  VendorName,
  Mimetype,
  Filename,
  TmpMimetype,
  TmpFilename,
    @Semantics.largeObject:
                      { mimeType: 'TmpMimetype',
                      fileName: 'TmpFilename',
                      contentDispositionPreference: #INLINE }
  TmpAttachment,
  LocalLastChangedAt,
  _InvoiceItems : redirected to composition child ZDM_C_INVITMTP
}
