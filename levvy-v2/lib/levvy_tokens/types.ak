use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{OutputReference}

pub type PosixTime =
  Int

pub type LendTokenDetails {
  ada_owner: Address,
  policy_id: PolicyId,
  asset_name: AssetName,
  token_amount: Int,
  loan_amount: Int,
  interest_amount: Int,
  loan_duration: Int,
  output_reference: OutputReference,
}

pub type BorrowTokenDetails {
  ada_owner: Address,
  asset_owner: Address,
  policy_id: PolicyId,
  asset_name: AssetName,
  token_amount: Int,
  loan_amount: Int,
  interest_amount: Int,
  loan_end_time: PosixTime,
  output_reference: OutputReference,
}

pub type RepayTokenDetails {
  ada_owner: Address,
  token_amount: Int,
  loan_amount: Int,
  interest_amount: Int,
  output_reference: OutputReference,
}

pub type TokenDatum {
  LendTokenDatum(LendTokenDetails)
  BorrowTokenDatum(BorrowTokenDetails)
  RepayTokenDatum(RepayTokenDetails)
}

pub type TokenAction {
  BorrowTokenAction
  RepayTokenAction
  ClaimTokenAction
  ForecloseTokenAction
  CancelTokenAction
}

pub type LendOutput {
  lend_details: LendTokenDetails,
  lend_value: Value,
}

pub type BorrowOutput {
  borrow_details: BorrowTokenDetails,
  borrow_value: Value,
}

pub type RepayOutput {
  repay_details: RepayTokenDetails,
  repay_value: Value,
}
