use aiken/cbor
use aiken/crypto.{Blake2b_256, Hash}
use cardano/address.{Address}
use cardano/assets.{lovelace_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use levvy/token_lending/types.{
  BorrowDatum, BorrowDetails, CollateralDetails, LendDatum, LendDetails,
  LevvyDatum, LevvyType, NFTs, OutputIndexes, Tokens,
}
use utils/functions.{
  calculate_loan_end_time, calculate_platform_fee, get_collateral_value,
  get_levvy_datum, get_ratio_amount, get_transaction_details,
  is_payment_key_equal, tx_signed_by_address, tx_submitted_after,
  verify_collateral_details,
}
use utils/types.{TransactionDetails} as utils_types

pub fn borrow(
  input_index: Int,
  output_indexes: OutputIndexes,
  platform_address: Address,
  levvy_type: LevvyType,
  tx: Transaction,
) {
  // Extract transaction details.
  let transaction_details =
    get_transaction_details(
      input_index,
      output_indexes.self_output_index,
      output_indexes.fee_output_index,
      output_indexes.change_index,
      tx,
    )
  let self_input = transaction_details.self_input
  let borrow_output = transaction_details.self_output
  let fee_output = transaction_details.fee_output
  let change_output = transaction_details.change_output
  let script_address = self_input.output.address

  // Retrieve lend and borrow datums
  expect LendDatum(lend_details) = get_levvy_datum(self_input.output)
  expect BorrowDatum(borrow_details) = get_levvy_datum(borrow_output)

  // Make sure that the platform fee output is present
  // since borrowing requires paying fees to the platform
  expect Some(fee_output) = fee_output

  // hash of the input's outref to match with the borrow datum and fee datum
  // this is necessary to prevent double satisfaction
  let datum_tag =
    self_input.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  // extract the collateral policy id and asset name from the lend datum
  let lend_collateral_policy_id = lend_details.collateral_details.policy_id
  let lend_collateral_asset_name = lend_details.collateral_details.asset_name

  // calculate the platform fee that need to be paid based on the loan type
  let platform_fee =
    when levvy_type is {
      Tokens ->
        calculate_platform_fee(
          borrow_details.interest_amount,
          types.tokens_fee_percent,
        )
      NFTs ->
        calculate_platform_fee(
          borrow_details.loan_amount,
          types.nfts_fee_percent,
        ) / 2
    }

  // Make sure that the levvy type in the lend and borrow datums is the same with the levvy type specified in the redeemer
  // This is to ensure that the correct calculations are done based on the levvy type
  let is_levvy_type_correct = and {
      lend_details.levvy_type == levvy_type,
      borrow_details.levvy_type == levvy_type,
    }

  // Verify that the input UTXO contains enough ADA to cover the loan specified in the datum.
  // We need to add the platform fee since the lender needs to pay for platform fees.
  let is_lend_position_valid =
    lovelace_of(self_input.output.value) >= lend_details.loan_amount + platform_fee

  // Check that the lender in the borrow datum matches the lend datum
  let is_lender_correct = borrow_details.lender == lend_details.lender

  // Ensure that borrow output is sent to validator address
  let is_borrow_output_sent_to_validator =
    borrow_output.address == script_address

  // Checks if the output contains the collateral specified in the lend datum and retrieves it
  let borrow_output_collateral_amount =
    get_collateral_value(
      lend_collateral_policy_id,
      lend_collateral_asset_name,
      borrow_output.value,
      levvy_type,
    )

  // Verify if the collateral details specified in the borrow datum matches the lend datum
  let is_collateral_valid =
    verify_collateral_details(
      lend_details.collateral_details,
      borrow_details.collateral_details,
      levvy_type,
    )

  let is_split_correct =
    when levvy_type is {
      Tokens -> {
        // Calculates the expected loan, interest, and collateral amounts,
        // then verifies that the borrow datum details match these computed values.
        let is_borrow_split_correct =
          is_borrow_split_correct(
            lend_details,
            borrow_details,
            borrow_output_collateral_amount,
          )

        // Checks if the collateral amount in the borrow output is less than the collateral amount in the lend datum
        let is_partial_borrow =
          borrow_output_collateral_amount < lend_details.collateral_details.collateral_amount

        // In the case of partial loans (i.e., when the borrow amount is less than the total loan to be consumed),
        // this verifies that the split is correct.
        let is_lend_split_correct =
          !is_partial_borrow || is_lend_split_correct(
            change_output,
            lend_details,
            lend_details.collateral_details.collateral_amount - borrow_output_collateral_amount,
            script_address,
            levvy_type,
          )

        and {
          is_borrow_split_correct,
          is_lend_split_correct,
        }
      }
      // For NFTs, there is no calculation to be done as long as there is asset in the output
      // that matches the collateral required by the lend datum.
      NFTs -> and {
          borrow_output_collateral_amount > 0,
          lend_details.loan_amount == borrow_details.loan_amount,
          lend_details.interest_amount == borrow_details.interest_amount,
        }
    }

  // Applying datum tagging to prevent double satisfaction
  let is_datum_tag_correct = datum_tag == borrow_details.tag

  // Calculates the loan end time based on the validity range and loan duration
  let loan_end_time =
    calculate_loan_end_time(tx.validity_range, lend_details.loan_duration)

  // Verifies that the calculated loan end time is greater than or
  // equal to the loan end time specified in the borrow datum
  let is_loan_end_time_acceptable =
    loan_end_time >= borrow_details.loan_end_time

  // Verifies that the necessary fees have been paid to the platform
  let is_fees_paid =
    is_fees_paid(
      borrow_output,
      fee_output,
      datum_tag,
      levvy_type,
      platform_address,
    )

  and {
    is_levvy_type_correct?,
    is_lend_position_valid?,
    is_borrow_output_sent_to_validator?,
    is_lender_correct?,
    is_collateral_valid?,
    is_split_correct?,
    is_datum_tag_correct?,
    is_loan_end_time_acceptable?,
    is_fees_paid?,
  }
}

pub fn repay(input_index: Int, output_indexes: OutputIndexes, tx: Transaction) {
  // Extract transaction details.
  let tx_details =
    get_transaction_details(
      input_index,
      output_indexes.self_output_index,
      output_indexes.fee_output_index,
      output_indexes.change_index,
      tx,
    )
  let self_input = tx_details.self_input
  let repay_output = tx_details.self_output

  // Retrieve borrow datum
  expect BorrowDatum(borrow_details) = get_levvy_datum(self_input.output)

  // Make sure that the platform fee output is present
  // since foreclosures requires paying fees to the platform
  // datum tag is used to prevent double satisfcation when paying fees
  let datum_tag =
    self_input.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  // Extract the repayment amount from the output
  let repay_amount = assets.lovelace_of(repay_output.value)

  // Validate the repayment amount
  // The repayment amount must be at least equal to the total amount borrowed + the interest amount
  let is_repay_amount_valid =
    repay_amount >= borrow_details.loan_amount + borrow_details.interest_amount

  // Check if the repayment amount is sent to the lender
  let is_repay_amount_paid_to_owner =
    repay_output.address == borrow_details.lender

  // Applying datum tagging to prevent double satisfaction
  expect InlineDatum(repay_datum) = repay_output.datum
  expect repay_datum: Hash<Blake2b_256, OutputReference> = repay_datum
  let is_datum_tag_correct = repay_datum == datum_tag

  // Check if the transaction is signed by the borrower
  let is_tx_signed_by_borrower =
    tx_signed_by_address(tx, borrow_details.borrower)

  and {
    is_repay_amount_valid?,
    is_repay_amount_paid_to_owner?,
    is_datum_tag_correct?,
    is_tx_signed_by_borrower?,
  }
}

pub fn foreclose(
  input_index: Int,
  output_indexes: OutputIndexes,
  levvy_type: LevvyType,
  tx: Transaction,
) {
  // Extract transaction details.
  let tx_details =
    get_transaction_details(
      input_index,
      output_indexes.self_output_index,
      output_indexes.fee_output_index,
      output_indexes.change_index,
      tx,
    )
  let self_input = tx_details.self_input
  let foreclose_output = tx_details.self_output

  // Retrieve borrow datum and payment datum
  expect BorrowDatum(borrow_details) = get_levvy_datum(self_input.output)

  // Retrieve the collateral policy id and asset name from the borrow datum
  let borrow_collateral_policy_id = borrow_details.collateral_details.policy_id
  let borrow_collateral_asset_name =
    borrow_details.collateral_details.asset_name

  // Checks if the output contains the collateral specified in the lend datum and retrieves it
  let output_collateral_amount =
    get_collateral_value(
      borrow_collateral_policy_id,
      borrow_collateral_asset_name,
      foreclose_output.value,
      levvy_type,
    )

  // Check if the collateral amount in the output is equal to the collateral amount in the borrow datum
  let is_collateral_sufficient =
    output_collateral_amount == borrow_details.collateral_details.collateral_amount

  // Check if the collateral is sent to the lender
  // this is necessary since foreclosures can be done by anyone
  // but the collateral should still be sent to the lender
  let is_collateral_sent_to_lender =
    foreclose_output.address == borrow_details.lender

  // Make sure that the loan has ended before foreclosing
  let is_loan_ended =
    tx_submitted_after(tx.validity_range, borrow_details.loan_end_time)

  and {
    is_collateral_sufficient?,
    is_collateral_sent_to_lender?,
    is_loan_ended?,
  }
}

pub fn cancel(input_index: Int, output_indexes: OutputIndexes, tx: Transaction) {
  // Extract transaction details.
  let tx_details =
    get_transaction_details(
      input_index,
      output_indexes.self_output_index,
      output_indexes.fee_output_index,
      output_indexes.change_index,
      tx,
    )
  let self_input = tx_details.self_input

  // Retrieve lend datum
  expect LendDatum(lend_details) = get_levvy_datum(self_input.output)

  // Make sure that the transaction is signed by the lender
  let is_tx_signed_by_lender = tx_signed_by_address(tx, lend_details.lender)

  is_tx_signed_by_lender?
}

pub fn is_borrow_split_correct(
  lend_details: LendDetails,
  borrow_details: BorrowDetails,
  borrow_collateral_amount: Int,
) {
  // Retrieve the collateral amount specified by the lender
  let lend_collateral_amount = lend_details.collateral_details.collateral_amount

  //Calculate the loan amount based on the lend and borrow token amounts
  // and the loan amount specified by the lender
  let loan_amount =
    get_ratio_amount(
      lend_collateral_amount,
      borrow_collateral_amount,
      lend_details.loan_amount,
    )

  //Calculate the interest amount  based on the lend and borrow token amounts
  // and the interest amount specified by the lender
  let interest_amount =
    get_ratio_amount(
      lend_collateral_amount,
      borrow_collateral_amount,
      lend_details.interest_amount,
    )

  // Ensure that the collateral amount specified by the borrower matches the amount specified by the lender
  let is_collateral_amount_correct =
    borrow_details.collateral_details.collateral_amount == borrow_collateral_amount

  // Esnure that the loan amount specified by the borrower matches the loan amount calculated 
  let is_loan_amount_correct = borrow_details.loan_amount == loan_amount

  // Esnure that the interest amount specified by the borrower matches the interest amount calculated 
  let is_interest_amount_correct =
    borrow_details.interest_amount == interest_amount

  and {
    is_collateral_amount_correct?,
    is_loan_amount_correct?,
    is_interest_amount_correct?,
  }
}

pub fn is_lend_split_correct(
  change_output: Option<Output>,
  previous_lend_details: LendDetails,
  new_token_amount: Int,
  script_address: Address,
  levvy_type: LevvyType,
) {
  // Extract outputs and datums
  expect Some(change_output) = change_output
  expect InlineDatum(data) = change_output.datum
  expect datum: LevvyDatum = data
  expect LendDatum(change_datum) = datum
  let change_lend_details = change_datum

  // Retrieve the loan amount and interest amount from the new lend datum
  let new_loan_amount_detail = change_lend_details.loan_amount
  let new_interest_detail = change_lend_details.interest_amount

  // Retrieve the lovelace from the change output
  let change_amount = lovelace_of(change_output.value)

  // Retrieve the collateral amount specified originally by the lender
  let previous_token_amount =
    previous_lend_details.collateral_details.collateral_amount

  // Check if the levvy type in the new lend datum is the same as the levvy type specified in the redeemer
  let is_levvy_type_correct = change_lend_details.levvy_type == levvy_type

  // Check if the change address is the same as the script address
  let is_change_address_valid =
    is_payment_key_equal(script_address, change_output.address)

  // Check if the lender in the new lend datum is the same as the lender in the previous lend datum
  let is_lender_correct =
    change_lend_details.lender == previous_lend_details.lender

  // Check if the collateral details in the new lend datum match the collateral details in the previous lend datum
  let is_collateral_valid =
    verify_collateral_details(
      previous_lend_details.collateral_details,
      change_lend_details.collateral_details,
      Tokens,
    )

  // Check if the collateral amount in the new lend datum matches the new token amount
  let is_collateral_amount_correct =
    change_lend_details.collateral_details.collateral_amount == new_token_amount

  // Calculate the new loan amount based on the previous and new token amounts and the loan amount specified by the lender
  let new_loan_amount =
    get_ratio_amount(
      previous_token_amount,
      new_token_amount,
      previous_lend_details.loan_amount,
    )

  // Calculate the new interest amount based on the previous and new token amounts and the loan amount specified by the lender
  let new_interest_amount =
    get_ratio_amount(
      previous_token_amount,
      new_token_amount,
      previous_lend_details.interest_amount,
    )

  // calculate the platform fee that need to be paid based on the loan type
  let platform_fee =
    when levvy_type is {
      Tokens ->
        calculate_platform_fee(new_interest_amount, types.tokens_fee_percent)
      NFTs ->
        calculate_platform_fee(new_loan_amount, types.nfts_fee_percent) / 2
    }

  // Calculate the maximum new loan and interest amounts
  // The ada buffer is added to the new loan and interest amounts to prevent overflow
  let ada_buffer = 2000000
  let max_new_loan_amount = new_loan_amount + platform_fee + ada_buffer
  let max_new_interest_amount = new_interest_amount + ada_buffer

  // Check if the change amount is acceptable
  // change amount should be greater than or equal to the calculated loan amount + platform fee
  // and less than or equal to the maximum new loan amount
  let is_change_amount_acceptable = and {
      change_amount >= new_loan_amount + platform_fee,
      change_amount <= max_new_loan_amount,
    }

  // Check if the new loan amount is acceptable:
  // The loan amount specified in the new lend datum should:
  //   - be greater than or equal to the calculated loan amount,
  //   - be less than or equal to the maximum new loan amount, and
  //   - equal the change amount minus the platform fee.
  // Additionally, the change UTXO must cover the platform fee, although the platform fee should not be included in the datum.
  let is_loan_amount_acceptable = and {
      new_loan_amount_detail >= new_loan_amount,
      new_loan_amount_detail <= max_new_loan_amount,
      new_loan_amount_detail == change_amount - platform_fee,
    }

  // Check if the new interest amount is acceptable
  // interest amount specified in the new lend datum should be greater than or equal to the calculated interest amount
  // less than or equal to the maximum new interest amount
  let is_interest_amount_acceptable = and {
      new_interest_detail >= new_interest_amount,
      new_interest_detail <= max_new_interest_amount,
    }

  // Check if the loan duration in the new lend datum is the same as the loan duration in the previous lend datum
  let is_loan_duration_correct =
    change_lend_details.loan_duration == previous_lend_details.loan_duration

  and {
    is_levvy_type_correct?,
    is_change_address_valid?,
    is_lender_correct?,
    is_collateral_valid?,
    is_collateral_amount_correct?,
    is_change_amount_acceptable?,
    is_loan_amount_acceptable?,
    is_interest_amount_acceptable?,
    is_loan_duration_correct?,
  }
}

pub fn is_fees_paid(
  self_output: Output,
  fee_output: Output,
  datum_tag: Hash<Blake2b_256, OutputReference>,
  levvy_type: LevvyType,
  platform_address: Address,
) {
  // Retrieve the payment datum from the fee output
  expect InlineDatum(self_output_data) = self_output.datum
  expect self_output_datum: LevvyDatum = self_output_data
  expect BorrowDatum(borrow_details) = self_output_datum

  // Check if the fees are paid to the platform main address
  let is_fees_paid_to_platform_address =
    is_payment_key_equal(fee_output.address, platform_address)

  // Retrieve the fee datum from the fee output
  expect InlineDatum(fee_datum) = fee_output.datum
  expect fee_datum: Hash<Blake2b_256, OutputReference> = fee_datum

  // Calculate the total fee that needs to be paid based on the loan type
  // We need to multiply the fee by 2 for token loans since this covers the fee that both the lender and the borrower must pay
  // For NFT loans, this still covers the fee that both the lender and the borrower must pay but the calculation is different so we don't need to multiply by 2
  let total_fee =
    when levvy_type is {
      Tokens ->
        calculate_platform_fee(
          borrow_details.interest_amount,
          types.tokens_fee_percent,
        ) * 2
      NFTs ->
        calculate_platform_fee(
          borrow_details.loan_amount,
          types.nfts_fee_percent,
        )
    }

  // Check if the fee datum is valid
  // This is used to prevent double satisfaction when paying fees
  let is_datum_tag_correct = fee_datum == datum_tag

  // Check if the output value is enough to cover the calculated total fee
  let is_fees_enough = lovelace_of(fee_output.value) >= total_fee

  and {
    is_fees_paid_to_platform_address?,
    is_datum_tag_correct?,
    is_fees_enough?,
  }
}
