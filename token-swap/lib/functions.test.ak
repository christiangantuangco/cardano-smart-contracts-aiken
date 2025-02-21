use aiken/cbor
use cardano/address.{Address, VerificationKey}

test apply_fee_address() {
  let fee_address =
    Address {
      payment_credential: VerificationKey(
        #"2d13ddda85f683519aaeb03d5fbe3bf2ab09b0f5e0fa6b380e4ee5a2",
      ),
      stake_credential: None,
    }

  trace cbor.serialise(fee_address)
  True
}
