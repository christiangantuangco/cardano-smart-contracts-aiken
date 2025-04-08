use aiken/crypto.{Blake2b_256, Hash}
use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{OutputReference}

// multiplier for platform fees for token loans
pub const tokens_fee_percent = 125

// multiplier for platform fees for nft loans
pub const nfts_fee_percent = 25

pub type PosixTime =
  Int

// The collateral details of the loan
pub type CollateralDetails {
  policy_id: PolicyId,
  asset_name: AssetName,
  collateral_amount: Int,
}

// The details of the lend position datum
pub type LendDetails {
  lender: Address,
  collateral_details: CollateralDetails,
  loan_amount: Int,
  interest_amount: Int,
  loan_duration: Int,
  levvy_type: LevvyType,
}

// The details of the borrow position datum
pub type BorrowDetails {
  lender: Address,
  borrower: Address,
  collateral_details: CollateralDetails,
  loan_amount: Int,
  interest_amount: Int,
  loan_end_time: PosixTime,
  levvy_type: LevvyType,
  tag: Hash<Blake2b_256, OutputReference>,
}

// This is wrapper type for the lend and borrow datums
pub type LevvyDatum {
  LendDatum(LendDetails)
  BorrowDatum(BorrowDetails)
}

// The type of lending that can be done
pub type LevvyType {
  Tokens
  NFTs
}

// The actions that can be performed on the loans
// Specifies the type of lending, whether it involves tokens or NFTs.
pub type ActionType {
  BorrowAction(LevvyType)
  RepayAction(LevvyType)
  ForecloseAction(LevvyType)
  CancelAction(LevvyType)
}

// input index, output indexes and the action to be performed
pub type Action {
  input_index: Int,
  output_indexes: OutputIndexes,
  action_type: ActionType,
}

// The redeemer for the withdraw purpose
pub type WithdrawRedeemer =
  List<Action>

// Output indexes in the transaction:
// - A required main output index.
// - An optional fee output index.
// - An optional script change output index
pub type OutputIndexes {
  self_output_index: Int,
  fee_output_index: Option<Int>,
  change_index: Option<Int>,
}
