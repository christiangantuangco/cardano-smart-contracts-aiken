use cardano/transaction.{Input, Output}

pub type TransactionDetails {
  self_input: Input,
  self_output: Output,
  fee_output: Option<Output>,
  change_output: Option<Output>,
}
