use aiken/cbor
use aiken/crypto
use aiken/interval.{Finite, Interval, IntervalBound, PositiveInfinity}
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{add, from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction, placeholder,
}
use levvy/token_lending/functions.{borrow, cancel, foreclose, repay}
use levvy/token_lending/types.{
  BorrowDatum, BorrowDetails, CollateralDetails, LendDatum, LendDetails, NFTs,
  OutputIndexes, Tokens,
} as levvy_types
use utils/functions.{calculate_platform_fee} as utils_functions

test basic_token_borrow() {
  let validator_hash = #"0000"
  let validator_creds = Script(validator_hash)

  let main_hash = #"0001"
  let platform_address =
    Address {
      payment_credential: VerificationKey(main_hash),
      stake_credential: None,
    }
  let owner_hash1 = #"7706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"
  let borrower_hash =
    #"6706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"
  let input_datum =
    LendDatum(
      LendDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash1),
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
  let platform_fee =
    calculate_platform_fee(10000000, levvy_types.tokens_fee_percent)

  let input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1234",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(200000000 + platform_fee),
        InlineDatum(input_datum),
        None,
      ),
    }

  let datum_tag =
    input.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let output_datum =
    BorrowDatum(
      BorrowDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash1),
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
        tag: datum_tag,
      },
    )

  let output =
    Output(
      Address {
        payment_credential: Script(validator_hash),
        stake_credential: None,
      },
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 100),
      InlineDatum(output_datum),
      None,
    )

  let datum_tag = datum_tag
  let fee_output =
    Output(
      platform_address,
      from_lovelace(1250000 * 2),
      InlineDatum(datum_tag),
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

  let self =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            inputs: [input],
            outputs: [output, fee_output],
            validity_range: validity_range,
          }
        }
  let output_indexes =
    OutputIndexes {
      self_output_index: 0,
      fee_output_index: Some(1),
      change_index: None,
    }
  borrow(0, output_indexes, platform_address, Tokens, self)
}

test basic_nft_borrow() {
  let validator_hash = #"0000"
  let validator_creds = Script(validator_hash)
  let main_hash = #"0001"
  let platform_address =
    Address {
      payment_credential: VerificationKey(main_hash),
      stake_credential: None,
    }
  let owner_hash1 = #"7706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"
  let borrower_hash =
    #"6706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"
  let input_datum =
    LendDatum(
      LendDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash1),
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
        levvy_type: NFTs,
      },
    )

  let platform_fee =
    calculate_platform_fee(200000000, levvy_types.nfts_fee_percent)

  let input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1234",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(200000000 + platform_fee),
        InlineDatum(input_datum),
        None,
      ),
    }
  let datum_tag =
    input.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()
  let output_datum =
    BorrowDatum(
      BorrowDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash1),
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
        levvy_type: NFTs,
        tag: datum_tag,
      },
    )

  let output =
    Output(
      Address {
        payment_credential: Script(validator_hash),
        stake_credential: None,
      },
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 1),
      InlineDatum(output_datum),
      None,
    )

  let fee_output =
    Output(
      platform_address,
      from_lovelace(2500000 * 2),
      InlineDatum(datum_tag),
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

  let self =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            inputs: [input],
            outputs: [output, fee_output],
            validity_range: validity_range,
          }
        }
  let output_indexes =
    OutputIndexes {
      self_output_index: 0,
      fee_output_index: Some(1),
      change_index: None,
    }
  borrow(0, output_indexes, platform_address, NFTs, self)
}

test partial_borrow() {
  let validator_hash = #"0000"
  let validator_creds = Script(validator_hash)
  let main_hash = #"0001"
  let platform_address =
    Address {
      payment_credential: VerificationKey(main_hash),
      stake_credential: None,
    }

  let owner_hash1 = #"7706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"
  let borrower_hash =
    #"6706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"
  let input_datum =
    LendDatum(
      LendDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash1),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 100,
        },
        loan_amount: 1000000000,
        interest_amount: 50000000,
        loan_duration: 1_209_600_000,
        levvy_type: Tokens,
      },
    )

  let input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"1234",
        output_index: 0,
      },
      output: Output(
        Address { payment_credential: validator_creds, stake_credential: None },
        from_lovelace(10000000000),
        InlineDatum(input_datum),
        None,
      ),
    }
  let datum_tag =
    input.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let output_datum =
    BorrowDatum(
      BorrowDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash1),
          stake_credential: None,
        },
        borrower: Address {
          payment_credential: VerificationKey(borrower_hash),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 20,
        },
        loan_amount: 200000000,
        interest_amount: 10000000,
        loan_end_time: 1_209_600_000,
        levvy_type: Tokens,
        tag: datum_tag,
      },
    )

  let output =
    Output(
      Address {
        payment_credential: Script(validator_hash),
        stake_credential: None,
      },
      from_lovelace(10000000)
        |> add(#"2233", #"2233", 20),
      InlineDatum(output_datum),
      None,
    )

  let fee_output =
    Output(
      platform_address,
      from_lovelace(1250000 * 2),
      InlineDatum(datum_tag),
      None,
    )

  let script_change_datum =
    LendDatum(
      LendDetails {
        lender: Address {
          payment_credential: VerificationKey(owner_hash1),
          stake_credential: None,
        },
        collateral_details: CollateralDetails {
          policy_id: #"2233",
          asset_name: #"2233",
          collateral_amount: 80,
        },
        loan_amount: 800000000,
        interest_amount: 40000000,
        loan_duration: 1_209_600_000,
        levvy_type: Tokens,
      },
    )

  let platform_fee =
    calculate_platform_fee(40000000, levvy_types.tokens_fee_percent)

  let script_change_output =
    Output(
      Address {
        payment_credential: Script(validator_hash),
        stake_credential: None,
      },
      from_lovelace(800000000 + platform_fee),
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

  let self =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            inputs: [input],
            outputs: [output, fee_output, script_change_output],
            validity_range: validity_range,
          }
        }
  let output_indexes =
    OutputIndexes {
      self_output_index: 0,
      fee_output_index: Some(1),
      change_index: Some(2),
    }
  borrow(0, output_indexes, platform_address, Tokens, self)
}

test tokens_repay_test() {
  let validator_hash = #"0000"
  let validator_creds = Script(validator_hash)

  let validator_address =
    Address { payment_credential: validator_creds, stake_credential: None }

  let lender_address =
    Address {
      payment_credential: VerificationKey(#"0002"),
      stake_credential: None,
    }

  let borrower_hash =
    #"6706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"
  let borrow_details =
    BorrowDetails {
      lender: lender_address,
      borrower: validator_address,
      collateral_details: CollateralDetails {
        policy_id: #"706f6c6963796964",
        asset_name: #"61737365746e616d65",
        collateral_amount: 5_000_000,
      },
      loan_amount: 6_000_000,
      interest_amount: 500_000,
      loan_end_time: 830,
      levvy_type: Tokens,
      tag: "0001",
    }

  let borrow_output =
    Output {
      address: validator_address,
      value: assets.from_asset(
        assets.ada_policy_id,
        assets.ada_asset_name,
        6_000_000,
      ),
      datum: InlineDatum(BorrowDatum(borrow_details)),
      reference_script: None,
    }

  let input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"02",
        output_index: 0,
      },
      output: borrow_output,
    }

  let datum_tag =
    input.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let repay_output =
    Output {
      address: lender_address,
      value: from_lovelace(
        borrow_details.loan_amount + borrow_details.interest_amount,
      ),
      datum: InlineDatum(datum_tag),
      reference_script: None,
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

  let transaction =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            inputs: [input],
            outputs: [repay_output],
            withdrawals: [Pair(validator_creds, 0)],
            validity_range: validity_range,
            extra_signatories: [borrower_hash],
          }
        }

  let is_repay_success =
    repay(
      input_index: 0,
      output_indexes: OutputIndexes {
        self_output_index: 0,
        fee_output_index: None,
        change_index: None,
      },
      tx: transaction,
    )

  is_repay_success?
}

test nfts_repay_test() {
  let validator_hash = #"0000"
  let validator_creds = Script(validator_hash)

  let validator_address =
    Address { payment_credential: validator_creds, stake_credential: None }

  let lender_address =
    Address {
      payment_credential: VerificationKey(#"0002"),
      stake_credential: None,
    }

  let borrower_hash =
    #"6706af019148849e516f95ba630307a2018bb7bf03803eca5ed7ed2c"
  let borrow_details =
    BorrowDetails {
      lender: lender_address,
      borrower: validator_address,
      collateral_details: CollateralDetails {
        policy_id: #"706f6c6963796964",
        asset_name: #"61737365746e616d65",
        collateral_amount: 1,
      },
      loan_amount: 6_000_000,
      interest_amount: 500_000,
      loan_end_time: 830,
      levvy_type: NFTs,
      tag: "0001",
    }

  let borrow_output =
    Output {
      address: validator_address,
      value: assets.from_asset(
        assets.ada_policy_id,
        assets.ada_asset_name,
        6_000_000,
      ),
      datum: InlineDatum(BorrowDatum(borrow_details)),
      reference_script: None,
    }

  let input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"02",
        output_index: 0,
      },
      output: borrow_output,
    }

  let actual_lender_value =
    borrow_details.loan_amount + borrow_details.interest_amount

  let datum_tag =
    input.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()
  let repay_output =
    Output {
      address: lender_address,
      value: from_lovelace(actual_lender_value),
      datum: InlineDatum(datum_tag),
      reference_script: None,
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

  let transaction =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            inputs: [input],
            outputs: [repay_output],
            withdrawals: [Pair(validator_creds, 0)],
            validity_range: validity_range,
            extra_signatories: [borrower_hash],
          }
        }

  let is_repay_success =
    repay(
      input_index: 0,
      output_indexes: OutputIndexes {
        self_output_index: 0,
        fee_output_index: None,
        change_index: None,
      },
      tx: transaction,
    )

  is_repay_success?
}

test foreclose_test() {
  let owner_hash = #"0010"
  let borrower_hash = #"0000"
  let owner_address =
    Address {
      payment_credential: VerificationKey(owner_hash),
      stake_credential: None,
    }

  let borrow_details =
    BorrowDetails {
      lender: owner_address,
      borrower: Address {
        payment_credential: VerificationKey(borrower_hash),
        stake_credential: None,
      },
      collateral_details: CollateralDetails {
        policy_id: #"2233",
        asset_name: #"2233",
        collateral_amount: 20,
      },
      loan_amount: 6_000_000,
      interest_amount: 500_000,
      loan_end_time: 1900,
      levvy_type: Tokens,
      tag: "0001",
    }

  let datum = BorrowDatum(borrow_details)

  let range: Interval<Int> =
    Interval {
      lower_bound: IntervalBound {
        bound_type: Finite(2000),
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: Finite(3000),
        is_inclusive: True,
      },
    }

  let foreclose_output =
    Output {
      address: owner_address,
      value: assets.from_asset(#"2233", #"2233", 20),
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"01",
        output_index: 0,
      },
      output: foreclose_output,
    }

  let platform_address =
    Address {
      payment_credential: VerificationKey(#"0001"),
      stake_credential: None,
    }

  let datum_tag =
    input.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let fee_output =
    Output {
      address: platform_address,
      value: from_lovelace(62_500),
      datum: InlineDatum(datum_tag),
      reference_script: None,
    }

  let idx = 0

  let output_index =
    OutputIndexes {
      self_output_index: idx,
      fee_output_index: Some(1),
      change_index: None,
    }

  let output =
    Output(
      owner_address,
      from_lovelace(6_000_000)
        |> add(#"2233", #"2233", 20),
      NoDatum,
      None,
    )

  let tx =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            validity_range: range,
            inputs: [input],
            outputs: [output, fee_output],
          }
        }

  foreclose(idx, output_index, Tokens, tx)
}

test nft_foreclose_test() {
  let owner_hash = #"0010"
  let borrower_hash = #"0000"
  let owner_address =
    Address {
      payment_credential: VerificationKey(owner_hash),
      stake_credential: None,
    }

  let borrow_details =
    BorrowDetails {
      lender: owner_address,
      borrower: Address {
        payment_credential: VerificationKey(borrower_hash),
        stake_credential: None,
      },
      collateral_details: CollateralDetails {
        policy_id: #"2233",
        asset_name: #"2233",
        collateral_amount: 1,
      },
      loan_amount: 6_000_000,
      interest_amount: 500_000,
      loan_end_time: 1900,
      levvy_type: NFTs,
      tag: "001",
    }

  let datum = BorrowDatum(borrow_details)

  let range: Interval<Int> =
    Interval {
      lower_bound: IntervalBound {
        bound_type: Finite(2000),
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: Finite(3000),
        is_inclusive: True,
      },
    }

  let foreclose_output =
    Output {
      address: owner_address,
      value: assets.from_asset(#"2233", #"2233", 1),
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"01",
        output_index: 0,
      },
      output: foreclose_output,
    }

  let platform_address =
    Address {
      payment_credential: VerificationKey(#"0001"),
      stake_credential: None,
    }

  let datum_tag =
    input.output_reference
      |> cbor.serialise()
      |> crypto.blake2b_256()

  let fee_output =
    Output {
      address: platform_address,
      value: from_lovelace(75_000),
      datum: InlineDatum(datum_tag),
      reference_script: None,
    }

  let idx = 0

  let output_index =
    OutputIndexes {
      self_output_index: idx,
      fee_output_index: Some(1),
      change_index: None,
    }

  let output =
    Output(
      owner_address,
      from_lovelace(6_000_000)
        |> add(#"2233", #"2233", 1),
      NoDatum,
      None,
    )

  let tx =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            validity_range: range,
            inputs: [input],
            outputs: [output, fee_output],
          }
        }

  foreclose(idx, output_index, NFTs, tx)
}

test cancel_test() {
  let owner_hash = #"0001"

  let owner_address =
    Address {
      payment_credential: VerificationKey(owner_hash),
      stake_credential: None,
    }

  let lend_details =
    LendDetails {
      lender: owner_address,
      collateral_details: CollateralDetails {
        policy_id: #"706f6c6963796964",
        asset_name: #"61737365746e616d65",
        collateral_amount: 5_000_000,
      },
      loan_amount: 6_000_000,
      interest_amount: 500_000,
      loan_duration: 830,
      levvy_type: Tokens,
    }

  let lend_output =
    Output {
      address: owner_address,
      value: assets.from_asset(
        assets.ada_policy_id,
        assets.ada_asset_name,
        6_000_000,
      ),
      datum: InlineDatum(LendDatum(lend_details)),
      reference_script: None,
    }

  let lend_input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"01",
        output_index: 0,
      },
      output: lend_output,
    }

  let cancel_output =
    Output {
      address: owner_address,
      value: from_lovelace(6_000_000),
      datum: NoDatum,
      reference_script: None,
    }

  let tx =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            inputs: [lend_input],
            outputs: [cancel_output],
            extra_signatories: [owner_hash],
          }
        }

  let is_cancel_success =
    cancel(
      input_index: 0,
      output_indexes: OutputIndexes {
        self_output_index: 0,
        fee_output_index: None,
        change_index: None,
      },
      tx: tx,
    )
  is_cancel_success?
}

test nfts_cancel_test() {
  let owner_hash = #"0001"

  let owner_address =
    Address {
      payment_credential: VerificationKey(owner_hash),
      stake_credential: None,
    }

  let lend_details =
    LendDetails {
      lender: owner_address,
      collateral_details: CollateralDetails {
        policy_id: #"706f6c6963796964",
        asset_name: #"61737365746e616d65",
        collateral_amount: 1,
      },
      loan_amount: 6_000_000,
      interest_amount: 500_000,
      loan_duration: 830,
      levvy_type: NFTs,
    }

  let lend_output =
    Output {
      address: owner_address,
      value: assets.from_asset(#"706f6c6963796964", #"706f6c6963796964", 1),
      datum: InlineDatum(LendDatum(lend_details)),
      reference_script: None,
    }

  let lend_input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"01",
        output_index: 0,
      },
      output: lend_output,
    }

  let cancel_output =
    Output {
      address: owner_address,
      value: from_lovelace(6_000_000),
      datum: NoDatum,
      reference_script: None,
    }

  let tx =
    placeholder
      |> fn(tx) {
          Transaction {
            ..tx,
            inputs: [lend_input],
            outputs: [cancel_output],
            extra_signatories: [owner_hash],
          }
        }

  let is_cancel_success =
    cancel(
      input_index: 0,
      output_indexes: OutputIndexes {
        self_output_index: 0,
        fee_output_index: None,
        change_index: None,
      },
      tx: tx,
    )
  is_cancel_success?
}
