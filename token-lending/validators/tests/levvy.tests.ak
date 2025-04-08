use aiken/cbor
use aiken/crypto
use aiken/interval.{Finite, Interval, IntervalBound, PositiveInfinity}
use cardano/address.{Address, Inline, Script, VerificationKey}
use cardano/assets.{add, from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction, placeholder,
}
use levvy/token_lending/types.{
  Action, BorrowAction, BorrowDatum, BorrowDetails, CancelAction,
  CollateralDetails, ForecloseAction, LendDatum, LendDetails, OutputIndexes,
  RepayAction, Tokens, WithdrawRedeemer,
} as levvy_types
use token_lending
use utils/functions.{calculate_platform_fee} as utils_types

test foreclose_zero_withdraw() {
  let validator_hash = #"0000"
  let validator_creds = Script(validator_hash)
  let owner_hash = #"af01"
  let borrower_hash_1 = #"7706"
  let borrower_hash_2 = #"ed2c"
  let borrower_hash_3 = #"5ba6"
  let platform_address =
    Address {
      payment_credential: VerificationKey(#"0001"),
      stake_credential: None,
    }

  let lender =
    Address {
      payment_credential: VerificationKey(owner_hash),
      stake_credential: None,
    }

  let input_datum_1 =
    BorrowDatum(
      BorrowDetails {
        lender,
        borrower: Address {
          payment_credential: VerificationKey(borrower_hash_1),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 200_000_000,
        interest_amount: 10000000,
        loan_end_time: 20,
        levvy_type: Tokens,
        tag: #"0010",
      },
    )

  let input_datum_2 =
    BorrowDatum(
      BorrowDetails {
        lender,
        borrower: Address {
          payment_credential: VerificationKey(borrower_hash_2),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 200_000_000,
        interest_amount: 10000000,
        loan_end_time: 100,
        levvy_type: Tokens,
        tag: #"0010",
      },
    )

  let input_datum_3 =
    BorrowDatum(
      BorrowDetails {
        lender,
        borrower: Address {
          payment_credential: VerificationKey(borrower_hash_3),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 200_000_000,
        interest_amount: 10000000,
        loan_end_time: 250,
        levvy_type: Tokens,
        tag: #"0010",
      },
    )

  let input_datum_4 =
    BorrowDatum(
      BorrowDetails {
        lender,
        borrower: Address {
          payment_credential: VerificationKey(borrower_hash_1),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 200_000_000,
        interest_amount: 10000000,
        loan_end_time: 120,
        levvy_type: Tokens,
        tag: #"0010",
      },
    )

  let output1 =
    Output(
      lender,
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 100),
      NoDatum,
      None,
    )

  let output2 =
    Output(
      lender,
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 100),
      NoDatum,
      None,
    )
  let output3 =
    Output(
      lender,
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 100),
      NoDatum,
      None,
    )
  let output4 =
    Output(
      lender,
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 100),
      NoDatum,
      None,
    )

  let input1 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1231",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(10000000)
          |> add(#"2233", #"2233", 100),
        InlineDatum(input_datum_1),
        None,
      ),
    }
  let input2 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1232",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(10000000)
          |> add(#"2233", #"2233", 100),
        InlineDatum(input_datum_2),
        None,
      ),
    }
  let input3 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1233",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(10000000)
          |> add(#"2233", #"2233", 100),
        InlineDatum(input_datum_3),
        None,
      ),
    }

  let input4 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1234",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(10000000)
          |> add(#"2233", #"2233", 100),
        InlineDatum(input_datum_4),
        None,
      ),
    }

  let validity_range =
    Interval {
      lower_bound: IntervalBound {
        bound_type: Finite(1000),
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: PositiveInfinity,
        is_inclusive: True,
      },
    }

  let action1 =
    Action {
      input_index: 0,
      output_indexes: OutputIndexes {
        self_output_index: 0,
        fee_output_index: None,
        change_index: None,
      },
      action_type: ForecloseAction(Tokens),
    }

  let action2 =
    Action {
      input_index: 1,
      output_indexes: OutputIndexes {
        self_output_index: 1,
        fee_output_index: None,
        change_index: None,
      },
      action_type: ForecloseAction(Tokens),
    }

  let action3 =
    Action {
      input_index: 2,
      output_indexes: OutputIndexes {
        self_output_index: 2,
        fee_output_index: None,
        change_index: None,
      },
      action_type: ForecloseAction(Tokens),
    }
  let action4 =
    Action {
      input_index: 3,
      output_indexes: OutputIndexes {
        self_output_index: 3,
        fee_output_index: None,
        change_index: None,
      },
      action_type: ForecloseAction(Tokens),
    }

  let withdraw_redeemer: WithdrawRedeemer = [action1, action2, action3, action4]

  let tx =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            validity_range: validity_range,
            inputs: [input1, input2, input3, input4],
            outputs: [output1, output2, output3, output4],
            withdrawals: [Pair(validator_creds, 0)],
          }
        }

  and {
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input1.output_reference,
      tx,
    ),
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input2.output_reference,
      tx,
    ),
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input3.output_reference,
      tx,
    ),
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input4.output_reference,
      tx,
    ),
    token_lending.token_lending.withdraw(
      platform_address,
      withdraw_redeemer,
      validator_creds,
      tx,
    ),
  }
}

test tokens_borrow_zero_withdraw() {
  let validator_hash = #"0000"
  let validator_creds = Script(validator_hash)
  let owner_hash = #"7706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"
  let borrower_hash =
    #"6706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"

  let platform_address =
    Address {
      payment_credential: VerificationKey(#"0001"),
      stake_credential: None,
    }

  let input_datum1 =
    LendDatum(
      LendDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_duration: 1_209_600_000,
        levvy_type: Tokens,
      },
    )

  let platform_fee1 =
    calculate_platform_fee(10000000, levvy_types.tokens_fee_percent)

  let input_datum2 =
    LendDatum(
      LendDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_duration: 1_209_600_000,
        levvy_type: Tokens,
      },
    )

  let platform_fee2 =
    calculate_platform_fee(10000000, levvy_types.tokens_fee_percent)

  let input_datum3 =
    LendDatum(
      LendDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_duration: 1_209_600_000,
        levvy_type: Tokens,
      },
    )

  let platform_fee3 =
    calculate_platform_fee(10000000, levvy_types.tokens_fee_percent)

  let input_datum4 =
    LendDatum(
      LendDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 500,
        },
        loan_amount: 1000000000,
        interest_amount: 50000000,
        loan_duration: 1_209_600_000,
        levvy_type: Tokens,
      },
    )

  let platform_fee4 =
    calculate_platform_fee(50000000, levvy_types.tokens_fee_percent)

  let input1 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1231",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(200000000 + platform_fee1),
        InlineDatum(input_datum1),
        None,
      ),
    }
  let input2 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1232",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(200000000 + platform_fee2),
        InlineDatum(input_datum2),
        None,
      ),
    }
  let input3 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1233",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(200000000 + platform_fee3),
        InlineDatum(input_datum3),
        None,
      ),
    }

  let input4 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1234",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(1000000000 + platform_fee4),
        InlineDatum(input_datum4),
        None,
      ),
    }

  let datum_tag1 =
    input1.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let datum_tag2 =
    input2.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let datum_tag3 =
    input3.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let datum_tag4 =
    input4.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let output_datum1 =
    BorrowDatum(
      BorrowDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        borrower: Address {
          payment_credential: VerificationKey(borrower_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_end_time: 1_209_600_000,
        levvy_type: Tokens,
        tag: datum_tag1,
      },
    )

  let output_datum2 =
    BorrowDatum(
      BorrowDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        borrower: Address {
          payment_credential: VerificationKey(borrower_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_end_time: 1_209_600_000,
        levvy_type: Tokens,
        tag: datum_tag2,
      },
    )

  let output_datum3 =
    BorrowDatum(
      BorrowDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        borrower: Address {
          payment_credential: VerificationKey(borrower_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_end_time: 1_209_600_000,
        levvy_type: Tokens,
        tag: datum_tag3,
      },
    )

  let output_datum4 =
    BorrowDatum(
      BorrowDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        borrower: Address {
          payment_credential: VerificationKey(borrower_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_end_time: 1_209_600_000,
        levvy_type: Tokens,
        tag: datum_tag4,
      },
    )

  let output1 =
    Output(
      Address {
        payment_credential: Script(validator_hash),
        stake_credential: None,
      },
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 100),
      InlineDatum(output_datum1),
      None,
    )

  let output2 =
    Output(
      Address {
        payment_credential: Script(validator_hash),
        stake_credential: None,
      },
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 100),
      InlineDatum(output_datum2),
      None,
    )
  let output3 =
    Output(
      Address {
        payment_credential: Script(validator_hash),
        stake_credential: None,
      },
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 100),
      InlineDatum(output_datum3),
      None,
    )
  let output4 =
    Output(
      Address {
        payment_credential: Script(validator_hash),
        stake_credential: None,
      },
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 100),
      InlineDatum(output_datum4),
      None,
    )

  let fee_output_datum1 = datum_tag1
  let fee_output_datum2 = datum_tag2
  let fee_output_datum3 = datum_tag3
  let fee_output_datum4 = datum_tag4

  let fee_output1 =
    Output(
      platform_address,
      from_lovelace(1250000 * 2),
      InlineDatum(fee_output_datum1),
      None,
    )
  let fee_output2 =
    Output(
      platform_address,
      from_lovelace(1250000 * 2),
      InlineDatum(fee_output_datum2),
      None,
    )
  let fee_output3 =
    Output(
      platform_address,
      from_lovelace(1250000 * 2),
      InlineDatum(fee_output_datum3),
      None,
    )
  let fee_output4 =
    Output(
      platform_address,
      from_lovelace(1250000 * 2),
      InlineDatum(fee_output_datum4),
      None,
    )

  let script_change_datum =
    LendDatum(
      LendDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 400,
        },
        loan_amount: 800000000,
        interest_amount: 40000000,
        loan_duration: 1_209_600_000,
        levvy_type: Tokens,
      },
    )

  let platform_fee_change =
    calculate_platform_fee(40000000, levvy_types.tokens_fee_percent)

  let script_change_output =
    Output(
      Address {
        payment_credential: Script(validator_hash),
        stake_credential: None,
      },
      from_lovelace(800000000 + platform_fee_change),
      InlineDatum(script_change_datum),
      None,
    )
  let validity_range =
    Interval {
      lower_bound: IntervalBound { bound_type: Finite(0), is_inclusive: True },
      upper_bound: IntervalBound {
        bound_type: PositiveInfinity,
        is_inclusive: True,
      },
    }

  let action1 =
    Action {
      input_index: 0,
      output_indexes: OutputIndexes {
        self_output_index: 0,
        fee_output_index: Some(4),
        change_index: None,
      },
      action_type: BorrowAction(Tokens),
    }

  let action2 =
    Action {
      input_index: 1,
      output_indexes: OutputIndexes {
        self_output_index: 1,
        fee_output_index: Some(5),
        change_index: None,
      },
      action_type: BorrowAction(Tokens),
    }

  let action3 =
    Action {
      input_index: 2,
      output_indexes: OutputIndexes {
        self_output_index: 2,
        fee_output_index: Some(6),
        change_index: None,
      },
      action_type: BorrowAction(Tokens),
    }
  let action4 =
    Action {
      input_index: 3,
      output_indexes: OutputIndexes {
        self_output_index: 3,
        fee_output_index: Some(7),
        change_index: Some(8),
      },
      action_type: BorrowAction(Tokens),
    }

  let withdraw_redeemer: WithdrawRedeemer = [action1, action2, action3, action4]

  let self =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            inputs: [input1, input2, input3, input4],
            outputs: [
              output1, output2, output3, output4, fee_output1, fee_output2,
              fee_output3, fee_output4, script_change_output,
            ],
            withdrawals: [Pair(validator_creds, 0)],
            validity_range: validity_range,
          }
        }
  and {
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input1.output_reference,
      self,
    ),
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input2.output_reference,
      self,
    ),
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input3.output_reference,
      self,
    ),
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input4.output_reference,
      self,
    ),
    token_lending.token_lending.withdraw(
      platform_address,
      withdraw_redeemer,
      validator_creds,
      self,
    ),
  }
}

test nfts_borrow_zero_withdraw() {
  let validator_hash = #"0000"
  let validator_creds = Script(validator_hash)
  let owner_hash = #"7706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"
  let borrower_hash =
    #"6706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"

  let platform_address =
    Address {
      payment_credential: VerificationKey(#"0001"),
      stake_credential: None,
    }
  let input_datum1 =
    LendDatum(
      LendDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 1,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_duration: 1_209_600_000,
        levvy_type: Tokens,
      },
    )

  let platform_fee1 =
    calculate_platform_fee(200000000, levvy_types.nfts_fee_percent)

  let input_datum2 =
    LendDatum(
      LendDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 1,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_duration: 1_209_600_000,
        levvy_type: Tokens,
      },
    )

  let platform_fee2 =
    calculate_platform_fee(200000000, levvy_types.nfts_fee_percent)

  let input_datum3 =
    LendDatum(
      LendDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 1,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_duration: 1_209_600_000,
        levvy_type: Tokens,
      },
    )

  let platform_fee3 =
    calculate_platform_fee(200000000, levvy_types.nfts_fee_percent)

  let input1 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1231",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(200000000 + platform_fee1),
        InlineDatum(input_datum1),
        None,
      ),
    }
  let input2 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1232",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(200000000 + platform_fee2),
        InlineDatum(input_datum2),
        None,
      ),
    }
  let input3 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1233",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(200000000 + platform_fee3),
        InlineDatum(input_datum3),
        None,
      ),
    }

  let datum_tag1 =
    input1.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let datum_tag2 =
    input2.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let datum_tag3 =
    input3.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let output_datum1 =
    BorrowDatum(
      BorrowDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        borrower: Address {
          payment_credential: VerificationKey(borrower_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 1,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_end_time: 1_209_600_000,
        levvy_type: Tokens,
        tag: datum_tag1,
      },
    )

  let output_datum2 =
    BorrowDatum(
      BorrowDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        borrower: Address {
          payment_credential: VerificationKey(borrower_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 1,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_end_time: 1_209_600_000,
        levvy_type: Tokens,
        tag: datum_tag2,
      },
    )

  let output_datum3 =
    BorrowDatum(
      BorrowDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash),
          stake_credential: None,
        },
        borrower: Address {
          payment_credential: VerificationKey(borrower_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 1,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_end_time: 1_209_600_000,
        levvy_type: Tokens,
        tag: datum_tag3,
      },
    )

  let output1 =
    Output(
      Address {
        payment_credential: Script(validator_hash),
        stake_credential: None,
      },
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 1),
      InlineDatum(output_datum1),
      None,
    )

  let output2 =
    Output(
      Address {
        payment_credential: Script(validator_hash),
        stake_credential: None,
      },
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 1),
      InlineDatum(output_datum2),
      None,
    )
  let output3 =
    Output(
      Address {
        payment_credential: Script(validator_hash),
        stake_credential: None,
      },
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 1),
      InlineDatum(output_datum3),
      None,
    )

  let fee_output_datum1 = datum_tag1
  let fee_output_datum2 = datum_tag2
  let fee_output_datum3 = datum_tag3

  let fee_output1 =
    Output(
      platform_address,
      from_lovelace(5000000 * 2),
      InlineDatum(fee_output_datum1),
      None,
    )
  let fee_output2 =
    Output(
      platform_address,
      from_lovelace(5000000 * 2),
      InlineDatum(fee_output_datum2),
      None,
    )
  let fee_output3 =
    Output(
      platform_address,
      from_lovelace(5000000 * 2),
      InlineDatum(fee_output_datum3),
      None,
    )

  let validity_range =
    Interval {
      lower_bound: IntervalBound { bound_type: Finite(0), is_inclusive: True },
      upper_bound: IntervalBound {
        bound_type: PositiveInfinity,
        is_inclusive: True,
      },
    }

  let action1 =
    Action {
      input_index: 0,
      output_indexes: OutputIndexes {
        self_output_index: 0,
        fee_output_index: Some(3),
        change_index: None,
      },
      action_type: BorrowAction(Tokens),
    }

  let action2 =
    Action {
      input_index: 1,
      output_indexes: OutputIndexes {
        self_output_index: 1,
        fee_output_index: Some(4),
        change_index: None,
      },
      action_type: BorrowAction(Tokens),
    }

  let action3 =
    Action {
      input_index: 2,
      output_indexes: OutputIndexes {
        self_output_index: 2,
        fee_output_index: Some(5),
        change_index: None,
      },
      action_type: BorrowAction(Tokens),
    }

  let withdraw_redeemer: WithdrawRedeemer = [action1, action2, action3]

  let self =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            inputs: [input1, input2, input3],
            outputs: [
              output1, output2, output3, fee_output1, fee_output2, fee_output3,
            ],
            withdrawals: [Pair(validator_creds, 0)],
            validity_range: validity_range,
          }
        }
  and {
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input1.output_reference,
      self,
    ),
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input2.output_reference,
      self,
    ),
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input3.output_reference,
      self,
    ),
    token_lending.token_lending.withdraw(
      platform_address,
      withdraw_redeemer,
      validator_creds,
      self,
    ),
  }
}

test tokens_repay_zero_withdraw() {
  let validator_hash = #"0000"
  let validator_creds = Script(validator_hash)

  let owner_hash = #"7706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"

  let owner_address =
    Address {
      payment_credential: VerificationKey(owner_hash),
      stake_credential: None,
    }

  let borrower_hash =
    #"6706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"

  let borrower_address =
    Address {
      payment_credential: VerificationKey(borrower_hash),
      stake_credential: None,
    }

  let platform_address =
    Address {
      payment_credential: Script(borrower_hash),
      stake_credential: None,
    }

  let input_datum1 =
    BorrowDatum(
      BorrowDetails {
        lender: owner_address,
        borrower: borrower_address,
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 10_000_000,
        interest_amount: 500_000,
        loan_end_time: 145000000,
        levvy_type: Tokens,
        tag: #"0010",
      },
    )

  let input_datum2 =
    BorrowDatum(
      BorrowDetails {
        lender: owner_address,
        borrower: borrower_address,
        collateral_details: CollateralDetails {
          policy_id: #"2234",
          asset_name: #"2234",
          collateral_amount: 100,
        },
        loan_amount: 5_000_000,
        interest_amount: 300_000,
        loan_end_time: 145000000,
        levvy_type: Tokens,
        tag: #"0010",
      },
    )

  let input1 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1113",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(10_000_000) |> add(#"2233", #"2233", 100),
        InlineDatum(input_datum1),
        None,
      ),
    }

  let input2 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1114",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(5_000_000) |> add(#"2234", #"2234", 100),
        InlineDatum(input_datum2),
        None,
      ),
    }

  let datum_tag1 =
    input1.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let datum_tag2 =
    input2.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let fee_output_datum1 = datum_tag1
  let fee_output_datum2 = datum_tag2
  let repay_output1 =
    Output {
      address: owner_address,
      value: from_lovelace(10_000_000 + 500_000),
      datum: InlineDatum(fee_output_datum1),
      reference_script: None,
    }

  let repay_output2 =
    Output {
      address: owner_address,
      value: from_lovelace(5_000_000 + 300_000),
      datum: InlineDatum(fee_output_datum2),
      reference_script: None,
    }

  let validity_range =
    Interval {
      lower_bound: IntervalBound { bound_type: Finite(0), is_inclusive: True },
      upper_bound: IntervalBound {
        bound_type: PositiveInfinity,
        is_inclusive: True,
      },
    }

  let action1 =
    Action {
      input_index: 0,
      output_indexes: OutputIndexes {
        self_output_index: 0,
        fee_output_index: None,
        change_index: None,
      },
      action_type: RepayAction(Tokens),
    }

  let action2 =
    Action {
      input_index: 1,
      output_indexes: OutputIndexes {
        self_output_index: 1,
        fee_output_index: None,
        change_index: None,
      },
      action_type: RepayAction(Tokens),
    }

  let withdraw_redeemer: WithdrawRedeemer = [action1, action2]

  let tx =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            inputs: [input1, input2],
            outputs: [repay_output1, repay_output2],
            withdrawals: [Pair(validator_creds, 0)],
            validity_range: validity_range,
            extra_signatories: [borrower_hash],
          }
        }
  and {
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input1.output_reference,
      tx,
    ),
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input2.output_reference,
      tx,
    ),
    token_lending.token_lending.withdraw(
      platform_address,
      withdraw_redeemer,
      validator_creds,
      tx,
    ),
  }
}

test cancel_zero_withdraw() {
  let validator_hash = #"0000"
  let validator_creds = Script(validator_hash)

  let owner_hash = #"7706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"

  let owner_address =
    Address {
      payment_credential: VerificationKey(owner_hash),
      stake_credential: None,
    }
  let platform_address =
    Address {
      payment_credential: VerificationKey(#"0001"),
      stake_credential: None,
    }

  let input_datum1 =
    LendDatum(
      LendDetails {
        lender: owner_address,
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 10_000_000,
        interest_amount: 500_000,
        loan_duration: 145000000,
        levvy_type: Tokens,
      },
    )

  let input_datum2 =
    LendDatum(
      LendDetails {
        lender: owner_address,
        collateral_details: CollateralDetails {
          policy_id: #"2234",
          asset_name: #"2234",
          collateral_amount: 100,
        },
        loan_amount: 5_000_000,
        interest_amount: 300_000,
        loan_duration: 145000000,
        levvy_type: Tokens,
      },
    )

  let input1 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1113",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(10_000_000) |> add(#"2233", #"2233", 100),
        InlineDatum(input_datum1),
        None,
      ),
    }

  let input2 =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1114",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(5_000_000) |> add(#"2234", #"2234", 100),
        InlineDatum(input_datum2),
        None,
      ),
    }

  let cancel_output1 =
    Output {
      address: owner_address,
      value: from_lovelace(10_000_000) |> add(#"2233", #"2233", 100),
      datum: NoDatum,
      reference_script: None,
    }

  let cancel_output2 =
    Output {
      address: owner_address,
      value: from_lovelace(5_000_000) |> add(#"2234", #"2234", 100),
      datum: NoDatum,
      reference_script: None,
    }

  let validity_range =
    Interval {
      lower_bound: IntervalBound { bound_type: Finite(0), is_inclusive: True },
      upper_bound: IntervalBound {
        bound_type: PositiveInfinity,
        is_inclusive: True,
      },
    }

  let action1 =
    Action {
      input_index: 0,
      output_indexes: OutputIndexes {
        self_output_index: 0,
        fee_output_index: None,
        change_index: None,
      },
      action_type: CancelAction(Tokens),
    }

  let action2 =
    Action {
      input_index: 1,
      output_indexes: OutputIndexes {
        self_output_index: 1,
        fee_output_index: None,
        change_index: None,
      },
      action_type: CancelAction(Tokens),
    }

  let withdraw_redeemer: WithdrawRedeemer = [action1, action2]

  let tx =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            inputs: [input1, input2],
            outputs: [cancel_output1, cancel_output2],
            withdrawals: [Pair(validator_creds, 0)],
            validity_range: validity_range,
            extra_signatories: [owner_hash],
          }
        }
  and {
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input1.output_reference,
      tx,
    ),
    token_lending.token_lending.spend(
      platform_address,
      None,
      [],
      input2.output_reference,
      tx,
    ),
    token_lending.token_lending.withdraw(
      platform_address,
      withdraw_redeemer,
      validator_creds,
      tx,
    ),
  }
}

test apply_params() {
  let address =
    Address {
      payment_credential: VerificationKey(
        #"04cb6fc6ebd4566bcdaba3f59803f9847e3feb9f18395af49bff5bfd",
      ),
      stake_credential: Some(
        Inline(
          VerificationKey(
            #"30e3b9955705ec401bc29bedc5a8da1995037044a1d299eb3e636bd2",
          ),
        ),
      ),
    }

  trace cbor.serialise(address)
  True
}
