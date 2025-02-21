use aiken/collection/list
use cardano/address.{Address, Script, VerificationKey}
use cardano/transaction.{InlineDatum, Output, OutputReference, Transaction}
use types.{Datum, Indexes, TransactionDetails}

pub fn cancel(fee_address: Address, indexes: Indexes, tx: Transaction) {
  let tx_details =
    get_tx_details(indexes.input_index, None, indexes.fee_index, tx)

  // Check if the owner signed the transaction
  let input_datum = get_datum(tx_details.input.output)
  expect VerificationKey(owner_pkh) = input_datum.owner.payment_credential
  let must_be_signed =
    tx.extra_signatories
      |> list.has(owner_pkh)

  // Check if the fees are paid
  let fee_output_address = tx_details.fee_output.address
  expect VerificationKey(fee_output_pkh) = fee_output_address.payment_credential
  expect VerificationKey(fee_pkh) = fee_address.payment_credential
  let is_fees_paid = fee_output_pkh == fee_pkh

  and {
    must_be_signed,
    is_fees_paid,
  }
}

pub fn get_tx_details(
  input_index: Int,
  output_index: Option<Int>,
  fee_index: Int,
  tx: Transaction,
) {
  expect Some(input) =
    tx.inputs
      |> list.at(input_index)

  let output =
    when output_index is {
      Some(index) ->
        tx.outputs
          |> list.at(index)
      None -> None
    }

  expect Some(fee_output) =
    tx.outputs
      |> list.at(fee_index)

  TransactionDetails { input, output, fee_output }
}

pub fn get_datum(output: Output) {
  expect InlineDatum(input_data) = output.datum
  expect input_datum: Datum = input_data
  input_datum
}

pub fn get_validator_hash(tx: Transaction, outref: OutputReference) {
  let inputs = tx.inputs
  let self_inputs =
    inputs |> list.filter(fn(input) { input.output_reference == outref })
  expect Some(self_input) = self_inputs |> list.head()
  expect Script(validator_hash) = self_input.output.address.payment_credential
  validator_hash
}
