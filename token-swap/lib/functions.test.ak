use aiken/cbor
use cardano/address.{Address, Inline, Script, VerificationKey}
use types.{Indexes, Swap, WithdrawRedeemer}

test apply_params() {
  let fee_address =
    Address {
      payment_credential: VerificationKey(
        #"5d1a755b8556bb84cdc379f784825ca079d425826c5f7106daf25bcc",
      ),
      stake_credential: None,
    }

  trace cbor.serialise(fee_address)
  True
}

test withdraw_redeemer() {
  let indexes = Indexes { input_index: 0, output_index: None, fee_index: 0 }

  let redeemer = WithdrawRedeemer { operation: [(Swap, indexes)] }

  trace cbor.serialise(redeemer)
  True
}

test user_address() {
  let user_address =
    Address {
      payment_credential: VerificationKey(
        #"8d775cd4e9397c2359f1b1c491ebee8541281abba5f3ed432e37882d",
      ),
      stake_credential: Some(
        Inline(
          VerificationKey(
            #"f38fd378b75df6519f23214cee2520d3da870611be24d093f8f6af9c",
          ),
        ),
      ),
    }

  trace cbor.serialise(user_address)
  True
}

test fee_address() {
  let fee_address =
    Address {
      payment_credential: VerificationKey(
        #"5d1a755b8556bb84cdc379f784825ca079d425826c5f7106daf25bcc",
      ),
      stake_credential: Some(
        Inline(
          Script(#"5d1a755b8556bb84cdc379f784825ca079d425826c5f7106daf25bcc"),
        ),
      ),
    }

  trace cbor.serialise(fee_address)
  True
}

test indexes() {
  let indexes = Indexes { input_index: 0, output_index: Some(0), fee_index: 0 }

  trace cbor.serialise(indexes)
  True
}
