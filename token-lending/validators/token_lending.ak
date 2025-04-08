use aiken/collection/list
use aiken/collection/pairs
use cardano/address.{Address, Credential, Script}
use cardano/transaction.{OutputReference, Transaction}
use levvy/token_lending/functions.{borrow, cancel, foreclose, repay}
use levvy/token_lending/types.{
  Action, BorrowAction, CancelAction, ForecloseAction, RepayAction,
  WithdrawRedeemer,
}
use utils/functions.{get_validator_hash} as utils_types

validator token_lending(platform_address: Address) {
  spend(
    _datum: Option<Data>,
    _redeemer: Data,
    utxo: OutputReference,
    self: Transaction,
  ) {
    // Retrieve the hash of the validator script
    let self_hash = get_validator_hash(self, utxo)

    // Check if the transaction has a withdrawal with the validator's hash as the staking credential
    // This means that the zero withdraw logic has run and validated the lending actions
    self.withdrawals
      |> pairs.has_key(Script(self_hash))
  }

  withdraw(redeemer: WithdrawRedeemer, _account: Credential, self: Transaction) {
    // Iterate over the sequence of input and output indexes in the redeemer and
    // execute the corresponding action specified
    redeemer
      |> list.all(
          fn(Action { input_index, output_indexes, action_type }) {
            when action_type is {
              BorrowAction(levvy_type) ->
                borrow(
                  input_index,
                  output_indexes,
                  platform_address,
                  levvy_type,
                  self,
                )?
              RepayAction(_) -> repay(input_index, output_indexes, self)?
              ForecloseAction(levvy_type) ->
                foreclose(input_index, output_indexes, levvy_type, self)?
              CancelAction(_) -> cancel(input_index, output_indexes, self)?
            }
          },
        )
  }

  else(_ctx: Data) {
    False
  }
}
