use aiken/cbor
use aiken/collection/list
use cardano/address.{Address, VerificationKey}
use cardano/transaction.{NoDatum, Transaction, placeholder}
use token_mint
use types.{valid_address_hashes}

test valid_addresses() {
  let valid_pkh = valid_address_hashes |> list.head()

  expect Some(payment_key_hash) = valid_pkh
  let valid_address =
    Address {
      payment_credential: VerificationKey(payment_key_hash),
      stake_credential: None,
    }

  trace cbor.serialise(valid_address)
  True
}

test token_mint() {
  let signers =
    [
      #"5d1a755b8556bb84cdc379f784825ca079d425826c5f7106daf25bcc",
      #"8d775cd4e9397c2359f1b1c491ebee8541281abba5f3ed432e37882d",
    ]

  let tx =
    placeholder |> fn(tx) { Transaction { ..tx, extra_signatories: signers } }

  token_mint.token_mint.mint(NoDatum, #"", tx)
}

test token_mint_must_fail() fail {
  let signers = [#"5d1a755b8556bb84cdc379f784825ca079d425826c5f7106daf25bcc"]

  let tx =
    placeholder
      |> fn(tx) { Transaction { ..tx, extra_signatories: signers } }

  token_mint.token_mint.mint(NoDatum, #"", tx)
}
