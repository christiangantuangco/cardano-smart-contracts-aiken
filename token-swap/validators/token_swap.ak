use aiken/collection/list
use aiken/collection/pairs
use cardano/address.{Address, Credential, Script}
use cardano/transaction.{OutputReference, Transaction}
use functions.{cancel, get_validator_hash}
use types.{Cancel, Swap, WithdrawRedeemer}

validator token_swap(fee_address: Address) {
  spend(
    _datum: Option<Data>,
    _redeemer: Data,
    utxo: OutputReference,
    self: Transaction,
  ) {
    let self_hash = get_validator_hash(self, utxo)
    self.withdrawals
      |> pairs.has_key(Script(self_hash))
  }

  withdraw(redeemer: WithdrawRedeemer, _account: Credential, self: Transaction) {
    redeemer.operation
      |> list.all(
          fn((action, indexes)) {
            when action is {
              Swap -> True
              Cancel -> cancel(fee_address, indexes, self)
            }
          },
        )
  }

  else(_) {
    fail
  }
}
