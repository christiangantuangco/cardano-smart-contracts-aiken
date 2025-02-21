use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{Input, Output}

pub type Datum {
  owner: Address,
  token: TokenDetails,
}

pub type TokenDetails {
  policy_id: PolicyId,
  asset_name: AssetName,
  amount: Int,
}

pub type Action {
  Swap
  Cancel
}

pub type Indexes {
  input_index: Int,
  output_index: Option<Int>,
  fee_index: Int,
}

pub type WithdrawRedeemer {
  operation: List<(Action, Indexes)>,
}

pub type TransactionDetails {
  input: Input,
  output: Option<Output>,
  fee_output: Output,
}
