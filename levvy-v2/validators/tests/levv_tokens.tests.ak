use aiken/cbor
use aiken/interval.{Finite, Interval, IntervalBound, PositiveInfinity}
use cardano/address.{Address, Inline, Script, VerificationKey}
use cardano/assets.{add, from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, placeholder,
}
use levvy_tokens/types.{
  BorrowTokenDatum, BorrowTokenDetails, LendTokenDatum, LendTokenDetails,
  TokenDatum,
}
use levvy_tokens/validation.{borrow}

test apply_params() {
  let main_address =
    Address {
      payment_credential: VerificationKey(
        #"167a9e75606fcf71b562353f88d6fa23c86bea40336a22d596404695",
      ),
      stake_credential: None,
    }

  let authorize_address =
    Address {
      payment_credential: VerificationKey(
        #"b49f8a47131260ba1cef59dcd2b993da61b248818df4bb236ed247c7",
      ),
      stake_credential: None,
    }

  trace cbor.serialise(main_address)
  trace cbor.serialise(authorize_address)
  True
}

test borrow_token_details() {
  let ada_owner =
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

  let asset_owner =
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

  let output_reference =
    OutputReference { transaction_id: #"00", output_index: 0 }

  let borrow_token_details =
    BorrowTokenDetails {
      ada_owner,
      asset_owner,
      policy_id: #"8b05e87a51c1d4a0fa888d2bb14dbc25e8c343ea379a171b63aa84a0",
      asset_name: #"434e4354",
      token_amount: 6000,
      loan_amount: 5000000,
      interest_amount: 3000000,
      loan_end_time: 3600,
      output_reference,
    }

  let token_datum = BorrowTokenDatum(borrow_token_details)

  trace cbor.serialise(token_datum)
  True
}

test lend_token_details() {
  let lend_token_details =
    LendTokenDetails {
      ada_owner: Address {
        payment_credential: VerificationKey(
          #"8d775cd4e9397c2359f1b1c491ebee8541281abba5f3ed432e37882d",
        ),
        stake_credential: Some(
          Inline(
            Script(#"f38fd378b75df6519f23214cee2520d3da870611be24d093f8f6af9c"),
          ),
        ),
      },
      policy_id: #"8b05e87a51c1d4a0fa888d2bb14dbc25e8c343ea379a171b63aa84a0",
      asset_name: #"434e4354",
      token_amount: 6000,
      loan_amount: 5000000,
      interest_amount: 3000000,
      loan_duration: 3600,
      output_reference: OutputReference {
        transaction_id: #"00",
        output_index: 0,
      },
    }

  trace cbor.serialise(lend_token_details)
  True
}

test borrow_test() {
  let lend_token_details =
    LendTokenDetails {
      ada_owner: Address {
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
      },
      policy_id: #"8b05e87a51c1d4a0fa888d2bb14dbc25e8c343ea379a171b63aa84a0",
      asset_name: #"434e4354",
      token_amount: 6000,
      loan_amount: 5000000,
      interest_amount: 3000000,
      loan_duration: 3600,
      output_reference: OutputReference {
        transaction_id: #"00",
        output_index: 0,
      },
    }
  let input_datum = LendTokenDatum(lend_token_details)

  let input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"d5e6f0b6e2c6b88fa61d96ec3b0479c83a2452a3f28419f0556efce35309e42f",
        output_index: 0,
      },
      output: Output(
        Address {
          payment_credential: Script(
            #"fda46e81fdd2e4f1c358d27e7484b9f0860b63b0e8e12e6ab5f87e8c",
          ),
          stake_credential: None,
        },
        from_lovelace(5000000),
        InlineDatum(input_datum),
        None,
      ),
    }
  let borrow_token_details =
    BorrowTokenDetails {
      ada_owner: Address {
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
      },
      asset_owner: Address {
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
      },
      policy_id: #"8b05e87a51c1d4a0fa888d2bb14dbc25e8c343ea379a171b63aa84a0",
      asset_name: #"434e4354",
      token_amount: 6000,
      loan_amount: 5000000,
      interest_amount: 3000000,
      loan_end_time: 3600,
      output_reference: OutputReference {
        transaction_id: #"d5e6f0b6e2c6b88fa61d96ec3b0479c83a2452a3f28419f0556efce35309e42f",
        output_index: 0,
      },
    }
  let borrow_token_datum = BorrowTokenDatum(borrow_token_details)

  let output =
    Output(
      Address {
        payment_credential: Script(
          #"fda46e81fdd2e4f1c358d27e7484b9f0860b63b0e8e12e6ab5f87e8c",
        ),
        stake_credential: None,
      },
      from_lovelace(5000000)
        |> add(
            #"8b05e87a51c1d4a0fa888d2bb14dbc25e8c343ea379a171b63aa84a0",
            #"434e4354",
            6000,
          ),
      InlineDatum(borrow_token_datum),
      None,
    )

  let tx =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            validity_range: Interval {
              lower_bound: IntervalBound {
                bound_type: Finite(3600),
                is_inclusive: True,
              },
              upper_bound: IntervalBound {
                bound_type: PositiveInfinity,
                is_inclusive: True,
              },
            },
            inputs: [input],
            outputs: [output],
          }
        }

  let is_borrow_valid =
    borrow(
      input_datum,
      tx,
      Address {
        payment_credential: Script(
          #"fda46e81fdd2e4f1c358d27e7484b9f0860b63b0e8e12e6ab5f87e8c",
        ),
        stake_credential: None,
      },
      input,
    )

  is_borrow_valid?
}
