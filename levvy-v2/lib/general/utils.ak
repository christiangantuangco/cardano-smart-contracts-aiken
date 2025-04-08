use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite}
use aiken/primitive/bytearray
use cardano/address.{
  Address, Inline, PaymentCredential, Script, StakeCredential, VerificationKey,
}
use cardano/assets.{Value}
use cardano/transaction.{
  Datum, DatumHash, InlineDatum, Input, NoDatum, OutputReference, Transaction,
  ValidityRange,
}
use general/constants
use general/types.{MintDatum, PaymentDatum, PublicKeyHash} as general_types
use levvy_tokens/types.{PosixTime}

pub fn get_own_input(
  tx: Transaction,
  output_reference: OutputReference,
) -> Input {
  expect Some(input) =
    list.find(
      tx.inputs,
      fn(input) { input.output_reference == output_reference },
    )
  input
}

pub fn get_data(tx: Transaction, datum: Datum) -> Data {
  when datum is {
    NoDatum -> fail
    DatumHash(h) -> {
      expect Some(d) = dict.get(tx.datums, h)
      d
    }
    InlineDatum(d) -> d
  }
}

/// This is a special signing function.
/// Signer can not only be a pub key address, but also a script address.
/// Unfortunately extra signatories can only be pub key hashes, that means we need a special mechanism
/// to check whether a native or plutus script signed the transaction.
/// At first it sounds like a good idea to mint an ownership token, but when the other party accepts the bid or listing it will also receive the extra token.
/// This could lead to some unnecessary bloat after some time. So the better solution is to check for inputs.
/// If the transaction contains an input with the same script hash as the address in the datum we can assume the transaction was correctly signed.
/// Of course for plutus script addresses some constraints need to be added.
pub fn tx_signed_by_address(tx: Transaction, owner: Address) -> Bool {
  when owner.payment_credential is {
    VerificationKey(keyhash) -> tx_signed_by_key(tx, keyhash)
    Script(_) as payment_credential -> signed_with_input(tx, payment_credential)
  }
}

// Transaction signed by a key hash. This function does not support script signatures
pub fn tx_signed_by_key(tx: Transaction, keyhash: PublicKeyHash) -> Bool {
  list.has(tx.extra_signatories, keyhash)
}

pub fn signed_with_input(
  tx: Transaction,
  script_credential: PaymentCredential,
) -> Bool {
  list.any(
    tx.inputs,
    fn(input) { input.output.address.payment_credential == script_credential },
  )
}

pub fn is_address_valid(address: Address) -> Bool {
  is_payment_credential_valid(address.payment_credential) && is_stake_credential_valid(
    address.stake_credential,
  )
}

pub fn is_payment_credential_valid(
  payment_credential: PaymentCredential,
) -> Bool {
  when payment_credential is {
    VerificationKey(keyhash) -> is_key_length_valid(keyhash)
    Script(keyhash) -> is_key_length_valid(keyhash)
  }
}

pub fn is_stake_credential_valid(
  option_stake_credential: Option<StakeCredential>,
) -> Bool {
  when option_stake_credential is {
    Some(stake_credential) ->
      when stake_credential is {
        Inline(credential) ->
          when credential is {
            VerificationKey(keyhash) -> is_key_length_valid(keyhash)
            Script(keyhash) -> is_key_length_valid(keyhash)
          }
        _ -> True
      }
    None -> True
  }
}

pub fn is_key_length_valid(key: ByteArray) -> Bool {
  let key_length = 28
  bytearray.length(key) == key_length
}

// Address Key Functions
pub fn is_payment_key_equal(address_1: Address, address_2: Address) -> Bool {
  let payment_key_1 = address_1.payment_credential
  let payment_key_2 = address_2.payment_credential
  payment_key_1 == payment_key_2
}

/// We expect outputs to be unique. Each output is tagged with a datum.
/// We also expect the datum to be inline
pub fn value_paid_to_with_datum(
  tx: Transaction,
  address: Address,
  payment_datum: PaymentDatum,
) -> Value {
  when
    list.filter(
      tx.outputs,
      fn(output) {
        output.address == address && output.datum == InlineDatum(payment_datum)
      },
    )
  is {
    [output] -> output.value
    _ -> fail
  }
}

/// We expect outputs to be unique for the mint. Each output is tagged with a datum.
/// We also expect the datum to be inline
pub fn value_paid_to_with_mint_datum(
  tx: Transaction,
  address: Address,
  mint_datum: MintDatum,
) -> Value {
  when
    list.filter(
      tx.outputs,
      fn(output) {
        output.address == address && output.datum == InlineDatum(mint_datum)
      },
    )
  is {
    [output] -> output.value
    _ -> fail
  }
}

// Fee Functions
pub fn paid_fee(
  tx: Transaction,
  address: Address,
  lovelaces: Int,
  payment_datum: PaymentDatum,
) -> Bool {
  let paid_lovelaces =
    assets.lovelace_of(value_paid_to_with_datum(tx, address, payment_datum))
  paid_lovelaces >= lovelaces
}

// This function is used to check if the asset name is valid and not a reference NFT, Royalty Token, or IP Token
pub fn is_asset_label_valid(asset_name: ByteArray) -> Bool {
  let used_label = bytearray.take(asset_name, constants.label_length)
  let is_valid_name =
    used_label != constants.label_100 && used_label != constants.label_500 && used_label != constants.label_600
  is_valid_name
}

// Time functions
pub fn tx_submitted_after(range: ValidityRange, time: PosixTime) -> Bool {
  when range.lower_bound.bound_type is {
    Finite(now) -> now > time
    _ -> False
  }
}

pub fn tx_submitted_before(range: ValidityRange, time: PosixTime) -> Bool {
  when range.upper_bound.bound_type is {
    Finite(upper_bound) -> upper_bound < time
    _ -> False
  }
}

// Value functions
pub fn is_value_greater_than_or_equal_to(value_1: Value, value_2: Value) -> Bool {
  let difference_value =
    assets.negate(value_2)
      |> assets.merge(value_1)

  let flattened_difference_value = assets.flatten(difference_value)

  // Negate value 2 and add it to value 1, then check to ensure all amounts are greater then or equal to 0
  let value_less_then =
    list.any(
      flattened_difference_value,
      fn(flat_value) {
        let (_, _, amount) = flat_value
        amount < 0
      },
    )
  !value_less_then
}

pub fn percent_of_value(
  input_value: Value,
  percent: Int,
  precision: Int,
) -> Value {
  let flattened_value = assets.flatten(input_value)

  list.reduce(
    flattened_value,
    assets.zero,
    fn(aggregated_value, flat_value) {
      let (policy, asset, amount) = flat_value
      let percent_amount = amount * percent / ( 100 * precision )
      let add_value = assets.from_asset(policy, asset, percent_amount)
      assets.merge(aggregated_value, add_value)
    },
  )
}

// Returns true if the value has only ada
pub fn value_has_only_lovelace(val: Value) -> Bool {
  expect [Pair(policy1, _amount1)] =
    val
      |> assets.to_dict
      |> dict.to_pairs()

  (policy1 == assets.ada_policy_id)?
}
