use cardano/address.{Address}
use cardano/assets
use cardano/transaction.{Input, OutputReference, Transaction}
use general/utils as general_utils
use levvy_tokens/types.{
  BorrowOutput, BorrowTokenDatum, BorrowTokenDetails, LendOutput, LendTokenDatum,
  LendTokenDetails, RepayOutput, RepayTokenDatum, TokenDatum,
}
use levvy_tokens/utils

pub fn borrow(
  datum: TokenDatum,
  tx: Transaction,
  script_address: Address,
  own_input: Input,
) -> Bool {
  expect LendTokenDatum(lend_details) = datum
  let output_reference = own_input.output_reference

  // Check if the script utxo has enough ada
  let script_utxo_has_enough_ada =
    assets.lovelace_of(own_input.output.value) >= lend_details.loan_amount

  // Get Borrow Output to script address
  let BorrowOutput { borrow_details, borrow_value }: BorrowOutput =
    utils.borrow_output_paid_to_with_borrow_datum(
      tx,
      script_address,
      output_reference,
    )
  let borrow_token_policy_id = borrow_details.policy_id
  let borrow_token_asset_name = borrow_details.asset_name

  let value_has_tokens_and_lovelace =
    utils.value_has_tokens_and_lovelace(
      borrow_value,
      borrow_token_policy_id,
      borrow_token_asset_name,
    )

  // Determine if the script has been paid with the correct number of tokens of the correct policyId
  let token_policy_id = lend_details.policy_id
  let (token_asset_name, token_amount) =
    utils.get_policy_value(token_policy_id, borrow_value)
  let script_output_value_has_asset =
    general_utils.is_asset_label_valid(token_asset_name)

  // Ensure the borrow output is acceptable with the token ratio
  let is_correct_borrow_split =
    borrow_split(lend_details, borrow_details, token_amount)

  // If someone takes less tokens then what is in the Utxo, make sure to put the utxo back on the chain with the correct datum
  let is_token_amount_less_than_lend = token_amount < lend_details.token_amount
  let is_correct_lend_split =
    !is_token_amount_less_than_lend || lend_split(
      tx,
      script_address,
      output_reference,
      lend_details,
      lend_details.token_amount - token_amount,
    )

  // Calculate the loan end time from the tx validity range
  let loan_end_time =
    utils.calculate_loan_end_time(tx.validity_range, lend_details.loan_duration)

  // Ensure the addresses are valid
  let is_ada_owner_valid =
    general_utils.is_address_valid(lend_details.ada_owner)
  let is_asset_owner_valid =
    general_utils.is_address_valid(borrow_details.asset_owner)

  // Ensure the new datum is correct
  let is_correct_ada_owner = borrow_details.ada_owner == lend_details.ada_owner
  let is_correct_policy_id = borrow_token_policy_id == lend_details.policy_id
  let is_correct_asset_name = borrow_token_asset_name == token_asset_name
  let is_loan_amount_positive = borrow_details.loan_amount > 0
  let is_interest_amount_positive = borrow_details.interest_amount > 0
  let is_token_amount_positive = borrow_details.token_amount > 0

  // Ensure our end time is acceptable
  let is_acceptable_loan_end_time =
    loan_end_time >= borrow_details.loan_end_time

  // Determine if we are allowed to borrow the ada
  and {
    script_utxo_has_enough_ada?,
    script_output_value_has_asset?,
    value_has_tokens_and_lovelace?,
    is_ada_owner_valid?,
    is_asset_owner_valid?,
    is_correct_ada_owner?,
    is_correct_policy_id?,
    is_correct_asset_name?,
    is_loan_amount_positive?,
    is_interest_amount_positive?,
    is_token_amount_positive?,
    is_correct_borrow_split?,
    is_correct_lend_split?,
    is_acceptable_loan_end_time?,
  }
}

pub fn lend_split(
  tx: Transaction,
  script_address: Address,
  output_reference: OutputReference,
  previous_lend_details: LendTokenDetails,
  new_token_amount: Int,
) {
  let LendOutput { lend_details, lend_value }: LendOutput =
    utils.lend_output_paid_to_with_lend_datum(
      tx,
      script_address,
      output_reference,
    )

  // Ensure the lend output only has ada
  let value_has_only_lovelace =
    general_utils.value_has_only_lovelace(lend_value)

  // Set Detail Variables
  let detail_loan_amount = lend_details.loan_amount
  let detail_interest_amount = lend_details.interest_amount

  // Get Ratio Variables
  let new_value_loan_amount = assets.lovelace_of(lend_value)
  let previous_token_amount = previous_lend_details.token_amount
  let new_loan_amount =
    utils.get_ratio_amount(
      previous_token_amount,
      new_token_amount,
      previous_lend_details.loan_amount,
    )
  let new_interest_amount =
    utils.get_ratio_amount(
      previous_token_amount,
      new_token_amount,
      previous_lend_details.interest_amount,
    )

  // Make sure the new loan amount and new interest amount are less then 2 ada higher
  let ada_buffer = 2000000
  let max_new_loan_amount = new_loan_amount + ada_buffer
  let max_new_interest_amount = new_interest_amount + ada_buffer

  // 1) Ensure the new loan_amount and interest_amount are the correct ratio
  let is_acceptable_value_loan_amount = and {
      new_value_loan_amount >= new_loan_amount,
      new_value_loan_amount <= max_new_loan_amount,
    }
  let is_acceptable_loan_amount = and {
      detail_loan_amount >= new_loan_amount,
      detail_loan_amount <= max_new_loan_amount,
      detail_loan_amount == new_value_loan_amount,
    }
  let is_acceptable_interest_amount = and {
      detail_interest_amount >= new_interest_amount,
      detail_interest_amount <= max_new_interest_amount,
    }

  // 2) Ensure the rest of the new lend_details are correct
  let is_correct_ada_owner =
    lend_details.ada_owner == previous_lend_details.ada_owner
  let is_correct_policy_id =
    lend_details.policy_id == previous_lend_details.policy_id
  let is_correct_asset_name =
    lend_details.asset_name == previous_lend_details.asset_name
  let is_correct_token_amount = lend_details.token_amount == new_token_amount
  let is_correct_loan_duration =
    lend_details.loan_duration == previous_lend_details.loan_duration

  and {
    value_has_only_lovelace?,
    is_acceptable_value_loan_amount?,
    is_acceptable_loan_amount?,
    is_acceptable_interest_amount?,
    is_correct_ada_owner?,
    is_correct_policy_id?,
    is_correct_asset_name?,
    is_correct_token_amount?,
    is_correct_loan_duration?,
  }
}

pub fn borrow_split(
  previous_lend_details: LendTokenDetails,
  new_borrow_details: BorrowTokenDetails,
  new_token_amount: Int,
) {
  let previous_token_amount = previous_lend_details.token_amount
  let new_loan_amount =
    utils.get_ratio_amount(
      previous_token_amount,
      new_token_amount,
      previous_lend_details.loan_amount,
    )
  let new_interest_amount =
    utils.get_ratio_amount(
      previous_token_amount,
      new_token_amount,
      previous_lend_details.interest_amount,
    )

  // Ensure the new token_amount, loan_amount, and interest_amount are the correct ratio
  let is_correct_token_amount =
    new_borrow_details.token_amount == new_token_amount
  let is_correct_loan_amount = new_borrow_details.loan_amount == new_loan_amount
  let is_correct_interest_amount =
    new_borrow_details.interest_amount == new_interest_amount

  and {
    is_correct_token_amount?,
    is_correct_loan_amount?,
    is_correct_interest_amount?,
  }
}

pub fn repay(
  datum: TokenDatum,
  tx: Transaction,
  script_address: Address,
  output_reference: OutputReference,
) {
  expect BorrowTokenDatum(borrow_details) = datum

  // Ensure the script address is getting the repay amount
  let RepayOutput { repay_details, repay_value }: RepayOutput =
    utils.repay_output_paid_to_with_repay_datum(
      tx,
      script_address,
      output_reference,
    )

  // Set Repay Variables
  let borrow_details_loan_amount = borrow_details.loan_amount
  let borrow_details_interest_amount = borrow_details.interest_amount

  let value_has_only_lovelace =
    general_utils.value_has_only_lovelace(repay_value)

  // Check valid repay amount
  let repay_amount = assets.lovelace_of(repay_value)
  let is_repay_amount_valid =
    repay_amount >= borrow_details_loan_amount + borrow_details_interest_amount

  // Ensure that tx is signed by the asset owner
  // This allows us to extend the loan by borrowing and repaying at the same time
  // While also ensuring that we can send the correct datum for the asset back to the smart contract
  let is_tx_signed_by_asset_owner =
    general_utils.tx_signed_by_address(tx, borrow_details.asset_owner)

  // Ensure the new datum is correct
  let is_correct_ada_owner = repay_details.ada_owner == borrow_details.ada_owner
  let is_correct_token_amount =
    repay_details.token_amount == borrow_details.token_amount
  let is_correct_loan_amount =
    repay_details.loan_amount == borrow_details_loan_amount
  let is_correct_interest_amount =
    repay_details.interest_amount == borrow_details_interest_amount

  and {
    is_repay_amount_valid?,
    is_tx_signed_by_asset_owner?,
    value_has_only_lovelace?,
    is_correct_ada_owner?,
    is_correct_token_amount?,
    is_correct_loan_amount?,
    is_correct_interest_amount?,
  }
}

pub fn claim(datum: TokenDatum, tx: Transaction) {
  expect RepayTokenDatum(repay_details) = datum
  let tx_signed_by_ada_owner =
    general_utils.tx_signed_by_address(tx, repay_details.ada_owner)
  tx_signed_by_ada_owner?
}

pub fn foreclose(datum: TokenDatum, tx: Transaction) {
  expect BorrowTokenDatum(borrow_details) = datum

  // Tx must be signed by the ada owner
  let tx_signed_by_ada_owner =
    general_utils.tx_signed_by_address(tx, borrow_details.ada_owner)

  // Tx validity window must be after the borrow_detaills end time
  let loan_ended =
    general_utils.tx_submitted_after(
      tx.validity_range,
      borrow_details.loan_end_time,
    )

  and {
    tx_signed_by_ada_owner?,
    loan_ended?,
  }
}

pub fn cancel(datum: TokenDatum, tx: Transaction) {
  expect LendTokenDatum(lend_details) = datum
  let tx_signed_by_ada_owner =
    general_utils.tx_signed_by_address(tx, lend_details.ada_owner)
  tx_signed_by_ada_owner?
}
