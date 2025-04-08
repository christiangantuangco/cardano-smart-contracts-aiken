use cardano/address.{Address}
use cardano/assets
use cardano/transaction.{Transaction}
use general/types.{PaymentDatum} as general_types
use general/utils as general_utils
use levvy_tokens/constants
use levvy_tokens/types.{
  BorrowTokenDatum, LendTokenDatum, RepayTokenDatum, TokenDatum,
}

// Fee Functions
pub fn fees_paid(
  tx: Transaction,
  address: Address,
  interest_amount: Int,
  payment_datum: PaymentDatum,
) -> Bool {
  let total_fee = calculate_fee(interest_amount, constants.fee_percent)
  let fee_paid_to_address =
    assets.lovelace_of(
      general_utils.value_paid_to_with_datum(tx, address, payment_datum),
    )

  let is_fee_paid_to_address = fee_paid_to_address >= total_fee
  is_fee_paid_to_address?
}

pub fn fees_paid_or_auth(
  authorize_address: Address,
  tx: Transaction,
  address: Address,
  interest_amount: Int,
  payment_datum: PaymentDatum,
) -> Bool {
  let tx_signed_by_authority =
    general_utils.tx_signed_by_address(tx, authorize_address)

  tx_signed_by_authority || fees_paid(
    tx,
    address,
    interest_amount,
    payment_datum,
  )
}

pub fn calculate_fee(interest_amount: Int, fee_percent_x_10: Int) -> Int {
  // Whole division rounds down
  let fee = interest_amount * fee_percent_x_10 / 1000
  fee
}

// Specific Fee Functions
pub fn borrow_fees_paid(
  authorize_address: Address,
  datum: TokenDatum,
  tx: Transaction,
  address: Address,
  payment_datum: PaymentDatum,
) -> Bool {
  expect LendTokenDatum(lend_details) = datum

  fees_paid_or_auth(
    authorize_address,
    tx,
    address,
    lend_details.interest_amount,
    payment_datum,
  )
}

pub fn claim_fees_paid(
  authorize_address: Address,
  datum: TokenDatum,
  tx: Transaction,
  address: Address,
  payment_datum: PaymentDatum,
) -> Bool {
  expect RepayTokenDatum(replay_details) = datum

  fees_paid_or_auth(
    authorize_address,
    tx,
    address,
    replay_details.interest_amount,
    payment_datum,
  )
}

pub fn foreclose_fees_paid(
  authorize_address: Address,
  datum: TokenDatum,
  tx: Transaction,
  address: Address,
  payment_datum: PaymentDatum,
) -> Bool {
  expect BorrowTokenDatum(borrow_details) = datum

  fees_paid_or_auth(
    authorize_address,
    tx,
    address,
    borrow_details.interest_amount,
    payment_datum,
  )
}
