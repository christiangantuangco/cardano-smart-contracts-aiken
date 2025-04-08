use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite}
use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId, Value, tokens}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Transaction, ValidityRange,
}
use general/utils as general_utils
use levvy_tokens/types.{
  BorrowOutput, BorrowTokenDatum, LendOutput, LendTokenDatum, PosixTime,
  RepayOutput, RepayTokenDatum, TokenDatum,
}

// Returns true if the value has only ada
pub fn value_has_tokens_and_lovelace(
  val: Value,
  policy: PolicyId,
  asset_name: AssetName,
) -> Bool {
  expect [Pair(policy1, amount1),
    Pair(policy2, amount2)] =
    val
      |> assets.to_dict
      |> dict.to_pairs()

  if policy1 == assets.ada_policy_id {
    // Should always reach here since maps come in ordered on chain
    expect [Pair(token_name, _quantity)] = amount2 |> dict.to_pairs()

    and {
      policy2 == policy,
      token_name == asset_name,
    }
  } else {
    expect [Pair(token_name, _quantity)] = amount1 |> dict.to_pairs()

    and {
      policy1 == policy,
      token_name == asset_name,
    }
  }
}

// Return the valid tokens from the value
pub fn get_policy_value(policy_id: PolicyId, check_value: Value) {
  expect [Pair(check_asset_name, check_amount)] =
    dict.to_pairs(tokens(check_value, policy_id))
  (check_asset_name, check_amount)
}

// We expect outputs to be unique. Each output is tagged with a datum to solve double satisfaction.
pub fn lend_output_paid_to_with_lend_datum(
  tx: Transaction,
  address: Address,
  output_reference: OutputReference,
) -> LendOutput {
  let script_outputs =
    list.filter(
      tx.outputs,
      fn(output) { general_utils.is_payment_key_equal(output.address, address) },
    )
  when
    list.filter(
      script_outputs,
      fn(output) {
        expect InlineDatum(data) = output.datum
        expect datum: TokenDatum = data
        when datum is {
          LendTokenDatum(lend_details) ->
            lend_details.output_reference == output_reference
          _ -> False
        }
      },
    )
  is {
    [output] -> get_lend_output(output)
    _ -> fail
  }
}

pub fn get_lend_output(output: Output) -> LendOutput {
  expect InlineDatum(data) = output.datum
  expect datum: TokenDatum = data
  expect LendTokenDatum(lend_details) = datum

  let lend_output: LendOutput =
    LendOutput { lend_details, lend_value: output.value }
  lend_output
}

// We expect outputs to be unique. Each output is tagged with a datum to solve double satisfaction.
pub fn borrow_output_paid_to_with_borrow_datum(
  tx: Transaction,
  address: Address,
  output_reference: OutputReference,
) -> BorrowOutput {
  let script_outputs =
    list.filter(
      tx.outputs,
      fn(output) { general_utils.is_payment_key_equal(output.address, address) },
    )
  when
    list.filter(
      script_outputs,
      fn(output) {
        expect InlineDatum(data) = output.datum
        expect datum: TokenDatum = data
        when datum is {
          BorrowTokenDatum(borrow_details) ->
            borrow_details.output_reference == output_reference
          _ -> False
        }
      },
    )
  is {
    [output] -> get_borrow_output(output)
    _ -> fail
  }
}

pub fn get_borrow_output(output: Output) -> BorrowOutput {
  expect InlineDatum(data) = output.datum
  expect datum: TokenDatum = data
  expect BorrowTokenDatum(borrow_details) = datum

  let borrow_output: BorrowOutput =
    BorrowOutput { borrow_details, borrow_value: output.value }
  borrow_output
}

/// We expect outputs to be unique. Each output is tagged with a datum to solve double satisfaction.
pub fn repay_output_paid_to_with_repay_datum(
  tx: Transaction,
  address: Address,
  output_reference: OutputReference,
) -> RepayOutput {
  let script_outputs =
    list.filter(
      tx.outputs,
      fn(output) { general_utils.is_payment_key_equal(output.address, address) },
    )
  when
    list.filter(
      script_outputs,
      fn(output) {
        expect InlineDatum(data) = output.datum
        expect datum: TokenDatum = data
        when datum is {
          RepayTokenDatum(repay_details) ->
            repay_details.output_reference == output_reference
          _ -> False
        }
      },
    )
  is {
    [output] -> get_repay_output(output)
    _ -> fail
  }
}

pub fn get_repay_output(output: Output) -> RepayOutput {
  expect InlineDatum(data) = output.datum
  expect datum: TokenDatum = data
  expect RepayTokenDatum(repay_details) = datum

  let repay_output: RepayOutput =
    RepayOutput { repay_details, repay_value: output.value }
  repay_output
}

// General Helper Functions
pub fn calculate_loan_end_time(
  validity_range: ValidityRange,
  loan_duration: Int,
) -> PosixTime {
  when validity_range.lower_bound.bound_type is {
    Finite(now) -> {
      let loan_end_time = now + loan_duration
      loan_end_time
    }
    _ -> fail
  }
}

// Calculate ratio from scale always rounded up
pub fn calculate_ratio(divisor: Int, dividend: Int, scale: Int) -> Int {
  ( divisor * scale + dividend - 1 ) / dividend
}

// Calculate amount from ratio and scale always rounded up
pub fn calculate_from_ratio(amount: Int, ratio: Int, scale: Int) -> Int {
  ( amount * ratio + scale - 1 ) / scale
}

pub fn get_ratio_amount(
  old_token_amount: Int,
  new_token_amount: Int,
  amount: Int,
) -> Int {
  let scale = 1000000
  let ratio = calculate_ratio(new_token_amount, old_token_amount, scale)
  calculate_from_ratio(amount, ratio, scale)
}
