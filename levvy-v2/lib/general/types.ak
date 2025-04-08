use aiken/collection/dict.{Dict}
use aiken/crypto.{Blake2b_224, Hash, Script, VerificationKey}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{OutputReference}

pub type PublicKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type ScriptHash =
  Hash<Blake2b_224, Script>

pub type PaymentDatum {
  output_reference: OutputReference,
}

pub type MintDatum {
  policy_id: PolicyId,
  asset_name: AssetName,
}

// CIP-68 Datum
pub type DatumMetadata {
  metadata: Metadata,
  version: Int,
  extra: Data,
}

pub type Metadata =
  Dict<ByteArray, Data>
