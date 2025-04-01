use aiken/collection/list
use cardano/assets.{PolicyId}
use cardano/transaction.{Transaction}
use types.{valid_address_hashes}

validator token_mint {
  mint(_redeemer: Data, _policy_id: PolicyId, self: Transaction) {
    let signers = self.extra_signatories

    let has_valid_signer =
      valid_address_hashes
        |> list.any(
            fn(valid_payment_key_hash) {
              signers |> list.has(valid_payment_key_hash)
            },
          )

    has_valid_signer?
  }

  else(_) {
    fail
  }
}
