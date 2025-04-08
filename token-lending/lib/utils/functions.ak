use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use aiken/interval.{Finite}
use cardano/address.{Address, PaymentCredential, Script, VerificationKey}
use cardano/assets.{AssetName, PolicyId, Value, tokens}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Transaction, ValidityRange,
}
use levvy/token_lending/types.{
  CollateralDetails, LevvyDatum, LevvyType, NFTs, Tokens,
}
use utils/types.{TransactionDetails} as utils_types

pub fn get_ratio_amount(
  old_token_amount: Int,
  new_token_amount: Int,
  amount: Int,
) -> Int {
  let scale = 1000000
  let ratio = calculate_ratio(new_token_amount, old_token_amount, scale)
  calculate_from_ratio(amount, ratio, scale)
}

pub fn calculate_ratio(divisor: Int, dividend: Int, scale: Int) -> Int {
  ( divisor * scale + dividend - 1 ) / dividend
}

pub fn calculate_from_ratio(amount: Int, ratio: Int, scale: Int) -> Int {
  ( amount * ratio + scale - 1 ) / scale
}

pub fn get_validator_hash(tx: Transaction, outref: OutputReference) {
  let inputs = tx.inputs
  expect Some(self_input) =
    inputs |> list.find(fn(input) { input.output_reference == outref })
  expect Script(validator_hash) = self_input.output.address.payment_credential
  validator_hash
}

pub fn get_transaction_details(
  input_index: Int,
  output_index: Int,
  fee_output_index: Option<Int>,
  script_change_output_index: Option<Int>,
  tx: Transaction,
) {
  expect Some(self_input) =
    tx.inputs
      |> list.at(input_index)
  expect Some(self_output) =
    tx.outputs
      |> list.at(output_index)
  let fee_output =
    when fee_output_index is {
      Some(index) -> tx.outputs |> list.at(index)
      None -> None
    }

  let change_output =
    when script_change_output_index is {
      Some(index) ->
        tx.outputs
          |> list.at(index)
      None -> None
    }

  TransactionDetails { self_input, self_output, fee_output, change_output }
}

pub fn is_payment_key_equal(address_1: Address, address_2: Address) {
  let payment_key_1 = address_1.payment_credential
  let payment_key_2 = address_2.payment_credential
  payment_key_1 == payment_key_2
}

pub fn tx_signed_by_address(tx: Transaction, owner: Address) -> Bool {
  when owner.payment_credential is {
    VerificationKey(keyhash) -> tx_signed_by_key(tx, keyhash)
    Script(_) as payment_credential -> signed_with_input(tx, payment_credential)
  }
}

pub fn tx_signed_by_key(tx: Transaction, keyhash: VerificationKeyHash) -> Bool {
  list.has(tx.extra_signatories, keyhash)
}

pub fn signed_with_input(
  tx: Transaction,
  script_credential: PaymentCredential,
) -> Bool {
  list.any(
    tx.inputs,
    fn(input) { input.output.address.payment_credential == script_credential },
  )
}

pub fn calculate_loan_end_time(
  validity_range: ValidityRange,
  loan_duration: Int,
) {
  when validity_range.lower_bound.bound_type is {
    Finite(now) -> {
      let loan_end_time = now + loan_duration
      loan_end_time
    }
    _ -> fail
  }
}

pub fn tx_submitted_after(range: ValidityRange, time: Int) -> Bool {
  when range.lower_bound.bound_type is {
    Finite(now) -> now > time
    _ -> False
  }
}

pub fn calculate_platform_fee(amount: Int, fee_percent: Int) {
  let fee = amount * fee_percent / 1000
  fee
}

pub fn get_levvy_datum(output: Output) {
  expect InlineDatum(input_data) = output.datum
  expect input_datum: LevvyDatum = input_data
  input_datum
}

pub fn verify_collateral_details(
  input_details: CollateralDetails,
  output_details: CollateralDetails,
  levvy_type: LevvyType,
) {
  let is_policy_id_same = input_details.policy_id == output_details.policy_id
  let is_asset_name_same =
    when levvy_type is {
      Tokens -> input_details.asset_name == output_details.asset_name
      NFTs -> True
    }
  let is_collateral_amount_positive = output_details.collateral_amount > 0
  and {
    is_policy_id_same?,
    is_asset_name_same?,
    is_collateral_amount_positive?,
  }
}

pub fn get_collateral_value(
  policy_id: PolicyId,
  asset_name: AssetName,
  val: Value,
  levvy_type: LevvyType,
) -> Int {
  expect Some(token) =
    tokens(val, policy_id)
      |> dict.to_pairs()
      |> list.filter(
          fn(Pair(name, _amount)) {
            when levvy_type is {
              Tokens -> name == asset_name
              NFTs -> True
            }
          },
        )
      |> list.head()
  token.2nd
}
