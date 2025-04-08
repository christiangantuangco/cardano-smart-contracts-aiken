use cardano/address.{Address}
use cardano/transaction.{Input, OutputReference, Transaction}
use general/types.{PaymentDatum} as general_types
use general/utils.{get_own_input}
use levvy_tokens/fees.{borrow_fees_paid, claim_fees_paid, foreclose_fees_paid}
use levvy_tokens/types.{
  BorrowTokenAction, CancelTokenAction, ClaimTokenAction, ForecloseTokenAction,
  RepayTokenAction, TokenAction, TokenDatum,
}
use levvy_tokens/validation.{borrow, cancel, claim, foreclose, repay}

validator levvy_tokens(main_address: Address, authorize_address: Address) {
  spend(
    datum: Option<TokenDatum>,
    redeemer: TokenAction,
    utxo: OutputReference,
    tx: Transaction,
  ) {
    let own_input: Input = get_own_input(tx, utxo)
    let script_address: Address = own_input.output.address
    let payment_datum =
      PaymentDatum { output_reference: own_input.output_reference }
    // Check redeemer action
    when redeemer is {
      BorrowTokenAction -> {
        expect Some(borrow_datum) = datum
        let is_borrow_success =
          borrow(borrow_datum, tx, script_address, own_input)
        let is_borrow_fees_paid =
          borrow_fees_paid(
            authorize_address,
            borrow_datum,
            tx,
            main_address,
            payment_datum,
          )

        is_borrow_success? && is_borrow_fees_paid?
      }
      RepayTokenAction -> {
        expect Some(repay_datum) = datum
        let is_repay_success =
          repay(repay_datum, tx, script_address, own_input.output_reference)
        is_repay_success?
      }
      ClaimTokenAction -> {
        expect Some(claim_datum) = datum
        let is_claim_success = claim(claim_datum, tx)
        let is_claim_fees_paid =
          claim_fees_paid(
            authorize_address,
            claim_datum,
            tx,
            main_address,
            payment_datum,
          )
        is_claim_success? && is_claim_fees_paid?
      }
      ForecloseTokenAction -> {
        expect Some(foreclose_datum) = datum
        let is_foreclose_success = foreclose(foreclose_datum, tx)
        let is_foreclose_fees_paid =
          foreclose_fees_paid(
            authorize_address,
            foreclose_datum,
            tx,
            main_address,
            payment_datum,
          )
        is_foreclose_success? && is_foreclose_fees_paid?
      }
      CancelTokenAction -> {
        expect Some(cancel_datum) = datum
        cancel(cancel_datum, tx)?
      }
    }
  }

  else(_) {
    fail
  }
}
